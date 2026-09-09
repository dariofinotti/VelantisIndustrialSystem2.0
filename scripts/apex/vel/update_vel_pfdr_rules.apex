// TEMPORARY FIX (260/262 bug): ExecuteOnRuleId is not created on INSERT, only on UPDATE.
// Affects ProductFulfillmentDecompRule, ProductFulfillmentScenario, FulfillmentStepDefinition,
// FulfillmentTaskAssignmentRule. Re-saving triggers ruleset generation. (#rlm-office-hours)
// Scoped to VEL rules only to avoid unnecessary re-saves of QB/EPRO records.
List<ProductFulfillmentDecompRule> rules = [
    SELECT Id FROM ProductFulfillmentDecompRule
    WHERE Name LIKE 'VEL %'
];
update rules;
