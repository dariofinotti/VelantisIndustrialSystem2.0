# vel-pricing — Velantis Industrial Systems Pricing

Standard Price Book entries, attribute-based price adjustments, and cost book data for all Velantis saleable products (USD).
Covers One-Time, Evergreen Monthly, and Term Annual selling models. Cost data powers the `velQuoteMargin` LWC margin analysis component on the Quote record page.

## Load commands

```bash
# Full load (delete first to avoid duplicates on re-run)
cci task run delete_vel_pricing_data --org <alias>
cci task run insert_vel_pricing_data --org <alias>
```

**Must run after `insert_vel_pcm_data`** — products and attributes must exist before pricing records can be created.

## Objects

| # | Object | Operation | Pre-Deleted¹ | Records | externalId |
|---|--------|-----------|--------------|---------|-----------|
| 1 | `ProductSellingModel` | Readonly | | — | `Name;SellingModelType` |
| 2 | `Product2` | Readonly | | — | `StockKeepingUnit` |
| 3 | `AttributeDefinition` | Readonly | | — | `Code` |
| 4 | `CostBook` | Upsert | | 1 | `Name` |
| 5 | `Pricebook2` | Upsert | | 1 | `Name;IsStandard` |
| 6 | `PriceAdjustmentSchedule` | Update | | 1 | `Name;CurrencyIsoCode` |
| 7 | `AttributeBasedAdjRule` | Upsert | | 6 | `Name` |
| 8 | `AttributeAdjustmentCondition` | Insert | ✓ | 6 | `AttributeBasedAdjRule.Name;AttributeDefinition.Code;Product.StockKeepingUnit` |
| 9 | `AttributeBasedAdjustment` | Insert | ✓ | 6 | `AttributeBasedAdjRule.Name;PriceAdjustmentSchedule.Name;Product.StockKeepingUnit;ProductSellingModel.Name;CurrencyIsoCode` |
| 10 | `PricebookEntry` | Insert | ✓ | 52 | `Product2.StockKeepingUnit;ProductSellingModel.Name;CurrencyIsoCode` |
| 11 | `CostBookEntry` | Insert | ✓ | 47 | `CostBook.Name;Product.StockKeepingUnit;CurrencyIsoCode` |

¹ **Pre-Deleted:** `delete_vel_pricing_data` deletes all Insert-operation records in reverse plan order (CostBookEntry → PricebookEntry → AttributeBasedAdjustment → AttributeAdjustmentCondition) before each load. Workaround for SFDMU v5 Bug 3 — Upsert with relationship-traversal externalId components always inserts instead of matching existing records.

**Notes:**
- `PriceAdjustmentSchedule`: `Update` — the platform auto-creates this record when the pricebook is provisioned; we only activate it
- `AttributeBasedAdjRule`: `Upsert` — human-readable `Name` values are portable across orgs (no timestamp-based names)
- `AttributeAdjustmentCondition` / `AttributeBasedAdjustment`: `Insert` — externalIds contain relationship traversal fields → SFDMU v5 Bug 3 prevents Upsert matching

## Attribute-Based Price Adjustments (6 rules)

Override adjustments that replace the bundle list price when the customer selects a specific attribute value.

### VEL-LSR-BDL — driven by ATTR-VEL-POWER

| Rule Name | Attribute Value | Override Price |
|-----------|-----------------|---------------|
| `VEL-LSR-Power-Standard-4kW` | `Standard (4 kW)` | $185,000 |
| `VEL-LSR-Power-High-10kW` | `High (10 kW)` | $215,000 |
| `VEL-LSR-Power-Ultra-15kW` | `Ultra (15 kW)` | $255,000 |

### VEL-PACK-G1-BDL — driven by ATTR-VEL-PKG-CFG

| Rule Name | Attribute Value | Override Price |
|-----------|-----------------|---------------|
| `VEL-PKG-Config-Standard` | `Standard` | $245,000 |
| `VEL-PKG-Config-Integrated` | `Integrated` | $285,000 |
| `VEL-PKG-Config-StandAlone` | `StandAlone` | $185,000 |

All 6 rules target the `Standard Attribute Based Adjustment` PriceAdjustmentSchedule, `One-Time` selling model, USD.

## Pricing table

