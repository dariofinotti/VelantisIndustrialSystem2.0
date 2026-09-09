# Velantis Industrial Systems — Constraint Testing Guide & Business Demo Stories

This document covers two things:
1. **Constraint Testing Guide** — step-by-step runtime validation of both Velantis product bundles in the Salesforce configurator
2. **Business Demo Stories** — narrative scenarios that explain the business logic behind each constraint rule

---

## Part 1 — Constraint Testing Guide

### Prerequisites

Before testing, confirm the following are loaded in the target org:

- Velantis PCM data (`cci task run insert_vel_pcm_data --org <alias>`)
- Velantis pricing data (`cci task run insert_vel_pricing_data --org <alias>`)
- Constraint models imported and active:
  - `VELPACK G1 Packaging System` — status: Active/Compiled
  - `PrecisionBeam+ Laser Cutting System` — status: Active/Compiled
- Navigate to **Revenue Cloud → Products → Catalog** and confirm both bundles appear

> **Picklist value reference** — the configurator dropdowns show the raw API values below. This document uses the human-readable labels in test steps; map them as follows when selecting in the UI:
>
> | Human-readable label | Dropdown value shown in org |
> |---|---|
> | Standard | `Standard` |
> | Integrated | `Integrated` |
> | Stand-Alone | `StandAlone` |
> | GMP+ | `GMP_Plus` |
> | FDA 21 CFR Part 11 | `FDA_21_CFR` |
> | 1530 / 2040 / 2060 | `1530` / `2040` / `2060` |
> | Standard (4 kW) / High (10 kW) / Ultra (15 kW) | same as shown |

---

### 1.1 VELPACK G1 Packaging System — Test Cases

Open a new Quote or Order and add **VELPACK G1 Packaging System** to configure it.

#### Test 1 — Base Machine (always required)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Open configurator | `Base Machine` group shows 1 required component auto-selected |
| 2 | Attempt to deselect the base machine | Blocked — `MinBundleComponents = 1` enforces it |

#### Test 2 — Configuration type drives Annual Capacity (CML Rule 1)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Packaging Configuration** to `Standard` | **Est. Annual Capacity (Blisters/yr)** = 23,400,000 (read-only) |
| 2 | Change **Packaging Configuration** to `Integrated` | **Est. Annual Capacity (Blisters/yr)** = 35,100,000 |
| 3 | Change **Packaging Configuration** to `Stand-Alone` | **Est. Annual Capacity (Blisters/yr)** = 15,600,000 |

#### Test 3 — Stand-Alone blocks Standard Track & Trace (CML Rule 3)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Packaging Configuration** to `Stand-Alone` | Standard T&T is blocked by CML |
| 2 | Try to select `Track & Trace Module — Standard` | Error: "Track & Trace is not compatible with StandAlone packaging configurations." |
| 3 | Select `Track & Trace Module — Professional` | Allowed (no CML block for Professional in StandAlone mode) |

#### Test 4 — T&T mutual exclusion (CML Rule 5)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Select `Track & Trace Module — Standard` | Standard T&T added |
| 2 | Select `Track & Trace Module — Professional` | Standard T&T auto-removed — error: "Select either Standard or Professional Track & Trace, not both." |
| 3 | Deselect Professional | Both T&T modules deselected — valid |

#### Test 5 — Pharma Film mutual exclusion (CML Rule 6)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Select `Pharma Film Alu-PVC` | Film added |
| 2 | Try to select `Pharma Film Cold-Form (Alu-Alu)` | Error: "Select only one packaging film type. Alu-PVC is already selected." |
| 3 | Try to select `Pharma Film Child-Resistant` | Error: "Select only one packaging film type. Alu-PVC is already selected." |
| 4 | Deselect Alu-PVC, select Cold-Form | Cold-Form added; Alu-PVC and Child-Resistant blocked |
| 5 | Deselect Cold-Form, select Child-Resistant | Child-Resistant added; other two blocked |

#### Test 6 — Maintenance mutual exclusion (CML Rule 7)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Select `Maintenance — Premium` | Premium selected |
| 2 | Try to select `Maintenance — Standard` | Error: "Select either Standard or Premium maintenance service, not both." |
| 3 | Deselect Premium, select Standard | Standard selected — valid |

