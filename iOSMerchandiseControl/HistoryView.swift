import SwiftUI
import SwiftData

struct HistoryView: View {
    // Legge tutte le HistoryEntry ordinate per timestamp decrescente
    @Query(
        sort: \HistoryEntry.timestamp,
        order: .reverse
    )
    private var entries: [HistoryEntry]
    
    var body: some View {
        Group {
            if entries.isEmpty {
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
                .padding()
            } else {
                List {
                    ForEach(entries) { entry in
                        NavigationLink(
                            destination: GeneratedView(entry: entry)
                        ) {
                            HistoryRow(entry: entry)
                        }
                    }
                    // se avevi già .onDelete(perform: deleteEntries), lascialo qui:
                    // .onDelete(perform: deleteEntries)
                }
                .listStyle(.plain)
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
