// Create VEL ProductComponentGroup + ProductRelatedComponent records.
// Idempotent: skips groups whose Code already exists; skips components
// whose (ParentProductId + ProductComponentGroupId + ChildProductId) already exists.
//
// Run via: cci task run run_apex_script -o apex_path scripts/apex/vel/create_vel_pcm_bundle_structure.apex

// ── 1. Collect product IDs ────────────────────────────────────────────────────
Map<String, Id> prodById = new Map<String, Id>();
for (Product2 p : [
    SELECT Id, StockKeepingUnit FROM Product2
    WHERE StockKeepingUnit IN (
        'VEL-PACK-G1-BDL', 'VEL-PACK-G1-BASE', 'VEL-PACK-G1-TT', 'VEL-PACK-G1-TT-PRO',
        'VEL-PACK-FILM', 'VEL-PACK-FILM-CF', 'VEL-PACK-FILM-CR',
        'VEL-SRV-INSTALL-PKG', 'VEL-SRV-MAINT-PKG', 'VEL-SRV-MAINT-PKG-PREM',
        'VEL-SRV-WARRANTY-PKG', 'VEL-SW-PACK-MGR',
        'VEL-LSR-BDL', 'VEL-LSR-1530', 'VEL-LSR-2040', 'VEL-LSR-2060',
        'VEL-LSR-SRC-4KW', 'VEL-LSR-SRC-10KW', 'VEL-LSR-SRC-15KW',
        'VEL-LSR-AUTO-CS', 'VEL-LSR-AUTO-LU', 'VEL-LSR-AUTO-SORT',
        'VEL-CUT-GAS', 'VEL-CUT-GAS-O2', 'VEL-CUT-GAS-AIR',
        'VEL-SRV-INSTALL-LSR',
        'VEL-SRV-MAINT-LSR', 'VEL-SRV-WARRANTY-LSR', 'VEL-SW-LSR-CAD',
        'VEL-STP-BDL', 'VEL-STP-CTRL', 'VEL-STP-CTRL-SW', 'VEL-STP-CTRL-FMM',
        'VEL-STP-DOOR-H', 'VEL-STP-DOOR-V',
        'VEL-STP-OPT-DRAIN', 'VEL-STP-OPT-GMP',
        'VEL-STP-CERT-PVC',
        'VEL-STP-LOAD-CART', 'VEL-STP-LOAD-TRAY', 'VEL-STP-LOAD-RACK',
        'VEL-STP-DOC-VAL', 'VEL-STP-SVC-INST',
        'VEL-STP-SRV-MAINT-STD', 'VEL-STP-SRV-MAINT-PREM'
    )
]) {
    prodById.put(p.StockKeepingUnit, p.Id);
}

// ── 2. ProductRelationshipType ────────────────────────────────────────────────
ProductRelationshipType prtRec = [
    SELECT Id FROM ProductRelationshipType
    WHERE Name = 'Bundle to Bundle Component Relationship' LIMIT 1
];
Id prtId = prtRec.Id;

// ── 3. Existing PCG codes (idempotency) ───────────────────────────────────────
Set<String> existingPcgCodes = new Set<String>();
for (ProductComponentGroup g : [
    SELECT Code FROM ProductComponentGroup WHERE Code LIKE 'PCG-VEL-%'
]) {
    existingPcgCodes.add(g.Code);
}

// ── 4. Define PCGs ────────────────────────────────────────────────────────────
List<ProductComponentGroup> pcgsToInsert = new List<ProductComponentGroup>();

// VELPACK G1 Packaging System groups
if (!existingPcgCodes.contains('PCG-VEL-PKG-BASE'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-PKG-BASE', Name='Base Machine',
        Description='Required VELPACK G1 base machine chassis',
        MinBundleComponents=1, MaxBundleComponents=1, Sequence=10,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-PKG-TT'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-PKG-TT', Name='Track & Trace Module',
        Description='Optional Track & Trace module — Standard or Professional variant',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=20,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-PKG-FILM'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-PKG-FILM', Name='Packaging Film',
        Description='Optional pharma packaging film — Alu-PVC Cold-Form or Child-Resistant',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=30,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-PKG-SERVICES'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-PKG-SERVICES', Name='Add-on Services',
        Description='Optional add-on services — installation / maintenance / warranty (choose any combination)',
        MinBundleComponents=0, MaxBundleComponents=4, Sequence=40,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-PKG-SW'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-PKG-SW', Name='Batch Control Software',
        Description='Optional batch control software subscription',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=50,
        ParentProductId=prodById.get('VEL-PACK-G1-BDL')));

