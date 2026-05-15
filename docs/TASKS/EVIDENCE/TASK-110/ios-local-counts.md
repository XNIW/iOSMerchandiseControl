# TASK-110 — iOS Local Counts

Checkpoint: 2026-05-15 12:15 -0400.

Simulator: iPhone 15 Pro Max, iOS 26.1.

SwiftData store letto da:
`~/Library/Developer/CoreSimulator/Devices/<SIM>/data/Containers/Data/Application/<APP>/Library/Application Support/default.store`

## Counts

| Entità SwiftData | Count |
|---|---:|
| `HistoryEntry` | 1 |
| `HistoryEntry.remoteID != nil` | 1 |
| `HistoryEntry.remoteID == nil` | 0 |
| History dirty | 0 |
| `Product` | 19695 |
| `Product.remoteID != nil` | 19695 |
| `Supplier` | 57 |
| `ProductCategory` | 27 |
| `ProductPrice` | 41109 |
| `ProductPrice.remoteID != nil` | 41109 |
| `LocalPendingChange` | 0 |
| `SyncEventOutboxEntry` | 0 |

## Conclusione

iOS locale è allineato ai counts Supabase osservati per History, products, suppliers, categories e prices. Al checkpoint iniziale il target principale iOS non mostra drift quantitativo locale/remoto.
