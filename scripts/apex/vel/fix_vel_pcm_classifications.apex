// Fix VEL bundle attribute scoping:
//   BEFORE: both bundles share VEL_INDUSTRIAL_HW with ALL 5 attributes
//   AFTER:  VEL_PKG_BDL → 3 packaging attrs (VELPACK G1)
//           VEL_LSR_BDL → 2 laser attrs (PrecisionBeam+)
//
// Safe to re-run (idempotent).

// ── 1. Delete incorrect PAD records linked to VEL_INDUSTRIAL_HW for bundles ──
List<ProductAttributeDefinition> wrongPads = [
    SELECT Id FROM ProductAttributeDefinition
    WHERE Product2.StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')
    AND ProductClassificationAttribute.ProductClassification.Code = 'VEL_INDUSTRIAL_HW'
];
if (!wrongPads.isEmpty()) {
    delete wrongPads;
    System.debug('Deleted wrong PAD records: ' + wrongPads.size());
}

// ── 2. Delete incorrect PCA records on VEL_INDUSTRIAL_HW (packaging+laser attrs) ──
List<ProductClassificationAttr> wrongPca = [
    SELECT Id FROM ProductClassificationAttr
    WHERE ProductClassification.Code = 'VEL_INDUSTRIAL_HW'
    AND AttributeDefinition.Code IN (
        'ATTR-VEL-PKG-CFG','ATTR-VEL-COMPLIANCE','ATTR-VEL-CAPACITY',
        'ATTR-VEL-SIZE','ATTR-VEL-POWER')
];
if (!wrongPca.isEmpty()) {
    delete wrongPca;
    System.debug('Deleted wrong PCA records: ' + wrongPca.size());
}

// ── 3. Reset bundle product BasedOnId to null (will be set after new PCs exist) ──
List<Product2> bundles = [
    SELECT Id FROM Product2
    WHERE StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')
    AND BasedOnId != null
    AND BasedOn.Code = 'VEL_INDUSTRIAL_HW'
];
for (Product2 p : bundles) p.BasedOnId = null;
if (!bundles.isEmpty()) {
    update bundles;
    System.debug('Reset BasedOnId on ' + bundles.size() + ' bundle products');
}

// ── 4. Create two bundle-specific ProductClassifications ──────────────────────
Map<String, Id> pcId = new Map<String, Id>();
for (ProductClassification pc : [SELECT Id, Code FROM ProductClassification WHERE Code LIKE 'VEL_%'])
    pcId.put(pc.Code, pc.Id);

List<ProductClassification> newPcs = new List<ProductClassification>();
if (!pcId.containsKey('VEL_PKG_BDL'))
    newPcs.add(new ProductClassification(Code='VEL_PKG_BDL',
        Name='VELPACK G1 Packaging Bundle', Status='Active'));
if (!pcId.containsKey('VEL_LSR_BDL'))
    newPcs.add(new ProductClassification(Code='VEL_LSR_BDL',
        Name='PrecisionBeam+ Laser Bundle', Status='Active'));
if (!newPcs.isEmpty()) {
    insert newPcs;
    for (ProductClassification pc : newPcs) pcId.put(pc.Code, pc.Id);
    System.debug('Created ProductClassifications: ' + newPcs.size());
}

// ── 5. Reload attribute IDs ───────────────────────────────────────────────────
Map<String, Id> attrId = new Map<String, Id>();
for (AttributeDefinition a : [SELECT Id, Code FROM AttributeDefinition WHERE Code LIKE 'ATTR-VEL-%'])
    attrId.put(a.Code, a.Id);

Map<String, Id> catId = new Map<String, Id>();
for (AttributeCategory c : [SELECT Id, Code FROM AttributeCategory WHERE Code LIKE 'VEL_%'])
    catId.put(c.Code, c.Id);

// ── 6. Create PCA for VEL_PKG_BDL (packaging attrs only) ─────────────────────
Set<String> existingPca = new Set<String>();
for (ProductClassificationAttr pca : [
    SELECT ProductClassificationId, AttributeDefinitionId FROM ProductClassificationAttr
    WHERE ProductClassification.Code IN ('VEL_PKG_BDL','VEL_LSR_BDL')
]) existingPca.add(pca.ProductClassificationId + '|' + pca.AttributeDefinitionId);

