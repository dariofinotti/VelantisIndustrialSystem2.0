# Velantis Industrial Systems — Deployment Guide

> **Target:** Any Salesforce Revenue Cloud org (QuantumBit or standalone RLM).  
> **Release:** Summer '26 (API v67.0 / Release 262).  
> **Estimated time:** 20–30 min on a fresh scratch org; ~10 min on an existing QB org.

---

## Overview

The Velantis Industrial Systems demo builds a full Revenue Cloud catalog covering:

- **VELPACK G1 Packaging System** — configurable pharmaceutical packaging bundle with CML constraint rules (T&T, film, compliance, maintenance)
- **PrecisionBeam+ Laser Cutting System** — configurable industrial laser bundle (frame sizing, laser power, automation, gas supply)
- **VelTherma STP Sterilizer** — configurable pharmaceutical sterilizer bundle
- **27 standalone and component products** across 4 catalog categories
- **Full DRO orchestration** — 15 decomposition rules, 13 step definitions, 12 cross-group dependencies
- **Lightning Experience theme** — Velantis branding (deep navy `#1A2B4A`, custom logo)
- **CML recommendation rule** — recommends Remote Monitoring Platform when Laser bundle is in cart

---

## Prerequisites

Before starting, confirm:

| Requirement | Check |
|---|---|
| `sf` CLI installed and authenticated to target org | `sf org display --target-org <alias>` |
| CumulusCI installed and org registered | `cci org info <alias>` |
| SFDMU v5.0.0+ installed | `sf plugins` → `sfdmu` |
| Revenue Cloud / RLM base org setup complete | Configurator enabled, standard PSGs assigned |
| `constraints_data` feature flag enabled (for CML import) | See §8 |

---

## File Map

All files listed below are relative to the repository root. They ship inside the main branch — no separate download required.

```
force-app/main/default/
  staticresources/VEL_*.png + *.resource-meta.xml   — 42 product images (84 files)
  contentassets/VEL_logo_rectangle.asset + meta      — Velantis logo
  brandingSets/LEXTHEMINGVelantis.brandingSet-meta.xml
  lightningExperienceThemes/VELTheme.lightningExperienceTheme-meta.xml
  flows/VEL_Maintenance_Contract_DRO_Task.flow-meta.xml

datasets/sfdmu/vel/en-US/
  vel-pcm/          — Product catalog (52 products, attributes, component groups)
  vel-pricing/      — Pricebook entries (54 rows), price adjustment schedules
  vel-product-images/ — DisplayUrl patch
  vel-dro/          — DRO config (decomp rules, steps, workspace, jeopardy rules)

datasets/constraints/vel/
  VelantisPackaging/ — VELPACK G1 CML model + compiled blob
  VelantisLaser/     — PrecisionBeam+ CML model + compiled blob

scripts/apex/vel/
  create_vel_pcm_attributes.apex        — Attribute chain (idempotent)
  create_vel_pcm_bundle_structure.apex  — Bundle PCG + PRC records (idempotent)
  create_vel_stp_pcm_additions.apex     — STP bundle additions (idempotent)
  create_vel_product_category_products.apex — Catalog links (idempotent)
  update_vel_pfdr_rules.apex            — PFDR re-save workaround (idempotent)

scripts/cml/
  VelantisPackaging.cml   — Packaging constraint model source
  VelantisLaser.cml       — Laser constraint model source
```

---

## Deployment Steps

### Step 1 — Set variables

```bash
SF_ALIAS="<your-sf-cli-alias>"          # e.g. salesforce-brc260-5gj5d0
CCI_ALIAS="<your-cci-alias>"            # e.g. BRC260CursorClaude
```

All subsequent commands use `$SF_ALIAS` and `$CCI_ALIAS`.

---

### Step 2 — Deploy Salesforce Metadata

Deploys the Velantis Lightning theme, branding, logo, product images, and the DRO orchestration flow.

