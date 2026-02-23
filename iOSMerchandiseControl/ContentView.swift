import SwiftUI
import SwiftData

struct ContentView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @StateObject private var excelSession = ExcelSessionViewModel()

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
        TabView {
            // TAB 1: Inventario
            NavigationStack {
                InventoryHomeView()
                    .environmentObject(excelSession)
            }
            .tabItem {
                Label("Inventario", systemImage: "doc.on.doc")
            }

            // TAB 2: Database
            NavigationStack {
                DatabaseView()
            }
            .tabItem {
                Label("Database", systemImage: "shippingbox")
            }

            // TAB 3: Cronologia
            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("Cronologia", systemImage: "clock.arrow.circlepath")
            }

            // TAB 4: Opzioni
            NavigationStack {
                OptionsView()
            }
            .tabItem {
                Label("Opzioni", systemImage: "gearshape")
            }
        }
        .preferredColorScheme(resolvedColorScheme)
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
