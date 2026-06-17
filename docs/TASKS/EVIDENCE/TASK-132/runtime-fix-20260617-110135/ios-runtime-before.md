# iOS Runtime Before

- Tipo verifica: SIM/RUNTIME + SQLITE
- Device: iPhone 15 Pro Max simulator `459C668B-7CE8-443B-BAB3-7D3D5FFC9143`.
- Bundle: `com.niwcyber.iOSMerchandiseControl`.
- Auth: signed-in from `sync.runtime.auth.isSignedIn=true` in `raw/ios-userdefaults-sync-before.txt`.
- Store: `Library/Application Support/default.store`.

| metric | count |
|---|---:|
| products | 19891 |
| suppliers | 193 |
| categories | 162 |
| productPrices | 41524 |
| historySessions | 152 |
| pendingLocalChanges | 4 |
| pendingOutboxEntries | 1 |
| baselineRuns | 25 |
| baselineRecords | 395624 |

## Pending Status

| ledger | status | count |
|---|---|---:|
| localPendingChange.status | acknowledged | 4 |
| syncEventOutbox.status | sent | 1 |

## Local TASK Residue

| metric | count |
|---|---:|
| suppliers_TASK_prefix | 134 |
| categories_TASK_prefix | 134 |
| products_TASK_prefix | 196 |
| history_TASK_contains | 117 |