| SKU | Name | Selling Model | Unit Price (USD) |
|-----|------|---------------|-----------------|
| VEL-PACK-G1-BDL | VELPACK G1 Packaging System | One-Time | $245,000 |
| VEL-PACK-G1-BASE | VELPACK G1 Base Machine | One-Time | $175,000 |
| VEL-PACK-G1-TT | Track & Trace Module — Standard | One-Time | $24,500 |
| VEL-PACK-G1-TT-PRO | Track & Trace Module — Professional | One-Time | $38,500 |
| VEL-PACK-FILM | Pharma Film Alu-PVC | Evergreen Monthly | $850/mo |
| VEL-PACK-FILM | Pharma Film Alu-PVC (bulk) | One-Time | $8,500 |
| VEL-PACK-FILM-CF | Pharma Film Cold-Form Alu-Alu | Evergreen Monthly | $1,150/mo |
| VEL-PACK-FILM-CR | Pharma Film Child-Resistant | Evergreen Monthly | $980/mo |
| VEL-SRV-INSTALL-PKG | VELPACK Installation Service | One-Time | $12,500 |
| VEL-SRV-MAINT-PKG | VELPACK Maintenance — Standard | Evergreen Monthly | $2,100/mo |
| VEL-SRV-MAINT-PKG | VELPACK Maintenance — Standard | Term Annual | $22,000/yr |
| VEL-SRV-MAINT-PKG-PREM | VELPACK Maintenance — Premium | Evergreen Monthly | $3,200/mo |
| VEL-SRV-MAINT-PKG-PREM | VELPACK Maintenance — Premium | Term Annual | $33,500/yr |
| VEL-SRV-WARRANTY-PKG | VELPACK Extended Warranty | Term Annual | $8,900/yr |
| VEL-SW-PACK-MGR | VelPackMgr Batch Control Software | Evergreen Monthly | $299/mo |
| VEL-SW-PACK-MGR | VelPackMgr Batch Control Software | Term Annual | $2,999/yr |
| VEL-LSR-BDL | PrecisionBeam+ Laser Cutting System | One-Time | $185,000 |
| VEL-LSR-1530 | PrecisionBeam+ 1530 Frame | One-Time | $95,000 |
| VEL-LSR-2040 | PrecisionBeam+ 2040 Frame | One-Time | $115,000 |
| VEL-LSR-2060 | PrecisionBeam+ 2060 Frame | One-Time | $148,000 |
| VEL-LSR-SRC-4KW | 4 kW Fiber Laser Source | One-Time | $32,000 |
| VEL-LSR-SRC-10KW | 10 kW Fiber Laser Source | One-Time | $58,000 |
| VEL-LSR-SRC-15KW | 15 kW Fiber Laser Source | One-Time | $82,000 |
| VEL-LSR-AUTO-CS | Compact Server Automation Module | One-Time | $24,500 |
| VEL-CUT-GAS | Nitrogen Assist Gas Subscription | Evergreen Monthly | $450/mo |
| VEL-SRV-INSTALL-LSR | PrecisionBeam+ Installation Service | One-Time | $15,500 |
| VEL-SRV-MAINT-LSR | PrecisionBeam+ Maintenance Plan | Evergreen Monthly | $1,800/mo |
| VEL-SRV-WARRANTY-LSR | PrecisionBeam+ Extended Warranty | Term Annual | $7,200/yr |
| VEL-SW-LSR-CAD | PrecisionCut CAD/CAM Software | Evergreen Monthly | $399/mo |
| VEL-SOFTWARE-NC | NC Programming Suite License | Evergreen Monthly | $149/mo |

**52 PricebookEntry records total** (covers all VEL products across One-Time, Evergreen Monthly, and Term Annual selling models, including multi-SM products)

## Cost book data (CostBookEntry — 47 records)

Costs are set to produce a realistic spread across all four margin bands for the `velQuoteMargin` demo component.
Cost is per unit; for subscription products the reference price is the monthly list price.

