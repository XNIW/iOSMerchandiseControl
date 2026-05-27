# TASK-127 Evidence 12 - iOS Summary Refresh Call Count

Provider test coverage:

- `OptionsSyncSummaryProviderTests/testRefreshIsDebouncedAndCoalescesRepeatedAppearNotifications`

Result:

- repeated refresh within the in-flight window increments `coalescedEvents`;
- the summary publishes after debounce;
- the Form can render while `isLoading == true`.

