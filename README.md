# Velantis Industrial Systems 2.0

> **Standalone demo package** — deploys on top of an existing QuantumBit Revenue Cloud org.  
> **Release:** Summer '26 (API v67.0 / Release 262).  
> **Estimated time:** 20–30 min on a fresh org; ~10 min on an existing QB org.

## Demo script link
<https://salesforce.enterprise.slack.com/docs/T01G0063H29/F0BLYCUM8BW>

---

## What's in this repo

This package adds the full **Velantis Industrial Systems** industry demo on top of a QuantumBit Revenue Cloud org. It does not include any QuantumBit or foundation metadata — only Velantis-specific content.

| Area | Contents |
|---|---|
| **Product Catalog** | 27 saleable products + 5 DRO stubs across 3 configurable bundles (VELPACK G1 packaging, PrecisionBeam+ laser, VelTherma STP sterilizer) |
| **Attributes** | 5 attribute chains (Config Type, Compliance, Machine Size, Laser Power, Num Doors), 4 picklists, 12 values |
| **Pricing** | 54 PricebookEntry rows (USD, Standard Price Book), attribute-based adjustment schedules, CostBook + 47 CostBookEntry records |
| **DRO orchestration** | 15 decomposition rules, 13 step definitions, 12 cross-group dependencies, 5 scenarios, workspace |
| **CML constraints** | VelantisPackaging + VelantisLaser models + compiled blobs |
| **Product images** | 42 PNG static resources (`VEL_*`) + Velantis logo content asset |
| **Lightning theme** | Velantis branding (deep navy `#1A2B4A`) + branding set |
| **Margin Analysis** | `velQuoteMargin` LWC on the Quote record page — per-line margin % and $ with colour-coded badges |
| **DRO flow** | `VEL_Maintenance_Contract_DRO_Task` orchestration flow |

### Repository layout

```
force-app/main/default/
  classes/VelQuoteMarginController.cls + meta    — Apex controller for margin analysis
  lwc/velQuoteMargin/                            — Margin Analysis LWC (SLDS2)
  staticresources/VEL_*.png + *.resource-meta.xml— 42 product images
  contentassets/VEL_logo_rectangle.*             — Velantis logo
  brandingSets/LEXTHEMINGVelantis.*
  lightningExperienceThemes/VELTheme.*
  flows/VEL_Maintenance_Contract_DRO_Task.*

unpackaged/post_ux/flexipages/
  RLM_Quote_Record_Page.flexipage-meta.xml       — Pre-assembled Quote page with Margin Analysis tab

datasets/sfdmu/vel/en-US/
  vel-pcm/          — Product catalog (52 products, attributes, component groups)
  vel-pricing/      — Pricebook entries (54 rows), cost book (47 entries), adjustments
  vel-product-images/— DisplayUrl patch
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

tasks/
  rlm_sfdmu.py     — CCI task class for SFDMU data loading
  rlm_cml.py       — CCI task class for CML import/export
```

### Margin Analysis badges

| Badge | Threshold |
|---|---|
| 🟢 Green | ≥ 30% |
| 🟡 Amber | ≥ 15% and < 30% |
| 🔴 Red | ≥ 0% and < 15% |
| ⬛ Negative | < 0% (loss-making) |

---

## Prerequisites

Before starting, confirm:

| Requirement | Check |
|---|---|
| `sf` CLI installed and authenticated to target org | `sf org display --target-org <alias>` |
| CumulusCI installed and org registered | `cci org info <alias>` |
| SFDMU v5.0.0+ installed | `sf plugins` → `sfdmu` |
| Revenue Cloud / RLM base org setup complete | Configurator enabled, standard PSGs assigned |
| QuantumBit demo data already loaded | QB products, pricebook, context visible in org |

---

## Deployment Steps

### Step 1 — Set variables

