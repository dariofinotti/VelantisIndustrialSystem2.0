# vel-pcm — Velantis Industrial Systems Product Catalog

Complete Product Catalog Management (PCM) data for Velantis Industrial Systems.
Defines two configurable machine bundles, 31 products, 5 attributes, and a full
catalog/category structure.

## Load command

```bash
cci task run insert_vel_pcm_data --org <alias>
```

## Bundle structure

### Bundle 1 — VEL-PACK-G1-BDL (VELPACK G1 Packaging System)

```
VEL-PACK-G1-BDL  [Bundle, One-Time, Allowed]
├── PCG-VEL-PKG-BASE     "Base Machine"          Min=1 Max=1  — required
│   └── VEL-PACK-G1-BASE
├── PCG-VEL-PKG-TT       "Track & Trace Module"  Min=0 Max=1  — 2 options
│   ├── VEL-PACK-G1-TT       Standard T&T
│   └── VEL-PACK-G1-TT-PRO  Professional T&T (FDA 21 CFR — inclusion rule)
├── PCG-VEL-PKG-FILM     "Packaging Film"        Min=0 Max=1  — 3 film types
│   ├── VEL-PACK-FILM        Alu-PVC (Monthly or One-Time)
│   ├── VEL-PACK-FILM-CF     Cold-Form Alu-Alu (Monthly)
│   └── VEL-PACK-FILM-CR     Child-Resistant (Monthly)
├── PCG-VEL-PKG-INSTALL  "Installation Service"  Min=0 Max=1
│   └── VEL-SRV-INSTALL-PKG
├── PCG-VEL-PKG-MAINT    "Maintenance Service"   Min=0 Max=1  — 2 tiers
│   ├── VEL-SRV-MAINT-PKG       Standard (Monthly or Annual)
│   └── VEL-SRV-MAINT-PKG-PREM  Premium 24/7 (Monthly or Annual)
├── PCG-VEL-PKG-WARRANTY "Extended Warranty"     Min=0 Max=1
│   └── VEL-SRV-WARRANTY-PKG
└── PCG-VEL-PKG-SW       "Batch Control Software" Min=0 Max=1
    └── VEL-SW-PACK-MGR  (Monthly or Annual)
```

### Bundle 2 — VEL-LSR-BDL (PrecisionBeam+ Laser Cutting System)

```
VEL-LSR-BDL  [Bundle, One-Time, Allowed]
├── PCG-VEL-LSR-FRAME    "Machine Frame"         Min=1 Max=1  — 3 sizes
│   ├── VEL-LSR-1530 / VEL-LSR-2040 / VEL-LSR-2060
├── PCG-VEL-LSR-POWER    "Laser Source Module"   Min=1 Max=1  — 3 power ratings
│   ├── VEL-LSR-SRC-4KW / VEL-LSR-SRC-10KW / VEL-LSR-SRC-15KW
├── PCG-VEL-LSR-AUTO     "Automation Module"     Min=0 Max=1
├── PCG-VEL-LSR-GAS      "Cutting Gas"           Min=0 Max=1
├── PCG-VEL-LSR-INSTALL  "Installation Service"  Min=0 Max=1
├── PCG-VEL-LSR-MAINT    "Maintenance Service"   Min=0 Max=1
├── PCG-VEL-LSR-WARRANTY "Extended Warranty"     Min=0 Max=1
└── PCG-VEL-LSR-SW       "CAD/CAM Software"      Min=0 Max=1
```

## Objects

| Object | Operation | # Records | externalId |
|--------|-----------|-----------|-----------|
| `AttributePicklist` | Upsert | 4 | `Name` |
| `AttributePicklistValue` | Upsert | 12 | `Code` |
| `AttributeDefinition` | Upsert | 5 | `Code` |
| `AttributeCategory` | Upsert | 2 | `Code` |
| `AttributeCategoryAttribute` | Upsert | 5 | `AttributeCategory.Code;AttributeDefinition.Code` |
| `ProductClassification` | Upsert | 3 | `Code` |
| `ProductClassificationAttr` | Upsert | 5 | `Name` |
| `Product2` | Upsert | 31 | `StockKeepingUnit` |
| `ProductAttributeDefinition` | Upsert | 5 | `AttributeDefinition.Code;Product2.StockKeepingUnit` |
| `ProductSellingModel` | ReadOnly | — | |
| `ProrationPolicy` | ReadOnly | — | |
| `ProductSellingModelOption` | Upsert | 30 | `Product2.StockKeepingUnit;ProductSellingModel.Name;ProductSellingModel.SellingModelType` |
| `ProductRelationshipType` | Upsert | 1 | `Name` |
| `ProductComponentGroup` | Upsert | 15 | `Code` |
| `ProductRelatedComponent` | Upsert | 23 | composite (5-field `$$` key) |
| `ProductCatalog` | Upsert | 1 | `Code` |
| `ProductCategory` | Upsert | 3 | `Code` |
| `ProductCategoryProduct` | Upsert | 26 | `ProductCategory.Code;Product.StockKeepingUnit` |

**Total loadable records: 171**

## Attributes

| Code | Label | DataType | Assigned To | Values |
|------|-------|----------|-------------|--------|
| `ATTR-VEL-PKG-CFG` | Packaging Configuration | Picklist | VEL-PACK-G1-BDL | Standard / Integrated / StandAlone |
| `ATTR-VEL-COMPLIANCE` | Regulatory Compliance | Picklist | VEL-PACK-G1-BDL | Standard / GMP_Plus / FDA_21_CFR |
| `ATTR-VEL-CAPACITY` | Est. Annual Capacity (Blisters/yr) | Number (CML formula) | VEL-PACK-G1-BDL | Computed — see VelantisPackaging.cml |
| `ATTR-VEL-SIZE` | Machine Size | Picklist | VEL-LSR-BDL | 1530 / 2040 / 2060 |
| `ATTR-VEL-POWER` | Laser Power | Picklist | VEL-LSR-BDL | Standard 4 kW / High 10 kW / Ultra 15 kW |

## Products with multiple selling models

| SKU | Selling Model 1 (default) | Selling Model 2 |
|-----|--------------------------|-----------------|
| `VEL-PACK-FILM` | Evergreen Monthly | One-Time |
| `VEL-SRV-MAINT-PKG` | Evergreen Monthly | Term Annual |
| `VEL-SRV-MAINT-PKG-PREM` | Evergreen Monthly | Term Annual |
| `VEL-SW-PACK-MGR` | Evergreen Monthly | Term Annual |

## DRO stub products (VEL-DRO-*)

5 inactive products (`IsActive=false`) serve as DRO routing destinations.
They do **not** appear in any product category and are never visible to customers.
They are loaded by the `insert_vel_pcm_data` task and then stamped with
DecompositionScope by `insert_vel_dro_data`.