| SKU | Unit Cost (USD) | Reference Price | Margin % | Band |
|-----|----------------|-----------------|----------|------|
| VEL-PACK-G1-BDL | $164,150 | $245,000 | 33% | Green ≥30% |
| VEL-PACK-G1-BASE | $131,250 | $175,000 | 25% | Amber 15–30% |
| VEL-PACK-G1-TT | $21,560 | $24,500 | 12% | Red 0–15% |
| VEL-PACK-G1-TT-PRO | $30,800 | $38,500 | 20% | Amber 15–30% |
| VEL-PACK-FILM | $382.50 | $850/mo | 55% | Green ≥30% |
| VEL-PACK-FILM-CF | $552 | $1,150/mo | 52% | Green ≥30% |
| VEL-PACK-FILM-CR | $450.80 | $980/mo | 54% | Green ≥30% |
| VEL-SRV-INSTALL-PKG | $9,375 | $12,500 | 25% | Amber 15–30% |
| VEL-SRV-MAINT-PKG | $1,470 | $2,100/mo | 30% | Green ≥30% |
| VEL-SRV-MAINT-PKG-PREM | $2,176 | $3,200/mo | 32% | Green ≥30% |
| VEL-SRV-WARRANTY-PKG | $6,408 | $8,900/yr | 28% | Amber 15–30% |
| VEL-SW-PACK-MGR | $74.75 | $299/mo | 75% | Green ≥30% |
| VEL-LSR-BDL | $123,950 | $185,000 | 33% | Green ≥30% |
| VEL-LSR-1530 | $76,000 | $95,000 | 20% | Amber 15–30% |
| VEL-LSR-2040 | $89,700 | $115,000 | 22% | Amber 15–30% |
| VEL-LSR-2060 | $111,000 | $148,000 | 25% | Amber 15–30% |
| VEL-LSR-SRC-4KW | $26,240 | $32,000 | 18% | Amber 15–30% |
| VEL-LSR-SRC-10KW | $46,400 | $58,000 | 20% | Amber 15–30% |
| VEL-LSR-SRC-15KW | $63,960 | $82,000 | 22% | Amber 15–30% |
| VEL-LSR-AUTO-CS | $15,925 | $24,500 | 35% | Green ≥30% |
| VEL-LSR-AUTO-LU | $26,950 | $38,500 | 30% | Green ≥30% |
| VEL-LSR-AUTO-SORT | $14,960 | $22,000 | 32% | Green ≥30% |
| VEL-CUT-GAS | $180 | $450/mo | 60% | Green ≥30% |
| VEL-CUT-GAS-O2 | $134.40 | $320/mo | 58% | Green ≥30% |
| VEL-CUT-GAS-AIR | $63 | $180/mo | 65% | Green ≥30% |
| VEL-SRV-INSTALL-LSR | $12,090 | $15,500 | 22% | Amber 15–30% |
| VEL-SRV-MAINT-LSR | $1,260 | $1,800/mo | 30% | Green ≥30% |
| VEL-SRV-WARRANTY-LSR | $5,184 | $7,200/yr | 28% | Amber 15–30% |
| VEL-SW-LSR-CAD | $119.70 | $399/mo | 70% | Green ≥30% |
| VEL-SOFTWARE-NC | $32.78 | $149/mo | 78% | Green ≥30% |
| VEL-SW-RMP | $139.72 | $499/mo | 72% | Green ≥30% |
| VEL-STP-BDL | $134,400 | $192,000 | 30% | Green ≥30% |
| VEL-STP-CTRL | $41,760 | $48,000 | 13% | Red 0–15% |
| VEL-STP-CTRL-SW | $4,140 | $9,200/yr | 55% | Green ≥30% |
| VEL-STP-CTRL-FMM | $6,500 | $12,500/yr | 48% | Green ≥30% |
| VEL-STP-DOOR-H | $7,920 | $8,800 | 10% | Red 0–15% |
| VEL-STP-DOOR-V | $9,240 | $10,500 | 12% | Red 0–15% |
| VEL-STP-OPT-DRAIN | $4,620 | $4,400 | **-5%** | **Dark-red negative** |
| VEL-STP-OPT-GMP | $11,520 | $16,000 | 28% | Amber 15–30% |
| VEL-STP-CERT-PVC | $3,770 | $5,800 | 35% | Green ≥30% |
| VEL-STP-LOAD-CART | $2,301 | $2,950 | 22% | Amber 15–30% |
| VEL-STP-LOAD-TRAY | $1,187.50 | $1,250 | 5% | Red 0–15% |
| VEL-STP-LOAD-RACK | $2,993 | $3,650 | 18% | Amber 15–30% |
| VEL-STP-DOC-VAL | $4,680 | $7,800 | 40% | Green ≥30% |
| VEL-STP-SVC-INST | $9,750 | $12,500 | 22% | Amber 15–30% |
| VEL-STP-SRV-MAINT-STD | $1,155 | $1,650/mo | 30% | Green ≥30% |
| VEL-STP-SRV-MAINT-PREM | $1,666 | $2,450/mo | 32% | Green ≥30% |

**Demo talking point:** `VEL-STP-OPT-DRAIN` (Sterilizer Optional Drain Kit) is intentionally sold below cost (-5%) as a value-add to win large sterilizer system deals — a useful margin conversation starter.
