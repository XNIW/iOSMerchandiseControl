import SwiftUI
import SwiftData

struct HistoryView: View {
    // Legge tutte le HistoryEntry ordinate per timestamp decrescente
    @Query(
        sort: \HistoryEntry.timestamp,
        order: .reverse
    )
    private var entries: [HistoryEntry]

    @State private var showOnlyErrorEntries: Bool = false
    @State private var selectedDateFilter: DateFilter = .all

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
                        }
                    }
                }
            }
        }
        .navigationTitle("Cronologia")
    }
}

// MARK: - Riga singola di cronologia

private struct HistoryRow: View {
    let entry: HistoryEntry
    
    private var dateString: String {
        entry.timestamp.formatted(date: .numeric, time: .shortened)
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
                    Text(entry.id)
                        .font(.headline)
                        .lineLimit(1)
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
