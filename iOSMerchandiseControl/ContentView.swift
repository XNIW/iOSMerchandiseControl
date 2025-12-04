import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            DatabaseView()
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
