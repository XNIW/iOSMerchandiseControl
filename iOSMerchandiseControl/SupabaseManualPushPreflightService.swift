import Foundation

nonisolated enum ManualPushBaselineInvalidationReason: String, Sendable, Equatable, Hashable, CaseIterable {
    case accountChanged
    case partialPull
    case sourceErrors
    case fingerprintVersionChanged
    case localReset
    case remoteTombstoneConflict
}

nonisolated struct ManualPushPullState: Sendable, Equatable {
    let isComplete: Bool
    let hasSourceErrors: Bool

    init(isComplete: Bool, hasSourceErrors: Bool = false) {
        self.isComplete = isComplete
        self.hasSourceErrors = hasSourceErrors
    }
}

nonisolated struct ManualPushAccountState: Sendable, Equatable {
    let currentUserID: UUID?
    let lastLinkedUserID: UUID?

    init(currentUserID: UUID?, lastLinkedUserID: UUID?) {
        self.currentUserID = currentUserID
        self.lastLinkedUserID = lastLinkedUserID
    }

    var hasMismatch: Bool {
        guard let currentUserID, let lastLinkedUserID else {
            return true
        }
        return currentUserID != lastLinkedUserID
    }
}

nonisolated struct ManualPushBaseline: Sendable, Equatable {
    let productFingerprintsByRemoteID: [UUID: ManualPushFingerprint]
    let remoteProductIDsByBarcode: [String: UUID]
    let remoteUpdatedAtByProductID: [UUID: Date]
    let remoteDeletedAtByProductID: [UUID: Date]
    let invalidationReasons: Set<ManualPushBaselineInvalidationReason>

    init(
        productFingerprintsByRemoteID: [UUID: ManualPushFingerprint],
        remoteProductIDsByBarcode: [String: UUID] = [:],
        remoteUpdatedAtByProductID: [UUID: Date] = [:],
        remoteDeletedAtByProductID: [UUID: Date] = [:],
        invalidationReasons: Set<ManualPushBaselineInvalidationReason> = []
    ) {
        self.productFingerprintsByRemoteID = productFingerprintsByRemoteID
        var normalizedRemoteProductIDsByBarcode: [String: UUID] = [:]
        for (barcode, remoteID) in remoteProductIDsByBarcode {
            guard let normalizedBarcode = ManualPushFingerprintNormalizer.semanticString(barcode) else {
                continue
            }
            normalizedRemoteProductIDsByBarcode[normalizedBarcode] = remoteID
        }
        self.remoteProductIDsByBarcode = normalizedRemoteProductIDsByBarcode
        self.remoteUpdatedAtByProductID = remoteUpdatedAtByProductID
        self.remoteDeletedAtByProductID = remoteDeletedAtByProductID
        self.invalidationReasons = invalidationReasons
    }

    var isValid: Bool {
        invalidationReasons.isEmpty
    }
}

nonisolated struct ManualPushProductState: Sendable, Equatable {
    let localID: String
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
    let barcode: String?
    let itemNumber: String?
    let productName: String?
    let secondProductName: String?
    let purchasePrice: Double?
    let retailPrice: Double?
    let stockQuantity: Double?
    let hasSupplierReference: Bool
    let supplierRemoteID: UUID?
    let hasCategoryReference: Bool
    let categoryRemoteID: UUID?
    let hasLocalPriceChanges: Bool

    init(
        localID: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        barcode: String? = nil,
        itemNumber: String? = nil,
        productName: String? = nil,
        secondProductName: String? = nil,
        purchasePrice: Double? = nil,
        retailPrice: Double? = nil,
        stockQuantity: Double? = nil,
        hasSupplierReference: Bool = false,
        supplierRemoteID: UUID? = nil,
        hasCategoryReference: Bool = false,
        categoryRemoteID: UUID? = nil,
        hasLocalPriceChanges: Bool = false
    ) {
        self.localID = localID
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.barcode = barcode
        self.itemNumber = itemNumber
        self.productName = productName
        self.secondProductName = secondProductName
        self.purchasePrice = purchasePrice
        self.retailPrice = retailPrice
        self.stockQuantity = stockQuantity
        self.hasSupplierReference = hasSupplierReference
        self.supplierRemoteID = supplierRemoteID
        self.hasCategoryReference = hasCategoryReference
        self.categoryRemoteID = categoryRemoteID
        self.hasLocalPriceChanges = hasLocalPriceChanges
    }

    var catalogFingerprint: ManualPushFingerprint {
        ManualPushFingerprintNormalizer.product(
            barcode: barcode,
            itemNumber: itemNumber,
            productName: productName,
            secondProductName: secondProductName,
            purchasePrice: purchasePrice,
            retailPrice: retailPrice,
            stockQuantity: stockQuantity,
            supplierRemoteID: supplierRemoteID,
            categoryRemoteID: categoryRemoteID
        )
    }
}

nonisolated struct ManualPushPreflightInput: Sendable, Equatable {
    let generatedAt: Date
    let pullState: ManualPushPullState
    let accountState: ManualPushAccountState
    let baseline: ManualPushBaseline?
    let products: [ManualPushProductState]
    let simulatedChangedCount: Int?

    init(
        generatedAt: Date = Date(),
        pullState: ManualPushPullState,
        accountState: ManualPushAccountState,
        baseline: ManualPushBaseline?,
        products: [ManualPushProductState],
        simulatedChangedCount: Int? = nil
    ) {
        self.generatedAt = generatedAt
        self.pullState = pullState
        self.accountState = accountState
        self.baseline = baseline
        self.products = products
        self.simulatedChangedCount = simulatedChangedCount
    }
}

