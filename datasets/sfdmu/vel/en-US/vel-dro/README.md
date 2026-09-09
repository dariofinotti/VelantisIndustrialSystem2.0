# vel-dro — Velantis Industrial Systems DRO Configuration

Dynamic Revenue Orchestrator (DRO) fulfillment configuration for Velantis machine bundles.
Maps **VELPACK G1** (pharmaceutical packaging), **PrecisionBeam+** (fiber laser cutting), and
**VelTherma STP** (steam sterilizer) orders through a six-stage industrial fulfillment workflow,
including automated service contract creation when maintenance or extended warranty is ordered.

## Load command

```bash
cci task run insert_vel_dro_data --org <alias>
cci task run update_vel_pfdr_rules --org <alias>   # REQUIRED after first load (260/262 platform bug)
```

After the first load, re-save the `VEL Maintenance Contract Service` `ProductFulfillmentScenario`
record via UI or Apex to populate `ScenarioRuleId` (known 260/262 bug — INSERT does not generate the ruleset).

## Objects

| Object | Operation | # Records | externalId / notes |
|--------|-----------|-----------|-------------------|
| `Product2` | Upsert | 25 | `StockKeepingUnit` — 19 source products stamped + 6 VEL-DRO-* routing stubs (incl. VEL-DRO-MAINT + 2 warranty SKUs) |
| `ProductFulfillmentDecompRule` | Upsert | 32 | `Name` — maps source SKUs to DRO routing products; includes 7 maintenance/warranty → VEL-DRO-MAINT rules |
| `FulfillmentStepDefinitionGroup` | Upsert | 6 | `Name` — Finance, Mfg & QC, Logistics, Install, Service Activation, **Maintenance & Warranty** |
| `FulfillmentStepDefinition` | Upsert | 14 | `Name` — 11 ManualTask + 2 Milestone + **1 AutoTask** (VEL Create Service Contract) |
| `FulfillmentStepDependencyDef` | Upsert | 14 | `Name` — includes 6 cross-group dependencies (new: Commission → Svc Contract) |
| `ProductFulfillmentScenario` | Upsert | 6 | `Name` — one per DRO routing product (new: VEL-DRO-MAINT) |
| `FulfillmentWorkspace` | Upsert | 1 | `Name` — "Velantis Machine Fulfillment" |
| `FulfillmentWorkspaceItem` | Upsert + deleteOldData | 6 | deleteOldData scoped to Velantis workspace only — clears stale items then re-inserts; matches QB pattern |
| `FulfillmentFalloutRule` | Upsert | 0 | Header only |
| `FulfillmentStepJeopardyRule` | Upsert | 5 | `Name` — placeholder names (update after first deploy) |
| `FulfillmentTaskAssignmentRule` | Upsert | 0 | Header only — autotask is flow-driven, no assignment rule needed |
| `User` | ReadOnly | — | AssignedTo placeholder resolution |
| `Group` | ReadOnly | — | Queue reference |
| `IntegrationProviderDef` | ReadOnly | — | Integration provider reference |

## Fulfillment Flow

```
[VEL-PACK-G1-BDL / VEL-LSR-BDL / VEL-STP-BDL]
        │
        ├──→ VEL-DRO-BILL    ──── VEL Finance Group ────────────────────────────┐
        │      Post Advance Invoice → Process Final Invoice → Receive Payment
        │                           ↑ (after Commissioning)
        │
        ├──→ VEL-DRO-MFG     ──── VEL Mfg & QC Group ──────────────────────────┤
        │      Schedule Production → Machine Assembly → Factory Acceptance Test
        │
        ├──→ VEL-DRO-LOGIS   ──── VEL Logistics Group ──────────────────────────┤
        │      Arrange Freight → Confirm Delivery Date
        │
        └──→ VEL-DRO-INST    ──── VEL Installation Group ────────────────────────┤
               Site Survey → On-Site Installation → Commissioning & Calibration

[VEL-SRV-INSTALL-PKG / VEL-SRV-INSTALL-LSR / VEL-STP-SVC-INST]
        └──→ VEL-DRO-INST    (Install & Commission)
        └──→ VEL-DRO-BILL    (Finance)

[VEL-SRV-MAINT-PKG / VEL-SRV-MAINT-PKG-PREM / VEL-SW-PACK-MGR / VEL-SRV-MAINT-LSR /
 VEL-SW-LSR-CAD / VEL-STP-SRV-MAINT-STD / VEL-STP-SRV-MAINT-PREM]
        └──→ VEL-DRO-SVCACT  ──── VEL Service Activation Group ──────────────────
               Register Warranty → Activate Software License

[VEL-SRV-MAINT-PKG / VEL-SRV-MAINT-PKG-PREM / VEL-SRV-MAINT-LSR /
 VEL-SRV-WARRANTY-PKG / VEL-SRV-WARRANTY-LSR /
 VEL-STP-SRV-MAINT-STD / VEL-STP-SRV-MAINT-PREM]
        └──→ VEL-DRO-MAINT   ──── VEL Maintenance & Warranty Group ──────────────
               VEL Create Service Contract  ← AutoTask (VEL_Maintenance_Contract_DRO_Task flow)
               (waits for Commissioning & Calibration if hardware is also ordered)
```

