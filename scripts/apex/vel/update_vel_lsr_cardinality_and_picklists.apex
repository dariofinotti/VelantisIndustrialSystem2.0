// Update PrecisionBeam+ Laser bundle:
//   1. Relax MaxBundleComponents to null on Machine Frame and Laser Source Module groups
//   2. Add blank (empty) picklist value to VEL_MachineSize and VEL_LaserPower
//   3. Demote old IsDefault flags (1530 and Standard 4 kW) so blank is the new default
//
// Run via: sf apex run --file scripts/apex/vel/update_vel_lsr_cardinality_and_picklists.apex --target-org <alias>

// ── 1. Relax Max cardinality ──────────────────────────────────────────────────
List<ProductComponentGroup> toUpdate = new List<ProductComponentGroup>();
for (ProductComponentGroup pcg : [
    SELECT Id, Code, MaxBundleComponents
    FROM ProductComponentGroup
    WHERE Code IN ('PCG-VEL-LSR-FRAME', 'PCG-VEL-LSR-POWER')
]) {
    pcg.MaxBundleComponents = null;
    toUpdate.add(pcg);
}
if (!toUpdate.isEmpty()) {
    update toUpdate;
    System.debug('Relaxed MaxBundleComponents on ' + toUpdate.size() + ' groups.');
} else {
    System.debug('WARN: PCG-VEL-LSR-FRAME / PCG-VEL-LSR-POWER not found.');
}

// ── 2. Add blank picklist values ─────────────────────────────────────────────
Map<String, Id> picklistIdByName = new Map<String, Id>();
for (AttributePicklist pl : [
    SELECT Id, Name FROM AttributePicklist
    WHERE Name IN ('VEL_MachineSize', 'VEL_LaserPower')
]) {
    picklistIdByName.put(pl.Name, pl.Id);
}
System.debug('Found picklists: ' + picklistIdByName.keySet());

Set<String> existingCodes = new Set<String>();
for (AttributePicklistValue v : [
    SELECT Code FROM AttributePicklistValue
    WHERE Code IN ('VEL_SIZE_NONE', 'VEL_PWR_NONE')
]) {
    existingCodes.add(v.Code);
}

List<AttributePicklistValue> pvsToInsert = new List<AttributePicklistValue>();
// NOTE: Insert must run AFTER demoting old defaults (platform rejects two IsDefault=true on same picklist).
// Run steps separately if needed: demote first, then insert.
if (!existingCodes.contains('VEL_SIZE_NONE') && picklistIdByName.containsKey('VEL_MachineSize')) {
    pvsToInsert.add(new AttributePicklistValue(
        Code='VEL_SIZE_NONE', Name='none', DisplayValue='none', Value='none',
        IsDefault=true, Sequence=0, Status='Active',
        PicklistId=picklistIdByName.get('VEL_MachineSize')
    ));
}
if (!existingCodes.contains('VEL_PWR_NONE') && picklistIdByName.containsKey('VEL_LaserPower')) {
    pvsToInsert.add(new AttributePicklistValue(
        Code='VEL_PWR_NONE', Name='none', DisplayValue='none', Value='none',
        IsDefault=true, Sequence=0, Status='Active',
        PicklistId=picklistIdByName.get('VEL_LaserPower')
    ));
}
if (!pvsToInsert.isEmpty()) {
    insert pvsToInsert;
    System.debug('Inserted ' + pvsToInsert.size() + ' blank AttributePicklistValue records.');
} else {
    System.debug('Blank picklist values already exist — skipped.');
}

// ── 3. Demote old defaults ────────────────────────────────────────────────────
List<AttributePicklistValue> pvsToUpdate = new List<AttributePicklistValue>();
for (AttributePicklistValue v : [
    SELECT Id, Code, IsDefault FROM AttributePicklistValue
    WHERE Code IN ('VEL_SIZE_1530', 'VEL_PWR_4KW') AND IsDefault = true
]) {
    v.IsDefault = false;
    pvsToUpdate.add(v);
}
if (!pvsToUpdate.isEmpty()) {
    update pvsToUpdate;
    System.debug('Demoted old defaults: ' + pvsToUpdate.size() + ' values.');
} else {
    System.debug('Old defaults already demoted — skipped.');
}

System.debug('Done.');
