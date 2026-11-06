#if DEBUG
import Foundation

/// Bounded process-local observations only. Does not read model data, grant a
/// capability, set the controller failure, submit work or change a query result.
nonisolated final class Task145StoreLoadFailureObservation: @unchecked Sendable {
    enum Entry: String { case repositoryLoad, invalidManifestCaught, otherLoadFailureCaught, businessRootConstructed, optionsBusinessRead }
    static let malformedManifest = Data("{task145: deliberately malformed controlled manifest}".utf8)
    private static let enabled = ProcessInfo.processInfo.environment["TASK145_SAFE_STORE_FAILURE_UI"] == "malformed-manifest"
        && ProcessInfo.processInfo.environment["TASK144_LOCAL_AVAILABILITY_FIXTURE"].flatMap(UUID.init(uuidString:)) != nil
    private static let shared = Task145StoreLoadFailureObservation()
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var observation = 0

    static func record(_ entry: Entry) {
        guard enabled else { return }
        shared.lock.lock(); defer { shared.lock.unlock() }
        shared.counts[entry.rawValue] = min(9, shared.counts[entry.rawValue, default: 0] + 1)
    }

    static func snapshot(namespace: UUID, failureCode: String?, malformedManifestPreserved: Bool,
                         manifestAbsent: Bool, signedIn: Bool) -> String {
        guard enabled else { return "" }
        shared.lock.lock(); defer { shared.lock.unlock() }
        shared.observation += 1
        var payload = shared.counts.mapValues { $0 as Any }
        for entry in [Entry.repositoryLoad, .invalidManifestCaught, .otherLoadFailureCaught, .businessRootConstructed, .optionsBusinessRead] {
            payload[entry.rawValue] = shared.counts[entry.rawValue, default: 0]
        }
        payload["namespace"] = namespace.uuidString.lowercased()
        payload["observation"] = shared.observation
        payload["failureCode"] = failureCode ?? "absent"
        payload["malformedManifestPreserved"] = malformedManifestPreserved
        payload["manifestAbsent"] = manifestAbsent
        payload["signedIn"] = signedIn
        return (try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]).base64EncodedString()) ?? "invalid"
    }
}
#endif