List<ProductClassificationAttr> pcaToInsert = new List<ProductClassificationAttr>();
for (List<Object> row : new List<List<Object>>{
    // VEL_PKG_BDL — packaging system attributes
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-PKG-CFG',   'Standard',       false,false,false,true, 10},
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-COMPLIANCE', 'Standard',       false,false,false,true, 20},
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-CAPACITY',   '23400000',       false,false,true, false,30},
    // VEL_LSR_BDL — laser system attributes
    new List<Object>{'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-SIZE',       '1530',           false,false,false,true, 10},
    new List<Object>{'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-POWER',      'Standard (4 kW)',false,false,false,true, 20}
}) {
    String pcCode   = (String)row[0];
    String catCode  = (String)row[1];
    String attrCode = (String)row[2];
    String defVal   = (String)row[3];
    Id pcIdVal   = pcId.get(pcCode);
    Id attrIdVal = attrId.get(attrCode);
    if (existingPca.contains(pcIdVal + '|' + attrIdVal)) continue;

    ProductClassificationAttr pca = new ProductClassificationAttr(
        ProductClassificationId=pcIdVal, AttributeDefinitionId=attrIdVal,
        AttributeCategoryId=catId.get(catCode),
        IsHidden=(Boolean)row[4], IsPriceImpacting=(Boolean)row[5],
        IsReadOnly=(Boolean)row[6], IsRequired=(Boolean)row[7],
        Sequence=(Integer)row[8], Status='Active',
        Name=pcCode + ' ' + attrCode);
    if (String.isNotBlank(defVal)) pca.DefaultValue = defVal;
    pcaToInsert.add(pca);
}
if (!pcaToInsert.isEmpty()) {
    insert pcaToInsert;
    System.debug('Created PCA records: ' + pcaToInsert.size());
}

// ── 7. Reload PCA map ─────────────────────────────────────────────────────────
Map<String, Id> pcaId = new Map<String, Id>();
for (ProductClassificationAttr pca : [
    SELECT Id, ProductClassificationId, AttributeDefinitionId FROM ProductClassificationAttr
    WHERE ProductClassification.Code IN ('VEL_PKG_BDL','VEL_LSR_BDL')
]) pcaId.put(pca.ProductClassificationId + '|' + pca.AttributeDefinitionId, pca.Id);

// ── 8. Update bundle products BasedOnId ───────────────────────────────────────
Map<String, Id> prodId = new Map<String, Id>();
for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2
                   WHERE StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')])
    prodId.put(p.StockKeepingUnit, p.Id);

List<Product2> prodsToUpdate = [
    SELECT Id, StockKeepingUnit, BasedOnId FROM Product2
    WHERE StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')
];
for (Product2 p : prodsToUpdate) {
    if (p.StockKeepingUnit == 'VEL-PACK-G1-BDL') p.BasedOnId = pcId.get('VEL_PKG_BDL');
    if (p.StockKeepingUnit == 'VEL-LSR-BDL')     p.BasedOnId = pcId.get('VEL_LSR_BDL');
}
if (!prodsToUpdate.isEmpty()) {
    update prodsToUpdate;
    System.debug('Updated bundle product BasedOnId: ' + prodsToUpdate.size());
}

// ── 9. Create corrected PAD records ──────────────────────────────────────────
Set<String> existingPad = new Set<String>();
for (ProductAttributeDefinition pad : [
    SELECT AttributeDefinitionId, Product2Id FROM ProductAttributeDefinition
    WHERE Product2.StockKeepingUnit LIKE 'VEL-%'
]) existingPad.add(pad.AttributeDefinitionId + '|' + pad.Product2Id);

List<ProductAttributeDefinition> padToInsert = new List<ProductAttributeDefinition>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL-PACK-G1-BDL','VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-PKG-CFG',   'Standard',       false,false,false,true, 10,'Active'},
    new List<Object>{'VEL-PACK-G1-BDL','VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-COMPLIANCE', 'Standard',       false,false,false,true, 20,'Active'},
    new List<Object>{'VEL-PACK-G1-BDL','VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-CAPACITY',   '23400000',       false,false,true, false,30,'Active'},
    new List<Object>{'VEL-LSR-BDL',    'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-SIZE',        '1530',           false,false,false,true, 10,'Active'},
    new List<Object>{'VEL-LSR-BDL',    'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-POWER',       'Standard (4 kW)',false,false,false,true, 20,'Active'}
}) {
    String sku      = (String)row[0];
    String pcCode   = (String)row[1];
    String catCode  = (String)row[2];
    String attrCode = (String)row[3];
    String defVal   = (String)row[4];

    Id pId   = prodId.get(sku);
    Id aId   = attrId.get(attrCode);
    Id pcIdV = pcId.get(pcCode);
    if (pId == null || aId == null || pcIdV == null) continue;
    if (existingPad.contains(aId + '|' + pId)) continue;

    Id pcaIdVal = pcaId.get(pcIdV + '|' + aId);
    if (pcaIdVal == null) { System.debug('WARN: no PCA for ' + pcCode + ' / ' + attrCode); continue; }

    ProductAttributeDefinition pad = new ProductAttributeDefinition(
        Product2Id=pId, AttributeDefinitionId=aId,
        AttributeCategoryId=catId.get(catCode),
        ProductClassificationAttributeId=pcaIdVal,
        IsHidden=(Boolean)row[5], IsPriceImpacting=(Boolean)row[6],
        IsReadOnly=(Boolean)row[7], IsRequired=(Boolean)row[8],
        Sequence=(Integer)row[9], Status=(String)row[10],
        Name=attrCode + ' ' + sku);
    if (String.isNotBlank(defVal)) pad.DefaultValue = defVal;
    padToInsert.add(pad);
}
if (!padToInsert.isEmpty()) {
    insert padToInsert;
    System.debug('Created PAD records: ' + padToInsert.size());
}

System.debug('Classification fix complete.');
