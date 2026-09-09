// Deletes duplicate FulfillmentWorkspaceItem records from the Velantis Machine Fulfillment workspace.
// insert_vel_dro_data uses Insert (no deleteOldData) on FulfillmentWorkspaceItem, so re-runs create
// duplicates. This script keeps the first-created item per step group and removes all later copies.
List<FulfillmentWorkspaceItem> allItems = [
    SELECT Id, FulfillmentStepDefinitionGroupId
    FROM FulfillmentWorkspaceItem
    WHERE FulfillmentWorkspace.Name = 'Velantis Machine Fulfillment'
    ORDER BY CreatedDate ASC
];

Set<Id> seen = new Set<Id>();
List<FulfillmentWorkspaceItem> toDelete = new List<FulfillmentWorkspaceItem>();
for (FulfillmentWorkspaceItem item : allItems) {
    if (seen.contains(item.FulfillmentStepDefinitionGroupId)) {
        toDelete.add(item);
    } else {
        seen.add(item.FulfillmentStepDefinitionGroupId);
    }
}
delete toDelete;
System.debug('Velantis workspace cleanup — deleted ' + toDelete.size() + ' duplicate FulfillmentWorkspaceItem records. Remaining: ' + (allItems.size() - toDelete.size()));