```bash
SF_ALIAS="<your-sf-cli-alias>"    # e.g. salesforce-brc260-5gj5d0
CCI_ALIAS="<your-cci-alias>"      # e.g. BRC260CursorClaude
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

> **Note:** To deploy only Velantis images (not all static resources):
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

Creates: 21 `ProductComponentGroup` records and 38 `ProductRelatedComponent` records across three bundles (VELPACK G1, PrecisionBeam+, VelTherma STP).

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

Creates `ProductCategoryProduct` records linking all 27 saleable products to their catalog categories.

---

### Step 8 — Load Pricing + Cost Book

```bash
SF_TEMP_SHOW_SECRETS=true cci task run insert_vel_pricing_data --org $CCI_ALIAS
```

Loads: 54 `PricebookEntry` rows (USD, Standard Price Book), `PriceAdjustmentSchedule`, `AttributeBasedAdjustment`, `AttributeAdjustmentCondition`, 1 `CostBook` (Standard Cost Book), 47 `CostBookEntry` records (one per SKU — required for the Margin Analysis component).

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

**Option A — Individually (recommended for this repo):**

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

---

### Step 14 — Deploy Margin Analysis Component

Deploys the `velQuoteMargin` LWC and its Apex controller, then pushes the updated Quote Record Page with the **Margin Analysis** tab.

```bash
# Deploy Apex controller + LWC
sf project deploy start \
  --source-dir force-app/main/default/classes/VelQuoteMarginController.cls \
  --source-dir force-app/main/default/lwc/velQuoteMargin \
  --target-org $SF_ALIAS

# Deploy the pre-assembled Quote Record Page flexipage
sf project deploy start \
  --metadata "FlexiPage:RLM_Quote_Record_Page" \
  --target-org $SF_ALIAS
```

> **Note:** Step 8 already loads the `CostBook` and `CostBookEntry` records required by this component. Run Step 8 before Step 14.

---

## Verification Checklist

After all steps complete, verify in the org:

- [ ] **Product Catalog** — Revenue Cloud → Products → Catalog → `VEL` catalog; 4 categories with products visible
- [ ] **Bundle configurator** — open VELPACK G1; packaging attributes (Config Type, Compliance, Annual Capacity) appear and CML rules trigger
- [ ] **Laser configurator** — open PrecisionBeam+; Machine Size and Laser Power attributes drive frame/source selection
- [ ] **Product images** — product cards show Velantis imagery (not placeholder icons)
- [ ] **Theme** — Lightning header shows Velantis navy branding and logo
- [ ] **Pricing** — VELPACK G1 bundle has USD One-Time price; software products show Evergreen Monthly pricing
- [ ] **DRO** — create a test order containing VEL-LSR-BDL; confirm fulfillment decomposition rules fire
- [ ] **Margin Analysis** — open a Quote record with Velantis products; the **Margin Analysis** tab shows per-line cost, margin $, margin % with colour-coded badges and a quote-total row

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
| Margin Analysis tab shows no data | Confirm Step 8 ran (CostBookEntry records needed); check Apex debug for `VelQuoteMarginController` |

---

## Re-running on an Existing Org

All Apex scripts are **idempotent** — safe to run multiple times; they skip records that already exist.

SFDMU plans:
- `vel-pricing` `PricebookEntry` uses `Insert` — run `delete_vel_pricing_data` first if re-loading
- `vel-product-images` `Product2` uses `Update` — always safe
- All other plans use `Upsert` keyed on stable external IDs — always safe

---

## CML Source Files

The compiled blobs in `datasets/constraints/vel/*/blobs/` contain internal org IDs from the source org. The `import_cml` task re-wires associations in the target org automatically.

If you need to re-compile from scratch:
1. Create a new Expression Set in the target org (Setup → Expression Sets)
2. Paste the source CML from `scripts/cml/VelantisPackaging.cml` or `VelantisLaser.cml`
3. Save and activate — the platform compiles the CML and generates a new blob
4. Export using:
   ```bash
   SF_TEMP_SHOW_SECRETS=true cci task run export_vel_packaging_cml --org $CCI_ALIAS
   SF_TEMP_SHOW_SECRETS=true cci task run export_vel_laser_cml --org $CCI_ALIAS
   ```
