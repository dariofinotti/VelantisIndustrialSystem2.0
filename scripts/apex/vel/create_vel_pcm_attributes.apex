// Create VEL AttributePicklist, AttributePicklistValue, AttributeDefinition,
// AttributeCategory, AttributeCategoryAttribute, and ProductAttributeDefinition
// records. Idempotent — skips objects whose Code/Name already exists.
//
// Bypass for SFDMU Bulk REST API silent-failure on BRC260 trial org.

// ── 1. Idempotency guards ─────────────────────────────────────────────────────
Set<String> existingPlCodes = new Set<String>();
for (AttributePicklist p : [SELECT Name FROM AttributePicklist WHERE Name LIKE 'VEL_%'])
    existingPlCodes.add(p.Name);

Set<String> existingAttrCodes = new Set<String>();
for (AttributeDefinition a : [SELECT Code FROM AttributeDefinition WHERE Code LIKE 'ATTR-VEL-%'])
    existingAttrCodes.add(a.Code);

Set<String> existingCatCodes = new Set<String>();
for (AttributeCategory c : [SELECT Code FROM AttributeCategory WHERE Code LIKE 'VEL_%'])
    existingCatCodes.add(c.Code);

// ── 2. AttributePicklist ──────────────────────────────────────────────────────
List<AttributePicklist> plToInsert = new List<AttributePicklist>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_PackagingConfig', 'Text'},
    new List<Object>{'VEL_Compliance',      'Text'},
    new List<Object>{'VEL_MachineSize',     'Text'},
    new List<Object>{'VEL_LaserPower',      'Text'}
}) {
    String nm = (String)row[0];
    if (!existingPlCodes.contains(nm))
        plToInsert.add(new AttributePicklist(
            Name=(String)row[0], Code=(String)row[0],
            DataType='Text', Status='Active'));
}
if (!plToInsert.isEmpty()) insert plToInsert;
System.debug('AttributePicklist inserted: ' + plToInsert.size());

// ── 3. Reload Picklist Name → Id ──────────────────────────────────────────────
Map<String, Id> plId = new Map<String, Id>();
for (AttributePicklist p : [SELECT Id, Name FROM AttributePicklist WHERE Name LIKE 'VEL_%'])
    plId.put(p.Name, p.Id);

// ── 4. AttributePicklistValue ─────────────────────────────────────────────────
Set<String> existingPlvCodes = new Set<String>();
for (AttributePicklistValue v : [SELECT Code FROM AttributePicklistValue WHERE Code LIKE 'VEL_%'])
    existingPlvCodes.add(v.Code);

List<AttributePicklistValue> plvToInsert = new List<AttributePicklistValue>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_PackagingConfig','VEL_PKGCFG_STD','Standard',  true, 1},
    new List<Object>{'VEL_PackagingConfig','VEL_PKGCFG_INT','Integrated',false, 2},
    new List<Object>{'VEL_PackagingConfig','VEL_PKGCFG_SA', 'StandAlone',false, 3},
    new List<Object>{'VEL_Compliance',     'VEL_COMP_STD',  'Standard',  true, 1},
    new List<Object>{'VEL_Compliance',     'VEL_COMP_GMP',  'GMP_Plus',  false,2},
    new List<Object>{'VEL_Compliance',     'VEL_COMP_FDA',  'FDA_21_CFR',false,3},
    new List<Object>{'VEL_MachineSize',    'VEL_SIZE_1530', '1530',      true, 1},
    new List<Object>{'VEL_MachineSize',    'VEL_SIZE_2040', '2040',      false,2},
    new List<Object>{'VEL_MachineSize',    'VEL_SIZE_2060', '2060',      false,3},
    new List<Object>{'VEL_LaserPower',     'VEL_PWR_4KW',  'Standard (4 kW)', true, 1},
    new List<Object>{'VEL_LaserPower',     'VEL_PWR_10KW', 'High (10 kW)',    false,2},
    new List<Object>{'VEL_LaserPower',     'VEL_PWR_15KW', 'Ultra (15 kW)',   false,3}
}) {
    String code = (String)row[1];
    if (!existingPlvCodes.contains(code))
        plvToInsert.add(new AttributePicklistValue(
            PicklistId=plId.get((String)row[0]),
            Code=code, Name=(String)row[2], Value=(String)row[2],
            DisplayValue=(String)row[2],
            IsDefault=(Boolean)row[3], Sequence=(Integer)row[4],
            Status='Active'));
}
if (!plvToInsert.isEmpty()) insert plvToInsert;
System.debug('AttributePicklistValue inserted: ' + plvToInsert.size());

