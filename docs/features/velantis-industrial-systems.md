# Velantis Industrial Systems — Revenue Cloud Demo Build

> **Release target**: Salesforce Revenue Cloud 262 (Summer '26, API v67.0)  
> **Build prefix**: `VEL-`  
> **Status**: PCM · Pricing · Images · DRO · Theme complete. CML (constraint rules) deferred — authored after bundle relationships are created in org.

---

## 1. Company Overview

**Velantis Industrial Systems** is a fictional European industrial machinery OEM headquartered in Milan. The company specialises in two high-value capital equipment product lines sold globally to pharmaceutical manufacturers and sheet-metal fabricators:

| Product Line | Machine | SKU Root |
|---|---|---|
| Pharmaceutical packaging automation | **VELPACK G1** — Automated Blister Packaging System | `VEL-PACK-*` |
| Fiber laser cutting | **PrecisionBeam+** — Fiber Laser Cutting System | `VEL-LSR-*` |

**Demo purpose**: Velantis demonstrates Revenue Cloud capabilities for complex industrial sales — configurable multi-option bundles, milestone-based pricing, multi-currency subscription models, regulatory compliance–driven configuration rules, and DRO-driven fulfillment orchestration from signed order through factory acceptance test, on-site commissioning, and final billing.

---

## 2. What's in the Build

| Area | Scope |
|---|---|
| **Product Catalog (PCM)** | 42 saleable products + 5 internal DRO routing products across 3 bundles + 1 standalone |
| **Pricing** | USD standard pricebook; One-Time, Evergreen Monthly, Term Annual selling models; multi-selling-model products |
| **Product Images** | 27 custom static resource PNGs (products + logo) |
| **Bundle Config Rules (CML)** | 3 CML files — `VelantisPackaging.cml` (packaging) + `VelantisLaser.cml` (laser) *deferred* + `VelantisSterlizer.cml` (STP sterilizer, 9 rules authored) |
| **DRO Fulfillment** | 5 step groups, 13 fulfillment steps, 15 decomposition rules — manufacturing FAT → commissioning flow |
| **Theme & Branding** | Velantis Lightning Experience Theme, BrandingSet, ContentAsset logo |

---

## 3. Products (26 saleable + 5 DRO stubs)

### Bundle 1 — VELPACK G1 Packaging System (`VEL-PACK-G1-BDL`)

12 products including the bundle root. Three component groups contain multiple product options (rep or constraint rule selects one per group).

| SKU | Name | Family | Selling Model(s) |
|---|---|---|---|
| `VEL-PACK-G1-BDL` | VELPACK G1 Packaging System | Hardware | One-Time |
| `VEL-PACK-G1-BASE` | VELPACK G1 Base Machine | Hardware | One-Time |
| `VEL-PACK-G1-TT` | Track & Trace Module — Standard | Hardware | One-Time |
| `VEL-PACK-G1-TT-PRO` | Track & Trace Module — Professional | Hardware | One-Time |
| `VEL-PACK-FILM` | Pharma Film Alu-PVC | Hardware | **Evergreen Monthly + One-Time bulk** |
| `VEL-PACK-FILM-CF` | Pharma Film Cold-Form (Alu-Alu) | Hardware | Evergreen Monthly |
| `VEL-PACK-FILM-CR` | Pharma Film Child-Resistant | Hardware | Evergreen Monthly |
| `VEL-SRV-INSTALL-PKG` | VELPACK Installation Service | Service | One-Time |
| `VEL-SRV-MAINT-PKG` | VELPACK Maintenance — Standard | Service | **Evergreen Monthly + Term Annual** |
| `VEL-SRV-MAINT-PKG-PREM` | VELPACK Maintenance — Premium 24/7 | Service | **Evergreen Monthly + Term Annual** |
| `VEL-SRV-WARRANTY-PKG` | VELPACK Extended Warranty | Service | Term Annual |
| `VEL-SW-PACK-MGR` | VelPackMgr Batch Control Software | Software | **Evergreen Monthly + Term Annual** |

### Bundle 2 — PrecisionBeam+ Laser Cutting System (`VEL-LSR-BDL`)

13 products including the bundle root. Frame and laser source groups each contain three alternatives; constraint rules select the correct one based on attribute values.

| SKU | Name | Family | Selling Model |
|---|---|---|---|
| `VEL-LSR-BDL` | PrecisionBeam+ Laser Cutting System | Hardware | One-Time |
| `VEL-LSR-1530` | PrecisionBeam+ 1530 Machine Frame | Hardware | One-Time |
| `VEL-LSR-2040` | PrecisionBeam+ 2040 Machine Frame | Hardware | One-Time |
| `VEL-LSR-2060` | PrecisionBeam+ 2060 Machine Frame | Hardware | One-Time |
| `VEL-LSR-SRC-4KW` | 4 kW Fiber Laser Source Module | Hardware | One-Time |
| `VEL-LSR-SRC-10KW` | 10 kW Fiber Laser Source Module | Hardware | One-Time |
| `VEL-LSR-SRC-15KW` | 15 kW Fiber Laser Source Module | Hardware | One-Time |
| `VEL-LSR-AUTO-CS` | Compact Server Automation Module | Hardware | One-Time |
| `VEL-CUT-GAS` | Nitrogen Assist Gas Subscription | Hardware | Evergreen Monthly |
| `VEL-SRV-INSTALL-LSR` | PrecisionBeam+ Installation Service | Service | One-Time |
| `VEL-SRV-MAINT-LSR` | PrecisionBeam+ Maintenance Plan | Service | Evergreen Monthly |
| `VEL-SRV-WARRANTY-LSR` | PrecisionBeam+ Extended Warranty | Service | Term Annual |
| `VEL-SW-LSR-CAD` | PrecisionCut CAD/CAM Software | Software | Evergreen Monthly |

### Standalone

| SKU | Name | Family | Selling Model |
|---|---|---|---|
| `VEL-SOFTWARE-NC` | NC Programming Suite License | Software | Evergreen Monthly |

---

## 4. Bundle Structures

### Bundle 1 — VELPACK G1 component groups

```
VEL-PACK-G1-BDL  [Bundle, One-Time]
│
├── PCG-VEL-PKG-BASE     "Base Machine"           Min=1 Max=1  — required
│   └── VEL-PACK-G1-BASE
│
├── PCG-VEL-PKG-TT       "Track & Trace Module"   Min=0 Max=1  — pick one
│   ├── VEL-PACK-G1-TT       Standard T&T
│   └── VEL-PACK-G1-TT-PRO  Professional T&T  ← required when Compliance = FDA_21_CFR
│
├── PCG-VEL-PKG-FILM     "Packaging Film"         Min=0 Max=1  — pick one film type
│   ├── VEL-PACK-FILM        Alu-PVC  (Monthly or One-Time bulk)
│   ├── VEL-PACK-FILM-CF     Cold-Form Alu-Alu
│   └── VEL-PACK-FILM-CR     Child-Resistant
│
├── PCG-VEL-PKG-INSTALL  "Installation Service"   Min=0 Max=1
│   └── VEL-SRV-INSTALL-PKG
│
├── PCG-VEL-PKG-MAINT    "Maintenance Service"    Min=0 Max=1  — pick tier
│   ├── VEL-SRV-MAINT-PKG       Standard (Monthly or Annual)
│   └── VEL-SRV-MAINT-PKG-PREM  Premium 24/7 SLA (Monthly or Annual)
│
├── PCG-VEL-PKG-WARRANTY "Extended Warranty"      Min=0 Max=1
│   └── VEL-SRV-WARRANTY-PKG
│
└── PCG-VEL-PKG-SW       "Batch Control Software" Min=0 Max=1
    └── VEL-SW-PACK-MGR  (Monthly or Annual)
```

### Bundle 2 — PrecisionBeam+ component groups

```
VEL-LSR-BDL  [Bundle, One-Time]
│
├── PCG-VEL-LSR-FRAME    "Machine Frame"          Min=1 Max=1  — constraint picks 1 of 3
│   ├── VEL-LSR-1530  /  VEL-LSR-2040  /  VEL-LSR-2060
│
├── PCG-VEL-LSR-POWER    "Laser Source Module"    Min=1 Max=1  — constraint picks 1 of 3
│   ├── VEL-LSR-SRC-4KW  /  VEL-LSR-SRC-10KW  /  VEL-LSR-SRC-15KW
│
├── PCG-VEL-LSR-AUTO     "Automation Module"      Min=0 Max=1
├── PCG-VEL-LSR-GAS      "Cutting Gas"            Min=0 Max=1
├── PCG-VEL-LSR-SERVICES "Add-on Services"        Min=0 Max=3
│   ├── VEL-SRV-INSTALL-LSR  /  VEL-SRV-MAINT-LSR  /  VEL-SRV-WARRANTY-LSR
└── PCG-VEL-LSR-SW       "CAD/CAM Software"       Min=0 Max=1
```

---

### Bundle 3 — VelTherma STP Sterilizer component groups

```
VEL-STP-BDL  [Bundle, One-Time]
│
├── PCG-VEL-STP-CTRL     "Process Controller & Software"  — required controller + optional SW
│   ├── VEL-STP-CTRL        (required, IsDefault=true)
│   ├── VEL-STP-CTRL-SW     (required, IsDefault=true)
│   └── VEL-STP-CTRL-FMM    (optional)
│
├── PCG-VEL-STP-DOORS    "Doors"                  Min=1 Max=2
│   ├── VEL-STP-DOOR-H   (Motorized Horizontal, IsDefault=true)
│   └── VEL-STP-DOOR-V   (Motorized Vertical)
│
├── PCG-VEL-STP-OPT      "Plant Options"          Min=0
│   ├── VEL-STP-OPT-DRAIN  /  VEL-STP-OPT-GMP
│
├── PCG-VEL-STP-CERT     "Pressure Vessel Certification"  Min=0
│   └── VEL-STP-CERT-PVC
│
├── PCG-VEL-STP-LOAD     "Loading & Handling"     Min=0
│   ├── VEL-STP-LOAD-CART (Max=5)  /  VEL-STP-LOAD-TRAY (Max=20)  /  VEL-STP-LOAD-RACK (Max=5)
│
└── PCG-VEL-STP-SVC      "Services & Documentation"
    ├── VEL-STP-DOC-VAL         (optional)
    ├── VEL-STP-SVC-INST        (required, IsDefault=true)
    ├── VEL-STP-SRV-MAINT-STD  (optional — Standard maintenance)
    └── VEL-STP-SRV-MAINT-PREM (optional — Premium maintenance, mutex w/ STD via CML rule)
```

---

## 5. Attributes & Configuration Rules

### Bundle 1 attributes

| Attribute Code | Label | Type | Values |
|---|---|---|---|
| `ATTR-VEL-PKG-CFG` | Packaging Configuration | Picklist | `Standard` (default) / `Integrated` / `StandAlone` |
| `ATTR-VEL-COMPLIANCE` | Regulatory Compliance | Picklist | `Standard` (default) / `GMP_Plus` / `FDA_21_CFR` |
| `ATTR-VEL-CAPACITY` | Est. Annual Capacity (Blisters/yr) | **Formula / Number** | Computed from `Packaging_Config` — read-only |

**Formula attribute — `ATTR-VEL-CAPACITY`:**

| Packaging Config | Throughput | Annual Capacity |
|---|---|---|
| `Integrated` | 4,500 blisters/hr | 35,100,000 blisters/yr |
| `Standard` | 3,000 blisters/hr | 23,400,000 blisters/yr |
| `StandAlone` | 2,000 blisters/hr | 15,600,000 blisters/yr |

### Bundle 2 attributes

| Attribute Code | Label | Type | Values |
|---|---|---|---|
| `ATTR-VEL-SIZE` | Machine Size | Picklist | `1530` (default) / `2040` / `2060` |
| `ATTR-VEL-POWER` | Laser Power | Picklist | `Standard (4 kW)` (default) / `High (10 kW)` / `Ultra (15 kW)` |

### Configuration rules (CML — deferred)

Configuration rules are authored **after** bundle relationships are built in a scratch org. Three separate CML files:

- `scripts/cml/VelantisSterlizer.cml` — **authored** — 9 rules for VelTherma STP bundle (vertical door dimension compatibility, maintenance exclusion, door-count → slot selection, multi-jurisdiction compliance recommendation, software license advisory)
- `scripts/cml/VelantisPackaging.cml` — *deferred* — packaging bundle rules
- `scripts/cml/VelantisLaser.cml` — *deferred* — laser bundle rules

**`VelantisPackaging.cml`** — VELPACK G1 rules:
- `Packaging_Config == "Integrated"` → require T&T module; recommend `VEL-SW-PACK-MGR`
- `Packaging_Config == "StandAlone"` → exclude T&T group
- **Attribute-based inclusion rule**: `Regulatory_Compliance == "FDA_21_CFR"` → require `VEL-PACK-G1-TT-PRO`, exclude `VEL-PACK-G1-TT`
- Formula: `ATTR-VEL-CAPACITY` computed from `Packaging_Config`

**`VelantisLaser.cml`** — PrecisionBeam+ rules:
- `Machine_Size` → include exactly one frame variant (1530 / 2040 / 2060)
- `Laser_Power` → include exactly one laser source (4kW / 10kW / 15kW)
- `Machine_Size == "2060"` or `Laser_Power == "Ultra (15 kW)"` → recommend `VEL-SW-LSR-CAD`
- Cart-level cross-sell: any laser bundle on quote → recommend `VEL-SW-LSR-CAD` as standalone line

### Test scenarios

| # | Bundle | Setup | Expected result |
|---|---|---|---|
| T1 | Packaging | Compliance = Standard, Config = Standard | No T&T required; no software recommendation |
| T2 | Packaging | Change Config → Integrated | T&T slot constrained; software recommendation badge |
| T3 | Packaging | Change Compliance → FDA_21_CFR | TT-PRO auto-included; Standard T&T excluded |
| T4 | Packaging | Change Config → StandAlone | T&T group hidden |
| T5 | Packaging | Observe ATTR-VEL-CAPACITY | Updates to match Config |
| T6 | Packaging | Select VEL-PACK-FILM | Two selling model options (Monthly vs One-Time bulk) |
| T7 | Packaging | Select VEL-SRV-MAINT-PKG | Two selling model options (Monthly vs Annual) |
| T8 | Laser | Machine_Size = 1530 | VEL-LSR-1530 auto-included; 2040 + 2060 hidden |
| T9 | Laser | Machine_Size = 2060 | 2060 included; CAD/CAM recommendation badge |
| T10 | Laser | Laser_Power = Ultra (15 kW) | 15kW source included; CAD/CAM recommendation badge |
| T11 | Laser | Any laser bundle on quote | Cart-level PrecisionCut CAD/CAM recommended |

---

## 6. Pricing

30 USD pricebook entries covering all selling models. Multi-selling-model products demonstrate the same product sold in two different revenue models:

| SKU | Selling Model | Unit Price |
|---|---|---|
| `VEL-PACK-G1-BDL` | One-Time | $245,000 |
| `VEL-PACK-G1-BASE` | One-Time | $185,000 |
| `VEL-PACK-G1-TT` | One-Time | $22,500 |
| `VEL-PACK-G1-TT-PRO` | One-Time | $38,500 |
| `VEL-PACK-FILM` | Evergreen Monthly | $850/mo |
| `VEL-PACK-FILM` | One-Time (bulk) | $8,500 |
| `VEL-PACK-FILM-CF` | Evergreen Monthly | $1,150/mo |
| `VEL-PACK-FILM-CR` | Evergreen Monthly | $980/mo |
| `VEL-SRV-INSTALL-PKG` | One-Time | $18,000 |
| `VEL-SRV-MAINT-PKG` | Evergreen Monthly | $2,100/mo |
| `VEL-SRV-MAINT-PKG` | Term Annual | $22,000/yr |
| `VEL-SRV-MAINT-PKG-PREM` | Evergreen Monthly | $3,200/mo |
| `VEL-SRV-MAINT-PKG-PREM` | Term Annual | $33,500/yr |
| `VEL-SRV-WARRANTY-PKG` | Term Annual | $9,500/yr |
| `VEL-SW-PACK-MGR` | Evergreen Monthly | $299/mo |
| `VEL-SW-PACK-MGR` | Term Annual | $2,999/yr |
| `VEL-LSR-BDL` | One-Time | $320,000 |
| `VEL-LSR-1530` / `2040` / `2060` | One-Time | $145,000 / $165,000 / $198,000 |
| `VEL-LSR-SRC-4KW` / `10KW` / `15KW` | One-Time | $38,000 / $62,000 / $89,000 |
| `VEL-LSR-AUTO-CS` | One-Time | $21,000 |
| `VEL-CUT-GAS` | Evergreen Monthly | $320/mo |
| `VEL-SRV-INSTALL-LSR` | One-Time | $22,000 |
| `VEL-SRV-MAINT-LSR` | Evergreen Monthly | $2,800/mo |
| `VEL-SRV-WARRANTY-LSR` | Term Annual | $12,500/yr |
| `VEL-SW-LSR-CAD` | Evergreen Monthly | $499/mo |
| `VEL-SOFTWARE-NC` | Evergreen Monthly | $199/mo |

---

## 7. DRO Fulfillment Orchestration

The fulfillment sequence follows the internationally recognized **FAT → SAT** pattern for capital equipment delivery:

```
Order Confirmed
    │
    ├─► VEL Post Advance Invoice ─────────────────────────────────────── Finance track
    │       │
    │       ├─► VEL Schedule Production ─► VEL Machine Assembly ─► VEL Factory Acceptance Test (FAT)
    │       │                                                              │
    │       │                                                    VEL Arrange Freight
    │       │                                                              │
    │       │                                                    VEL Confirm Delivery Date
    │       │                                                              │
    │       └─► VEL Site Survey ──────────────────────────────────────────┤
    │                                                                      │
    │                                                          VEL On-Site Installation
    │                                                                      │
    │                                               VEL Commissioning & Calibration (SAT)
    │                                                              │               │
    │                                              ┌───────────────┘               └──────────────┐
    │                                              ▼                                              ▼
    │                                   VEL Process Final Invoice             VEL Register Warranty
    │                                              │
    │                                   VEL Receive Payment
    └──────────────────────────────────────────────────────────────────── Service Activation track
```

### DRO object summary

| Object | Records | Operation | Notes |
|---|---|---|---|
| Product2 (DRO stub products) | 5 | Upsert | `IsActive = false` — internal routing only |
| Product2 (source product stamps) | 11 | Upsert | Sets `DecompositionScope` on existing VEL products |
| ProductFulfillmentDecompRule | 15 | Upsert | 8 for VELPACK G1, 7 for PrecisionBeam+ |
| FulfillmentStepDefinitionGroup | 5 | Upsert | Finance, Manufacturing, Logistics, Installation, Service Activation |
| FulfillmentStepDefinition | 13 | Upsert | Full FAT → commissioning chain |
| FulfillmentStepDependencyDef | 12 | Upsert | Cross-group dependencies (advance → production → FAT → freight → install → commission → invoice) |
| ProductFulfillmentScenario | 5 | Upsert | One per DRO stub product |
| FulfillmentWorkspace | 1 | Upsert | `Velantis Machine Fulfillment` |
| FulfillmentWorkspaceItem | 5 | Insert | One per step group; re-running creates duplicates (clean up if needed) |
| FulfillmentFalloutRule | 0 | — | Not applicable — all steps are ManualTask |
| FulfillmentStepJeopardyRule | 5 | Upsert | Auto-numbered Names — update CSV after first deploy |

---

## 8. Prerequisites

- Salesforce org with **Revenue Cloud / RLM enabled** (Release 262, API v67.0)
- **CumulusCI** installed and configured (`cci` CLI)
- **SFDMU v5.0.0+** (`sf sfdmu run`)
- `vel` feature flag enabled in your CCI org config

---

## 9. How to Load

```bash
# 1. Deploy static resources and theme
sf project deploy start \
  --source-dir force-app/main/default/staticresources \
  --source-dir force-app/main/default/lightningExperienceThemes \
  --source-dir force-app/main/default/brandingSets \
  --source-dir force-app/main/default/contentassets \
  --target-org <sf_alias>

# 2. Load product catalog (PCM)
cci task run insert_vel_pcm_data --org <cci_alias>

# 3. Load pricing
cci task run insert_vel_pricing_data --org <cci_alias>

# 4. Update product display images
cci task run insert_vel_product_image_data --org <cci_alias>

# 5. Load DRO fulfillment configuration
cci task run insert_vel_dro_data --org <cci_alias>
cci task run update_vel_pfdr_rules --org <cci_alias>

# 6. (After bundle relationships built in org) Load CML constraint rules
cci task run import_vel_packaging_cml --org <cci_alias>
cci task run import_vel_laser_cml --org <cci_alias>
```

> **Note**: Steps 2–5 are non-destructive (Upsert / Insert without deleteOldData). They layer data on top of existing records and are safe to run on a shared or partially configured org.

---

## 10. Key Demo Talking Points

| Capability | Demo Story |
|---|---|
| **Multi-selling-model products** | `VEL-PACK-FILM` is sold on Monthly subscription *or* one-time bulk purchase — same product, two revenue models, both available in the same bundle |
| **Attribute-based inclusion rule** | FDA 21 CFR Part 11 compliance automatically includes the Professional Track & Trace module and blocks the Standard one — no rep manual selection needed |
| **Formula attribute** | Annual throughput capacity (`ATTR-VEL-CAPACITY`) is computed from the Packaging Configuration selection — updates in real time, no manual entry |
| **DRO milestone billing** | Advance invoice fires at order; final invoice only after commissioning completes — two billing moments, one order |
| **Cross-group DRO dependencies** | The workspace shows the full FAT → freight → installation → SAT → invoice chain; each step group knows what it depends on |
| **Recommendation rules** | Selecting Integrated config or large-format laser surfaces software recommendations in the configurator UI |

---

## 11. Repository File Layout

```
datasets/sfdmu/vel/en-US/
├── vel-pcm/                  # Product catalog: 26 products, 5 attrs, 15 groups, 23 components
├── vel-pricing/              # Pricebook entries: 30 rows, 3 selling models
├── vel-product-images/       # DisplayUrl updates for all 26 products
└── vel-dro/                  # DRO: 13 steps, 15 decomp rules, 5 step groups

force-app/main/default/
├── staticresources/VEL_*.{png,resource-meta.xml}   # 27 product + logo images
├── lightningExperienceThemes/VELTheme.*             # Velantis Lightning theme
├── brandingSets/LEXTHEMINGVelantis.*               # Navy blue branding set
└── contentassets/VEL_logo_rectangle.*              # Velantis logo content asset

scripts/apex/vel/
└── update_vel_pfdr_rules.apex    # Re-save workaround for ProductFulfillmentDecompRule bug

scripts/cml/                  # DEFERRED — authored after bundle relationships built in org
├── VelantisPackaging.cml
└── VelantisLaser.cml

datasets/constraints/vel/     # DEFERRED — ExpressionSet blobs for CML rules
├── VelantisPackaging/
└── VelantisLaser/
```

---

## 12. Known Issues & Workarounds

| Issue | Workaround |
|---|---|
| `ProductFulfillmentDecompRule.ExecuteOnRuleId` not generated on insert (platform bug) | `update_vel_pfdr_rules` Apex task re-saves all `VEL%` PFDR records to trigger generation |
| `FulfillmentWorkspaceItem` — no direct-field unique key exists | `operation: Insert` (no `deleteOldData`) used instead of Upsert; re-running creates duplicate items — clean up manually if needed |
| `FulfillmentStepJeopardyRule.Name` is auto-numbered by the platform | CSV uses placeholder names (`VEL-FSJR-001` … `VEL-FSJR-005`); update the CSV with platform-assigned names after first deploy for idempotent subsequent runs |