// PrecisionBeam+ Laser Cutting System groups
// PCG-VEL-LSR-CONFIG is the parent container for Machine Frame + Laser Source Module (nested group pattern)
if (!existingPcgCodes.contains('PCG-VEL-LSR-CONFIG'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-CONFIG', Name='Machine Configuration',
        Description='Machine configuration group — frame size and laser source are selected together via attribute-driven constraints',
        Sequence=5,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-FRAME'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-FRAME', Name='Machine Frame',
        Description='Required machine frame — constraint selects one of three sizes',
        MinBundleComponents=1, MaxBundleComponents=1, Sequence=10,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-POWER'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-POWER', Name='Laser Source Module',
        Description='Required laser source module — constraint selects one of three power ratings',
        MinBundleComponents=1, MaxBundleComponents=1, Sequence=20,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-AUTO'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-AUTO', Name='Automation Module',
        Description='Optional compact server automation module',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=30,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-GAS'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-GAS', Name='Cutting Gas',
        Description='Optional nitrogen assist gas subscription',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=40,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-SERVICES'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-SERVICES', Name='Add-on Services',
        Description='Optional add-on services — installation / maintenance / warranty (choose any combination)',
        MinBundleComponents=0, MaxBundleComponents=3, Sequence=50,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!existingPcgCodes.contains('PCG-VEL-LSR-SW'))
    pcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-LSR-SW', Name='CAD/CAM Software',
        Description='Optional CAD/CAM software subscription',
        MinBundleComponents=0, MaxBundleComponents=1, Sequence=60,
        ParentProductId=prodById.get('VEL-LSR-BDL')));

if (!pcgsToInsert.isEmpty()) {
    insert pcgsToInsert;
    System.debug('Inserted ' + pcgsToInsert.size() + ' ProductComponentGroup records.');
} else {
    System.debug('All ProductComponentGroup records already exist — skipped.');
}

// ── 5. Reload PCG code → Id map ───────────────────────────────────────────────
Map<String, Id> pcgById = new Map<String, Id>();
for (ProductComponentGroup g : [
    SELECT Id, Code FROM ProductComponentGroup WHERE Code LIKE 'PCG-VEL-%'
]) {
    pcgById.put(g.Code, g.Id);
}

// ── 5b. Wire nested group hierarchy (Machine Frame + Laser Source under Machine Configuration) ─
Id configGroupId = pcgById.get('PCG-VEL-LSR-CONFIG');
if (configGroupId != null) {
    List<ProductComponentGroup> toNest = new List<ProductComponentGroup>();
    for (ProductComponentGroup g : [
        SELECT Id, Code, ParentGroupId FROM ProductComponentGroup
        WHERE Code IN ('PCG-VEL-LSR-FRAME', 'PCG-VEL-LSR-POWER')
    ]) {
        if (g.ParentGroupId != configGroupId) {
            g.ParentGroupId = configGroupId;
            toNest.add(g);
        }
    }
    if (!toNest.isEmpty()) {
        update toNest;
        System.debug('Nested ' + toNest.size() + ' groups under PCG-VEL-LSR-CONFIG.');
    } else {
        System.debug('PCG-VEL-LSR-FRAME and PCG-VEL-LSR-POWER already nested under PCG-VEL-LSR-CONFIG — skipped.');
    }
} else {
    System.debug('WARNING: PCG-VEL-LSR-CONFIG not found — cannot wire nested hierarchy.');
}

