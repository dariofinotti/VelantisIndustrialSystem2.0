// Create VEL STP PCM additions — NUM-DOORS attribute chain + maintenance product bundle slots.
// Idempotent — skips anything that already exists.
//
// Adds:
//   - AttributePicklist: VEL_STP_NumDoors + values (Single Door, Double Door)
//   - AttributeDefinition: ATTR-VEL-STP-NUM-DOORS
//   - AttributeCategoryAttribute junction (VEL_STP_PROC_PARAMS + ATTR-VEL-STP-NUM-DOORS)
//   - ProductClassificationAttr: VEL_STP_BDL + ATTR-VEL-STP-NUM-DOORS (seq 85)
//   - ProductAttributeDefinition: VEL-STP-BDL + ATTR-VEL-STP-NUM-DOORS (seq 85)
//   - ProductRelatedComponent: VEL-STP-SRV-MAINT-STD + VEL-STP-SRV-MAINT-PREM under PCG-VEL-STP-SVC
//
// Bypass for SFDMU Bulk REST API silent-failure on BRC260 trial org.
// Run via: cci task run run_apex_script -o apex_path scripts/apex/vel/create_vel_stp_pcm_additions.apex

// ── 1. Idempotency guards ─────────────────────────────────────────────────────
Set<String> existingPlCodes = new Set<String>();
for (AttributePicklist p : [SELECT Name FROM AttributePicklist WHERE Name = 'VEL_STP_NumDoors'])
    existingPlCodes.add(p.Name);

Set<String> existingAttrCodes = new Set<String>();
for (AttributeDefinition a : [SELECT Code FROM AttributeDefinition WHERE Code = 'ATTR-VEL-STP-NUM-DOORS'])
    existingAttrCodes.add(a.Code);

// ── 2. AttributePicklist ──────────────────────────────────────────────────────
List<AttributePicklist> plToInsert = new List<AttributePicklist>();
if (!existingPlCodes.contains('VEL_STP_NumDoors'))
    plToInsert.add(new AttributePicklist(
        Name='VEL_STP_NumDoors', Code='VEL_STP_NumDoors',
        DataType='Text', Status='Active'));
if (!plToInsert.isEmpty()) insert plToInsert;
System.debug('AttributePicklist inserted: ' + plToInsert.size());

// ── 3. Reload Picklist Id ─────────────────────────────────────────────────────
AttributePicklist ndPl = [SELECT Id FROM AttributePicklist WHERE Name = 'VEL_STP_NumDoors' LIMIT 1];
Id ndPlId = ndPl.Id;

// ── 4. AttributePicklistValue ─────────────────────────────────────────────────
Set<String> existingPlvCodes = new Set<String>();
for (AttributePicklistValue v : [SELECT Code FROM AttributePicklistValue WHERE Code IN ('VEL_STP_NUM_SINGLE','VEL_STP_NUM_DOUBLE')])
    existingPlvCodes.add(v.Code);

List<AttributePicklistValue> plvToInsert = new List<AttributePicklistValue>();
if (!existingPlvCodes.contains('VEL_STP_NUM_SINGLE'))
    plvToInsert.add(new AttributePicklistValue(
        PicklistId=ndPlId, Code='VEL_STP_NUM_SINGLE',
        Name='Single Door', Value='Single Door', DisplayValue='Single Door',
        IsDefault=true, Sequence=1, Status='Active'));
if (!existingPlvCodes.contains('VEL_STP_NUM_DOUBLE'))
    plvToInsert.add(new AttributePicklistValue(
        PicklistId=ndPlId, Code='VEL_STP_NUM_DOUBLE',
        Name='Double Door (Pass-Through)', Value='Double Door (Pass-Through)', DisplayValue='Double Door (Pass-Through)',
        IsDefault=false, Sequence=2, Status='Active'));
if (!plvToInsert.isEmpty()) insert plvToInsert;
System.debug('AttributePicklistValue inserted: ' + plvToInsert.size());

// ── 5. AttributeDefinition ────────────────────────────────────────────────────
if (!existingAttrCodes.contains('ATTR-VEL-STP-NUM-DOORS')) {
    AttributeDefinition     a = new AttributeDefinition(
        Code='ATTR-VEL-STP-NUM-DOORS', DeveloperName='ATTR_VEL_STP_NUM_DOORS',
        Name='STP Door Configuration', Label='STP Door Configuration',
        DataType='Picklist', DefaultValue='Single Door',
        PicklistId=ndPlId,
        IsActive=true, IsRequired=false);
    insert a;
    System.debug('AttributeDefinition inserted: ATTR-VEL-STP-NUM-DOORS');
}

