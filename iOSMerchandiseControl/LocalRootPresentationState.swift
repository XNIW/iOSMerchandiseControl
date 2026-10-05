import Combine
import Foundation
import SwiftUI
import SwiftData

/// Presentation receipt for one durable Save, not a queue or cloud authority.
/// Only immutable values cross the store-generation boundary.
nonisolated struct LocalProductSaveReceipt: Equatable, Sendable {
    let remoteID: UUID?
    let barcode: String
    let productFingerprint: String
    let supplierRemoteID: UUID?
    let categoryRemoteID: UUID?
    let accountHash: String
    let storeIdentity: LocalStoreIdentity
    let shopID: UUID
    let deviceIdentityHash: String
    let intents: [LocalPendingChangeCASToken]

    init(product: Product, manifest: SyncStoreGenerationManifest, intents: [LocalPendingChangeCASToken]) {
        remoteID = product.remoteID; barcode = product.barcode
        productFingerprint = Self.businessSaveFingerprint(product)
        supplierRemoteID = product.supplier?.remoteID; categoryRemoteID = product.category?.remoteID
        accountHash = manifest.accountHash; storeIdentity = manifest.storeIdentity
        shopID = manifest.shopID; deviceIdentityHash = manifest.deviceIdentityHash
        self.intents = intents
    }

    func matches(_ manifest: SyncStoreGenerationManifest?) -> Bool {
        guard let manifest else { return false }
        return accountHash == manifest.accountHash && storeIdentity == manifest.storeIdentity
            && shopID == manifest.shopID && deviceIdentityHash == manifest.deviceIdentityHash
    }

    func matches(_ product: Product, readback: LocalProductSaveReadback? = nil) -> Bool {
        (remoteID.map { $0 == product.remoteID } ?? (barcode == product.barcode))
            && product.supplier?.remoteID == (supplierRemoteID ?? readback?.supplierRemoteID)
            && product.category?.remoteID == (categoryRemoteID ?? readback?.categoryRemoteID)
            && productFingerprint == Self.businessSaveFingerprint(product)
    }

    /// The user's body and relation names identify this Save. Assigning IDs
    /// to its new relations is ACK metadata, while existing IDs stay fenced
    /// above. Canonical sync fingerprints and immutable intent tokens do not
    /// use this presentation-only identity.
    private static func businessSaveFingerprint(_ product: Product) -> String {
        let parts = [ManualPushFingerprintNormalizer.product(barcode: product.barcode,
            itemNumber: product.itemNumber, productName: product.productName,
            secondProductName: product.secondProductName, purchasePrice: product.purchasePrice,
            retailPrice: product.retailPrice, stockQuantity: product.stockQuantity,
            supplierRemoteID: nil, categoryRemoteID: nil).canonicalString,
            ManualPushFingerprintNormalizer.supplier(name: product.supplier?.name).canonicalString,
            ManualPushFingerprintNormalizer.category(name: product.category?.name).canonicalString]
        return LocalPendingChangeLogicalKey.privacyHash(parts.map { "\($0.utf8.count):\($0)" }.joined(separator: "|"))
    }

    /// ACK is written only by the typed response/CAS path. Another record's
    /// pending state, a local-only body proof, or an old A ACK cannot confirm B.
    func isCloudConfirmed(by changes: [LocalPendingChange]) -> Bool {
        guard !intents.isEmpty, intents.count <= 5, changes.count == intents.count,
              Set(intents.map(\.changeID)).count == intents.count else { return false }
        return intents.allSatisfy { acknowledgedChange(for: $0, changes: changes) != nil }
    }

    /// Only the exact qualified ACK for this Save's relation intent may bind
    /// a previously absent remote ID. Same-name foreign IDs are never wildcards.
    func readback(by changes: [LocalPendingChange]) -> LocalProductSaveReadback {
        func relatedID(_ kind: LocalPendingChangeEntityKind) -> UUID? {
            let matching = intents.filter { $0.entityKindRaw == kind.rawValue }
            guard matching.count == 1, let intent = matching.first,
                  let acknowledged = acknowledgedChange(for: intent, changes: changes) else { return nil }
            return acknowledged.entityRemoteID
        }
        return LocalProductSaveReadback(isCloudConfirmed: isCloudConfirmed(by: changes),
            supplierRemoteID: supplierRemoteID ?? relatedID(.supplier),
            categoryRemoteID: categoryRemoteID ?? relatedID(.productCategory))
    }

    private func acknowledgedChange(for intent: LocalPendingChangeCASToken,
                                    changes: [LocalPendingChange]) -> LocalPendingChange? {
        guard intents.count <= 5, changes.count == intents.count else { return nil }
        let matching = changes.filter { $0.changeID == intent.changeID }
        guard matching.count == 1, let change = matching.first,
              let ownerRaw = intent.ownerUserID, let owner = UUID(uuidString: ownerRaw),
              AccountBindingStore.accountHash(for: owner) == accountHash,
              let fingerprint = intent.intendedFingerprintHash, !fingerprint.isEmpty else { return nil }
        guard change.statusRaw == LocalPendingChangeStatus.acknowledged.rawValue
            && change.idempotencyKey == intent.idempotencyKey
            && change.ownerUserID == intent.ownerUserID && change.ownerHash == accountHash
            && change.storeId == storeIdentity.storeId && change.localStoreId == storeIdentity.localStoreId
            && change.syncProtocolVersion == storeIdentity.syncProtocolVersion
            && change.schemaVersion == storeIdentity.schemaVersion && change.storeEpoch == storeIdentity.storeEpoch
            && change.recordSchemaVersion == intent.recordSchemaVersion
            && change.entityKindRaw == intent.entityKindRaw && change.originRaw == intent.originRaw
            && change.intendedFingerprintHash == intent.intendedFingerprintHash
            && change.supersededByChangeID == nil else { return nil }
        return change
    }
}

