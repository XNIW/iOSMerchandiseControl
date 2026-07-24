#if DEBUG
import Foundation
import UIKit

/// Isolated process-relaunch proof for sec-mobile-prebound-resource-003.
///
/// The host runs `prepare`, terminates the app, and launches `verify` on a
/// fresh Simulator. The harness uses production account/shop gates, watermark,
/// recovery-fence and Product Image cache implementations, but never opens the
/// normal app store or constructs network/auth dependencies.
@MainActor
enum Task139PreboundResourceRuntimeHarness {
    private enum Action: String {
        case prepare
        case verify
    }

    private struct State: Codable {
        let schemaVersion: Int
        let preparePID: Int32
        let ownerA: UUID
        let ownerB: UUID
        let shopA: UUID
        let shopB: UUID
        let productID: UUID
        let versionID: UUID
        let generationID: UUID
        let deviceIdentityHash: String
        let recoveryScopeKey: String
    }

    private struct Result: Codable {
        let schemaVersion: Int
        let action: String
        let passed: Bool
        let pid: Int32
        let preparePID: Int32?
        let automaticGateError: String?
        let productImageScopeBAllowed: Bool?
        let oldCacheReadable: Bool?
        let newScopeCacheEmpty: Bool?
        let watermarkA: Int64?
        let watermarkB: Int64?
        let fenceAReadable: Bool?
        let fenceBEmpty: Bool?
        let pendingMarkerReadable: Bool?
        let stalePublishMarkersAbsent: Bool?
        let errorCode: String?
    }

    private enum HarnessError: String, Error {
        case invalidMode
        case unavailableDirectory
        case fixtureAlreadyExists
        case missingState
        case identitySetupFailed
        case scopeSetupFailed
        case cacheSetupFailed
        case verificationFailed
    }

    private static let ownerA = UUID(uuidString: "a1390000-0000-4000-8000-000000000001")!
    private static let ownerB = UUID(uuidString: "b1390000-0000-4000-8000-000000000002")!
    private static let shopA = UUID(uuidString: "a1390000-0000-4000-8000-000000000003")!
    private static let shopB = UUID(uuidString: "b1390000-0000-4000-8000-000000000004")!
    private static let productID = UUID(uuidString: "a1390000-0000-4000-8000-000000000005")!
    private static let versionID = UUID(uuidString: "a1390000-0000-4000-8000-000000000006")!
    private static let generationID = UUID(uuidString: "a1390000-0000-4000-8000-000000000007")!

    static func runIfRequested() -> Bool {
        guard let rawMode = ProcessInfo.processInfo.environment[
            "TASK139_PREBOUND_RUNTIME_MODE"
        ]?.trimmingCharacters(in: .whitespacesAndNewlines),
              let action = Action(rawValue: rawMode) else {
            return false
        }

        Task { @MainActor in
            do {
                switch action {
                case .prepare:
                    try await prepare()
                case .verify:
                    try await verify()
                }
            } catch {
                writeFailureBestEffort(action: action, error: error)
            }
        }
        return true
    }

    private static func prepare() async throws {
        let root = try harnessRoot()
        guard !FileManager.default.fileExists(atPath: root.path) else {
            throw HarnessError.fixtureAlreadyExists
        }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let defaults = try harnessDefaults()
        let accountHashA = AccountBindingStore.accountHash(for: ownerA)
        let selectedA = selectedShop(id: shopA, name: "TASK-139 scope A")
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHashA)
        guard selectedStore.save(selectedA, accountHash: accountHashA),
              AccountBindingStore(defaults: defaults).saveBinding(
                accountHash: accountHashA,
                storeIdentity: selectedA.localStoreIdentity
              ) else {
            throw HarnessError.identitySetupFailed
        }

        let scopeA = try Task126OwnerStoreGate.captureAutomaticScope(
            ownerUserID: ownerA,
            defaults: defaults
        )
        let watermarkScopeA = WatermarkStore.Scope(
            accountHash: scopeA.accountHash,
            storeIdentity: scopeA.storeIdentity
        )
        guard WatermarkStore(defaults: defaults).saveAuthoritativeRecoveryCheckpoint(
            41,
            generationID: generationID,
            for: watermarkScopeA
        ) else {
            throw HarnessError.scopeSetupFailed
        }
        let recoveryScopeKey = ShopSyncRecoveryCanonical.sha256(
            "task139-prebound:\(scopeA.accountHash):\(scopeA.storeIdentity.rawValue):"
                + scopeA.deviceIdentityHash
        )
        let recoveryScope = ShopSyncRecoveryScope(
            kind: "shop_scoped",
            key: recoveryScopeKey,
            legacyOwnerKey: nil,
            accountKey: scopeA.accountHash,
            deviceKey: scopeA.deviceIdentityHash
        )
        guard ShopSyncRecoveryFenceStore(defaults: defaults).saveAuthoritative(
            scope: recoveryScope,
            watermark: 41,
            accountHash: scopeA.accountHash,
            storeIdentity: scopeA.storeIdentity,
            deviceIdentityHash: scopeA.deviceIdentityHash
        ) else {
            throw HarnessError.scopeSetupFailed
        }

