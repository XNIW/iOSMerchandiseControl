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
    @State private var customFrom: Date = Self.defaultCustomFrom
    @State private var customTo: Date = Date()
    @State private var editingCustomDate: CustomDateField?
    @State private var showingDateFilterDialog = false
    
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
        case currentMonth
        case previousMonth
        case custom

        var id: Self { self }

        var title: String {
            switch self {
            case .all: return "Tutto"
            case .last7Days: return "Ultimi 7 giorni"
            case .last30Days: return "Ultimi 30 giorni"
            case .currentMonth: return "Mese corrente"
            case .previousMonth: return "Mese precedente"
            case .custom: return "Personalizzato"
            }
        }
    }

    private enum CustomDateField: String, Identifiable {
        case from
        case to

        var id: Self { self }

        var title: String {
            switch self {
            case .from: return "Da"
            case .to: return "A"
            }
        }

        var sheetTitle: String {
            switch self {
            case .from: return "Seleziona data iniziale"
            case .to: return "Seleziona data finale"
            }
        }
    }

    private static var defaultCustomFrom: Date {
        startOfMonth(for: Date())
    }
    
    /// Applica i filtri (periodo + solo errori) alle entry.
    private var filteredEntries: [HistoryEntry] {
        var result = entries

        let now = Date()
        let calendar = Calendar.current
        switch selectedDateFilter {
        case .all:
            break
        case .last7Days:
            if let from = calendar.date(byAdding: .day, value: -7, to: now) {
                result = result.filter { $0.timestamp >= from }
            }
        case .last30Days:
            if let from = calendar.date(byAdding: .day, value: -30, to: now) {
                result = result.filter { $0.timestamp >= from }
            }
        case .currentMonth:
            let from = Self.startOfMonth(for: now)
            let to = endOfDay(for: now)
            result = result.filter { $0.timestamp >= from && $0.timestamp <= to }
        case .previousMonth:
            let currentMonthStart = Self.startOfMonth(for: now)
            let previousMonthDate = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
                ?? currentMonthStart
            let previousMonthStart = Self.startOfMonth(for: previousMonthDate)
            let previousMonthEndDate = calendar.date(byAdding: .day, value: -1, to: currentMonthStart)
                ?? currentMonthStart
            let previousMonthEnd = endOfDay(for: previousMonthEndDate)
            result = result.filter { $0.timestamp >= previousMonthStart && $0.timestamp <= previousMonthEnd }
        case .custom:
            let from = startOfDay(for: customFrom)
            let to = endOfDay(for: customTo)
            result = result.filter { $0.timestamp >= from && $0.timestamp <= to }
        }

        if showOnlyErrorEntries {
            // Consideriamo "con errori" le entry marcate come attemptedWithErrors
            result = result.filter { $0.syncStatus == .attemptedWithErrors }
        }

        return result
    }

    private static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    private func startOfDay(for date: Date) -> Date {
        Calendar.current.startOfDay(for: date)
    }

    private func endOfDay(for date: Date) -> Date {
        let startOfNextDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay(for: date))
            ?? startOfDay(for: date)
        return startOfNextDay.addingTimeInterval(-1)
    }

    private func customDateText(for field: CustomDateField) -> String {
        switch field {
        case .from:
            return customFrom.formatted(date: .numeric, time: .omitted)
        case .to:
            return customTo.formatted(date: .numeric, time: .omitted)
        }
    }

    private var selectedDateFilterText: String {
        selectedDateFilter.title
    }

    private func customDateBinding(for field: CustomDateField) -> Binding<Date> {
        switch field {
        case .from:
            return $customFrom
        case .to:
            return $customTo
        }
    }

    @ViewBuilder
    private func customDatePicker(for field: CustomDateField) -> some View {
        switch field {
        case .from:
            DatePicker(
                field.title,
                selection: customDateBinding(for: field),
                displayedComponents: .date
            )
        case .to:
            DatePicker(
                field.title,
                selection: customDateBinding(for: field),
                in: customFrom...,
                displayedComponents: .date
            )
        }
    }

    private func customDateButton(for field: CustomDateField) -> some View {
        Button {
            editingCustomDate = field
        } label: {
            HStack(spacing: 12) {
                Text(field.title)
                    .foregroundStyle(.primary)

                Spacer()

                Text(customDateText(for: field))
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    private var dateFilterButton: some View {
        Button {
            showingDateFilterDialog = true
        } label: {
            HStack(spacing: 12) {
                Text("Periodo")
                    .foregroundStyle(.primary)

                Spacer()

                Text(selectedDateFilterText)
                    .foregroundStyle(.blue)

                Image(systemName: "chevron.up.chevron.down")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
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
                                dateFilterButton

                                if selectedDateFilter == .custom {
                                    VStack(spacing: 0) {
                                        customDateButton(for: .from)
                                        Divider()
                                        customDateButton(for: .to)
                                    }
                                }

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
        .onChange(of: customFrom) { _, newValue in
            if customTo < newValue {
                customTo = newValue
            }
        }
        .confirmationDialog(
            "Seleziona periodo",
            isPresented: $showingDateFilterDialog,
            titleVisibility: .visible
        ) {
            ForEach(DateFilter.allCases) { filter in
                Button(filter.title) {
                    selectedDateFilter = filter
                }
            }

            Button("Annulla", role: .cancel) {}
        }
        .sheet(item: $editingCustomDate) { field in
            NavigationStack {
                VStack {
                    customDatePicker(for: field)
                        .datePickerStyle(.graphical)
                        .labelsHidden()
                }
                .padding()
                .navigationTitle(field.sheetTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fine") {
                            editingCustomDate = nil
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
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