#### Test 7 — FDA 21 CFR Part 11 warning (CML Rule 4)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Regulatory Compliance** to `FDA 21 CFR Part 11` | No hard block — field accepts the value |
| 2 | Select `Track & Trace Module — Standard` | Warning message: "Standard Track & Trace does not meet FDA 21 CFR Part 11 serialization requirements. Select a professional module." |
| 3 | Replace Standard with `Track & Trace Module — Professional` | Warning disappears — compliant configuration |

#### Test 8 — GMP+ advisory (CML Rule 8)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Regulatory Compliance** to `GMP+` | No hard blocks |
| 2 | Ensure no T&T module is selected | Advisory message: "GMP+ compliance typically requires electronic batch record traceability. Consider adding a Track & Trace module." |
| 3 | Select any T&T module | Advisory message disappears |

---

### 1.2 PrecisionBeam+ Laser Cutting System — Test Cases

Open a new Quote or Order and add **PrecisionBeam+ Laser Cutting System** to configure it.

#### Test 10 — Nested group structure (Machine Configuration)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Open configurator | A **Machine Configuration** group appears at the top of the component list |
| 2 | Expand **Machine Configuration** | Two sub-groups visible: **Machine Frame** and **Laser Source Module** |
| 3 | Verify Machine Frame contains 3 variants | `PrecisionBeam 1530`, `2040`, and `2060 Machine Frame` all listed inside Machine Frame |
| 4 | Verify Laser Source Module contains 3 variants | `4 kW`, `10 kW`, and `15 kW Fiber Laser Source Module` all listed inside Laser Source Module |

#### Test 11 — Frame size drives machine frame selection (CML Rule 1)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Default **Machine Size** = `1530` | `PrecisionBeam 1530 Machine Frame` is required (inside Machine Frame sub-group) |
| 2 | 2040 frame and 2060 frame cannot be selected | Blocked with "Only one machine frame can be selected." |
| 3 | Change **Machine Size** to `2040` | 2040 frame required, 1530 and 2060 excluded |
| 4 | Change **Machine Size** to `2060` | 2060 frame required, others excluded |

#### Test 12 — Laser power drives source module (CML Rule 2) — Bug Fix Verification
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Default **Laser Power** = `Standard (4 kW)` | **4 kW Fiber Laser Source Module** required (not 10 kW) |
| 2 | Change **Laser Power** to `High (10 kW)` | **10 kW Fiber Laser Source Module** required (not 4 kW) |
| 3 | Change **Laser Power** to `Ultra (15 kW)` | **15 kW Fiber Laser Source Module** required |
| 4 | For each power level, verify the other two source modules are blocked | "Only one laser source module can be selected." |

> **Note:** This test case specifically validates the 4kW/10kW constraint bug fix. Before the fix, selecting `High (10 kW)` was incorrectly requiring the 4 kW module. Confirm correct product names in the component list.

#### Test 13 — 2060 large-format recommendations (CML Rule 3)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Machine Size** to `2060` | Compact Server Automation Module shows as recommended |
| 2 | Check software | PrecisionCut CAD/CAM Software shows as recommended |
| 3 | Change **Machine Size** to `1530` | Recommendations for automation and CAD/CAM disappear |

#### Test 14 — Ultra (15 kW) recommendations (CML Rule 4)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Laser Power** to `Ultra (15 kW)` | Nitrogen Assist Gas Subscription shows as recommended |
| 2 | Check software | PrecisionCut CAD/CAM Software shows as recommended |
| 3 | Select Oxygen Assist Gas Subscription instead | Advisory: "Oxygen assist gas with Ultra (15 kW) power may cause oxidation on stainless steel cut surfaces..." |

#### Test 15 — Ultra (15 kW) maintenance advisory (CML Rule 5)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Set **Laser Power** to `Ultra (15 kW)` and leave maintenance plan empty | Advisory message: "A Maintenance Plan is strongly recommended..." |
| 2 | Select `+ Maintenance Plan` | Advisory disappears |

#### Test 16 — Cutting gas mutual exclusion (CML Rule 6)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Select `Nitrogen Assist Gas Subscription` | Nitrogen added |
| 2 | Try to select `Oxygen Assist Gas Subscription` | Error: "Select only one assist gas type. Nitrogen is already selected." |
| 3 | Try to select `Air Assist Gas Subscription` | Error: "Select only one assist gas type. Nitrogen is already selected." |
| 4 | Switch to Oxygen only | Valid — nitrogen and air are blocked |

