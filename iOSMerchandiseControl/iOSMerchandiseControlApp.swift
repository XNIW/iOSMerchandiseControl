import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {

    // Come il tuo AppDatabase Room: contiene lo schema SwiftData
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            Supplier.self,
            Category.self
            // Più avanti aggiungeremo HistoryEntry, ProductPrice, ecc.
        ])

        let configuration = ModelConfiguration(schema: schema)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Impossibile creare ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()   // tra poco la riempiamo
        }
        .modelContainer(sharedModelContainer)
    }
}