// ── 5. AttributeDefinition ────────────────────────────────────────────────────
List<AttributeDefinition> attrToInsert = new List<AttributeDefinition>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'ATTR-VEL-PKG-CFG',    'ATTR_VEL_PKG_CFG',    'Packaging Configuration',                  'Picklist', 'Standard',       true,  true,  'VEL_PackagingConfig'},
    new List<Object>{'ATTR-VEL-COMPLIANCE', 'ATTR_VEL_COMPLIANCE', 'Regulatory Compliance',                    'Picklist', 'Standard',       true,  true,  'VEL_Compliance'},
    new List<Object>{'ATTR-VEL-CAPACITY',   'ATTR_VEL_CAPACITY',   'Est. Annual Capacity (Blisters/yr)',       'Number',   '',               true,  false, null},
    new List<Object>{'ATTR-VEL-SIZE',       'ATTR_VEL_SIZE',       'Machine Size',                             'Picklist', '1530',           true,  true,  'VEL_MachineSize'},
    new List<Object>{'ATTR-VEL-POWER',      'ATTR_VEL_POWER',      'Laser Power',                              'Picklist', 'Standard (4 kW)',true,  true,  'VEL_LaserPower'}
}) {
    String code = (String)row[0];
    if (!existingAttrCodes.contains(code)) {
        AttributeDefinition a = new AttributeDefinition(
            Code=code, DeveloperName=(String)row[1],
            Name=(String)row[2], Label=(String)row[2],
            DataType=(String)row[3],
            IsActive=(Boolean)row[6], IsRequired=(Boolean)row[7]);
        String defVal = (String)row[4];
        if (String.isNotBlank(defVal)) a.DefaultValue = defVal;
        String plName = (String)row[8];
        if (plName != null && plId.containsKey(plName)) a.PicklistId = plId.get(plName);
        attrToInsert.add(a);
    }
}
if (!attrToInsert.isEmpty()) insert attrToInsert;
System.debug('AttributeDefinition inserted: ' + attrToInsert.size());

// ── 6. AttributeCategory ──────────────────────────────────────────────────────
List<AttributeCategory> catToInsert = new List<AttributeCategory>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_PKG_SPECS','Packaging System Specifications',
        'Technical and regulatory specifications for VELPACK G1 packaging machines'},
    new List<Object>{'VEL_LSR_SPECS','Laser System Specifications',
        'Technical configuration specifications for PrecisionBeam+ laser cutting systems'}
}) {
    String code = (String)row[0];
    if (!existingCatCodes.contains(code))
        catToInsert.add(new AttributeCategory(Code=code, Name=(String)row[1], Description=(String)row[2]));
}
if (!catToInsert.isEmpty()) insert catToInsert;
System.debug('AttributeCategory inserted: ' + catToInsert.size());

// ── 7. Reload attr code → Id, cat code → Id ───────────────────────────────────
Map<String, Id> attrId = new Map<String, Id>();
for (AttributeDefinition a : [SELECT Id, Code FROM AttributeDefinition WHERE Code LIKE 'ATTR-VEL-%'])
    attrId.put(a.Code, a.Id);

Map<String, Id> catId = new Map<String, Id>();
for (AttributeCategory c : [SELECT Id, Code FROM AttributeCategory WHERE Code LIKE 'VEL_%'])
    catId.put(c.Code, c.Id);

// ── 8. AttributeCategoryAttribute ─────────────────────────────────────────────
Set<String> existingAca = new Set<String>();
for (AttributeCategoryAttribute aca : [
    SELECT AttributeCategoryId, AttributeDefinitionId FROM AttributeCategoryAttribute
    WHERE AttributeCategory.Code LIKE 'VEL_%'
]) existingAca.add(aca.AttributeCategoryId + '|' + aca.AttributeDefinitionId);