```bash
# Static resource images (42 products × 2 files = 84 files)
sf project deploy start \
  --metadata "StaticResource" \
  --target-org $SF_ALIAS \
  --ignore-warnings

# Theme, branding set, logo content asset
sf project deploy start \
  --metadata "LightningExperienceTheme:VELTheme,BrandingSet:LEXTHEMINGVelantis,ContentAsset:VEL_logo_rectangle" \
  --target-org $SF_ALIAS

# DRO orchestration flow
sf project deploy start \
  --metadata "Flow:VEL_Maintenance_Contract_DRO_Task" \
  --target-org $SF_ALIAS
```

> **Note:** Deploying all `StaticResource` metadata also deploys QB and EPRO images if they exist in your `force-app`. To deploy only Velantis images, use:
> ```bash
> sf project deploy start \
>   --metadata $(ls force-app/main/default/staticresources/VEL_*.resource-meta.xml | \
>     sed 's|.*/||; s|\.resource-meta\.xml||; s|^|StaticResource:|' | tr '\n' ',') \
>   --target-org $SF_ALIAS
> ```

---

### Step 3 — Load PCM Data (Products, Catalog, Selling Models)

```bash
SF_TEMP_SHOW_SECRETS=true cci task run insert_vel_pcm_data --org $CCI_ALIAS
```

Loads: 52 `Product2` records (27 saleable + 5 DRO stubs + others), `ProductCatalog`, `ProductCategory`, `ProductCategoryProduct`, `ProductSellingModel`, `ProductSellingModelOption`, `ProrationPolicy`, `ProductRelationshipType`.

---

### Step 4 — Create Attribute Chain (Apex — required)

SFDMU's Bulk API silently drops attribute records in some org types. Run this Apex script instead:

```bash
sf apex run \
  --file scripts/apex/vel/create_vel_pcm_attributes.apex \
  --target-org $SF_ALIAS
```

Creates: `AttributePicklist` (4), `AttributePicklistValue` (12), `AttributeDefinition` (5), `AttributeCategory` (2), `AttributeCategoryAttribute` (5), `ProductClassification` (3), `ProductClassificationAttr` (5), `ProductAttributeDefinition` (5). Sets `Product2.BasedOnId` for the two configurable bundles.

---

### Step 5 — Create Bundle Structure (Apex — required)

```bash
sf apex run \
  --file scripts/apex/vel/create_vel_pcm_bundle_structure.apex \
  --target-org $SF_ALIAS
```

Creates: 21 `ProductComponentGroup` records and 38 `ProductRelatedComponent` records across three bundles (VELPACK G1, PrecisionBeam+, VelTherma STP), including the nested Machine Configuration group for the laser system.

---

### Step 6 — Create STP Bundle Additions (Apex)

```bash
sf apex run \
  --file scripts/apex/vel/create_vel_stp_pcm_additions.apex \
  --target-org $SF_ALIAS
```

Creates: `ATTR-VEL-STP-NUM-DOORS` attribute chain and service slots for the VelTherma STP sterilizer bundle.

---

### Step 7 — Create Catalog Links (Apex — required)

```bash
sf apex run \
  --file scripts/apex/vel/create_vel_product_category_products.apex \
  --target-org $SF_ALIAS
```

Creates `ProductCategoryProduct` records linking all 27 saleable products to their catalog categories. Also ensures `IsSoldOnlyWithOtherProds = false` for service products so they appear in the catalog standalone.

---

### Step 8 — Load Pricing

```bash
SF_TEMP_SHOW_SECRETS=true cci task run insert_vel_pricing_data --org $CCI_ALIAS
```

Loads: 54 `PricebookEntry` rows (USD, Standard Price Book), `PriceAdjustmentSchedule`, `AttributeBasedAdjustment`, `AttributeAdjustmentCondition`.

