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
    let supplierFingerprintsByRemoteID: [UUID: ManualPushFingerprint]
    let categoryFingerprintsByRemoteID: [UUID: ManualPushFingerprint]
    let productFingerprintsByRemoteID: [UUID: ManualPushFingerprint]
    let remoteSupplierIDsByName: [String: UUID]
    let remoteCategoryIDsByName: [String: UUID]
    let remoteProductIDsByBarcode: [String: UUID]
    let remoteSupplierAmbiguousNames: Set<String>
    let remoteCategoryAmbiguousNames: Set<String>
    let remoteProductAmbiguousBarcodes: Set<String>
    let remoteUpdatedAtBySupplierID: [UUID: Date]
    let remoteUpdatedAtByCategoryID: [UUID: Date]
    let remoteUpdatedAtByProductID: [UUID: Date]
    let remoteDeletedAtBySupplierID: [UUID: Date]
    let remoteDeletedAtByCategoryID: [UUID: Date]
    let remoteDeletedAtByProductID: [UUID: Date]
    let invalidationReasons: Set<ManualPushBaselineInvalidationReason>

    init(
        supplierFingerprintsByRemoteID: [UUID: ManualPushFingerprint] = [:],
        categoryFingerprintsByRemoteID: [UUID: ManualPushFingerprint] = [:],
        productFingerprintsByRemoteID: [UUID: ManualPushFingerprint],
        remoteSupplierIDsByName: [String: UUID] = [:],
        remoteCategoryIDsByName: [String: UUID] = [:],
        remoteProductIDsByBarcode: [String: UUID] = [:],
        remoteSupplierAmbiguousNames: Set<String> = [],
        remoteCategoryAmbiguousNames: Set<String> = [],
        remoteProductAmbiguousBarcodes: Set<String> = [],
        remoteUpdatedAtBySupplierID: [UUID: Date] = [:],
        remoteUpdatedAtByCategoryID: [UUID: Date] = [:],
        remoteUpdatedAtByProductID: [UUID: Date] = [:],
        remoteDeletedAtBySupplierID: [UUID: Date] = [:],
        remoteDeletedAtByCategoryID: [UUID: Date] = [:],
        remoteDeletedAtByProductID: [UUID: Date] = [:],
        invalidationReasons: Set<ManualPushBaselineInvalidationReason> = []
    ) {
        self.supplierFingerprintsByRemoteID = supplierFingerprintsByRemoteID
        self.categoryFingerprintsByRemoteID = categoryFingerprintsByRemoteID
        self.productFingerprintsByRemoteID = productFingerprintsByRemoteID
        self.remoteSupplierIDsByName = Self.normalizedLookupMap(remoteSupplierIDsByName)
        self.remoteCategoryIDsByName = Self.normalizedLookupMap(remoteCategoryIDsByName)
        var normalizedRemoteProductIDsByBarcode: [String: UUID] = [:]
        for (barcode, remoteID) in remoteProductIDsByBarcode {
            guard let normalizedBarcode = ManualPushFingerprintNormalizer.semanticString(barcode) else {
                continue
            }
            normalizedRemoteProductIDsByBarcode[normalizedBarcode] = remoteID
        }
        self.remoteProductIDsByBarcode = normalizedRemoteProductIDsByBarcode
        self.remoteSupplierAmbiguousNames = Self.normalizedLookupSet(remoteSupplierAmbiguousNames)
        self.remoteCategoryAmbiguousNames = Self.normalizedLookupSet(remoteCategoryAmbiguousNames)
        self.remoteProductAmbiguousBarcodes = Self.normalizedSemanticSet(remoteProductAmbiguousBarcodes)
        self.remoteUpdatedAtBySupplierID = remoteUpdatedAtBySupplierID
        self.remoteUpdatedAtByCategoryID = remoteUpdatedAtByCategoryID
        self.remoteUpdatedAtByProductID = remoteUpdatedAtByProductID
        self.remoteDeletedAtBySupplierID = remoteDeletedAtBySupplierID
        self.remoteDeletedAtByCategoryID = remoteDeletedAtByCategoryID
        self.remoteDeletedAtByProductID = remoteDeletedAtByProductID
        self.invalidationReasons = invalidationReasons
    }

    var isValid: Bool {
        invalidationReasons.isEmpty
    }

    private static func normalizedLookupMap(_ values: [String: UUID]) -> [String: UUID] {
        var result: [String: UUID] = [:]
        for (name, remoteID) in values {
            guard let normalized = SupabasePullPreviewNormalizer.normalizedLookupName(name) else {
                continue
            }
            result[normalized] = remoteID
        }
        return result
    }

    private static func normalizedLookupSet(_ values: Set<String>) -> Set<String> {
        Set(values.compactMap(SupabasePullPreviewNormalizer.normalizedLookupName))
    }

    private static func normalizedSemanticSet(_ values: Set<String>) -> Set<String> {
        Set(values.compactMap(ManualPushFingerprintNormalizer.semanticString))
    }
}

