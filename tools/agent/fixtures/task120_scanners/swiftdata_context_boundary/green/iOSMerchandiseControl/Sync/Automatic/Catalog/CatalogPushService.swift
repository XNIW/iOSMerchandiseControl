import SwiftData

final class CatalogPushService {
    let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func run() {
        let context = ModelContext(modelContainer)
        _ = context
    }
}