// ── 6. Existing PRCs (idempotency guard) ──────────────────────────────────────
Set<String> existingPrcKeys = new Set<String>();
for (ProductRelatedComponent prc : [
    SELECT ParentProductId, ProductComponentGroupId, ChildProductId
    FROM ProductRelatedComponent
    WHERE ParentProduct.StockKeepingUnit LIKE 'VEL-%'
]) {
    existingPrcKeys.add(prc.ParentProductId + '|' + prc.ProductComponentGroupId + '|' + prc.ChildProductId);
}

// ── 7. Define PRCs ────────────────────────────────────────────────────────────
List<ProductRelatedComponent> prcsToInsert = new List<ProductRelatedComponent>();

// Helper inner class / closure via local method not available in Anonymous Apex;
// use inline helper pattern
Id packBdl  = prodById.get('VEL-PACK-G1-BDL');
Id lsrBdl   = prodById.get('VEL-LSR-BDL');

// ── VELPACK G1 bundle components ──────────────────────────────────────────────
// Group: Base Machine (1 of 1, required)
String key;
key = packBdl + '|' + pcgById.get('PCG-VEL-PKG-BASE') + '|' + prodById.get('VEL-PACK-G1-BASE');
if (!existingPrcKeys.contains(key))
    prcsToInsert.add(new ProductRelatedComponent(
        ParentProductId=packBdl, ChildProductId=prodById.get('VEL-PACK-G1-BASE'),
        ProductComponentGroupId=pcgById.get('PCG-VEL-PKG-BASE'),
        ProductRelationshipTypeId=prtId,
        IsComponentRequired=true, IsDefaultComponent=true, IsQuantityEditable=true,
        Quantity=1, QuoteVisibility='Always', Sequence=10));

// Group: Track & Trace (0–1, 2 variants)
key = packBdl + '|' + pcgById.get('PCG-VEL-PKG-TT') + '|' + prodById.get('VEL-PACK-G1-TT');
if (!existingPrcKeys.contains(key))
    prcsToInsert.add(new ProductRelatedComponent(
        ParentProductId=packBdl, ChildProductId=prodById.get('VEL-PACK-G1-TT'),
        ProductComponentGroupId=pcgById.get('PCG-VEL-PKG-TT'),
        ProductRelationshipTypeId=prtId,
        IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
        Quantity=1, QuoteVisibility='Always', Sequence=10));

key = packBdl + '|' + pcgById.get('PCG-VEL-PKG-TT') + '|' + prodById.get('VEL-PACK-G1-TT-PRO');
if (!existingPrcKeys.contains(key))
    prcsToInsert.add(new ProductRelatedComponent(
        ParentProductId=packBdl, ChildProductId=prodById.get('VEL-PACK-G1-TT-PRO'),
        ProductComponentGroupId=pcgById.get('PCG-VEL-PKG-TT'),
        ProductRelationshipTypeId=prtId,
        IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
        Quantity=1, QuoteVisibility='Always', Sequence=20));

// Group: Packaging Film (0–1, 3 variants)
for (List<Object> item : new List<List<Object>>{
    new List<Object>{'VEL-PACK-FILM', 10},
    new List<Object>{'VEL-PACK-FILM-CF', 20},
    new List<Object>{'VEL-PACK-FILM-CR', 30}
}) {
    String sku = (String)item[0];
    Integer seq = (Integer)item[1];
    key = packBdl + '|' + pcgById.get('PCG-VEL-PKG-FILM') + '|' + prodById.get(sku);
    if (!existingPrcKeys.contains(key))
        prcsToInsert.add(new ProductRelatedComponent(
            ParentProductId=packBdl, ChildProductId=prodById.get(sku),
            ProductComponentGroupId=pcgById.get('PCG-VEL-PKG-FILM'),
            ProductRelationshipTypeId=prtId,
            IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
            Quantity=1, QuoteVisibility='Always', Sequence=seq));
}

