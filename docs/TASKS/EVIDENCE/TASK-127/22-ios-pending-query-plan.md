# TASK-127 Evidence 22 - Pending Query Plan

Pending attention count moved out of `OptionsView`:

- removed unscoped `@Query [LocalPendingChange]`;
- added `OptionsPendingAttentionCounter.count`;
- count is scoped by owner when signed in;
- signed-out count remains anonymous only;
- terminal statuses `superseded` and `acknowledged` are excluded.

