// Consolidate Velantis service component groups.
//
// BEFORE: 3 separate groups per bundle (Install / Maintenance / Warranty)
// AFTER:  1 unified "Add-on Services" group per bundle holding all three service types
//
// Steps:
//   1. Create PCG-VEL-PKG-SERVICES (Max=4) and PCG-VEL-LSR-SERVICES (Max=3)
//   2. Move PRC records from the 6 old service groups to the new consolidated groups
//   3. Delete the old PRCs that pointed to the 6 old groups
//   4. Delete the 6 old PCG records
//
// Idempotent: safe to re-run (new PCGs skipped if Code already exists).
//
// Run via: sf apex run --file scripts/apex/vel/consolidate_vel_service_groups.apex --target-org <username>

// ── 1. Product IDs ────────────────────────────────────────────────────────────
Map<String, Id> prodById = new Map<String, Id>();
for (Product2 p : [
    SELECT Id, StockKeepingUnit FROM Product2
    WHERE StockKeepingUnit IN (
        'VEL-PACK-G1-BDL', 'VEL-LSR-BDL',
        'VEL-SRV-INSTALL-PKG', 'VEL-SRV-MAINT-PKG', 'VEL-SRV-MAINT-PKG-PREM',
        'VEL-SRV-WARRANTY-PKG',
        'VEL-SRV-INSTALL-LSR', 'VEL-SRV-MAINT-LSR', 'VEL-SRV-WARRANTY-LSR'
    )
]) {
    prodById.put(p.StockKeepingUnit, p.Id);
}

// ── 2. ProductRelationshipType ────────────────────────────────────────────────
Id prtId = [
    SELECT Id FROM ProductRelationshipType
    WHERE Name = 'Bundle to Bundle Component Relationship' LIMIT 1
].Id;

// ── 3. Existing PCG codes → Ids ───────────────────────────────────────────────
Map<String, Id> pcgByCode = new Map<String, Id>();
for (ProductComponentGroup g : [
    SELECT Id, Code FROM ProductComponentGroup WHERE Code LIKE 'PCG-VEL-%'
]) {
    pcgByCode.put(g.Code, g.Id);
}

// ── 4. Create the two new consolidated service groups (idempotent) ─────────────
List<ProductComponentGroup> newGroups = new List<ProductComponentGroup>();