#### Test 17 — Automation module cardinality (Max = 3)
| Step | Action | Expected Result |
|------|--------|----------------|
| 1 | Select `Compact Server Automation Module` | Added |
| 2 | Also select `Automated Sheet Loader/Unloader` | Added (max 3 allows combining) |
| 3 | Also select `Smart Parts Sorting Unit` | Added |
| 4 | All three automation options selected simultaneously | Valid — Max = 3 permits full automation stack |

---

## Part 2 — Business Demo Stories

### Story A — Pharma Compliance Buyer (VELPACK G1)

**Customer:** A mid-size generic pharmaceutical manufacturer in Germany expanding their blister packaging line to include US-regulated markets.

**Situation:** The buyer needs to configure the VELPACK G1 Packaging System for two distinct production lines — one for the EU market (GMP+ certified) and one for the US FDA 21 CFR Part 11-regulated line.

**Demo flow:**

1. **Line 1 — GMP+ EU Line:** Set **Regulatory Compliance** to `GMP+`, leave T&T unselected. The system immediately shows the advisory: *"GMP+ compliance typically requires electronic batch record traceability."* The sales rep points out that adding the Standard T&T module satisfies the GMP+ requirement for batch traceability without the cost of full serialization — the advisory disappears.

2. **Line 2 — FDA US Line:** Set **Regulatory Compliance** to `FDA 21 CFR Part 11`, then add Standard T&T. The configurator immediately shows a warning: *"Standard Track & Trace does not meet FDA 21 CFR Part 11 serialization requirements. Select a professional module."* The rep switches to Professional T&T — warning clears. The rep explains: *"The Falsified Medicines Directive and FDA 21 CFR Part 11 require serialization-grade audit trails, which only the Professional module provides."*

3. **Configuration type impact:** The buyer sets **Packaging Configuration** to `Integrated` (their MES integrates with line control). The **Est. Annual Capacity (Blisters/yr)** immediately updates to **35,100,000** and the system recommends the VelPackMgr Batch Control Software and Standard T&T — exactly what the MES integration needs.

**Why the rules exist:** FDA 21 CFR Part 11 is a hard regulatory requirement in the US. A customer who unknowingly configures a non-compliant line would face FDA audit findings. The constraint protects the customer and Velantis from liability. The GMP+ advisory is softer — it's a recommendation, not a legal mandate — so an advisory message (not a hard block) is appropriate.

---

### Story B — Automotive Sheet Metal Manufacturer (PrecisionBeam+ Laser)

**Customer:** A Tier-1 automotive supplier in northern Italy running a high-volume cutting cell for mild steel chassis components and stainless steel exhaust shields.

**Situation:** The buyer needs a large-format cutting system for both materials. They want maximum throughput on mild steel (the bulk of their work) but need oxide-free cuts on the stainless shields.

**Demo flow:**

1. **Frame selection:** Set **Machine Size** to `2060`. The configurator immediately requires the 2060 frame and recommends the Compact Server Automation Module for lights-out production.

2. **Power selection:** Set **Laser Power** to `Ultra (15 kW)`. The system requires the 15 kW Fiber Laser Source Module and recommends Nitrogen Assist Gas and PrecisionCut CAD/CAM.

3. **Gas selection dilemma:** The buyer says: *"We want oxygen for the mild steel runs — it's faster and cheaper."* The sales rep selects Oxygen Assist Gas. The system shows the advisory: *"Oxygen assist gas with Ultra (15 kW) power may cause oxidation on stainless steel cut surfaces."* The rep explains that for a mixed-material operation, nitrogen is the safer choice — or they should plan separate cutting programs per material. The buyer switches to Nitrogen.

4. **Full automation stack:** The rep selects all three automation modules (Compact Server + Loader/Unloader + Parts Sorter). The group allows up to 3 components — all three are valid simultaneously, creating a fully automated cell: sheets load automatically, parts cut at 15 kW, and finished pieces sort by nest program with no operator intervention.

5. **Maintenance advisory:** With Ultra 15 kW configured but no maintenance plan, the advisory fires. The rep adds the `+ Maintenance Plan` — advisory clears.