List<AttributeCategoryAttribute> acaToInsert = new List<AttributeCategoryAttribute>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_PKG_SPECS','ATTR-VEL-PKG-CFG'},
    new List<Object>{'VEL_PKG_SPECS','ATTR-VEL-COMPLIANCE'},
    new List<Object>{'VEL_PKG_SPECS','ATTR-VEL-CAPACITY'},
    new List<Object>{'VEL_LSR_SPECS','ATTR-VEL-SIZE'},
    new List<Object>{'VEL_LSR_SPECS','ATTR-VEL-POWER'}
}) {
    String catCode  = (String)row[0];
    String attrCode = (String)row[1];
    Id cId = catId.get(catCode);
    Id aId = attrId.get(attrCode);
    if (cId != null && aId != null && !existingAca.contains(cId + '|' + aId))
        acaToInsert.add(new AttributeCategoryAttribute(
            AttributeCategoryId=cId, AttributeDefinitionId=aId));
}
if (!acaToInsert.isEmpty()) insert acaToInsert;
System.debug('AttributeCategoryAttribute inserted: ' + acaToInsert.size());

// ── 9. ProductClassification ──────────────────────────────────────────────────
Set<String> existingPcCodes = new Set<String>();
for (ProductClassification pc : [SELECT Code FROM ProductClassification WHERE Code LIKE 'VEL_%'])
    existingPcCodes.add(pc.Code);

List<ProductClassification> pcToInsert = new List<ProductClassification>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_INDUSTRIAL_HW', 'Velantis Industrial Hardware'},
    new List<Object>{'VEL_INDUSTRIAL_SVC','Velantis Industrial Services'},
    new List<Object>{'VEL_INDUSTRIAL_SW', 'Velantis Industrial Software'},
    new List<Object>{'VEL_PKG_BDL',       'VELPACK G1 Packaging Bundle'},
    new List<Object>{'VEL_LSR_BDL',       'PrecisionBeam+ Laser Bundle'}
}) {
    String code = (String)row[0];
    if (!existingPcCodes.contains(code))
        pcToInsert.add(new ProductClassification(Code=code, Name=(String)row[1], Status='Active'));
}
if (!pcToInsert.isEmpty()) insert pcToInsert;
System.debug('ProductClassification inserted: ' + pcToInsert.size());

Map<String, Id> pcId = new Map<String, Id>();
for (ProductClassification pc : [SELECT Id, Code FROM ProductClassification WHERE Code LIKE 'VEL_%'])
    pcId.put(pc.Code, pc.Id);

// ── 10. ProductClassificationAttr ─────────────────────────────────────────────
// VEL_PKG_BDL → packaging attrs only (VELPACK G1)
// VEL_LSR_BDL → laser attrs only (PrecisionBeam+)
Set<String> existingPca = new Set<String>();
for (ProductClassificationAttr pca : [
    SELECT ProductClassificationId, AttributeDefinitionId FROM ProductClassificationAttr
    WHERE ProductClassification.Code LIKE 'VEL_%'
]) existingPca.add(pca.ProductClassificationId + '|' + pca.AttributeDefinitionId);

List<ProductClassificationAttr> pcaToInsert = new List<ProductClassificationAttr>();
for (List<Object> row : new List<List<Object>>{
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-PKG-CFG',   'Standard',       false,false,false,true, 10},
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-COMPLIANCE', 'Standard',       false,false,false,true, 20},
    new List<Object>{'VEL_PKG_BDL','VEL_PKG_SPECS','ATTR-VEL-CAPACITY',   '23400000',       false,false,true, false,30},
    new List<Object>{'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-SIZE',       '1530',           false,false,false,true, 10},
    new List<Object>{'VEL_LSR_BDL','VEL_LSR_SPECS','ATTR-VEL-POWER',      'Standard (4 kW)',false,false,false,true, 20}
}) {
    String pcCode   = (String)row[0];
    String catCode  = (String)row[1];
    String attrCode = (String)row[2];
    String defVal   = (String)row[3];
    Boolean isHidden     = (Boolean)row[4];
    Boolean isPriceImpact= (Boolean)row[5];
    Boolean isReadOnly   = (Boolean)row[6];
    Boolean isRequired   = (Boolean)row[7];
    Integer seq          = (Integer)row[8];

    Id pcIdVal  = pcId.get(pcCode);
    Id attrIdVal = attrId.get(attrCode);
    if (pcIdVal == null || attrIdVal == null) continue;
    if (existingPca.contains(pcIdVal + '|' + attrIdVal)) continue;

    ProductClassificationAttr pca = new ProductClassificationAttr(
        ProductClassificationId=pcIdVal, AttributeDefinitionId=attrIdVal,
        AttributeCategoryId=catId.get(catCode),
        IsHidden=isHidden, IsPriceImpacting=isPriceImpact,
        IsReadOnly=isReadOnly, IsRequired=isRequired,
        Sequence=seq, Status='Active',
        Name=pcCode + ' ' + attrCode);
    if (String.isNotBlank(defVal)) pca.DefaultValue = defVal;
    pcaToInsert.add(pca);
}
if (!pcaToInsert.isEmpty()) insert pcaToInsert;
System.debug('ProductClassificationAttr inserted: ' + pcaToInsert.size());

