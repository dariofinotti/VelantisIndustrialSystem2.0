"""
CumulusCI tasks for the Velantis Partner Community (Aura Experience Cloud site).

The site metadata lives in ``unpackaged/post_partner_site`` with org-specific values
replaced by placeholders so the repo never stores a real username/email/record Id:

    __SITE_ADMIN_USERNAME__      -> CustomSite siteAdmin / siteGuestRecordDefaultOwner
    __NETWORK_EMAIL_SENDER__     -> Network emailSenderAddress (immutable after creation)
    __QUOTE_ALL_LISTVIEW_ID__    -> Id of the "All Quotes" list view (hero button link)

``DeployPartnerSite`` renders those placeholders into a temporary copy and deploys it,
so the files in the repo are never modified. ``RetrievePartnerSite`` does the reverse:
it retrieves the site from an org and re-applies the placeholders.

CLI calls use ``org_config.username`` (never the access token); REST is only used for
the small SOQL lookups needed to resolve the placeholders.
"""
import os
import re
import shutil
import subprocess
import tempfile

import requests

try:
    from cumulusci.core.exceptions import CommandException, TaskOptionsError
    from cumulusci.core.tasks import BaseTask
except ImportError:  # pragma: no cover - allows import outside CumulusCI
    BaseTask = object
    TaskOptionsError = Exception
    CommandException = Exception

DEFAULT_PATH = "unpackaged/post_partner_site"
DEFAULT_SITE = "DFBYOPartner"
DEFAULT_BUNDLE = "DFBYOPartner1"
TEXT_EXTENSIONS = (".xml", ".json")

PLACEHOLDER_ADMIN = "__SITE_ADMIN_USERNAME__"
PLACEHOLDER_EMAIL = "__NETWORK_EMAIL_SENDER__"
PLACEHOLDER_LISTVIEW = "__QUOTE_ALL_LISTVIEW_ID__"

SFDX_PROJECT = '{"packageDirectories":[{"path":"src","default":true}],"sourceApiVersion":"67.0"}'


def _is_true(value):
    return str(value).strip().lower() in ("true", "1", "yes", "y")


class _PartnerSiteBase(BaseTask):
    def _api_version(self):
        return (
            getattr(self.org_config, "api_version", None)
            or getattr(self.project_config, "project__package__api_version", None)
            or "67.0"
        )

    def _soql(self, query):
        url = f"{self.org_config.instance_url}/services/data/v{self._api_version()}/query"
        headers = {"Authorization": f"Bearer {self.org_config.access_token}"}
        response = requests.get(url, headers=headers, params={"q": query}, timeout=60)
        response.raise_for_status()
        return response.json().get("records", [])

    def _sf(self, args):
        cmd = ["sf"] + args + ["--target-org", self.org_config.username]
        self.logger.info("Running: " + " ".join(cmd))
        result = subprocess.run(cmd, capture_output=True, text=True)
        if result.stdout:
            self.logger.info(result.stdout)
        if result.returncode != 0:
            raise CommandException(
                f"sf command failed ({result.returncode}):\n{result.stderr}\n{result.stdout}"
            )

    def _walk_text_files(self, root):
        for dirpath, _dirs, files in os.walk(root):
            for name in files:
                if name.lower().endswith(TEXT_EXTENSIONS):
                    yield os.path.join(dirpath, name)

    def _replace_in_tree(self, root, mapping):
        changed = 0
        for path in self._walk_text_files(root):
            with open(path, "r", encoding="utf-8") as handle:
                text = handle.read()
            new_text = text
            for old, new in mapping.items():
                new_text = new_text.replace(old, new)
            if new_text != text:
                with open(path, "w", encoding="utf-8") as handle:
                    handle.write(new_text)
                changed += 1
        return changed


