import Foundation
import SwiftData

/// Servizio che applica un inventario (HistoryEntry) al database prodotti.
@MainActor
struct InventorySyncService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    struct SyncResult {
        let processedRows: Int
        let attemptedUpdates: Int
        let succeeded: Int
        let failed: Int
        let priceRowsInserted: Int
        let pendingCloudChanges: Int

        init(
            processedRows: Int,
            attemptedUpdates: Int,
            succeeded: Int,
            failed: Int,
            priceRowsInserted: Int = 0,
            pendingCloudChanges: Int = 0
        ) {
            self.processedRows = processedRows
            self.attemptedUpdates = attemptedUpdates
            self.succeeded = succeeded
            self.failed = failed
            self.priceRowsInserted = priceRowsInserted
            self.pendingCloudChanges = pendingCloudChanges
        }

        /// Testo pronto da mostrare in UI
        var summaryMessage: String {
            """
            Righe con quantità: \(attemptedUpdates)
            Aggiornate correttamente: \(succeeded)
            In errore: \(failed)
            Prezzi registrati: \(priceRowsInserted)
            Pending cloud creati: \(pendingCloudChanges)
            """
        }
    }

    /// Applica l’inventario al database:
    /// - Usa realQuantity (o quantity se vuota)
    /// - Aggiorna stockQuantity
    /// - Aggiorna retailPrice se presente
    /// - Scrive ProductPrice(type: .retail, source: "INVENTORY_SYNC")
    /// - Aggiorna entry.syncStatus
    /// - Scrive errori riga-per-riga nella colonna "SyncError"
    func sync(entry: HistoryEntry, ownerUserID: UUID? = nil) throws -> SyncResult {
        // Copia modificabile della griglia
        var grid = entry.data
        guard !grid.isEmpty else {
            return SyncResult(processedRows: 0, attemptedUpdates: 0, succeeded: 0, failed: 0)
        }
        let pendingAccumulator = ownerUserID.map { owner in
            let selectedShopID = ShopContextSelection.selectedShopID(ownerUserID: owner)
            return LocalPendingChangeAccumulator(
                context: context,
                ownerUserID: owner,
                storeIdentity: selectedShopID == nil ? .anonymous : ShopContextSelection.localStoreIdentity(ownerUserID: owner)
            )
        }

        var header = grid[0]

        // Assicuriamoci che esista la colonna SyncError
        let syncErrorColumnName = "SyncError"
        let errorColumnIndex: Int
        if let existingIndex = header.firstIndex(of: syncErrorColumnName) {
            errorColumnIndex = existingIndex
        } else {
            header.append(syncErrorColumnName)
            errorColumnIndex = header.count - 1
            grid[0] = header
        }

        // Helper per assicurare che ogni riga abbia abbastanza colonne
        func ensureRowCapacity(_ row: [String]) -> [String] {
            if row.count >= header.count { return row }
            var newRow = row
            newRow.append(contentsOf: Array(repeating: "", count: header.count - row.count))
            return newRow
        }

        // Indici delle colonne chiave
        let barcodeIndex = header.firstIndex(of: "barcode")
        let quantityIndex = header.firstIndex(of: "quantity")
        let realQuantityIndex = header.firstIndex(of: "realQuantity")
        let retailPriceIndex = header.firstIndex(of: "RetailPrice")

        // Se non c'è barcode, non si può fare nulla
        guard let bIndex = barcodeIndex else {
            entry.data = grid
            return SyncResult(processedRows: 0, attemptedUpdates: 0, succeeded: 0, failed: 0)
        }

        var processed = 0
        var attempted = 0
        var succeeded = 0
        var failed = 0
        var priceRowsInserted = 0
        var pendingCloudChanges = 0

        // Ciclo sulle righe dati (saltiamo l'header)
        for rowIndex in 1..<grid.count {
            processed += 1

            var row = ensureRowCapacity(grid[rowIndex])
            row[errorColumnIndex] = ""  // reset errore di eventuali sync precedenti

            // 1) Barcode
            let rawBarcode = row[bIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if rawBarcode.isEmpty {
                // Riga senza barcode → ignorata, nessun errore
                grid[rowIndex] = row
                continue
            }

            // 2) Quantità: realQuantity → quantity → ""
            let quantityText: String = {
                if let rqIndex = realQuantityIndex, rqIndex < row.count {
                    return row[rqIndex]
                } else if let qIndex = quantityIndex, qIndex < row.count {
                    return row[qIndex]
                } else {
                    return ""
                }
            }()

            let normalizedQty = normalizeNumberString(quantityText)
            if normalizedQty.isEmpty {
                // Nessuna quantità compilata → riga non partecipa alla sync
                grid[rowIndex] = row
                continue
            }

            attempted += 1

            guard let quantity = Double(normalizedQty), quantity >= 0 else {
                row[errorColumnIndex] = "Quantità non valida"
                failed += 1
                grid[rowIndex] = row
                continue
            }

            // 3) RetailPrice opzionale
            var newRetailPrice: Double? = nil
            if let rpIndex = retailPriceIndex, rpIndex < row.count {
                let rawPrice = row[rpIndex]
                let normalizedPrice = normalizeNumberString(rawPrice)
                if !normalizedPrice.isEmpty {
                    guard let price = Double(normalizedPrice), price >= 0 else {
                        row[errorColumnIndex] = "Prezzo di vendita non valido"
                        failed += 1
                        grid[rowIndex] = row
                        continue
                    }
                    newRetailPrice = price
                }
            }

            // 4) Trova Product per barcode
            let descriptor = FetchDescriptor<Product>(
                predicate: #Predicate { $0.barcode == rawBarcode }
            )

            guard let product = try context.fetch(descriptor).first else {
                row[errorColumnIndex] = "Barcode non trovato"
                failed += 1
                grid[rowIndex] = row
                continue
            }

            var changedFields: [String] = []
            let oldRetailPrice = product.retailPrice
            if !Self.doublesEqual(product.stockQuantity, quantity) {
                changedFields.append("stockQuantity")
            }

            // 5) Aggiorna stockQuantity con il conteggio di inventario
            product.stockQuantity = quantity

            // 6) Aggiorna retailPrice e storico se presente
            if let retail = newRetailPrice {
                let retailChanged = !Self.doublesEqual(oldRetailPrice, retail)
                if retailChanged {
                    changedFields.append("retailPrice")
                }
                product.retailPrice = retail

                if retailChanged {
                    let pricePoint = ProductPrice(
                        type: .retail,
                        price: retail,
                        effectiveAt: Date(),
                        source: "INVENTORY_SYNC",
                        note: nil,
                        product: product
                    )
                    context.insert(pricePoint)
                    priceRowsInserted += 1
                    if let pendingAccumulator {
                        if try pendingAccumulator.recordProductPriceChange(
                            price: pricePoint,
                            origin: .confirmedImport
                        ) != nil {
                            pendingCloudChanges += 1
                        }
                    }
                }
            }

            if !changedFields.isEmpty {
                if let pendingAccumulator {
                    if try pendingAccumulator.recordProductChange(
                        product: product,
                        operation: .update,
                        origin: .confirmedImport,
                        changedFields: changedFields
                    ) != nil {
                        pendingCloudChanges += 1
                    }
                }
            }

            // Riga OK
            succeeded += 1
            // lasciamo SyncError vuoto
            grid[rowIndex] = row
        }

        // Aggiorniamo la griglia dell'entry con la colonna SyncError compilata
        entry.data = grid

        // Se nessuna riga aveva una quantità → non cambiamo lo stato di sync
        guard attempted > 0 else {
            try context.save()
            return SyncResult(
                processedRows: processed,
                attemptedUpdates: 0,
                succeeded: 0,
                failed: failed,
                priceRowsInserted: priceRowsInserted,
                pendingCloudChanges: pendingCloudChanges
            )
        }

        // Aggiorna syncStatus dell’HistoryEntry
        if failed == 0 {
            entry.syncStatus = .syncedSuccessfully
        } else {
            entry.syncStatus = .attemptedWithErrors
        }

        try context.save()

        return SyncResult(
            processedRows: processed,
            attemptedUpdates: attempted,
            succeeded: succeeded,
            failed: failed,
            priceRowsInserted: priceRowsInserted,
            pendingCloudChanges: pendingCloudChanges
        )
    }

    /// Sostituisce la virgola con il punto e trimma gli spazi.
    private func normalizeNumberString(_ text: String) -> String {
        return text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func doublesEqual(_ lhs: Double?, _ rhs: Double?) -> Bool {
        switch (lhs, rhs) {
        case (.none, .none):
            return true
        case let (.some(lhs), .some(rhs)):
            return abs(lhs - rhs) < 0.000_001
        case (.none, .some), (.some, .none):
            return false
        }
    }
}
