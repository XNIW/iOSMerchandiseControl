# TASK-127 Evidence 13 - ProductPrice Count Cost

ProductPrice count path changed from full fetch/filter to `fetchCount` with active product predicate.

Evidence:

- `OptionsLocalSummaryServiceTests/testReconciliationAwareSummaryCountsActiveProductPricesWithoutMaterializingAllPendingRows`: PASS
- `OptionsLocalSummaryServiceTests/testLargeSyntheticSummaryStaysInsideLocalBudget`: PASS
- `scan productprice-full-fetch-mainactor --task TASK-127 --strict`: PASS after patch

