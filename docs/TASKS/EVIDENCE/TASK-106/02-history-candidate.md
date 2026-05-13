# TASK-106 History Candidate

## Origin alignment
- `git fetch --prune origin` executed before code changes.
- `HEAD`: `a4e2e20b01fcffa78608d651fb2da62387082c02`.
- `origin/main`: `a4e2e20b01fcffa78608d651fb2da62387082c02`.
- Work branch during execution: `main`.

## DatabaseView history
Recent commits touching `iOSMerchandiseControl/DatabaseView.swift`:

```text
a4e2e20 Task 105
f603142 Task 102
71dcbb4 Task 101
7a3b330 Task 93
7685cc3 Task 92
f47302d Task85
```

## Candidate introduction point
- Primary layout regression candidate: `f603142 Task 102`.
- Evidence: `git show --stat --oneline f603142 -- iOSMerchandiseControl/DatabaseView.swift` reported `248 insertions` and `106 deletions` in `DatabaseView.swift`, including the recent product row/card layout, chips, empty-state treatment, and row action structure.
- Secondary recent touch: `a4e2e20 Task 105`.
- Evidence: `git show --stat --oneline a4e2e20 -- iOSMerchandiseControl/DatabaseView.swift` reported only `13 insertions`, scoped to scanner fallback search focus.

## Decision from history
Full restore was not selected because TASK-102/TASK-105 also contain useful behavior to preserve: empty states, accessibility containment, delete confirmation context, and scanner fallback focus. The selected fix restores the cleaner row hierarchy while keeping those useful behaviors.
