# TASK-111 — 02 Android Behavior Map

Data: 2026-05-17  
Repo riferimento: `/Users/minxiang/AndroidStudioProjects/MerchandiseControlSplitView`

## OBSERVED — Contratti Android usati come riferimento funzionale

- Parser/header: `ExcelUtils.kt:113`, `ExcelUtils.kt:224`, `ExcelUtils.kt:1257` normalizzano numeri/header e includono alias per `discountedPrice`, `realQuantity`, previous price.
- Import analysis: `ImportAnalysis.kt:55`, `:75`, `:106`, `:217`, `:243`, `:261`, `:277`, `:280` coprono parse number, validation row, streaming relations, real quantity, duplicate warning, discounted price, previous prices.
- Duplicate policy: Android usa warning non bloccante, last row base, quantity aggregata e `DuplicateWarning.totalOccurrences`.
- Apply DB: `InventoryRepository.kt:602`, `:609`, `:1452` applicano con mutex + Room transaction.
- Supplier/category: `InventoryRepository.kt:1456`, `:1472`, `:1498`, `:1848` risolvono per normalized relation key.
- ProductPrice history: `InventoryRepository.kt:1699`, `:1703`, `:1722`, `:1735` registra previous/current price e pending price history.
- Dirty/pending sync: `InventoryRepository.kt:1794` e seguenti marcano local changes; TASK-111 iOS preserva accumulator esistente senza riaprire TASK-109.
- UI ImportAnalysis: `ImportAnalysisScreen.kt:83`, `:159`, `:222`, `:293`, `:308`, `:352` usa sezioni espandibili, conferma se righe valide, warnings/errors/export.

## INFERRED — Parity target applicata a iOS

- iOS non copia layout Compose; adotta pattern SwiftUI nativi: `List`, chip orizzontali, `safeAreaInset` CTA, `Form` per edit.
- Android rimane piu' completo su transaction Room; iOS usa SwiftData context + rollback/catch gia' presente nel pipeline, documentato come recovery boundary.

## NOT_RUN

- Build/test Android non eseguiti perche' nessun file Android e' stato modificato.