nonisolated struct SupabaseManualPushPreflightService: Sendable {
    init() {}

    func makePreview(input: ManualPushPreflightInput) -> ManualPushPreview {
        let plan = makePlan(input: input)
        return ManualPushPreview(
            generatedAt: input.generatedAt,
            plan: plan
        )
    }

    func makePlan(input: ManualPushPreflightInput) -> ManualPushPlan {
        var candidates: [PushCandidate] = []
        var blockedReasons: [PushBlockedReason] = []
        var warnings: [PushWarning] = []

        if input.accountState.hasMismatch {
            blockedReasons.append(.blockedAccountMismatch)
        }

        if !input.pullState.isComplete || input.pullState.hasSourceErrors {
            blockedReasons.append(.blockedPartialPull)
        }

        let baseline = input.baseline
        if baseline?.isValid != true {
            blockedReasons.append(.blockedMissingBaseline)
        }

        let hasGlobalBlocker = !blockedReasons.isEmpty

        for product in input.products.sorted(by: { $0.localID < $1.localID }) {
            if product.hasLocalPriceChanges {
                candidates.append(
                    PushCandidate(
                        entityKind: .productPrice,
                        localID: product.localID,
                        remoteID: product.remoteID,
                        action: .futurePricePushCandidate,
                        detail: "ProductPrice changes are future-only in TASK-041."
                    )
                )
            }

            guard !hasGlobalBlocker else {
                continue
            }

            if hasRemoteTombstone(product: product, baseline: baseline) {
                blockedReasons.append(.blockedTombstoneConflict)
                continue
            }

            if productHasUnresolvedLookupReference(product) {
                blockedReasons.append(.blockedMissingSupplierCategoryRemoteID)
                appendUnique(.warningLocalOnlySupplierCategory, to: &warnings)
                continue
            }

            guard let baseline else {
                blockedReasons.append(.blockedMissingBaseline)
                continue
            }

            if let remoteID = product.remoteID {
                classifyLinkedProduct(
                    product,
                    remoteID: remoteID,
                    baseline: baseline,
                    candidates: &candidates,
                    blockedReasons: &blockedReasons,
                    warnings: &warnings
                )
            } else {
                classifyLocalOnlyProduct(
                    product,
                    baseline: baseline,
                    candidates: &candidates,
                    blockedReasons: &blockedReasons
                )
            }
        }

        let realChangedCount = candidates.filter {
            $0.action == .dryRunCreateCandidate || $0.action == .dryRunUpdateCandidate
        }.count
        let futureEventChangedCount = input.simulatedChangedCount ?? realChangedCount

        if futureEventChangedCount > ManualPushPlan.futureEventSplitThreshold {
            appendUnique(.futureEventSplitRequired, to: &warnings)
        }

        return ManualPushPlan(
            generatedAt: input.generatedAt,
            candidates: candidates,
            blockedReasons: blockedReasons,
            warnings: warnings,
            futureEventChangedCount: futureEventChangedCount
        )
    }

    private func classifyLinkedProduct(
        _ product: ManualPushProductState,
        remoteID: UUID,
        baseline: ManualPushBaseline,
        candidates: inout [PushCandidate],
        blockedReasons: inout [PushBlockedReason],
        warnings: inout [PushWarning]
    ) {
        if let baselineRemoteUpdatedAt = baseline.remoteUpdatedAtByProductID[remoteID],
           let localRemoteUpdatedAt = product.remoteUpdatedAt,
           baselineRemoteUpdatedAt > localRemoteUpdatedAt {
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        if product.remoteUpdatedAt == nil,
           baseline.remoteUpdatedAtByProductID[remoteID] != nil {
            appendUnique(.warningStaleRemote, to: &warnings)
        }

        guard let baselineFingerprint = baseline.productFingerprintsByRemoteID[remoteID] else {
            blockedReasons.append(.blockedMissingBaseline)
            return
        }

        let localFingerprint = product.catalogFingerprint
        let action: PushCandidateAction = localFingerprint == baselineFingerprint
            ? .noOpAlreadySynced
            : .dryRunUpdateCandidate
        candidates.append(
            PushCandidate(
                entityKind: .product,
                localID: product.localID,
                remoteID: remoteID,
                action: action,
                fingerprint: localFingerprint
            )
        )
    }

    private func classifyLocalOnlyProduct(
        _ product: ManualPushProductState,
        baseline: ManualPushBaseline,
        candidates: inout [PushCandidate],
        blockedReasons: inout [PushBlockedReason]
    ) {
        if let barcode = ManualPushFingerprintNormalizer.semanticString(product.barcode),
           baseline.remoteProductIDsByBarcode[barcode] != nil {
            blockedReasons.append(.blockedNoRemoteID)
            return
        }

        candidates.append(
            PushCandidate(
                entityKind: .product,
                localID: product.localID,
                action: .dryRunCreateCandidate,
                fingerprint: product.catalogFingerprint
            )
        )
    }

    private func hasRemoteTombstone(
        product: ManualPushProductState,
        baseline: ManualPushBaseline?
    ) -> Bool {
        if product.remoteDeletedAt != nil {
            return true
        }
        guard let remoteID = product.remoteID else {
            return false
        }
        return baseline?.remoteDeletedAtByProductID[remoteID] != nil
    }

    private func productHasUnresolvedLookupReference(_ product: ManualPushProductState) -> Bool {
        (product.hasSupplierReference && product.supplierRemoteID == nil)
            || (product.hasCategoryReference && product.categoryRemoteID == nil)
    }

    private func appendUnique(_ warning: PushWarning, to warnings: inout [PushWarning]) {
        guard !warnings.contains(warning) else {
            return
        }
        warnings.append(warning)
    }
}