nonisolated struct ManualPushLookupState: Sendable, Equatable {
    let entityKind: PushEntityKind
    let localID: String
    let remoteID: UUID?
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
    let name: String

    init(
        entityKind: PushEntityKind,
        localID: String,
        remoteID: UUID? = nil,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        name: String
    ) {
        self.entityKind = entityKind
        self.localID = localID
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.name = name
    }

    var catalogFingerprint: ManualPushFingerprint {
        switch entityKind {
        case .supplier:
            return ManualPushFingerprintNormalizer.supplier(remoteID: remoteID, name: name)
        case .productCategory:
            return ManualPushFingerprintNormalizer.category(remoteID: remoteID, name: name)
        case .product, .productPrice:
            return ManualPushFingerprintNormalizer.fingerprint(entityKind: entityKind, fields: [])
        }
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
    let supplierLocalID: String?
    let supplierName: String?
    let supplierRemoteID: UUID?
    let hasCategoryReference: Bool
    let categoryLocalID: String?
    let categoryName: String?
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
        supplierLocalID: String? = nil,
        supplierName: String? = nil,
        supplierRemoteID: UUID? = nil,
        hasCategoryReference: Bool = false,
        categoryLocalID: String? = nil,
        categoryName: String? = nil,
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
        self.supplierLocalID = supplierLocalID
        self.supplierName = supplierName
        self.supplierRemoteID = supplierRemoteID
        self.hasCategoryReference = hasCategoryReference
        self.categoryLocalID = categoryLocalID
        self.categoryName = categoryName
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
    let baselineRunID: UUID?
    let pullState: ManualPushPullState
    let accountState: ManualPushAccountState
    let baseline: ManualPushBaseline?
    let suppliers: [ManualPushLookupState]
    let categories: [ManualPushLookupState]
    let products: [ManualPushProductState]
    let simulatedChangedCount: Int?

    init(
        generatedAt: Date = Date(),
        baselineRunID: UUID? = nil,
        pullState: ManualPushPullState,
        accountState: ManualPushAccountState,
        baseline: ManualPushBaseline?,
        suppliers: [ManualPushLookupState] = [],
        categories: [ManualPushLookupState] = [],
        products: [ManualPushProductState],
        simulatedChangedCount: Int? = nil
    ) {
        self.generatedAt = generatedAt
        self.baselineRunID = baselineRunID
        self.pullState = pullState
        self.accountState = accountState
        self.baseline = baseline
        self.suppliers = suppliers
        self.categories = categories
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
        if let baseline, !baseline.isValid {
            blockedReasons.append(blockedReason(for: baseline))
        } else if baseline == nil {
            blockedReasons.append(.blockedMissingBaseline)
        }

        let hasGlobalBlocker = !blockedReasons.isEmpty

        for supplier in input.suppliers.sorted(by: { $0.localID < $1.localID }) {
            guard !hasGlobalBlocker else { continue }
            guard let baseline else {
                blockedReasons.append(.blockedMissingBaseline)
                continue
            }
            classifyLookup(
                supplier,
                baseline: baseline,
                candidates: &candidates,
                blockedReasons: &blockedReasons,
                warnings: &warnings
            )
        }

        for category in input.categories.sorted(by: { $0.localID < $1.localID }) {
            guard !hasGlobalBlocker else { continue }
            guard let baseline else {
                blockedReasons.append(.blockedMissingBaseline)
                continue
            }
            classifyLookup(
                category,
                baseline: baseline,
                candidates: &candidates,
                blockedReasons: &blockedReasons,
                warnings: &warnings
            )
        }

        let plannedSupplierLocalIDs = plannedLookupLocalIDs(entityKind: .supplier, candidates: candidates)
        let plannedCategoryLocalIDs = plannedLookupLocalIDs(entityKind: .productCategory, candidates: candidates)
        let plannedSupplierNames = plannedLookupNames(states: input.suppliers, localIDs: plannedSupplierLocalIDs)
        let plannedCategoryNames = plannedLookupNames(states: input.categories, localIDs: plannedCategoryLocalIDs)

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

            if productHasUnresolvedLookupReference(
                product,
                plannedSupplierLocalIDs: plannedSupplierLocalIDs,
                plannedSupplierNames: plannedSupplierNames,
                plannedCategoryLocalIDs: plannedCategoryLocalIDs,
                plannedCategoryNames: plannedCategoryNames
            ) {
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
            baselineRunID: input.baselineRunID,
            ownerUserID: input.accountState.currentUserID,
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
            guard product.remoteUpdatedAt != nil else {
                blockedReasons.append(.blockedMissingBaseline)
                return
            }
            candidates.append(
                PushCandidate(
                    entityKind: .product,
                    localID: product.localID,
                    remoteID: remoteID,
                    action: .dryRunLinkCandidate,
                    fingerprint: product.catalogFingerprint
                )
            )
            appendUnique(.warningStaleRemote, to: &warnings)
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
           baseline.remoteProductAmbiguousBarcodes.contains(barcode) {
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        if let barcode = ManualPushFingerprintNormalizer.semanticString(product.barcode),
           let remoteID = baseline.remoteProductIDsByBarcode[barcode] {
            candidates.append(
                PushCandidate(
                    entityKind: .product,
                    localID: product.localID,
                    remoteID: remoteID,
                    action: .dryRunLinkCandidate,
                    fingerprint: product.catalogFingerprint
                )
            )
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

    private func classifyLookup(
        _ lookup: ManualPushLookupState,
        baseline: ManualPushBaseline,
        candidates: inout [PushCandidate],
        blockedReasons: inout [PushBlockedReason],
        warnings: inout [PushWarning]
    ) {
        if lookup.remoteDeletedAt != nil || hasRemoteTombstone(lookup: lookup, baseline: baseline) {
            blockedReasons.append(.blockedTombstoneConflict)
            return
        }

        if let remoteID = lookup.remoteID {
            classifyLinkedLookup(
                lookup,
                remoteID: remoteID,
                baseline: baseline,
                candidates: &candidates,
                blockedReasons: &blockedReasons,
                warnings: &warnings
            )
        } else {
            classifyLocalOnlyLookup(
                lookup,
                baseline: baseline,
                candidates: &candidates,
                blockedReasons: &blockedReasons
            )
        }
    }

    private func classifyLinkedLookup(
        _ lookup: ManualPushLookupState,
        remoteID: UUID,
        baseline: ManualPushBaseline,
        candidates: inout [PushCandidate],
        blockedReasons: inout [PushBlockedReason],
        warnings: inout [PushWarning]
    ) {
        let updatedAtByID: [UUID: Date]
        let fingerprintByID: [UUID: ManualPushFingerprint]
        switch lookup.entityKind {
        case .supplier:
            updatedAtByID = baseline.remoteUpdatedAtBySupplierID
            fingerprintByID = baseline.supplierFingerprintsByRemoteID
        case .productCategory:
            updatedAtByID = baseline.remoteUpdatedAtByCategoryID
            fingerprintByID = baseline.categoryFingerprintsByRemoteID
        case .product, .productPrice:
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        if let baselineRemoteUpdatedAt = updatedAtByID[remoteID],
           let localRemoteUpdatedAt = lookup.remoteUpdatedAt,
           baselineRemoteUpdatedAt > localRemoteUpdatedAt {
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        if lookup.remoteUpdatedAt == nil, updatedAtByID[remoteID] != nil {
            appendUnique(.warningStaleRemote, to: &warnings)
        }

        guard let baselineFingerprint = fingerprintByID[remoteID] else {
            guard lookup.remoteUpdatedAt != nil else {
                blockedReasons.append(.blockedMissingBaseline)
                return
            }
            candidates.append(
                PushCandidate(
                    entityKind: lookup.entityKind,
                    localID: lookup.localID,
                    remoteID: remoteID,
                    action: .dryRunLinkCandidate,
                    fingerprint: lookup.catalogFingerprint
                )
            )
            appendUnique(.warningStaleRemote, to: &warnings)
            return
        }

        let localFingerprint = lookup.catalogFingerprint
        let action: PushCandidateAction = localFingerprint == baselineFingerprint
            ? .noOpAlreadySynced
            : .dryRunUpdateCandidate
        candidates.append(
            PushCandidate(
                entityKind: lookup.entityKind,
                localID: lookup.localID,
                remoteID: remoteID,
                action: action,
                fingerprint: localFingerprint
            )
        )
    }

    private func classifyLocalOnlyLookup(
        _ lookup: ManualPushLookupState,
        baseline: ManualPushBaseline,
        candidates: inout [PushCandidate],
        blockedReasons: inout [PushBlockedReason]
    ) {
        guard let normalizedName = SupabasePullPreviewNormalizer.normalizedLookupName(lookup.name) else {
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        switch lookup.entityKind {
        case .supplier:
            if baseline.remoteSupplierAmbiguousNames.contains(normalizedName) {
                blockedReasons.append(.blockedRemoteConflict)
                return
            }
            if let remoteID = baseline.remoteSupplierIDsByName[normalizedName] {
                candidates.append(
                    PushCandidate(
                        entityKind: .supplier,
                        localID: lookup.localID,
                        remoteID: remoteID,
                        action: .dryRunLinkCandidate,
                        fingerprint: lookup.catalogFingerprint
                    )
                )
                return
            }
        case .productCategory:
            if baseline.remoteCategoryAmbiguousNames.contains(normalizedName) {
                blockedReasons.append(.blockedRemoteConflict)
                return
            }
            if let remoteID = baseline.remoteCategoryIDsByName[normalizedName] {
                candidates.append(
                    PushCandidate(
                        entityKind: .productCategory,
                        localID: lookup.localID,
                        remoteID: remoteID,
                        action: .dryRunLinkCandidate,
                        fingerprint: lookup.catalogFingerprint
                    )
                )
                return
            }
        case .product, .productPrice:
            blockedReasons.append(.blockedRemoteConflict)
            return
        }

        candidates.append(
            PushCandidate(
                entityKind: lookup.entityKind,
                localID: lookup.localID,
                action: .dryRunCreateCandidate,
                fingerprint: lookup.catalogFingerprint
            )
        )
    }

    private func hasRemoteTombstone(
        lookup: ManualPushLookupState,
        baseline: ManualPushBaseline
    ) -> Bool {
        guard let remoteID = lookup.remoteID else { return false }
        switch lookup.entityKind {
        case .supplier:
            return baseline.remoteDeletedAtBySupplierID[remoteID] != nil
        case .productCategory:
            return baseline.remoteDeletedAtByCategoryID[remoteID] != nil
        case .product, .productPrice:
            return false
        }
    }

    private func productHasUnresolvedLookupReference(
        _ product: ManualPushProductState,
        plannedSupplierLocalIDs: Set<String>,
        plannedSupplierNames: Set<String>,
        plannedCategoryLocalIDs: Set<String>,
        plannedCategoryNames: Set<String>
    ) -> Bool {
        if product.hasSupplierReference,
           product.supplierRemoteID == nil,
           product.supplierLocalID.map({ plannedSupplierLocalIDs.contains($0) }) != true,
           product.supplierName.flatMap(SupabasePullPreviewNormalizer.normalizedLookupName).map({ plannedSupplierNames.contains($0) }) != true {
            return true
        }
        if product.hasCategoryReference,
           product.categoryRemoteID == nil,
           product.categoryLocalID.map({ plannedCategoryLocalIDs.contains($0) }) != true,
           product.categoryName.flatMap(SupabasePullPreviewNormalizer.normalizedLookupName).map({ plannedCategoryNames.contains($0) }) != true {
            return true
        }
        return false
    }

    private func blockedReason(for baseline: ManualPushBaseline) -> PushBlockedReason {
        if baseline.invalidationReasons.contains(.fingerprintVersionChanged)
            || baseline.invalidationReasons.contains(.partialPull)
            || baseline.invalidationReasons.contains(.sourceErrors) {
            return .blockedStaleOrPartialBaseline
        }
        return .blockedMissingBaseline
    }

    private func appendUnique(_ warning: PushWarning, to warnings: inout [PushWarning]) {
        guard !warnings.contains(warning) else {
            return
        }
        warnings.append(warning)
    }

    private func plannedLookupLocalIDs(
        entityKind: PushEntityKind,
        candidates: [PushCandidate]
    ) -> Set<String> {
        Set(candidates.compactMap { candidate in
            guard candidate.entityKind == entityKind,
                  candidate.action == .dryRunCreateCandidate || candidate.action == .dryRunLinkCandidate else {
                return nil
            }
            return candidate.localID
        })
    }

    private func plannedLookupNames(
        states: [ManualPushLookupState],
        localIDs: Set<String>
    ) -> Set<String> {
        Set(states.compactMap { state in
            guard localIDs.contains(state.localID) else { return nil }
            return SupabasePullPreviewNormalizer.normalizedLookupName(state.name)
        })
    }
}
