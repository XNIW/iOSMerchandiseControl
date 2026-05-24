import SwiftData

enum SyncAutomaticRuntimeFactory {
    static func make(context: ModelContext) {
        _ = context.container
    }
}