        let cache = ProductImageCache(rootDirectory: cacheRoot(root))
        let prepared = try makePreparedImage()
        try await cache.write(
            prepared.thumb.data,
            for: cacheKey(accountID: ownerA, shopID: shopA)
        )
        guard try await cache.diskEntryCount() == 1 else {
            throw HarnessError.cacheSetupFailed
        }

        try Data("A|G1|pending".utf8).write(
            to: root.appendingPathComponent("pending-g1"),
            options: [.atomic]
        )
        let state = State(
            schemaVersion: 1,
            preparePID: ProcessInfo.processInfo.processIdentifier,
            ownerA: ownerA,
            ownerB: ownerB,
            shopA: shopA,
            shopB: shopB,
            productID: productID,
            versionID: versionID,
            generationID: generationID,
            deviceIdentityHash: scopeA.deviceIdentityHash,
            recoveryScopeKey: recoveryScopeKey
        )
        try writeJSON(state, to: stateURL(root))
        guard defaults.synchronize() else {
            throw HarnessError.scopeSetupFailed
        }
        try writeJSON(
            Result(
                schemaVersion: 1,
                action: Action.prepare.rawValue,
                passed: true,
                pid: ProcessInfo.processInfo.processIdentifier,
                preparePID: nil,
                automaticGateError: nil,
                productImageScopeBAllowed: nil,
                oldCacheReadable: true,
                newScopeCacheEmpty: true,
                watermarkA: 41,
                watermarkB: 0,
                fenceAReadable: true,
                fenceBEmpty: true,
                pendingMarkerReadable: true,
                stalePublishMarkersAbsent: true,
                errorCode: nil
            ),
            to: resultURL(root, action: .prepare)
        )
    }

    private static func verify() async throws {
        let root = try harnessRoot()
        let state: State = try readJSON(State.self, from: stateURL(root))
        guard state.schemaVersion == 1,
              state.ownerA == ownerA,
              state.ownerB == ownerB,
              state.shopA == shopA,
              state.shopB == shopB,
              state.productID == productID,
              state.versionID == versionID,
              state.preparePID != ProcessInfo.processInfo.processIdentifier else {
            throw HarnessError.verificationFailed
        }

        let defaults = try harnessDefaults()
        let selectedB = selectedShop(id: shopB, name: "TASK-139 scope B")
        let accountHashB = AccountBindingStore.accountHash(for: ownerB)
        let selectedStore = SelectedShopStore(defaults: defaults)
        selectedStore.noteActiveAccount(accountHashB)
        guard selectedStore.save(selectedB, accountHash: accountHashB) else {
            throw HarnessError.identitySetupFailed
        }

        let automaticGateError: String
        do {
            _ = try Task126OwnerStoreGate.captureAutomaticScope(
                ownerUserID: ownerB,
                defaults: defaults
            )
            automaticGateError = "unexpected_success"
        } catch let error as Task126OwnerStoreGateError {
            automaticGateError = String(describing: error)
        }

        let bindingStore = AccountBindingStore(defaults: defaults)
        let bindingA = bindingStore.currentBinding
        let scopeB = ProductImageScope(accountID: ownerB, shopID: shopB)
        let productImageScopeBAllowed = ProductImageOwnerStoreGate.allows(
            scope: scopeB,
            selectedShop: selectedB,
            binding: bindingA,
            hasPendingReplacement: bindingStore.hasPendingReplacementJournal
        )

        let selectedA = selectedShop(id: shopA, name: "TASK-139 scope A")
        let accountHashA = AccountBindingStore.accountHash(for: ownerA)
        let watermarkStore = WatermarkStore(defaults: defaults)
        let watermarkScopeA = WatermarkStore.Scope(
            accountHash: accountHashA,
            storeIdentity: selectedA.localStoreIdentity
        )
        let watermarkScopeB = WatermarkStore.Scope(
            accountHash: accountHashB,
            storeIdentity: selectedB.localStoreIdentity
        )
        let watermarkA = watermarkStore.watermark(for: watermarkScopeA)
        let watermarkB = watermarkStore.watermark(for: watermarkScopeB)
        let fenceStore = ShopSyncRecoveryFenceStore(defaults: defaults)
        let fenceA = fenceStore.scopeKey(
            accountHash: accountHashA,
            storeIdentity: selectedA.localStoreIdentity,
            deviceIdentityHash: state.deviceIdentityHash,
            watermark: 41
        )
        let fenceB = fenceStore.scopeKey(
            accountHash: accountHashB,
            storeIdentity: selectedB.localStoreIdentity,
            deviceIdentityHash: state.deviceIdentityHash,
            watermark: 41
        )

        let cache = ProductImageCache(rootDirectory: cacheRoot(root))
        let oldCache = try await cache.read(cacheKey(accountID: ownerA, shopID: shopA))
        let newCache = try await cache.read(cacheKey(accountID: ownerB, shopID: shopB))
        let pendingMarker = FileManager.default.fileExists(
            atPath: root.appendingPathComponent("pending-g1").path
        )
        let stalePublishMarkersAbsent = [
            "published-g1",
            "terminal-receipt-g1",
            "no-work-g1"
        ].allSatisfy {
            !FileManager.default.fileExists(
                atPath: root.appendingPathComponent($0).path
            )
        }
        let passed = automaticGateError == String(
            describing: Task126OwnerStoreGateError.bindingMismatch
        )
            && !productImageScopeBAllowed
            && bindingA?.accountHash == accountHashA
            && bindingA?.storeIdentity == selectedA.localStoreIdentity
            && oldCache != nil
            && newCache == nil
            && watermarkA == 41
            && watermarkB == 0
            && fenceA == state.recoveryScopeKey
            && fenceB == nil
            && pendingMarker
            && stalePublishMarkersAbsent

        try writeJSON(
            Result(
                schemaVersion: 1,
                action: Action.verify.rawValue,
                passed: passed,
                pid: ProcessInfo.processInfo.processIdentifier,
                preparePID: state.preparePID,
                automaticGateError: automaticGateError,
                productImageScopeBAllowed: productImageScopeBAllowed,
                oldCacheReadable: oldCache != nil,
                newScopeCacheEmpty: newCache == nil,
                watermarkA: watermarkA,
                watermarkB: watermarkB,
                fenceAReadable: fenceA == state.recoveryScopeKey,
                fenceBEmpty: fenceB == nil,
                pendingMarkerReadable: pendingMarker,
                stalePublishMarkersAbsent: stalePublishMarkersAbsent,
                errorCode: passed ? nil : HarnessError.verificationFailed.rawValue
            ),
            to: resultURL(root, action: .verify)
        )
        guard passed else { throw HarnessError.verificationFailed }
    }

    private static func selectedShop(id: UUID, name: String) -> SelectedShop {
        SelectedShop(
            shopID: id,
            code: "TASK139",
            name: name,
            role: "owner",
            status: "active",
            selectable: true,
            canWrite: true,
            selectedAt: Date(timeIntervalSince1970: 139)
        )
    }

    private static func cacheKey(
        accountID: UUID,
        shopID: UUID
    ) -> ProductImageCacheKey {
        ProductImageCacheKey(
            cacheScope: ProductImageService.expectedCacheScope(accountID: accountID),
            shopID: shopID,
            productID: productID,
            versionID: versionID,
            variant: .thumb
        )
    }

    private static func makePreparedImage() throws -> PreparedProductImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 96, height: 72))
        let image = renderer.image { context in
            UIColor(red: 0.12, green: 0.42, blue: 0.76, alpha: 1).setFill()
            context.fill(CGRect(x: 0, y: 0, width: 96, height: 72))
        }
        guard let jpeg = image.jpegData(compressionQuality: 0.9) else {
            throw HarnessError.cacheSetupFailed
        }
        return try ProductImageProcessor.prepare(data: jpeg)
    }

    private static func harnessDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults(
            suiteName: "Task139PreboundResourceRuntimeHarness"
        ) else {
            throw HarnessError.identitySetupFailed
        }
        return defaults
    }

    private static func harnessRoot() throws -> URL {
        guard let support = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw HarnessError.unavailableDirectory
        }
        return support.appendingPathComponent(
            "Task139PreboundResourceRuntimeHarness",
            isDirectory: true
        )
    }

    private static func cacheRoot(_ root: URL) -> URL {
        root.appendingPathComponent("image-cache", isDirectory: true)
    }

    private static func stateURL(_ root: URL) -> URL {
        root.appendingPathComponent("state.json")
    }

    private static func resultURL(_ root: URL, action: Action) -> URL {
        root.appendingPathComponent("\(action.rawValue)-result.json")
    }

    private static func writeJSON<Value: Encodable>(_ value: Value, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic])
    }

    private static func readJSON<Value: Decodable>(
        _ type: Value.Type,
        from url: URL
    ) throws -> Value {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw HarnessError.missingState
        }
        return try JSONDecoder().decode(type, from: Data(contentsOf: url))
    }

    private static func writeFailureBestEffort(action: Action, error: Error) {
        guard let root = try? harnessRoot() else { return }
        let code = (error as? HarnessError)?.rawValue
            ?? String(describing: type(of: error))
        try? writeJSON(
            Result(
                schemaVersion: 1,
                action: action.rawValue,
                passed: false,
                pid: ProcessInfo.processInfo.processIdentifier,
                preparePID: nil,
                automaticGateError: nil,
                productImageScopeBAllowed: nil,
                oldCacheReadable: nil,
                newScopeCacheEmpty: nil,
                watermarkA: nil,
                watermarkB: nil,
                fenceAReadable: nil,
                fenceBEmpty: nil,
                pendingMarkerReadable: nil,
                stalePublishMarkersAbsent: nil,
                errorCode: code
            ),
            to: root.appendingPathComponent("failure-\(action.rawValue).json")
        )
    }
}
#endif
