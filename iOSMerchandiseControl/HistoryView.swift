import SwiftUI
import SwiftData

#if canImport(UIKit)
import UIKit
#endif

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    
    // Legge tutte le HistoryEntry ordinate per timestamp decrescente
    @Query(
        sort: \HistoryEntry.timestamp,
        order: .reverse
    )
    private var entries: [HistoryEntry]

    @State private var showOnlyErrorEntries: Bool = false
    @State private var selectedDateFilter: DateFilter = .all
    
    // 🔹 nuovo stato per la cancellazione con conferma
    @State private var showDeleteConfirmation = false
    @State private var entryPendingDeletion: HistoryEntry?
    
    private struct ShareItem: Identifiable {
        let id = UUID()
        let url: URL
    }
    @State private var shareItem: ShareItem?

    private struct EditItem: Identifiable {
        let id = UUID()
        let entry: HistoryEntry
    }
    @State private var editItem: EditItem?

    /// Filtro per periodo temporale (es. tutti, ultimi 7 giorni, ultimo mese)
    private enum DateFilter: String, CaseIterable, Identifiable {
        case all
        case last7Days
        case last30Days

        var id: Self { self }

        var title: String {
            switch self {
            case .all: return "Tutto"
            case .last7Days: return "Ultimi 7 giorni"
            case .last30Days: return "Ultimi 30 giorni"
            }
        }
    }
    
    /// Applica i filtri (periodo + solo errori) alle entry.
    private var filteredEntries: [HistoryEntry] {
        var result = entries

        let now = Date()
        switch selectedDateFilter {
        case .all:
            break
        case .last7Days:
            if let from = Calendar.current.date(byAdding: .day, value: -7, to: now) {
                result = result.filter { $0.timestamp >= from }
            }
        case .last30Days:
            if let from = Calendar.current.date(byAdding: .day, value: -30, to: now) {
                result = result.filter { $0.timestamp >= from }
            }
        }

        if showOnlyErrorEntries {
            // Consideriamo "con errori" le entry marcate come attemptedWithErrors
            result = result.filter { $0.syncStatus == .attemptedWithErrors }
        }

        return result
    }
    
    // MARK: - Azioni

    private func deleteEntry(_ entry: HistoryEntry) {
        context.delete(entry)
        do {
            try context.save()
        } catch {
            print("Errore durante l'eliminazione della HistoryEntry: \(error)")
        }
    }
    
    private func deleteEntries(at offsets: IndexSet) {
        // offsets si riferisce agli indici in filteredEntries, non in entries
        for index in offsets {
            guard filteredEntries.indices.contains(index) else { continue }
            let entry = filteredEntries[index]
            context.delete(entry)
        }

        do {
            try context.save()
        } catch {
            // per ora solo log, se vuoi puoi aggiungere un alert in futuro
            print("Errore durante l'eliminazione della HistoryEntry: \(error)")
        }
    }
    
    @MainActor
    private func exportHistoryEntry(_ entry: HistoryEntry) {
        let grid = entry.data
        guard !grid.isEmpty else { return }

        let name = entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? entry.id
            : entry.title

        Task {
            do {
                let url = try InventoryXLSXExporter.export(grid: grid, preferredName: name)
                shareItem = ShareItem(url: url)
                entry.wasExported = true
                try? context.save()
            } catch {
                print("Errore durante l'esportazione XLSX:", error)
            }
        }
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                // placeholder "Nessuna cronologia" (lascia com’era)
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("Nessuna cronologia")
                        .font(.headline)
                    Text("Quando generi file di inventario, li vedrai qui.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let errorEntriesCount = entries.filter { $0.syncStatus == .attemptedWithErrors }.count
                let totalCount = entries.count

                List {
                        // Barra filtri in cima alla lista
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                Picker("Periodo", selection: $selectedDateFilter) {
                                    ForEach(DateFilter.allCases) { filter in
                                        Text(filter.title).tag(filter)
                                    }
                                }
                                .pickerStyle(.segmented)

                                HStack {
                                    Toggle("Mostra solo entry con errori", isOn: $showOnlyErrorEntries)
                                        .font(.footnote)

                                    Spacer()

                                    if errorEntriesCount > 0 {
                                        Text("\(errorEntriesCount) su \(totalCount) con errori")
                                            .font(.footnote)
                                            .foregroundStyle(.red)
                                    } else {
                                        Text("Nessuna entry con errori")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }

                    // Lista cronologia filtrata
                    Section {
                        ForEach(filteredEntries, id: \.id) { entry in
                            NavigationLink(
                                destination: GeneratedView(entry: entry)
                            ) {
                                HistoryRow(entry: entry)
                            }
                            // ✅ Leading: Modifica
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    editItem = EditItem(entry: entry)
                                } label: {
                                    Label("Modifica", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                            // ✅ Trailing: Condividi + Elimina
                            .swipeActions(edge: .trailing) {
                                Button {
                                    exportHistoryEntry(entry)
                                } label: {
                                    Label("Condividi", systemImage: "square.and.arrow.up")
                                }
                                
                                Button(role: .destructive) {
                                    entryPendingDeletion = entry
                                    showDeleteConfirmation = true
                                } label: {
                                    Label("Elimina", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Cronologia")
        .alert(
            "Eliminare questo inventario?",
            isPresented: $showDeleteConfirmation,
            presenting: entryPendingDeletion
        ) { entry in
            Button("Annulla", role: .cancel) {
                // non facciamo nulla, l'alert si chiude
            }
            Button("Elimina", role: .destructive) {
                deleteEntry(entry)
            }
        } message: { entry in
            Text("""
            Questa operazione rimuoverà definitivamente l'inventario:
            \(entry.id)
            """)
        }
        // 🔹 nuova sheet per condividere il CSV
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.url])
        }
        .sheet(item: $editItem) { item in
            EntryInfoEditor(entry: item.entry)
        }
    }
}

// MARK: - Riga singola di cronologia

private struct HistoryRow: View {
    let entry: HistoryEntry
    
    private var dateString: String {
        entry.timestamp.formatted(date: .numeric, time: .shortened)
    }
    
    private var displayName: String {
        let t = entry.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? entry.id : t
    }
    
    /// Conta quante righe di questo HistoryEntry hanno un messaggio nella colonna "SyncError".
    private var errorCount: Int {
        guard !entry.data.isEmpty else { return 0 }
        let header = entry.data[0]
        guard let errorIndex = header.firstIndex(of: "SyncError") else {
            return 0
        }
        return entry.data.dropFirst().reduce(0) { partial, row in
            guard row.indices.contains(errorIndex) else { return partial }
            let value = row[errorIndex]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return partial + (value.isEmpty ? 0 : 1)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                SyncStatusIcon(status: entry.syncStatus)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName).font(.headline).lineLimit(1)

                    if !entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(entry.id)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Text(dateString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                if entry.wasExported {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.secondary)
                        .help("Esportato")
                }
            }
            
            HStack(spacing: 12) {
                if !entry.supplier.isEmpty {
                    Label(entry.supplier, systemImage: "building.2")
                }
                if !entry.category.isEmpty {
                    Label(entry.category, systemImage: "tag")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack(spacing: 16) {
                HistorySummaryChip(title: "Articoli", value: "\(entry.totalItems)")
                HistorySummaryChip(title: "Ordine", value: formatMoney(entry.orderTotal))
                HistorySummaryChip(title: "Pagato", value: formatMoney(entry.paymentTotal))
                
                if entry.syncStatus == .attemptedWithErrors && errorCount > 0 {
                    HistorySummaryChip(title: "Errori", value: "\(errorCount)")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption2)
        }
        .padding(.vertical, 8)
    }
    
    private func formatMoney(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        return formatter.string(from: value as NSNumber) ?? String(value)
    }
}

// Icona piccola che rappresenta lo stato di sincronizzazione
private struct SyncStatusIcon: View {
    let status: HistorySyncStatus  // Assicurati che sia HistorySyncStatus e non SyncStatus
    
    var body: some View {
        let (systemName, color): (String, Color) = {
            switch status {
            case .notAttempted:
                return ("arrow.triangle.2.circlepath", .gray)
            case .syncedSuccessfully:
                return ("checkmark.seal.fill", .green)
            case .attemptedWithErrors:
                return ("exclamationmark.triangle.fill", .orange)
            }
        }()
        
        Image(systemName: systemName)
            .foregroundStyle(color)
    }
}

// "chip" riassuntiva per numeri e soldi
private struct HistorySummaryChip: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Text(title + ":")
            Text(value)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
