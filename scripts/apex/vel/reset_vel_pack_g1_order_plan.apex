// Resets the DRO state for a Velantis VELPACK G1 order so decomposition can run correctly.
// Run BEFORE re-activating the order.
// 1. Finds the FulfillmentPlan linked to the order
// 2. Deletes all FulfillmentPlanItem records in that plan
// 3. Deletes the FulfillmentPlan itself
// After running this script: reload vel-dro data, run update_vel_pfdr_rules, then re-activate the order.

String orderNumber = '00000125'; // <-- change if needed

List<Order> orders = [SELECT Id FROM Order WHERE OrderNumber = :orderNumber LIMIT 1];
if (orders.isEmpty()) {
    System.debug('ERROR: Order ' + orderNumber + ' not found');
    return;
}
Id orderId = orders[0].Id;

// FulfillmentPlan links to the source Quote or Order via SourceId
List<FulfillmentPlan> plans = [
    SELECT Id, Name, State
    FROM FulfillmentPlan
    WHERE SourceIdentifier = :orderId
    LIMIT 10
];
System.debug('Found ' + plans.size() + ' FulfillmentPlan(s) for order ' + orderNumber);
for (FulfillmentPlan p : plans) {
    System.debug('  Plan: ' + p.Name + ' | State: ' + p.State + ' | Id: ' + p.Id);
}

if (plans.isEmpty()) {
    // Try by plan name (auto-number match)
    plans = [SELECT Id, Name, State FROM FulfillmentPlan WHERE Name = '000000019' LIMIT 1];
    System.debug('Fallback by Name=000000019: ' + plans.size() + ' plan(s)');
}

if (!plans.isEmpty()) {
    System.debug('Deleting ' + plans.size() + ' FulfillmentPlan record(s)');
    delete plans;
    System.debug('Done. Re-activate the order to trigger fresh decomposition.');
} else {
    System.debug('No FulfillmentPlan found — nothing to delete.');
}