// Groups: Add-on Services (install + maint standard + maint premium + warranty in one group), Software
for (List<Object> item : new List<List<Object>>{
    new List<Object>{'PCG-VEL-PKG-SERVICES', 'VEL-SRV-INSTALL-PKG',    10},
    new List<Object>{'PCG-VEL-PKG-SERVICES', 'VEL-SRV-MAINT-PKG',      20},
    new List<Object>{'PCG-VEL-PKG-SERVICES', 'VEL-SRV-MAINT-PKG-PREM', 30},
    new List<Object>{'PCG-VEL-PKG-SERVICES', 'VEL-SRV-WARRANTY-PKG',   40},
    new List<Object>{'PCG-VEL-PKG-SW',       'VEL-SW-PACK-MGR',        10}
}) {
    String grpCode = (String)item[0];
    String sku     = (String)item[1];
    Integer seq    = (Integer)item[2];
    key = packBdl + '|' + pcgById.get(grpCode) + '|' + prodById.get(sku);
    if (!existingPrcKeys.contains(key))
        prcsToInsert.add(new ProductRelatedComponent(
            ParentProductId=packBdl, ChildProductId=prodById.get(sku),
            ProductComponentGroupId=pcgById.get(grpCode),
            ProductRelationshipTypeId=prtId,
            IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
            Quantity=1, QuoteVisibility='Always', Sequence=seq));
}

// ── PrecisionBeam+ Laser bundle components ────────────────────────────────────
// Group: Machine Frame (1 of 1, 3 size variants)
for (List<Object> item : new List<List<Object>>{
    new List<Object>{'VEL-LSR-1530', 10},
    new List<Object>{'VEL-LSR-2040', 20},
    new List<Object>{'VEL-LSR-2060', 30}
}) {
    String sku = (String)item[0];
    Integer seq = (Integer)item[1];
    key = lsrBdl + '|' + pcgById.get('PCG-VEL-LSR-FRAME') + '|' + prodById.get(sku);
    if (!existingPrcKeys.contains(key))
        prcsToInsert.add(new ProductRelatedComponent(
            ParentProductId=lsrBdl, ChildProductId=prodById.get(sku),
            ProductComponentGroupId=pcgById.get('PCG-VEL-LSR-FRAME'),
            ProductRelationshipTypeId=prtId,
            IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
            Quantity=1, QuoteVisibility='Always', Sequence=seq));
}

// Group: Laser Source Module (1 of 1, 3 power variants)
for (List<Object> item : new List<List<Object>>{
    new List<Object>{'VEL-LSR-SRC-4KW',  10},
    new List<Object>{'VEL-LSR-SRC-10KW', 20},
    new List<Object>{'VEL-LSR-SRC-15KW', 30}
}) {
    String sku = (String)item[0];
    Integer seq = (Integer)item[1];
    key = lsrBdl + '|' + pcgById.get('PCG-VEL-LSR-POWER') + '|' + prodById.get(sku);
    if (!existingPrcKeys.contains(key))
        prcsToInsert.add(new ProductRelatedComponent(
            ParentProductId=lsrBdl, ChildProductId=prodById.get(sku),
            ProductComponentGroupId=pcgById.get('PCG-VEL-LSR-POWER'),
            ProductRelationshipTypeId=prtId,
            IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
            Quantity=1, QuoteVisibility='Always', Sequence=seq));
}

// Groups: Automation, Gas, Add-on Services (install + maint + warranty in one group), CAD/CAM
for (List<Object> item : new List<List<Object>>{
    new List<Object>{'PCG-VEL-LSR-AUTO',     'VEL-LSR-AUTO-CS',      10},
    new List<Object>{'PCG-VEL-LSR-AUTO',     'VEL-LSR-AUTO-LU',      20},
    new List<Object>{'PCG-VEL-LSR-AUTO',     'VEL-LSR-AUTO-SORT',    30},
    new List<Object>{'PCG-VEL-LSR-GAS',      'VEL-CUT-GAS',          10},
    new List<Object>{'PCG-VEL-LSR-GAS',      'VEL-CUT-GAS-O2',       20},
    new List<Object>{'PCG-VEL-LSR-GAS',      'VEL-CUT-GAS-AIR',      30},
    new List<Object>{'PCG-VEL-LSR-SERVICES', 'VEL-SRV-INSTALL-LSR',  10},
    new List<Object>{'PCG-VEL-LSR-SERVICES', 'VEL-SRV-MAINT-LSR',    20},
    new List<Object>{'PCG-VEL-LSR-SERVICES', 'VEL-SRV-WARRANTY-LSR', 30},
    new List<Object>{'PCG-VEL-LSR-SW',       'VEL-SW-LSR-CAD',       10}
}) {
    String grpCode = (String)item[0];
    String sku     = (String)item[1];
    Integer seq    = (Integer)item[2];
    key = lsrBdl + '|' + pcgById.get(grpCode) + '|' + prodById.get(sku);
    if (!existingPrcKeys.contains(key))
        prcsToInsert.add(new ProductRelatedComponent(
            ParentProductId=lsrBdl, ChildProductId=prodById.get(sku),
            ProductComponentGroupId=pcgById.get(grpCode),
            ProductRelationshipTypeId=prtId,
            IsComponentRequired=false, IsDefaultComponent=false, IsQuantityEditable=true,
            Quantity=1, QuoteVisibility='Always', Sequence=seq));
}

