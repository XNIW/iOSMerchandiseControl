import Foundation
import SwiftData

/// Servizio che applica un inventario (HistoryEntry) al database prodotti.
@MainActor
final class InventorySyncService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    struct SyncResult {
        let processedRows: Int
        let attemptedUpdates: Int
        let succeeded: Int
        let failed: Int

        /// Testo pronto da mostrare in UI
        var summaryMessage: String {
            """
            Righe con quantità: \(attemptedUpdates)
            Aggiornate correttamente: \(succeeded)
            In errore: \(failed)
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
    func sync(entry: HistoryEntry) throws -> SyncResult {
        // Copia modificabile della griglia
        var grid = entry.data
        guard !grid.isEmpty else {
            return SyncResult(processedRows: 0, attemptedUpdates: 0, succeeded: 0, failed: 0)
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

            // 5) Aggiorna stockQuantity con il conteggio di inventario
            product.stockQuantity = quantity

            // 6) Aggiorna retailPrice e storico se presente
            if let retail = newRetailPrice {
                product.retailPrice = retail

                let pricePoint = ProductPrice(
                    type: .retail,
                    price: retail,
                    effectiveAt: Date(),
                    source: "INVENTORY_SYNC",
                    note: nil,
                    product: product
                )
                context.insert(pricePoint)
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
                failed: failed
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
            failed: failed
        )
    }

    /// Sostituisce la virgola con il punto e trimma gli spazi.
    private func normalizeNumberString(_ text: String) -> String {
        return text
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
