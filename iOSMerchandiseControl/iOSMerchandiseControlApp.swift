import SwiftUI
import SwiftData

@main
struct iOSMerchandiseControlApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Product.self,
            Supplier.self,
            ProductCategory.self   // ← nuovo nome
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
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