class DeployPartnerSite(_PartnerSiteBase):
    """Deploy the Velantis Partner Community (Network, CustomSite, ExperienceBundle,
    navigation menus, theme images and logo) to the target org.

    Prerequisites in the target org: Digital Experiences enabled with a My Domain, and the
    Account / Opportunity / Quote objects visible to the profiles or permission sets
    your partner users will use. The repo files are never modified (placeholders are
    rendered into a temporary copy)."""

    task_options = {
        "path": {
            "description": f"Source folder (default: {DEFAULT_PATH})",
            "required": False,
        },
        "site_name": {
            "description": f"Network / CustomSite name (default: {DEFAULT_SITE})",
            "required": False,
        },
        "check_only": {
            "description": "Validate only (sf project deploy validate); nothing is changed in the org. Default: False",
            "required": False,
        },
        "publish": {
            "description": "Publish the site after a successful deploy (sf community publish). Default: False",
            "required": False,
        },
        "wait": {
            "description": "Minutes to wait for the deployment (default: 30)",
            "required": False,
        },
    }

    def _resolve_tokens(self, site_name):
        username = self.org_config.username

        email = ""
        safe_site = site_name.replace("'", "''")
        records = self._soql(f"SELECT EmailSenderAddress FROM Network WHERE Name = '{safe_site}' LIMIT 1")
        if records and records[0].get("EmailSenderAddress"):
            email = records[0]["EmailSenderAddress"]
            self.logger.info("Network already exists - keeping its existing emailSenderAddress.")
        else:
            safe_user = username.replace("'", "''")
            users = self._soql(f"SELECT Email FROM User WHERE Username = '{safe_user}' LIMIT 1")
            if not users:
                raise TaskOptionsError(f"Could not read the email of user {username}.")
            email = users[0]["Email"]

        listview = self._soql(
            "SELECT Id FROM ListView WHERE SobjectType = 'Quote' AND DeveloperName = 'All' LIMIT 1"
        )
        if listview:
            listview_id = listview[0]["Id"]
        else:
            listview_id = "Default"
            self.logger.warning("'All Quotes' list view not found - the hero button will use 'Default'.")

        return {
            PLACEHOLDER_ADMIN: username,
            PLACEHOLDER_EMAIL: email,
            PLACEHOLDER_LISTVIEW: listview_id,
        }

    def _run_task(self):
        path = self.options.get("path", DEFAULT_PATH)
        site_name = self.options.get("site_name", DEFAULT_SITE)
        check_only = _is_true(self.options.get("check_only", False))
        publish = _is_true(self.options.get("publish", False))
        wait = str(self.options.get("wait", 30))

        source = os.path.join(self.project_config.repo_root, path)
        if not os.path.isdir(source):
            raise TaskOptionsError(f"Source folder not found: {source}")

        tokens = self._resolve_tokens(site_name)
        tmp = tempfile.mkdtemp(prefix="vel_partner_site_")
        try:
            src = os.path.join(tmp, "src")
            shutil.copytree(source, src)
            with open(os.path.join(tmp, "sfdx-project.json"), "w", encoding="utf-8") as handle:
                handle.write(SFDX_PROJECT)
            count = self._replace_in_tree(src, tokens)
            self.logger.info(f"Rendered placeholders in {count} file(s).")

            verb = "validate" if check_only else "start"
            cwd = os.getcwd()
            os.chdir(tmp)
            try:
                self._sf(["project", "deploy", verb, "--source-dir", "src", "--wait", wait])
            finally:
                os.chdir(cwd)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)

        if publish and not check_only:
            self._sf(["community", "publish", "--name", site_name])
            self.logger.info(f"Published site {site_name}.")
        elif not check_only:
            self.logger.info(
                "Deployed to the Experience Builder draft. Publish from Builder, or re-run with -o publish True."
            )


