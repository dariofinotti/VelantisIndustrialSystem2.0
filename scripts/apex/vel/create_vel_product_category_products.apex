// Create Velantis ProductCategoryProduct records and enable standalone selling for services.
//
// SFDMU silently dropped all but the first PCP per category.
// This script:
//   1. Clears IsSoldOnlyWithOtherProds on service/software products so they can be
//      both bundle add-ons AND independently browsable in the catalog.
//   2. Inserts all missing ProductCategoryProduct records.
// Idempotent — safe to re-run.
//
// Run via: sf apex run --file scripts/apex/vel/create_vel_product_category_products.apex --target-org <username>

// ── 0. Clear IsSoldOnlyWithOtherProds for service/software products ───────────
List<String> svcSkus = new List<String>{
    'VEL-SRV-INSTALL-PKG','VEL-SRV-MAINT-PKG','VEL-SRV-MAINT-PKG-PREM',
    'VEL-SRV-WARRANTY-PKG','VEL-SW-PACK-MGR',
    'VEL-SRV-INSTALL-LSR','VEL-SRV-MAINT-LSR','VEL-SRV-WARRANTY-LSR','VEL-SW-LSR-CAD'
};
List<Product2> svcToUpdate = [SELECT Id, IsSoldOnlyWithOtherProds FROM Product2 WHERE StockKeepingUnit IN :svcSkus AND IsSoldOnlyWithOtherProds = true];
for (Product2 p : svcToUpdate) p.IsSoldOnlyWithOtherProds = false;
if (!svcToUpdate.isEmpty()) {
    update svcToUpdate;
    System.debug('Cleared IsSoldOnlyWithOtherProds on ' + svcToUpdate.size() + ' service/software products.');
}

// ── 1. Collect category IDs ──────────────────────────────────────────────────
Map<String, Id> catById = new Map<String, Id>();
for (ProductCategory c : [
    SELECT Id, Code FROM ProductCategory WHERE Code IN ('VEL_CAT_PKG', 'VEL_CAT_LSR', 'VEL_CAT_SVC')
]) {
    catById.put(c.Code, c.Id);
}
System.debug('Categories found: ' + catById.keySet());

// ── 2. Collect product IDs ───────────────────────────────────────────────────
Map<String, Id> prodById = new Map<String, Id>();
for (Product2 p : [
    SELECT Id, StockKeepingUnit FROM Product2
    WHERE StockKeepingUnit IN (
        'VEL-PACK-G1-BDL', 'VEL-PACK-G1-BASE', 'VEL-PACK-G1-TT', 'VEL-PACK-G1-TT-PRO',
        'VEL-PACK-FILM', 'VEL-PACK-FILM-CF', 'VEL-PACK-FILM-CR',
        'VEL-LSR-BDL', 'VEL-LSR-1530', 'VEL-LSR-2040', 'VEL-LSR-2060',
        'VEL-LSR-SRC-4KW', 'VEL-LSR-SRC-10KW', 'VEL-LSR-SRC-15KW',
        'VEL-LSR-AUTO-CS', 'VEL-CUT-GAS',
        'VEL-SRV-INSTALL-PKG', 'VEL-SRV-MAINT-PKG', 'VEL-SRV-MAINT-PKG-PREM',
        'VEL-SRV-WARRANTY-PKG', 'VEL-SW-PACK-MGR',
        'VEL-SRV-INSTALL-LSR', 'VEL-SRV-MAINT-LSR', 'VEL-SRV-WARRANTY-LSR',
        'VEL-SW-LSR-CAD', 'VEL-SOFTWARE-NC'
    )
]) {
    prodById.put(p.StockKeepingUnit, p.Id);
}
System.debug('Products found: ' + prodById.size());

// ── 3. Existing PCP pairs (idempotency) ──────────────────────────────────────
Set<String> existingKeys = new Set<String>();
for (ProductCategoryProduct pcp : [
    SELECT ProductCategoryId, ProductId
    FROM ProductCategoryProduct
    WHERE ProductCategory.Code IN ('VEL_CAT_PKG', 'VEL_CAT_LSR', 'VEL_CAT_SVC')
]) {
    existingKeys.add(pcp.ProductCategoryId + '|' + pcp.ProductId);
}
System.debug('Existing PCP records: ' + existingKeys.size());

// ── 5. Define catalog-eligible mappings ───────────────────────────────────────
// Bundle component products (frames, film types, laser sources, etc.) have
// "Sell only with other products" enabled and CANNOT be directly categorized.
// Only bundle root products and standalone service/software products are eligible.
Map<String, List<String>> catToSkus = new Map<String, List<String>>{
    'VEL_CAT_PKG' => new List<String>{
        'VEL-PACK-G1-BDL'  // bundle root — components are configure-only
    },
    'VEL_CAT_LSR' => new List<String>{
        'VEL-LSR-BDL'       // bundle root — components are configure-only
    },
    'VEL_CAT_SVC' => new List<String>{
        'VEL-SRV-INSTALL-PKG', 'VEL-SRV-MAINT-PKG', 'VEL-SRV-MAINT-PKG-PREM',
        'VEL-SRV-WARRANTY-PKG', 'VEL-SW-PACK-MGR',
        'VEL-SRV-INSTALL-LSR', 'VEL-SRV-MAINT-LSR', 'VEL-SRV-WARRANTY-LSR',
        'VEL-SW-LSR-CAD', 'VEL-SOFTWARE-NC'
    }
};

// ── 6. Build records to insert ───────────────────────────────────────────────
List<ProductCategoryProduct> toInsert = new List<ProductCategoryProduct>();
for (String catCode : catToSkus.keySet()) {
    Id catId = catById.get(catCode);
    if (catId == null) { System.debug('WARNING: category not found: ' + catCode); continue; }
    for (String sku : catToSkus.get(catCode)) {
        Id prodId = prodById.get(sku);
        if (prodId == null) { System.debug('WARNING: product not found: ' + sku); continue; }
        String key = catId + '|' + prodId;
        if (!existingKeys.contains(key)) {
            toInsert.add(new ProductCategoryProduct(
                ProductCategoryId=catId,
                ProductId=prodId,
                IsPrimaryCategory=true
            ));
        }
    }
}

System.debug('ProductCategoryProduct records to insert: ' + toInsert.size());

if (!toInsert.isEmpty()) {
    insert toInsert;
    System.debug('Successfully inserted ' + toInsert.size() + ' ProductCategoryProduct records.');
} else {
    System.debug('All ProductCategoryProduct records already exist — nothing to insert.');
}

System.debug('VEL product category assignment complete.');