**Why the rules exist:** At 15 kW power density, optics and cutting head components wear faster than on lower-power machines. A warranty claim on unconfigured maintenance is costly for Velantis. The advisory drives attach rate for high-margin service contracts. The gas advisory prevents a customer from discovering an expensive quality problem on stainless exhaust shields mid-production-run.

---

### Story C — Food Packaging OEM — Lights-Out Factory (PrecisionBeam+)

**Customer:** A packaging equipment OEM in the Netherlands building a lights-out sheet metal factory for production of food-safe packaging machine components (aluminium and mild steel enclosures).

**Situation:** The buyer is building a 24/7 unmanned facility. Material handling automation is as important as the laser itself. They are cutting aluminium sheet (oxide-sensitive, thin-gauge) and mild steel (structural enclosures).

**Demo flow:**

1. **Size:** Set **Machine Size** to `2040` — optimal for 2000×4000 mm aluminium sheets used in enclosure panels.

2. **Power:** Set **Laser Power** to `High (10 kW)` — sufficient for aluminium and mid-gauge mild steel without the optics wear of 15 kW. The system correctly selects the 10 kW Fiber Laser Source Module. *(This is the corrected behaviour — before the constraint fix, this incorrectly selected the 4 kW module.)*

3. **Automation:** The rep builds the full stack:
   - `Compact Server Automation Module` — nesting software and machine interface
   - `Automated Sheet Loader/Unloader` — unmanned raw sheet feeding, critical for lights-out
   - `Smart Parts Sorting Unit` — automatic part sorting by nest ID, no manual sorting
   All three fit within the Automation Module group (Max = 3).

4. **Gas:** Aluminium cutting with oxygen would produce a dark oxide edge unacceptable for food-safe anodised enclosures. The rep selects `Air Assist Gas Subscription` — lowest cost, oxide-free on thin-gauge aluminium, appropriate for the application. Switching to air correctly blocks nitrogen and oxygen.

5. **Software:** The 2040 frame recommendation fires for PrecisionCut CAD/CAM — the rep adds it, completing a fully automated quoting configuration.

**Why the rules exist:** The gas mutual exclusion prevents a double-subscription that would be physically impossible (one machine, one gas circuit). The automation cardinality of 3 reflects real manufacturing practice — server + loader + sorter is a common combination in Prima Power installations. The 10 kW / 4 kW bug fix is business-critical: an order booked with the wrong laser source module would require field re-engineering at Velantis's cost.

---

## Appendix — Constraint Rule Index

### VELPACK G1 Packaging System

| Rule # | Trigger | Effect | CML type |
|--------|---------|--------|----------|
| 1 | **Packaging Configuration** value | Sets **Est. Annual Capacity (Blisters/yr)** via lookup table | `constraint(table(...))` |
| 2 | **Packaging Configuration** = `Integrated` | Recommends Standard T&T + batch software (UI-level only) | — |
| 3 | **Packaging Configuration** = `Stand-Alone` | Blocks Standard T&T | `constraint` |
| 4 | **Regulatory Compliance** = `FDA 21 CFR Part 11` + Standard T&T selected | Warning message: upgrade to Professional T&T | `message` |
| 5 | Professional T&T selected | Blocks Standard T&T | `constraint` |
| 6 | Any film selected | Blocks the other two film types | `constraint` |
| 7 | Premium maintenance selected | Blocks Standard maintenance | `constraint` |
| 8 | **Regulatory Compliance** = `GMP+` + no T&T module | Informational advisory message | `message` |

### PrecisionBeam+ Laser Cutting System

| Rule # | Trigger | Effect | Type |
|--------|---------|--------|------|
| 1 | **Machine Size** value | Requires matching frame; blocks other frames | `constraint` |
| 2 | **Laser Power** value | Requires matching laser source; blocks others | `constraint` |
| 3 | **Machine Size** = `2060` | Recommends Compact Server Automation + CAD/CAM | `preference` |
| 4 | **Laser Power** = `Ultra (15 kW)` | Recommends Nitrogen gas + CAD/CAM; advisory on Oxygen | `preference` + `message` |
| 5 | **Laser Power** = `Ultra (15 kW)` + no maintenance | Advisory message | `message` |
| 6 | Any gas selected | Blocks the other two gas types | `constraint` |