// ── 6. Reload attr id, cat id ────────────────────────────────────────────────
AttributeDefinition ndAttr = [SELECT Id FROM AttributeDefinition WHERE Code = 'ATTR-VEL-STP-NUM-DOORS' LIMIT 1];
Id ndAttrId = ndAttr.Id;

Map<String, Id> catId = new Map<String, Id>();
for (AttributeCategory c : [SELECT Id, Code FROM AttributeCategory WHERE Code LIKE 'VEL_STP_%'])
    catId.put(c.Code, c.Id);

// ── 7. AttributeCategoryAttribute ─────────────────────────────────────────────
if (!catId.isEmpty() && catId.containsKey('VEL_STP_PROC_PARAMS')) {
    Id procParamCatId = catId.get('VEL_STP_PROC_PARAMS');
    List<AttributeCategoryAttribute> existingAca = [
        SELECT Id FROM AttributeCategoryAttribute
        WHERE AttributeCategoryId = :procParamCatId AND AttributeDefinitionId = :ndAttrId
    ];
    if (existingAca.isEmpty()) {
        insert new AttributeCategoryAttribute(
            AttributeCategoryId=procParamCatId, AttributeDefinitionId=ndAttrId);
        System.debug('AttributeCategoryAttribute inserted for VEL_STP_PROC_PARAMS + ATTR-VEL-STP-NUM-DOORS');
    } else {
        System.debug('AttributeCategoryAttribute already exists — skipped.');
    }
} else {
    System.debug('WARN: VEL_STP_PROC_PARAMS category not found — skipping ACA');
}

// ── 8. ProductClassification + ProductClassificationAttr ──────────────────────
Map<String, Id> pcId = new Map<String, Id>();
for (ProductClassification pc : [SELECT Id, Code FROM ProductClassification WHERE Code = 'VEL_STP_BDL'])
    pcId.put(pc.Code, pc.Id);

if (!pcId.isEmpty() && pcId.containsKey('VEL_STP_BDL')) {
    Id stpBdlPcId = pcId.get('VEL_STP_BDL');
    List<ProductClassificationAttr> existingPca = [
        SELECT Id FROM ProductClassificationAttr
        WHERE ProductClassificationId = :stpBdlPcId AND AttributeDefinitionId = :ndAttrId
    ];
    if (existingPca.isEmpty()) {
        Id procParamCatId = catId.get('VEL_STP_PROC_PARAMS');
        ProductClassificationAttr pca = new ProductClassificationAttr(
            ProductClassificationId=stpBdlPcId, AttributeDefinitionId=ndAttrId,
            AttributeCategoryId=procParamCatId,
            IsHidden=false, IsPriceImpacting=false, IsReadOnly=false, IsRequired=false,
            Sequence=85, Status='Active', DefaultValue='Single Door',
            Name='VEL_STP_BDL STP Door Configuration');
        insert pca;
        System.debug('ProductClassificationAttr inserted: VEL_STP_BDL / ATTR-VEL-STP-NUM-DOORS');
    } else {
        System.debug('ProductClassificationAttr already exists — skipped.');
    }
} else {
    System.debug('WARN: VEL_STP_BDL classification not found — skipping PCA');
}

// ── 9. ProductAttributeDefinition ────────────────────────────────────────────
Map<String, Id> prodId = new Map<String, Id>();
for (Product2 p : [SELECT Id, StockKeepingUnit FROM Product2 WHERE StockKeepingUnit = 'VEL-STP-BDL'])
    prodId.put(p.StockKeepingUnit, p.Id);

