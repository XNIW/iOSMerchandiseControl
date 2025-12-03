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
    // Preview con SwiftData in-memory
    ContentView()
        .modelContainer(for: [
            Product.self,
            Supplier.self,
            Category.self
        ], inMemory: true)
}