## AutoTask: VEL Create Service Contract

The `VEL Create Service Contract` step (`StepType = AutoTask`) runs the flow
`VEL_Maintenance_Contract_DRO_Task` when a maintenance or extended warranty product is
included in the order. The flow:

- Receives `planSourceIdentifierId` (Order ID) from DRO
- Looks up the order's Quote and finds a QuoteLineItem whose product name contains
  "Maintenance" or "Warranty" (filter: `1 OR 2`)
- Presents a screen for the fulfillment agent to confirm Service Contract details
  (name, start/end dates, account, contact)
- Creates a `ServiceContract`, one or more `Entitlements`, and a `ContractLineItem`

**Triggering products** (all route to `VEL-DRO-MAINT` via PFDR):

| Source SKU | Product Name |
|------------|-------------|
| `VEL-SRV-MAINT-PKG` | VELPACK Maintenance — Standard |
| `VEL-SRV-MAINT-PKG-PREM` | VELPACK Maintenance — Premium |
| `VEL-SRV-MAINT-LSR` | PrecisionBeam+ Maintenance Plan |
| `VEL-SRV-WARRANTY-PKG` | Extended Warranty (VELPACK G1) |
| `VEL-SRV-WARRANTY-LSR` | Extended Warranty (PrecisionBeam+) |
| `VEL-STP-SRV-MAINT-STD` | VelTherma Standard Maintenance Contract |
| `VEL-STP-SRV-MAINT-PREM` | VelTherma Premium Maintenance Contract |

**Cross-group dependency**: When hardware is also ordered (VEL-DRO-INST in the plan),
`VEL Create Service Contract` waits for `VEL Commissioning & Calibration` to complete
before executing. For maintenance-only orders without hardware, the step runs immediately
(the dependency step is absent from the plan).

**Note on VEL-SRV-WARRANTY-PKG / VEL-SRV-WARRANTY-LSR**: These warranty SKUs exist in
the PCM catalog (`vel-pcm`) but had no prior DRO configuration. They are now added to
`vel-dro/Product2.csv` and wired to `VEL-DRO-MAINT` via PFDR rules.

## Cross-group dependencies

14 `FulfillmentStepDependencyDef` records wire the end-to-end flow across groups:

| Depends On (upstream) | Triggers (downstream) | Connection Name |
|-----------------------|-----------------------|-----------------|
| Post Advance Invoice | Schedule Production | VEL Advance to Production |
| Post Advance Invoice | Site Survey | VEL Advance to Survey |
| Schedule Production | Machine Assembly | VEL Schedule to Assembly |
| Machine Assembly | Factory Acceptance Test | VEL Assembly to FAT |
| Factory Acceptance Test | Arrange Freight | VEL FAT to Freight |
| Arrange Freight | Confirm Delivery Date | VEL Freight to Delivery |
| Confirm Delivery Date | On-Site Installation | VEL Delivery to Install |
| Site Survey | On-Site Installation | VEL Survey to Install |
| On-Site Installation | Commissioning & Calibration | VEL Install to Commission |
| Commissioning & Calibration | Process Final Invoice | VEL Commission to Invoice |
| Process Final Invoice | Receive Payment | VEL Invoice to Payment |
| Commissioning & Calibration | Register Warranty | VEL Commission to Warranty |
| Commissioning & Calibration | Activate Software License | VEL Commission to Software |
| Commissioning & Calibration | **VEL Create Service Contract** | **VEL Commission to Svc Contract** |

## Loading strategy

- All operations are **Upsert** (matched on `Name`) — safe to re-run
- `FulfillmentWorkspaceItem` uses **Upsert + deleteOldData** scoped to `Velantis Machine Fulfillment` — clears existing Velantis workspace items then re-inserts; QB pattern; does not affect other workspaces
- `deleteOldData` only affects `FulfillmentWorkspaceItem` scoped to the Velantis workspace
- DRO routing products (`VEL-DRO-*`) are `IsActive = true` — required for the platform to create decomposed order line items; they are not visible in the storefront because they have no `PricebookEntry` records and are never placed in a product catalog

## Known issues

1. **`ExecuteOnRuleId` not generated on INSERT** (platform bug 260/262): Run `update_vel_pfdr_rules` after first load.
2. **`ScenarioRuleId` not generated on INSERT** (platform bug 260/262): After the first load, re-save the `VEL Maintenance Contract Service` `ProductFulfillmentScenario` record via the UI or Apex to populate `ScenarioRuleId`.
3. **`FulfillmentStepJeopardyRule.Name` is auto-numbered**: The placeholder names (VEL-FSJR-001 through 005) will be replaced by platform-assigned auto-numbered names on insert. After the first deploy, query the records and update the CSV names to the platform-assigned values for idempotency on subsequent runs.