class RetrievePartnerSite(_PartnerSiteBase):
    """Retrieve the Velantis Partner Community from an org into ``unpackaged/post_partner_site``
    and re-apply the placeholders so no username, email or record Id is committed.

    The experiences/<bundle> folder is replaced with the org's current version; review
    ``git diff`` before committing."""

    task_options = {
        "path": {"description": f"Target folder (default: {DEFAULT_PATH})", "required": False},
        "site_name": {"description": f"Network / CustomSite name (default: {DEFAULT_SITE})", "required": False},
        "bundle_name": {"description": f"ExperienceBundle name (default: {DEFAULT_BUNDLE})", "required": False},
        "navigation_menus": {
            "description": "Comma-separated NavigationMenu names",
            "required": False,
        },
        "static_resources": {
            "description": "Comma-separated StaticResource names",
            "required": False,
        },
        "content_assets": {
            "description": "Comma-separated ContentAsset names",
            "required": False,
        },
    }

    def _run_task(self):
        path = self.options.get("path", DEFAULT_PATH)
        site = self.options.get("site_name", DEFAULT_SITE)
        bundle = self.options.get("bundle_name", DEFAULT_BUNDLE)
        menus = self._csv("navigation_menus", f"SFDC_Default_Navigation_{site},Default_User_Profile_Menu")
        statics = self._csv(
            "static_resources",
            "VEL_partner_header_bg,VEL_partner_hero_bg",
        )
        assets = self._csv("content_assets", "VEL_logo_transparent")

        # The CustomSite points at an auto-generated SNA static resource; include it.
        site_dir = os.path.join(self.project_config.repo_root, path, "sites", f"{site}.site-meta.xml")
        if os.path.isfile(site_dir):
            with open(site_dir, "r", encoding="utf-8") as handle:
                match = re.search(r"<serverIsDown>([^<]+)</serverIsDown>", handle.read())
            if match and match.group(1) not in statics:
                statics.append(match.group(1))

        metadata = (
            [f"ExperienceBundle:{bundle}", f"Network:{site}", f"CustomSite:{site}"]
            + [f"NavigationMenu:{m}" for m in menus]
            + [f"StaticResource:{s}" for s in statics]
            + [f"ContentAsset:{a}" for a in assets]
        )

        tmp = tempfile.mkdtemp(prefix="vel_partner_site_retrieve_")
        try:
            with open(os.path.join(tmp, "sfdx-project.json"), "w", encoding="utf-8") as handle:
                handle.write(SFDX_PROJECT)
            os.makedirs(os.path.join(tmp, "src"))
            cwd = os.getcwd()
            os.chdir(tmp)
            try:
                self._sf(["project", "retrieve", "start", "--metadata", *metadata, "--output-dir", "src", "--wait", "30"])
            finally:
                os.chdir(cwd)

            src = os.path.join(tmp, "src")
            # Re-apply placeholders so nothing org-specific is stored in the repo.
            self._tokenize(src, site)

            dest = os.path.join(self.project_config.repo_root, path)
            exp_dest = os.path.join(dest, "experiences", bundle)
            if os.path.isdir(exp_dest):
                shutil.rmtree(exp_dest)
            for entry in os.listdir(src):
                if entry in ("package.xml",):
                    continue
                src_entry = os.path.join(src, entry)
                dest_entry = os.path.join(dest, entry)
                if os.path.isdir(src_entry):
                    shutil.copytree(src_entry, dest_entry, dirs_exist_ok=True)
                else:
                    shutil.copy2(src_entry, dest_entry)
        finally:
            shutil.rmtree(tmp, ignore_errors=True)
        self.logger.info(f"Retrieved Partner Community into {path}. Review `git diff` before committing.")

    def _csv(self, option, default):
        return [v.strip() for v in str(self.options.get(option, default)).split(",") if v.strip()]

    def _tokenize(self, root, site):
        for filepath in self._walk_text_files(root):
            with open(filepath, "r", encoding="utf-8") as handle:
                text = handle.read()
            new = text
            if filepath.endswith(".site-meta.xml"):
                new = re.sub(r"(<siteAdmin>)[^<]+", rf"\1{PLACEHOLDER_ADMIN}", new)
                new = re.sub(r"(<siteGuestRecordDefaultOwner>)[^<]+", rf"\1{PLACEHOLDER_ADMIN}", new)
            if filepath.endswith(".network-meta.xml"):
                new = re.sub(r"(<emailSenderAddress>)[^<]+", rf"\1{PLACEHOLDER_EMAIL}", new)
            if filepath.endswith(".json"):
                new = re.sub(
                    rf'(?:https?://[^"/]+)?/{re.escape(site)}/s/quote/Quote/00B[A-Za-z0-9]{{12,15}}',
                    f"/{site}/s/quote/Quote/{PLACEHOLDER_LISTVIEW}",
                    new,
                )
            if new != text:
                with open(filepath, "w", encoding="utf-8") as handle:
                    handle.write(new)
