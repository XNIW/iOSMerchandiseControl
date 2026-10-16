# Android candidata4 — review indipendente

Reviewer `/root/android_candidate_review`, distinto dai writer. **CHANGES_REQUIRED**. Tutti11pin coincidono prima/dopo; patch SHA256 `86b6ab41d19a613a79fd5e04726abbde7a3760c03ee9a635a0c5828272aa07fd`.

- P1 nuova conferma mismatch: Application1681 rifiuta journal nonJSON con count!=0, ma il producer reale InventoryRepository3010 crea il primo requisito confermato con count1. Application911 chiama scheduler senza poter creare claim/RPC. RED richiesto: metodo pubblico App→producer→scheduler, nessuna correzione artificiale del count; cumulativo preservato.
- P2 timer epoch vecchio: il job cattura context/epoch e attende. Refresh stesso shop aggiorna epoch e scope_align viene coalesciato nel vecchio job; alla deadline quello esce senza successore. Richiesti refresh reale durante cooldown e variante cambio shop con zeroRPC dello scope vecchio, senza ulteriori trigger manuali.

Nessun altro problema concreto nel parser canonico, classifier/header, mapping VM o clock seam Inventory. Non è approvazione globale: outboxQ01, saturazione1M, replay503 e liveness legacy/in_flight restano distinti. Nessun build/test/device/rete/Git della review; risultati eseguiti da root nel registro.
