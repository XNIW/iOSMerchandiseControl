import Foundation

enum SyncStringCollectionHelpers {
    nonisolated static func uniquedSorted(_ values: [String]) -> [String] {
        Array(Set(values)).sorted()
    }
}