// Reload PCA: (classificationId|attrDefinitionId) → Id for PAD lookup
Map<String, Id> pcaId = new Map<String, Id>();
for (ProductClassificationAttr pca : [
    SELECT Id, ProductClassificationId, AttributeDefinitionId
    FROM ProductClassificationAttr
    WHERE ProductClassification.Code IN ('VEL_PKG_BDL','VEL_LSR_BDL')
]) pcaId.put(pca.ProductClassificationId + '|' + pca.AttributeDefinitionId, pca.Id);

// ── 11. Set BasedOnId on bundle products (each to its own scoped classification)
List<Product2> prodsToUpdate = new List<Product2>();
for (Product2 p : [SELECT Id, BasedOnId, StockKeepingUnit FROM Product2
                   WHERE StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')]) {
    if (p.StockKeepingUnit == 'VEL-PACK-G1-BDL' && p.BasedOnId != pcId.get('VEL_PKG_BDL')) {
        p.BasedOnId = pcId.get('VEL_PKG_BDL');
        prodsToUpdate.add(p);
    } else if (p.StockKeepingUnit == 'VEL-LSR-BDL' && p.BasedOnId != pcId.get('VEL_LSR_BDL')) {
        p.BasedOnId = pcId.get('VEL_LSR_BDL');
        prodsToUpdate.add(p);
    }
}
if (!prodsToUpdate.isEmpty()) update prodsToUpdate;
System.debug('Product2 BasedOnId updated: ' + prodsToUpdate.size());

// ── 12. ProductAttributeDefinition ───────────────────────────────────────────
Map<String, Id> prodId = new Map<String, Id>();
for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2
                   WHERE StockKeepingUnit IN ('VEL-PACK-G1-BDL','VEL-LSR-BDL')])
    prodId.put(p.StockKeepingUnit, p.Id);

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
    Boolean isHidden     = (Boolean)row[5];
    Boolean isPriceImpact= (Boolean)row[6];
    Boolean isReadOnly   = (Boolean)row[7];
    Boolean isRequired   = (Boolean)row[8];
    Integer seq     = (Integer)row[9];
    String status   = (String)row[10];

    Id pId = prodId.get(sku);
    Id aId = attrId.get(attrCode);
    if (pId == null || aId == null) continue;
    if (existingPad.contains(aId + '|' + pId)) continue;

    Id pcaIdVal = pcaId.get(pcId.get(pcCode) + '|' + aId);
    if (pcaIdVal == null) { System.debug('WARN: no PCA for ' + attrCode); continue; }
    ProductAttributeDefinition pad = new ProductAttributeDefinition(
        Product2Id=pId, AttributeDefinitionId=aId,
        AttributeCategoryId=catId.get(catCode),
        ProductClassificationAttributeId=pcaIdVal,
        IsHidden=isHidden, IsPriceImpacting=isPriceImpact,
        IsReadOnly=isReadOnly, IsRequired=isRequired,
        Sequence=seq, Status=status,
        Name=attrCode + ' ' + sku);
    if (String.isNotBlank(defVal)) pad.DefaultValue = defVal;
    padToInsert.add(pad);
}
if (!padToInsert.isEmpty()) insert padToInsert;
System.debug('ProductAttributeDefinition inserted: ' + padToInsert.size());

System.debug('VEL attribute creation complete.');
