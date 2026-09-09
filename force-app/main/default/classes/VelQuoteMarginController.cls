/**
 * Apex controller for the velQuoteMargin LWC component.
 * Returns per-line margin data by joining QuoteLineItem with CostBookEntry.
 * Designed for demo orgs that have a single CostBook (no CostBook filter needed).
 */
public with sharing class VelQuoteMarginController {

    @AuraEnabled(cacheable=true)
    public static List<LineMarginData> getMarginData(Id quoteId) {
        if (quoteId == null) return new List<LineMarginData>();

        List<QuoteLineItem> lines = [
            SELECT Id, Product2Id, Product2.Name, Product2.StockKeepingUnit,
                   Quantity, UnitPrice, NetUnitPrice, NetTotalPrice
            FROM QuoteLineItem
            WHERE QuoteId = :quoteId
            WITH USER_MODE
            ORDER BY Product2.Name
        ];

        Set<Id> productIds = new Set<Id>();
        for (QuoteLineItem li : lines) {
            if (li.Product2Id != null) productIds.add(li.Product2Id);
        }

        Map<Id, Decimal> costByProduct = new Map<Id, Decimal>();
        if (!productIds.isEmpty()) {
            for (CostBookEntry cbe : [
                SELECT ProductId, Cost
                FROM CostBookEntry
                WHERE ProductId IN :productIds
                WITH USER_MODE
            ]) {
                if (!costByProduct.containsKey(cbe.ProductId)) {
                    costByProduct.put(cbe.ProductId, cbe.Cost);
                }
            }
        }

        List<LineMarginData> result = new List<LineMarginData>();
        for (QuoteLineItem li : lines) {
            LineMarginData d = new LineMarginData();
            d.lineId        = li.Id;
            d.productName   = li.Product2?.Name;
            d.sku           = li.Product2?.StockKeepingUnit;
            d.quantity      = li.Quantity;
            d.netUnitPrice  = li.NetUnitPrice;
            d.netTotalPrice = li.NetTotalPrice;

            Decimal unitCost = costByProduct.get(li.Product2Id);
            if (unitCost != null) {
                Decimal qty       = li.Quantity != null ? li.Quantity : 1;
                Decimal totalCost = unitCost * qty;
                Decimal netTotal  = li.NetTotalPrice != null ? li.NetTotalPrice : 0;

                d.unitCost  = unitCost;
                d.totalCost = totalCost;

                if (netTotal != 0) {
                    d.marginAmount = netTotal - totalCost;
                    d.marginPct    = ((netTotal - totalCost) / netTotal * 100).setScale(1);
                } else {
                    d.marginAmount = -totalCost;
                    d.marginPct    = null;
                }
            }
            result.add(d);
        }

        return result;
    }

    public class LineMarginData {
        @AuraEnabled public Id      lineId;
        @AuraEnabled public String  productName;
        @AuraEnabled public String  sku;
        @AuraEnabled public Decimal quantity;
        @AuraEnabled public Decimal netUnitPrice;
        @AuraEnabled public Decimal netTotalPrice;
        @AuraEnabled public Decimal unitCost;
        @AuraEnabled public Decimal totalCost;
        @AuraEnabled public Decimal marginAmount;
        @AuraEnabled public Decimal marginPct;
    }
}