if (!prodId.isEmpty()) {
    Id stpBdlProdId = prodId.get('VEL-STP-BDL');
    List<ProductAttributeDefinition> existingPad = [
        SELECT Id FROM ProductAttributeDefinition
        WHERE Product2Id = :stpBdlProdId AND AttributeDefinitionId = :ndAttrId
    ];
    if (existingPad.isEmpty()) {
        // Look up the PCA we just created
        List<ProductClassificationAttr> pcaList = [
            SELECT Id FROM ProductClassificationAttr
            WHERE ProductClassification.Code = 'VEL_STP_BDL' AND AttributeDefinitionId = :ndAttrId
            LIMIT 1
        ];
        Id procParamCatId = catId.get('VEL_STP_PROC_PARAMS');
        ProductAttributeDefinition pad = new ProductAttributeDefinition(
            Product2Id=stpBdlProdId, AttributeDefinitionId=ndAttrId,
            AttributeCategoryId=procParamCatId,
            ProductClassificationAttributeId=pcaList.isEmpty() ? null : pcaList[0].Id,
            IsHidden=false, IsPriceImpacting=false, IsReadOnly=false, IsRequired=false,
            Sequence=85, Status='Active', DefaultValue='Single Door',
            Name='ATTR-VEL-STP-NUM-DOORS VEL-STP-BDL');
        insert pad;
        System.debug('ProductAttributeDefinition inserted: VEL-STP-BDL / ATTR-VEL-STP-NUM-DOORS');
    } else {
        System.debug('ProductAttributeDefinition already exists — skipped.');
    }
} else {
    System.debug('WARN: VEL-STP-BDL product not found — skipping PAD (run insert_vel_pcm_data first)');
}

// ── 10. Maintenance product PRC under PCG-VEL-STP-SVC ────────────────────────
// Collect all required product IDs
Map<String, Id> stpProdIds = new Map<String, Id>();
for (Product2 p : [
    SELECT Id, StockKeepingUnit FROM Product2
    WHERE StockKeepingUnit IN ('VEL-STP-BDL', 'VEL-STP-SRV-MAINT-STD', 'VEL-STP-SRV-MAINT-PREM')
]) stpProdIds.put(p.StockKeepingUnit, p.Id);

Id stpBdlId = stpProdIds.get('VEL-STP-BDL');
Id maintStdId = stpProdIds.get('VEL-STP-SRV-MAINT-STD');
Id maintPremId = stpProdIds.get('VEL-STP-SRV-MAINT-PREM');

List<ProductComponentGroup> svcGrpList = [
    SELECT Id FROM ProductComponentGroup WHERE Code = 'PCG-VEL-STP-SVC' LIMIT 1
];
ProductRelationshipType prtRec = [
    SELECT Id FROM ProductRelationshipType
    WHERE Name = 'Bundle to Bundle Component Relationship' LIMIT 1
];
Id prtId = prtRec.Id;

if (stpBdlId != null && !svcGrpList.isEmpty()) {
    Id svcGrpId = svcGrpList[0].Id;

    Set<String> existingPrcKeys = new Set<String>();
    for (ProductRelatedComponent prc : [
        SELECT ParentProductId, ProductComponentGroupId, ChildProductId
        FROM ProductRelatedComponent
        WHERE ParentProductId = :stpBdlId AND ProductComponentGroupId = :svcGrpId
    ]) existingPrcKeys.add(prc.ParentProductId + '|' + prc.ProductComponentGroupId + '|' + prc.ChildProductId);

    List<ProductRelatedComponent> prcsToInsert = new List<ProductRelatedComponent>();

    if (maintStdId != null) {
        String k = stpBdlId + '|' + svcGrpId + '|' + maintStdId;
        if (!existingPrcKeys.contains(k))
            prcsToInsert.add(new ProductRelatedComponent(
                ParentProductId=stpBdlId, ChildProductId=maintStdId,
                ProductComponentGroupId=svcGrpId, ProductRelationshipTypeId=prtId,
                IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
                MaxQuantity=1, MinQuantity=1,
                Quantity=1, QuoteVisibility='Always', Sequence=30));
    }
    if (maintPremId != null) {
        String k = stpBdlId + '|' + svcGrpId + '|' + maintPremId;
        if (!existingPrcKeys.contains(k))
            prcsToInsert.add(new ProductRelatedComponent(
                ParentProductId=stpBdlId, ChildProductId=maintPremId,
                ProductComponentGroupId=svcGrpId, ProductRelationshipTypeId=prtId,
                IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
                MaxQuantity=1, MinQuantity=1,
                Quantity=1, QuoteVisibility='Always', Sequence=40));
    }

    if (!prcsToInsert.isEmpty()) {
        insert prcsToInsert;
        System.debug('ProductRelatedComponent inserted: ' + prcsToInsert.size() + ' STP maintenance slots');
    } else {
        System.debug('STP maintenance PRC records already exist — skipped.');
    }
} else {
    System.debug('WARN: VEL-STP-BDL product or PCG-VEL-STP-SVC group not found — skipping PRC (run insert_vel_pcm_data and create_vel_pcm_bundle_structure first)');
}

System.debug('VEL STP PCM additions complete.');