> If re-running on an existing org, run `delete_vel_pricing_data` first:
> ```bash
> SF_TEMP_SHOW_SECRETS=true cci task run delete_vel_pricing_data --org $CCI_ALIAS
> ```

---

### Step 9 — Patch Product Images (DisplayUrl)

```bash
SF_TEMP_SHOW_SECRETS=true cci task run insert_vel_product_image_data --org $CCI_ALIAS
```

Updates `Product2.DisplayUrl` for all 27 saleable products to point to their `/resource/VEL_*` static resource.

> If SFDMU's Update operation processes 0 records (known Bulk API issue), patch manually:
> ```bash
> sf apex run \
>   --file scripts/apex/vel/create_vel_product_category_products.apex \
>   --target-org $SF_ALIAS
> ```

---

### Step 10 — Load DRO Configuration

```bash
SF_TEMP_SHOW_SECRETS=true cci task run insert_vel_dro_data --org $CCI_ALIAS
```

Loads: `ProductFulfillmentScenario` (5), `FulfillmentStepDefinitionGroup` (5), `FulfillmentStepDefinition` (13), `FulfillmentStepDependencyDef` (12), `FulfillmentWorkspace`, `FulfillmentWorkspaceItem` (13), `FulfillmentTaskAssignmentRule` (10), `FulfillmentFalloutRule` (4), `FulfillmentStepJeopardyRule` (3), `ProductFulfillmentDecompRule` (15).

---

### Step 11 — Re-save Decomposition Rules (Apex workaround)

Platform bug: `ProductFulfillmentDecompRule` records must be re-saved after insert for the DRO engine to recognize them.

```bash
sf apex run \
  --file scripts/apex/vel/update_vel_pfdr_rules.apex \
  --target-org $SF_ALIAS
```

---

### Step 12 — Import CML Constraint Models

> Requires `constraints` and `constraints_data` feature flags enabled in `cumulusci.yml`.

**Option A — Via CCI (recommended):**

```bash
# Enable the vel feature flag in your cumulusci.yml custom section:
#   vel: true
#   constraints_data: true

SF_TEMP_SHOW_SECRETS=true cci flow run prepare_constraints --org $CCI_ALIAS
```

Steps 14–15 of `prepare_constraints` import the Velantis Packaging and Laser CML models (guarded by `custom__vel`).

**Option B — Individually:**

```bash
SF_TEMP_SHOW_SECRETS=true cci task run import_vel_packaging_cml --org $CCI_ALIAS
SF_TEMP_SHOW_SECRETS=true cci task run import_vel_laser_cml --org $CCI_ALIAS
```

After import, activate the constraint versions in the org UI:
**Setup → Revenue Lifecycle Management → Product Configurator → Expression Sets**

---

### Step 13 — Activate Lightning Theme

In Salesforce Setup:
1. Go to **Themes and Branding**
2. Select **Velantis Theme** → **Activate**

Or deploy via Metadata API (the `VELTheme` metadata activates on deploy in some orgs — verify in Setup after Step 2).

---

### Step 14 — Deploy Margin Analysis Component

Deploys the `velQuoteMargin` LWC and its Apex controller, then pushes the updated Quote Record Page layout that adds the **Margin Analysis** tab.

```bash
# Deploy Apex controller + LWC
sf project deploy start \
  --source-dir force-app/main/default/classes/VelQuoteMarginController.cls \
  --source-dir force-app/main/default/lwc/velQuoteMargin \
  --target-org $SF_ALIAS

# Assemble and deploy the updated Quote Record Page (adds Margin Analysis tab)
SF_TEMP_SHOW_SECRETS=true cci task run assemble_and_deploy_ux \
  -o metadata_type flexipages \
  -o metadata_name "RLM_Quote_Record_Page.flexipage-meta.xml"
```

> **Note:** The `insert_vel_pricing_data` task (Step 8) already loads `CostBook` and `CostBookEntry` records required by this component. Run Step 8 first.

The component displays per-line **margin amount** and **margin %** with colour-coded badges:

| Badge | Threshold |
|---|---|
| 🟢 Green | ≥ 30% |
| 🟡 Amber | ≥ 15% and < 30% |
| 🔴 Red | ≥ 0% and < 15% |
| ⬛ Negative | < 0% (loss-making) |

---

## Verification Checklist

After all steps complete, verify in the org:

- [ ] **Product Catalog** — navigate to Revenue Cloud → Products → Catalog → `VEL` catalog; confirm 4 categories visible with products
- [ ] **Bundle configurator** — open VELPACK G1; confirm packaging configuration attributes (Config Type, Compliance, Annual Capacity) appear and CML rules trigger
- [ ] **Laser configurator** — open PrecisionBeam+; confirm Machine Size and Laser Power attributes drive frame/source selection
- [ ] **Product images** — product cards show Velantis imagery (not placeholder icons)
- [ ] **Theme** — Lightning header shows Velantis navy branding and logo
- [ ] **Pricing** — VELPACK G1 bundle has USD One-Time price; software products show Evergreen Monthly pricing
- [ ] **DRO** — create a test order containing VEL-LSR-BDL; confirm fulfillment decomposition rules fire
- [ ] **Margin Analysis** — open a Quote record containing Velantis products; confirm the **Margin Analysis** tab shows per-line cost, margin $, margin % with coloured badges and a quote-total row

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Attributes not visible in configurator | Run Step 4 (`create_vel_pcm_attributes.apex`) — SFDMU may have silently skipped attribute records |
| Bundle components not showing in product structure | Run Step 5 (`create_vel_pcm_bundle_structure.apex`) |
| Products not visible in catalog | Run Step 7 (`create_vel_product_category_products.apex`) — checks `IsSoldOnlyWithOtherProds` |
| CML error "no associations for constraint version" | In the Expression Set UI, add associations: packaging type → VELPACK product; laser type → laser bundle |
| Pricing insert fails with duplicate key | Run `delete_vel_pricing_data` first, then re-run Step 8 |
| SFDMU error `INVALID_AUTH_HEADER` | Re-authenticate: `sf org login web --alias $SF_ALIAS`, then re-run with `SF_TEMP_SHOW_SECRETS=true` |
| DRO rules not triggering | Run Step 11 (`update_vel_pfdr_rules.apex`) — PFDR records need a re-save post-insert |
| Image upload fails (413 / request too large) | Deploy static resources in smaller batches by prefix (`VEL_CUT_*`, `VEL_LSR_*`, etc.) |

---

## Re-running on an Existing Org

All Apex scripts are **idempotent** — safe to run multiple times; they skip records that already exist.

SFDMU plans use `Upsert` operations (keyed on stable external IDs) except:
- `vel-pricing` `PricebookEntry` uses `Insert` — run `delete_vel_pricing_data` first if re-loading
- `vel-product-images` `Product2` uses `Update` — always safe

---

## CCI Feature Flag Reference

To enable Velantis tasks in automated flows, add to your `cumulusci.yml` project custom section:

```yaml
project:
  custom:
    vel: true                # gates import_vel_packaging_cml / import_vel_laser_cml in prepare_constraints
    constraints: true        # gates constraint Permission Set assignment + metadata deploy
    constraints_data: true   # gates CML import steps
```

---

## CML Source Files

The compiled blobs in `datasets/constraints/vel/*/blobs/` contain internal org IDs from the source org. The `import_cml` task re-wires associations in the target org automatically.

If you need to re-compile from scratch:
1. Create a new Expression Set in the target org (Setup → Expression Sets)
2. Paste the source CML from `scripts/cml/VelantisPackaging.cml` or `VelantisLaser.cml`
3. Save and activate — the platform compiles the CML and generates a new blob
4. Export using: `SF_TEMP_SHOW_SECRETS=true cci task run export_vel_packaging_cml --org $CCI_ALIAS`