if (!prcsToInsert.isEmpty()) {
    insert prcsToInsert;
    System.debug('Inserted ' + prcsToInsert.size() + ' ProductRelatedComponent records.');
} else {
    System.debug('All ProductRelatedComponent records already exist — skipped.');
}

// ── VelTherma STP Sterilizer bundle ──────────────────────────────────────────
Id stpBdl = prodById.get('VEL-STP-BDL');

if (stpBdl != null) {
    List<ProductComponentGroup> stpPcgsToInsert = new List<ProductComponentGroup>();
    if (!existingPcgCodes.contains('PCG-VEL-STP-CTRL'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-CTRL', Name='Process Controller & Software',
            Description='Required VelControl Pro controller + optional FMM platform',
            MinBundleComponents=null, MaxBundleComponents=null, Sequence=10,
            ParentProductId=stpBdl));

    if (!existingPcgCodes.contains('PCG-VEL-STP-DOORS'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-DOORS', Name='Doors',
            Description='Motorized access door selection — 1 required, up to 2 for pass-through',
            MinBundleComponents=1, MaxBundleComponents=2, Sequence=20,
            ParentProductId=stpBdl));

    if (!existingPcgCodes.contains('PCG-VEL-STP-OPT'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-OPT', Name='Plant Options',
            Description='Optional plant-side accessories — drainage upgrade, GMP compliance package',
            MinBundleComponents=0, MaxBundleComponents=null, Sequence=30,
            ParentProductId=stpBdl));

    if (!existingPcgCodes.contains('PCG-VEL-STP-CERT'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-CERT', Name='Pressure Vessel Certification',
            Description='Optional multi-jurisdiction pressure vessel certification',
            MinBundleComponents=0, MaxBundleComponents=null, Sequence=40,
            ParentProductId=stpBdl));

    if (!existingPcgCodes.contains('PCG-VEL-STP-LOAD'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-LOAD', Name='Loading & Handling',
            Description='Optional loading carts, trays, and racks for sterilizer chamber',
            MinBundleComponents=0, MaxBundleComponents=null, Sequence=50,
            ParentProductId=stpBdl));

    if (!existingPcgCodes.contains('PCG-VEL-STP-SVC'))
        stpPcgsToInsert.add(new ProductComponentGroup(Code='PCG-VEL-STP-SVC', Name='Services & Documentation',
            Description='Installation/commissioning service, maintenance contracts, and validation documentation',
            MinBundleComponents=null, MaxBundleComponents=null, Sequence=60,
            ParentProductId=stpBdl));

    if (!stpPcgsToInsert.isEmpty()) {
        insert stpPcgsToInsert;
        System.debug('Inserted ' + stpPcgsToInsert.size() + ' STP ProductComponentGroup records.');
    }

    // Reload PCG map after STP inserts
    for (ProductComponentGroup g : [SELECT Id, Code FROM ProductComponentGroup WHERE Code LIKE 'PCG-VEL-STP-%'])
        pcgById.put(g.Code, g.Id);

    // STP PRCs
    List<ProductRelatedComponent> stpPrcsToInsert = new List<ProductRelatedComponent>();
    for (List<Object> item : new List<List<Object>>{
        new List<Object>{'PCG-VEL-STP-CTRL',  'VEL-STP-CTRL',           true,  true,  false, null, null, 10},
        new List<Object>{'PCG-VEL-STP-CTRL',  'VEL-STP-CTRL-SW',        true,  true,  true,  1,    1,    20},
        new List<Object>{'PCG-VEL-STP-CTRL',  'VEL-STP-CTRL-FMM',       false, false, true,  1,    1,    30},
        new List<Object>{'PCG-VEL-STP-DOORS', 'VEL-STP-DOOR-H',         false, true,  true,  2,    1,    10},
        new List<Object>{'PCG-VEL-STP-DOORS', 'VEL-STP-DOOR-V',         false, false, true,  2,    1,    20},
        new List<Object>{'PCG-VEL-STP-OPT',   'VEL-STP-OPT-DRAIN',      false, false, true,  1,    1,    10},
        new List<Object>{'PCG-VEL-STP-OPT',   'VEL-STP-OPT-GMP',        false, false, true,  1,    1,    20},
        new List<Object>{'PCG-VEL-STP-CERT',  'VEL-STP-CERT-PVC',       false, false, true,  1,    1,    10},
        new List<Object>{'PCG-VEL-STP-LOAD',  'VEL-STP-LOAD-CART',      false, false, true,  5,    1,    10},
        new List<Object>{'PCG-VEL-STP-LOAD',  'VEL-STP-LOAD-TRAY',      false, false, true,  20,   1,    20},
        new List<Object>{'PCG-VEL-STP-LOAD',  'VEL-STP-LOAD-RACK',      false, false, true,  5,    1,    30},
        new List<Object>{'PCG-VEL-STP-SVC',   'VEL-STP-DOC-VAL',        false, false, true,  1,    1,    10},
        new List<Object>{'PCG-VEL-STP-SVC',   'VEL-STP-SVC-INST',       true,  true,  false, null, null, 20},
        new List<Object>{'PCG-VEL-STP-SVC',   'VEL-STP-SRV-MAINT-STD',  false, false, true,  1,    1,    30},
        new List<Object>{'PCG-VEL-STP-SVC',   'VEL-STP-SRV-MAINT-PREM', false, false, true,  1,    1,    40}
    }) {
        String grpCode = (String)item[0];
        String sku     = (String)item[1];
        Boolean isReq  = (Boolean)item[2];
        Boolean isDef  = (Boolean)item[3];
        Boolean isQty  = (Boolean)item[4];
        Object maxQ    = item[5];
        Object minQ    = item[6];
        Integer seq    = (Integer)item[7];

        Id childId = prodById.get(sku);
        Id grpId   = pcgById.get(grpCode);
        if (childId == null || grpId == null) { System.debug('WARN: skipping STP PRC ' + sku + ' / ' + grpCode); continue; }

        String k = stpBdl + '|' + grpId + '|' + childId;
        if (existingPrcKeys.contains(k)) continue;

        ProductRelatedComponent prc = new ProductRelatedComponent(
            ParentProductId=stpBdl, ChildProductId=childId,
            ProductComponentGroupId=grpId, ProductRelationshipTypeId=prtId,
            IsComponentRequired=isReq, IsDefaultComponent=isDef, IsQuantityEditable=isQty,
            Quantity=1, QuoteVisibility='Always', Sequence=seq);
        if (maxQ != null) prc.MaxQuantity = (Integer)maxQ;
        if (minQ != null) prc.MinQuantity = (Integer)minQ;
        stpPrcsToInsert.add(prc);
    }
    if (!stpPrcsToInsert.isEmpty()) {
        insert stpPrcsToInsert;
        System.debug('Inserted ' + stpPrcsToInsert.size() + ' STP ProductRelatedComponent records.');
    } else {
        System.debug('All STP ProductRelatedComponent records already exist — skipped.');
    }
} else {
    System.debug('WARN: VEL-STP-BDL product not found — skipping STP bundle structure (run insert_vel_pcm_data first)');
}

System.debug('VEL bundle structure creation complete.');
