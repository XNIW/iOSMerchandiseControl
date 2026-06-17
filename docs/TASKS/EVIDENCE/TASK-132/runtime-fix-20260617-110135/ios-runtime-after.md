# iOS Runtime After

- Tipo verifica: SIM/RUNTIME + SQLITE
- Reopen launch exit: `0`.
- Wait window: 90 seconds.
- Options tap exit: `0`; Options screenshot capture exit: `0`.
- Screenshot: `ios-options-screenshot.png`.
- Auth after: signed-in from `sync.runtime.auth.isSignedIn=true` in `raw/ios-userdefaults-sync-after.txt`.

| metric | before | after | delta |
|---|---:|---:|---:|
| products | 19891 | 19891 | 0 |
| suppliers | 193 | 193 | 0 |
| categories | 162 | 162 | 0 |
| productPrices | 41524 | 41524 | 0 |
| historySessions | 152 | 152 | 0 |
| pendingLocalChangesActive | 0 | 0 | 0 |
| outboxEntriesActive | 0 | 0 | 0 |

## Local TASK Residue After

| metric | before | after | delta |
|---|---:|---:|---:|
| suppliers_TASK_prefix | 134 | 134 | 0 |
| categories_TASK_prefix | 134 | 134 | 0 |
| products_TASK_prefix | 196 | 196 | 0 |
| history_TASK_contains | 117 | 117 | 0 |
