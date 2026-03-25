import Foundation
import SwiftData

private enum HistoryEntryJSONField: String {
    case data
    case editable
    case complete
}

private struct HistoryEntryJSONDecodeOutcome<Value> {
    let value: Value
    let hasFault: Bool
}

struct HistoryEntryJSONDecodeSnapshot {
    let dataGrid: [[String]]
    let editableGrid: [[String]]
    let completeFlags: [Bool]
    let hasDataFault: Bool
    let hasEditableFault: Bool
    let hasCompleteFault: Bool

    var hasAnyFault: Bool {
        hasDataFault || hasEditableFault || hasCompleteFault
    }
}

private final class HistoryEntryJSONLogDedup: @unchecked Sendable {
    static let shared = HistoryEntryJSONLogDedup()

    private let lock = NSLock()
    private var loggedKeys: Set<String> = []

    private init() {}

    func shouldLog(entryUID: UUID, field: HistoryEntryJSONField) -> Bool {
        let key = "\(entryUID.uuidString)#\(field.rawValue)"

        lock.lock()
        defer { lock.unlock() }

        return loggedKeys.insert(key).inserted
    }
}

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

    /// Snapshot immutabile della griglia al momento della generazione dell'inventario
    var originalDataJSON: Data?
    
    /// Valori editabili (quantità contata, ecc.)
    var editableJSON: Data?
    
    /// Riga completata / non completata
    var completeJSON: Data?

    /// Fault sticky persistito quando almeno uno dei payload JSON salvati non e' decodificabile
    var hasPersistedJSONDecodeFault: Bool = false
    
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
            decodePayload([[String]].self, from: dataJSON, field: .data, default: []).value
        }
        set {
            dataJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var editable: [[String]] {
        get {
            decodePayload([[String]].self, from: editableJSON, field: .editable, default: []).value
        }
        set {
            editableJSON = try? JSONEncoder().encode(newValue)
        }
    }
    
    var complete: [Bool] {
        get {
            decodePayload([Bool].self, from: completeJSON, field: .complete, default: []).value
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
        originalDataJSON: Data? = nil,
        editable: [[String]] = [],
        complete: [Bool] = [],
        hasPersistedJSONDecodeFault: Bool = false,
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
        self.originalDataJSON = originalDataJSON
        self.editableJSON = try? JSONEncoder().encode(editable)
        self.completeJSON = try? JSONEncoder().encode(complete)
        self.hasPersistedJSONDecodeFault = hasPersistedJSONDecodeFault
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

    func evaluateJSONDecodeSnapshot() -> HistoryEntryJSONDecodeSnapshot {
        let dataResult = decodePayload([[String]].self, from: dataJSON, field: .data, default: [])
        let editableResult = decodePayload([[String]].self, from: editableJSON, field: .editable, default: [])
        let completeResult = decodePayload([Bool].self, from: completeJSON, field: .complete, default: [])

        return HistoryEntryJSONDecodeSnapshot(
            dataGrid: dataResult.value,
            editableGrid: editableResult.value,
            completeFlags: completeResult.value,
            hasDataFault: dataResult.hasFault,
            hasEditableFault: editableResult.hasFault,
            hasCompleteFault: completeResult.hasFault
        )
    }

    private func decodePayload<T: Decodable>(
        _ type: T.Type,
        from payload: Data?,
        field: HistoryEntryJSONField,
        default defaultValue: T
    ) -> HistoryEntryJSONDecodeOutcome<T> {
        guard let payload, !payload.isEmpty else {
            return HistoryEntryJSONDecodeOutcome(value: defaultValue, hasFault: false)
        }

        do {
            return HistoryEntryJSONDecodeOutcome(
                value: try JSONDecoder().decode(type, from: payload),
                hasFault: false
            )
        } catch {
            if HistoryEntryJSONLogDedup.shared.shouldLog(entryUID: uid, field: field) {
                debugPrint(
                    "[HistoryEntry JSON] uid=\(uid.uuidString) id=\(id) field=\(field.rawValue) error=\(error)"
                )
            }

            return HistoryEntryJSONDecodeOutcome(value: defaultValue, hasFault: true)
        }
    }
}
