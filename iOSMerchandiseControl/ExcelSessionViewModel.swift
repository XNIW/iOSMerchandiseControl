import Foundation
import SwiftUI
import SwiftData
import Combine

/// ViewModel globale per il flusso Excel
/// (equivalente concettuale di ExcelViewModel su Android)
@MainActor
final class ExcelSessionViewModel: ObservableObject {

    // Header normalizzato (es. ["barcode", "productName", "purchasePrice", ...])
    @Published var header: [String] = []

    // Tutte le righe dell'Excel (inclusa la riga 0 = header)
    @Published var rows: [[String]] = []

    // Per ogni colonna: true = inclusa, false = esclusa
    @Published var selectedColumns: [Bool] = []

    // Fornitore / categoria scelti nella pre-elaborazione
    @Published var supplierName: String = ""
    @Published var categoryName: String = ""

    // Entry di cronologia associata alla sessione corrente
    @Published var currentHistoryEntry: HistoryEntry?

    // Costruttore vuoto
    init() { }

    // MARK: - Utilità base (per ora molto semplici)

    /// Resetta completamente la sessione (come un reset() del ViewModel in Android)
    func resetSession() {
        header = []
        rows = []
        selectedColumns = []
        supplierName = ""
        categoryName = ""
        currentHistoryEntry = nil
    }

    /// In futuro: carica uno o più file Excel e popola header/rows.
    /// Qui solo lo scheletro, così il codice compila.
    func load(from urls: [URL], in context: ModelContext) async throws {
        // TODO: porta qui la logica di:
        // - loadFromMultipleUris
        // - readAndAnalyzeExcel (versione iOS)
    }

    /// In futuro: genera/aggiorna una HistoryEntry a partire da header/rows + fornitore/categoria.
    func generateHistoryEntry(in context: ModelContext) async throws {
        // TODO: porta qui la logica di:
        // - generateFilteredWithOldPrices
        // - updateHistoryEntry
        // - markCurrentEntryAsExported
    }
}