if (!pcgByCode.containsKey('PCG-VEL-PKG-SERVICES'))
    newGroups.add(new ProductComponentGroup(
        Code='PCG-VEL-PKG-SERVICES', Name='Add-on Services',
        Description='Optional add-on services — installation / maintenance / warranty (choose any combination)',
        MinBundleComponents=0, MaxBundleComponents=4, Sequence=40,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

if (!pcgByCode.containsKey('PCG-VEL-LSR-SERVICES'))
    newGroups.add(new ProductComponentGroup(
        Code='PCG-VEL-LSR-SERVICES', Name='Add-on Services',
        Description='Optional add-on services — installation / maintenance / warranty (choose any combination)',
        MinBundleComponents=0, MaxBundleComponents=3, Sequence=50,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!newGroups.isEmpty()) {
    insert newGroups;
    System.debug('Created ' + newGroups.size() + ' new consolidated service group(s).');
    // Reload map so we have the new Ids
    for (ProductComponentGroup g : newGroups) {
        pcgByCode.put(g.Code, g.Id);
    }
} else {
    System.debug('Consolidated service groups already exist — skipping creation.');
}

// ── 5. Find old PRCs to replace ───────────────────────────────────────────────
Set<String> oldGroupCodes = new Set<String>{
    'PCG-VEL-PKG-INSTALL', 'PCG-VEL-PKG-MAINT', 'PCG-VEL-PKG-WARRANTY',
    'PCG-VEL-LSR-INSTALL', 'PCG-VEL-LSR-MAINT', 'PCG-VEL-LSR-WARRANTY'
};

Set<Id> oldGroupIds = new Set<Id>();
for (String code : oldGroupCodes) {
    if (pcgByCode.containsKey(code)) oldGroupIds.add(pcgByCode.get(code));
}

List<ProductRelatedComponent> oldPrcs = [
    SELECT Id, ParentProductId, ChildProductId, ProductComponentGroupId,
           ProductRelationshipTypeId, IsComponentRequired, IsDefaultComponent,
           IsQuantityEditable, Quantity, QuoteVisibility, Sequence
    FROM ProductRelatedComponent
    WHERE ProductComponentGroupId IN :oldGroupIds
];

System.debug('Found ' + oldPrcs.size() + ' PRC record(s) pointing to old service groups.');

// ── 6. Build replacement PRC records ─────────────────────────────────────────
//  Mapping: old group code → new group code
Map<Id, Id> oldToNewPcgId = new Map<Id, Id>();
for (String oldCode : new List<String>{
        'PCG-VEL-PKG-INSTALL', 'PCG-VEL-PKG-MAINT', 'PCG-VEL-PKG-WARRANTY'}) {
    if (pcgByCode.containsKey(oldCode) && pcgByCode.containsKey('PCG-VEL-PKG-SERVICES'))
        oldToNewPcgId.put(pcgByCode.get(oldCode), pcgByCode.get('PCG-VEL-PKG-SERVICES'));
}
for (String oldCode : new List<String>{
        'PCG-VEL-LSR-INSTALL', 'PCG-VEL-LSR-MAINT', 'PCG-VEL-LSR-WARRANTY'}) {
    if (pcgByCode.containsKey(oldCode) && pcgByCode.containsKey('PCG-VEL-LSR-SERVICES'))
        oldToNewPcgId.put(pcgByCode.get(oldCode), pcgByCode.get('PCG-VEL-LSR-SERVICES'));
}

// Sequence map for the VELPACK services group (install=10, maint-std=20, maint-prem=30, warranty=40)
Map<Id, Integer> pkgSvcSequence = new Map<Id, Integer>{
    prodById.get('VEL-SRV-INSTALL-PKG')    => 10,
    prodById.get('VEL-SRV-MAINT-PKG')      => 20,
    prodById.get('VEL-SRV-MAINT-PKG-PREM') => 30,
    prodById.get('VEL-SRV-WARRANTY-PKG')   => 40
};
// Sequence map for the Laser services group (install=10, maint=20, warranty=30)
Map<Id, Integer> lsrSvcSequence = new Map<Id, Integer>{
    prodById.get('VEL-SRV-INSTALL-LSR')  => 10,
    prodById.get('VEL-SRV-MAINT-LSR')    => 20,
    prodById.get('VEL-SRV-WARRANTY-LSR') => 30
};

// Guard: skip if the new PRC already exists
Set<String> existingNewKeys = new Set<String>();
Id pkgSvcId = pcgByCode.get('PCG-VEL-PKG-SERVICES');
Id lsrSvcId = pcgByCode.get('PCG-VEL-LSR-SERVICES');
for (ProductRelatedComponent prc : [
    SELECT ParentProductId, ProductComponentGroupId, ChildProductId
    FROM ProductRelatedComponent
    WHERE ProductComponentGroupId IN (:pkgSvcId, :lsrSvcId)
]) {
    existingNewKeys.add(prc.ParentProductId + '|' + prc.ProductComponentGroupId + '|' + prc.ChildProductId);
}

List<ProductRelatedComponent> newPrcs = new List<ProductRelatedComponent>();
for (ProductRelatedComponent old : oldPrcs) {
    Id newPcgId = oldToNewPcgId.get(old.ProductComponentGroupId);
    if (newPcgId == null) continue;

    String dedupeKey = old.ParentProductId + '|' + newPcgId + '|' + old.ChildProductId;
    if (existingNewKeys.contains(dedupeKey)) continue;

    Integer seq = pkgSvcSequence.containsKey(old.ChildProductId)
        ? pkgSvcSequence.get(old.ChildProductId)
        : (lsrSvcSequence.containsKey(old.ChildProductId)
            ? lsrSvcSequence.get(old.ChildProductId)
            : old.Sequence);

    newPrcs.add(new ProductRelatedComponent(
        ParentProductId=old.ParentProductId,
        ChildProductId=old.ChildProductId,
        ProductComponentGroupId=newPcgId,
        ProductRelationshipTypeId=prtId,
        IsComponentRequired=old.IsComponentRequired,
        IsDefaultComponent=old.IsDefaultComponent,
        IsQuantityEditable=old.IsQuantityEditable,
        Quantity=old.Quantity,
        QuoteVisibility=old.QuoteVisibility,
        Sequence=seq));
}

if (!newPrcs.isEmpty()) {
    insert newPrcs;
    System.debug('Inserted ' + newPrcs.size() + ' replacement PRC record(s) in the new groups.');
}

// ── 7. Delete old PRCs ────────────────────────────────────────────────────────
if (!oldPrcs.isEmpty()) {
    delete oldPrcs;
    System.debug('Deleted ' + oldPrcs.size() + ' old service PRC record(s).');
}

// ── 8. Delete old PCGs (only if they are now empty) ───────────────────────────
List<ProductComponentGroup> pcgsToDelete = [
    SELECT Id, Code FROM ProductComponentGroup WHERE Code IN :oldGroupCodes
];
if (!pcgsToDelete.isEmpty()) {
    delete pcgsToDelete;
    System.debug('Deleted ' + pcgsToDelete.size() + ' old service PCG record(s): '
        + String.join(new List<String>(oldGroupCodes), ', '));
}

System.debug('Velantis service group consolidation complete.');
