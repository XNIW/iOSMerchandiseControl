import Foundation
import SwiftData

// Cronologia dei file di inventario generati
@Model
final class HistoryEntry {
    /// Nome file (es. "2025-12-03_fornitore.xlsx")
    var id: String
    
    /// Momento della generazione
    var timestamp: Date
    
    var isManualEntry: Bool
    
    /// Griglia dell'Excel generato (intestazione + righe)
    var dataJSON: Data?
    
    /// Valori editabili (quantità contata, ecc.)
    var editableJSON: Data?
    
    /// Riga completata / non completata
    var completeJSON: Data?
    
    var title: String = "" 
    var supplier: String
    var category: String
    var totalItems: Int
    var orderTotal: Double
    var paymentTotal: Double
    var missingItems: Int
    
    var syncStatus: HistorySyncStatus
    var wasExported: Bool
    
    /// UID interno (tipo il `uid: Long` in Room)
    var uid: UUID
    
    // Proprietà calcolate per accedere ai dati in formato array
    var data: [[String]] {
        get {
            guard let dataJSON = dataJSON else { return [] }
            return (try? JSONDecoder().decode([[String]].self, from: dataJSON)) ?? []
        }
        set {
            dataJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var editable: [[String]] {
        get {
            guard let editableJSON = editableJSON else { return [] }
            return (try? JSONDecoder().decode([[String]].self, from: editableJSON)) ?? []
        }
        set {
            editableJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var complete: [Bool] {
        get {
            guard let completeJSON = completeJSON else { return [] }
            return (try? JSONDecoder().decode([Bool].self, from: completeJSON)) ?? []
        }
        set {
            completeJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    init(
        id: String,
        timestamp: Date = Date(),
        isManualEntry: Bool = false,
        data: [[String]] = [],
        editable: [[String]] = [],
        complete: [Bool] = [],
        supplier: String = "",
        category: String = "",
        totalItems: Int = 0,
        orderTotal: Double = 0,
        paymentTotal: Double = 0,
        missingItems: Int = 0,
        syncStatus: HistorySyncStatus = .notAttempted,
        wasExported: Bool = false,
        uid: UUID = UUID()
    ) {
        self.id = id
        self.timestamp = timestamp
        self.isManualEntry = isManualEntry
        self.dataJSON = try? JSONEncoder().encode(data)
        self.editableJSON = try? JSONEncoder().encode(editable)
        self.completeJSON = try? JSONEncoder().encode(complete)
        self.supplier = supplier
        self.category = category
        self.totalItems = totalItems
        self.orderTotal = orderTotal
        self.paymentTotal = paymentTotal
        self.missingItems = missingItems
        self.syncStatus = syncStatus
        self.wasExported = wasExported
        self.uid = uid
    }
}
