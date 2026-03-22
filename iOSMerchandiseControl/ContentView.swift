import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @Environment(\.modelContext) private var modelContext
    @StateObject private var excelSession = ExcelSessionViewModel()
    @State private var selectedTab = 0

    private var resolvedColorScheme: ColorScheme? {
        switch appTheme {
        case "light":
            return .light
        case "dark":
            return .dark
        default:
            return nil
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // TAB 1: Inventario
            NavigationStack {
                InventoryHomeView()
                    .environmentObject(excelSession)
            }
            .tabItem {
                Label("Inventario", systemImage: "doc.on.doc")
            }
            .tag(0)

            // TAB 2: Database
            NavigationStack {
                DatabaseView()
            }
            .tabItem {
                Label("Database", systemImage: "shippingbox")
            }
            .tag(1)

            // TAB 3: Cronologia
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Cronologia", systemImage: "clock.arrow.circlepath")
            }
            .tag(2)

            // TAB 4: Opzioni
            NavigationStack {
                OptionsView()
            }
            .tabItem {
                Label("Opzioni", systemImage: "gearshape")
            }
            .tag(3)
        }
        .preferredColorScheme(resolvedColorScheme)
        .task {
            do {
                let inserted = try PriceHistoryBackfillService.backfillIfNeeded(context: modelContext)
                if inserted > 0 {
                    debugPrint("[Backfill] Inseriti \(inserted) record ProductPrice legacy.")
                }
            } catch {
                debugPrint("[Backfill] Errore durante il backfill prezzi: \(error)")
            }
        }
        .onOpenURL { url in
            guard url.isFileURL else { return }
            // Policy URL singolo: se c'è già un URL pendente o un import in corso, scarta
            guard excelSession.pendingOpenURL == nil, !excelSession.isLoading else {
                // L'errore verrà mostrato da loadExternalFile quando consuma il pendingOpenURL,
                // oppure qui se isLoading è true. Per semplicità, ignoriamo silenziosamente
                // il secondo URL a livello di ContentView — il blocco con errore user-friendly
                // è già gestito in loadExternalFile per il caso isLoading.
                return
            }
            selectedTab = 0
            excelSession.pendingOpenURL = url
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Product.self,
                Supplier.self,
                ProductCategory.self,
                HistoryEntry.self,
                ProductPrice.self
            ],
            inMemory: true
        )
}