nonisolated struct LocalProductSaveReadback: Equatable, Sendable {
    let isCloudConfirmed: Bool
    let supplierRemoteID: UUID?
    let categoryRemoteID: UUID?
}

/// Only value state crosses a generation boundary. SwiftData models, image
/// operations and runtime admission tokens remain owned by the mounted root.
@MainActor
final class LocalRootPresentationState: ObservableObject {
    struct EditorDraft: Equatable {
        var remoteID: UUID?
        var originalBarcode: String
        var baseline: ProductDraft?
        var barcode: String
        var name: String
        var secondName: String
        var itemNumber: String
        var purchasePrice: String
        var retailPrice: String
        var stockQuantity: String
        var supplierName: String
        var categoryName: String
        var focusedField: String?
    }

    struct Values {
        var selectedTab: Int?
        var databaseSection = "products"
        var barcodeFilter = ""
        var namedEntityFilter = ""
        var storefrontFilter = "all"
        var productScrollAnchor: String?
        var editor: EditorDraft?
        var savedProduct: LocalProductSaveReceipt?
    }

    private struct Scope: Equatable {
        let accountHash: String
        let storeIdentity: LocalStoreIdentity
        let shopID: UUID
        let deviceIdentityHash: String
    }

    // This publisher deliberately never fires from the activation observer,
    // which runs under the existing store-generation publication lease.
    let objectWillChange = ObservableObjectPublisher()
    private var presentationID: String?
    private var scope: Scope?
    private var values = Values()

    var currentPresentationID: String? { presentationID }

    func isCurrent(presentationID: String?) -> Bool {
        presentationID == nil || presentationID == self.presentationID
    }

    func advanceStoreGeneration(presentationID: String) {
        self.presentationID = presentationID
    }

    func admit(
        manifest: SyncStoreGenerationManifest?,
        ownerUserID: UUID?,
        presentationID: String,
        localAccessPermitted: Bool
    ) -> Values? {
        guard self.presentationID == presentationID else { return nil }
        guard localAccessPermitted, let manifest, let ownerUserID,
              manifest.accountHash == AccountBindingStore.accountHash(for: ownerUserID) else {
            scope = nil
            values = Values()
            return nil
        }
        let current = Scope(accountHash: manifest.accountHash, storeIdentity: manifest.storeIdentity,
            shopID: manifest.shopID, deviceIdentityHash: manifest.deviceIdentityHash)
        if scope != current {
            scope = current
            values = Values()
        }
        return values
    }

    func update(presentationID: String?, _ mutation: (inout Values) -> Void) {
        guard let presentationID, presentationID == self.presentationID, scope != nil else { return }
        mutation(&values)
    }

    func savedProduct(presentationID: String?) -> LocalProductSaveReceipt? {
        guard presentationID == self.presentationID, scope != nil else { return nil }
        return values.savedProduct
    }

    /// Called after the guarded writer has committed and released its lease.
    func recordSavedProduct(_ receipt: LocalProductSaveReceipt, presentationID: String?) {
        guard presentationID == self.presentationID, let scope,
              scope.accountHash == receipt.accountHash, scope.storeIdentity == receipt.storeIdentity,
              scope.shopID == receipt.shopID, scope.deviceIdentityHash == receipt.deviceIdentityHash else { return }
        values.savedProduct = receipt
        objectWillChange.send()
    }

    func editor(presentationID: String?, remoteID: UUID?, barcode: String) -> EditorDraft? {
        guard let presentationID, presentationID == self.presentationID, scope != nil,
              let editor = values.editor,
              editor.remoteID.map({ $0 == remoteID }) ?? (editor.originalBarcode == barcode) else { return nil }
        return editor
    }
}

private struct LocalRootPresentationStateKey: EnvironmentKey {
    static let defaultValue: LocalRootPresentationState? = nil
}

private struct LocalModelGenerationFenceKey: EnvironmentKey {
    static let defaultValue: () -> Bool = { true }
}

extension EnvironmentValues {
    var localRootPresentationState: LocalRootPresentationState? {
        get { self[LocalRootPresentationStateKey.self] }
        set { self[LocalRootPresentationStateKey.self] = newValue }
    }
    var localModelGenerationIsCurrent: () -> Bool {
        get { self[LocalModelGenerationFenceKey.self] }
        set { self[LocalModelGenerationFenceKey.self] = newValue }
    }
}
