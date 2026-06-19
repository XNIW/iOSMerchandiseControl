import Foundation

nonisolated enum PushSeverity: String, Sendable, Equatable, CaseIterable {
    case blocker
    case warning
    case info
    case futureOnly
}

nonisolated enum PushEntityKind: String, Sendable, Equatable, CaseIterable {
    case product
    case supplier
    case productCategory
    case productPrice
}

nonisolated enum ManualPushPreflightCategory: String, Sendable, Equatable, Hashable, CaseIterable {
    case dryRunCreateCandidate
    case dryRunUpdateCandidate
    case dryRunLinkCandidate
    case dryRunTombstoneCandidate
    case noOpAlreadySynced
    case blockedNoRemoteID
    case blockedAccountMismatch
    case blockedPartialPull
    case blockedMissingBaseline
    case blockedStaleOrPartialBaseline
    case blockedRemoteConflict
    case blockedTombstoneConflict
    case blockedMissingSupplierCategoryRemoteID
    case blockedOutsideScope
    case blockedScopedDependency
    case warningLocalOnlySupplierCategory
    case warningStaleRemote
    case futurePricePushCandidate

    var severity: PushSeverity {
        switch self {
        case .blockedNoRemoteID,
             .blockedAccountMismatch,
             .blockedPartialPull,
             .blockedMissingBaseline,
             .blockedStaleOrPartialBaseline,
             .blockedRemoteConflict,
             .blockedTombstoneConflict,
             .blockedMissingSupplierCategoryRemoteID,
             .blockedOutsideScope,
             .blockedScopedDependency:
            return .blocker
        case .warningLocalOnlySupplierCategory,
             .warningStaleRemote:
            return .warning
        case .noOpAlreadySynced:
            return .info
        case .futurePricePushCandidate:
            return .futureOnly
        case .dryRunCreateCandidate,
             .dryRunUpdateCandidate,
             .dryRunLinkCandidate,
             .dryRunTombstoneCandidate:
            return .info
        }
    }
}

nonisolated enum PushCandidateAction: String, Sendable, Equatable, CaseIterable {
    case dryRunCreateCandidate
    case dryRunUpdateCandidate
    case dryRunLinkCandidate
    case dryRunTombstoneCandidate
    case noOpAlreadySynced
    case futurePricePushCandidate

    var category: ManualPushPreflightCategory {
        switch self {
        case .dryRunCreateCandidate:
            return .dryRunCreateCandidate
        case .dryRunUpdateCandidate:
            return .dryRunUpdateCandidate
        case .dryRunLinkCandidate:
            return .dryRunLinkCandidate
        case .dryRunTombstoneCandidate:
            return .dryRunTombstoneCandidate
        case .noOpAlreadySynced:
            return .noOpAlreadySynced
        case .futurePricePushCandidate:
            return .futurePricePushCandidate
        }
    }

    var severity: PushSeverity {
        category.severity
    }
}

nonisolated enum PushBlockedReason: String, Sendable, Equatable, CaseIterable {
    case blockedNoRemoteID
    case blockedAccountMismatch
    case blockedPartialPull
    case blockedMissingBaseline
    case blockedStaleOrPartialBaseline
    case blockedRemoteConflict
    case blockedTombstoneConflict
    case blockedMissingSupplierCategoryRemoteID
    case blockedOutsideScope
    case blockedScopedDependency

    var category: ManualPushPreflightCategory {
        switch self {
        case .blockedNoRemoteID:
            return .blockedNoRemoteID
        case .blockedAccountMismatch:
            return .blockedAccountMismatch
        case .blockedPartialPull:
            return .blockedPartialPull
        case .blockedMissingBaseline:
            return .blockedMissingBaseline
        case .blockedStaleOrPartialBaseline:
            return .blockedStaleOrPartialBaseline
        case .blockedRemoteConflict:
            return .blockedRemoteConflict
        case .blockedTombstoneConflict:
            return .blockedTombstoneConflict
        case .blockedMissingSupplierCategoryRemoteID:
            return .blockedMissingSupplierCategoryRemoteID
        case .blockedOutsideScope:
            return .blockedOutsideScope
        case .blockedScopedDependency:
            return .blockedScopedDependency
        }
    }

    var severity: PushSeverity {
        .blocker
    }
}

nonisolated enum PushWarning: String, Sendable, Equatable, CaseIterable {
    case warningLocalOnlySupplierCategory
    case warningStaleRemote
    case futureEventSplitRequired

    var category: ManualPushPreflightCategory? {
        switch self {
        case .warningLocalOnlySupplierCategory:
            return .warningLocalOnlySupplierCategory
        case .warningStaleRemote:
            return .warningStaleRemote
        case .futureEventSplitRequired:
            return nil
        }
    }

    var severity: PushSeverity {
        switch self {
        case .futureEventSplitRequired:
            return .futureOnly
        case .warningLocalOnlySupplierCategory,
             .warningStaleRemote:
            return .warning
        }
    }
}

nonisolated struct ManualPushFingerprint: Sendable, Equatable, Hashable {
    let entityKind: PushEntityKind
    let version: Int
    let canonicalString: String
}

nonisolated struct ManualPushFingerprintField: Sendable, Equatable {
    let name: String
    let value: ManualPushFingerprintValue

    init(_ name: String, _ value: ManualPushFingerprintValue) {
        self.name = name
        self.value = value
    }
}

nonisolated enum ManualPushFingerprintValue: Sendable, Equatable {
    case string(String?)
    case number(Double?)
    case uuid(UUID?)
}

nonisolated enum ManualPushFingerprintNormalizer {
    static let version = SupabaseCatalogFingerprintSchema.currentVersion

    static func product(
        barcode: String?,
        itemNumber: String?,
        productName: String?,
        secondProductName: String?,
        purchasePrice: Double?,
        retailPrice: Double?,
        stockQuantity: Double?,
        supplierRemoteID: UUID?,
        categoryRemoteID: UUID?
    ) -> ManualPushFingerprint {
        SupabaseCatalogFingerprintNormalizer.product(
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

    static func supplier(name: String?) -> ManualPushFingerprint {
        supplier(remoteID: nil, name: name)
    }

    static func supplier(remoteID: UUID?, name: String?) -> ManualPushFingerprint {
        SupabaseCatalogFingerprintNormalizer.supplier(remoteID: remoteID, name: name)
    }

    static func category(name: String?) -> ManualPushFingerprint {
        category(remoteID: nil, name: name)
    }

    static func category(remoteID: UUID?, name: String?) -> ManualPushFingerprint {
        SupabaseCatalogFingerprintNormalizer.category(remoteID: remoteID, name: name)
    }

    static func fingerprint(
        entityKind: PushEntityKind,
        fields: [ManualPushFingerprintField]
    ) -> ManualPushFingerprint {
        let body = fields
            .map { "\($0.name)=\(normalizedValue($0.value))" }
            .joined(separator: "|")
        return ManualPushFingerprint(
            entityKind: entityKind,
            version: version,
            canonicalString: "v\(version)|\(entityKind.rawValue)|\(body)"
        )
    }

    static func semanticString(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func normalizedValue(_ value: ManualPushFingerprintValue) -> String {
        switch value {
        case .string(let string):
            guard let string else { return "string:nil" }
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return "string:empty" }
            return "string:\(escaped(trimmed))"
        case .number(let number):
            guard let number else { return "number:nil" }
            guard let normalized = SupabaseCatalogFingerprintNormalizer.canonicalNumberString(number) else {
                return "number:nil"
            }
            return "number:\(normalized)"
        case .uuid(let uuid):
            guard let uuid else { return "uuid:nil" }
            return "uuid:\(uuid.uuidString.lowercased())"
        }
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "=", with: "\\=")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

nonisolated enum ManualPushPreflightScope: String, Sendable, Equatable, Hashable, CaseIterable {
    case global
    case scopedTask045

    var isScopedTask045: Bool {
        self == .scopedTask045
    }
}

nonisolated struct ManualPushScopeSummary: Sendable, Equatable {
    let mode: ManualPushPreflightScope
    let included: Int
    let excludedOutsideScope: Int
    let blockedDependencies: Int

    init(
        mode: ManualPushPreflightScope = .global,
        included: Int = 0,
        excludedOutsideScope: Int = 0,
        blockedDependencies: Int = 0
    ) {
        self.mode = mode
        self.included = included
        self.excludedOutsideScope = excludedOutsideScope
        self.blockedDependencies = blockedDependencies
    }

    var hasScopedBlocker: Bool {
        mode.isScopedTask045 && blockedDependencies > 0
    }
}

nonisolated enum ManualPushTask045Scope {
    static let rawPrefix = "TASK045_"

    private static var lookupPrefix: String {
        SupabasePullPreviewNormalizer.normalizedLookupName(rawPrefix) ?? rawPrefix.lowercased()
    }

    static func contains(_ lookup: ManualPushLookupState) -> Bool {
        switch lookup.entityKind {
        case .supplier:
            return containsSupplierName(lookup.name)
        case .productCategory:
            return containsCategoryName(lookup.name)
        case .product, .productPrice:
            return false
        }
    }

    static func containsSupplierName(_ name: String?) -> Bool {
        SupabasePullPreviewNormalizer.normalizedLookupName(name)?.hasPrefix(lookupPrefix) == true
    }

    static func containsCategoryName(_ name: String?) -> Bool {
        SupabasePullPreviewNormalizer.normalizedLookupName(name)?.hasPrefix(lookupPrefix) == true
    }

    static func contains(_ product: ManualPushProductState) -> Bool {
        if let barcode = ManualPushFingerprintNormalizer.semanticString(product.barcode) {
            return barcode.hasPrefix(rawPrefix)
        }
        return ManualPushFingerprintNormalizer.semanticString(product.productName)?.hasPrefix(rawPrefix) == true
    }

    static func contains(_ supplier: Supplier) -> Bool {
        containsSupplierName(supplier.name)
    }

    static func contains(_ category: ProductCategory) -> Bool {
        containsCategoryName(category.name)
    }

    static func contains(_ product: Product) -> Bool {
        if let barcode = ManualPushFingerprintNormalizer.semanticString(product.barcode) {
            return barcode.hasPrefix(rawPrefix)
        }
        return ManualPushFingerprintNormalizer.semanticString(product.productName)?.hasPrefix(rawPrefix) == true
    }
}

nonisolated struct PushCandidate: Identifiable, Sendable, Equatable {
    let id: String
    let entityKind: PushEntityKind
    let localID: String
    let remoteID: UUID?
    let action: PushCandidateAction
    let fingerprint: ManualPushFingerprint?
    let detail: String?

    init(
        entityKind: PushEntityKind,
        localID: String,
        remoteID: UUID? = nil,
        action: PushCandidateAction,
        fingerprint: ManualPushFingerprint? = nil,
        detail: String? = nil
    ) {
        self.entityKind = entityKind
        self.localID = localID
        self.remoteID = remoteID
        self.action = action
        self.fingerprint = fingerprint
        self.detail = detail
        self.id = "\(entityKind.rawValue):\(localID):\(action.rawValue)"
    }

    var category: ManualPushPreflightCategory {
        action.category
    }

    var severity: PushSeverity {
        action.severity
    }
}

nonisolated struct ManualPushPlan: Sendable, Equatable {
    static let futureEventSplitThreshold = 100_000

    let generatedAt: Date
    let baselineRunID: UUID?
    let ownerUserID: UUID?
    let fingerprintSchemaVersion: Int
    let scope: ManualPushPreflightScope
    let scopeSummary: ManualPushScopeSummary
    let candidates: [PushCandidate]
    let blockedReasons: [PushBlockedReason]
    let warnings: [PushWarning]
    let futureEventChangedCount: Int

    init(
        generatedAt: Date,
        baselineRunID: UUID? = nil,
        ownerUserID: UUID? = nil,
        fingerprintSchemaVersion: Int = SupabaseCatalogFingerprintSchema.currentVersion,
        scope: ManualPushPreflightScope = .global,
        scopeSummary: ManualPushScopeSummary = ManualPushScopeSummary(),
        candidates: [PushCandidate],
        blockedReasons: [PushBlockedReason],
        warnings: [PushWarning],
        futureEventChangedCount: Int
    ) {
        self.generatedAt = generatedAt
        self.baselineRunID = baselineRunID
        self.ownerUserID = ownerUserID
        self.fingerprintSchemaVersion = fingerprintSchemaVersion
        self.scope = scope
        self.scopeSummary = scopeSummary
        self.candidates = candidates
        self.blockedReasons = blockedReasons
        self.warnings = warnings
        self.futureEventChangedCount = futureEventChangedCount
    }

    var isDryRun: Bool { true }
    var isSendable: Bool { !hasBlockers && hasWriteOrLinkCandidates }

    var hasBlockers: Bool {
        !blockedReasons.isEmpty
    }

    var hasWriteOrLinkCandidates: Bool {
        candidates.contains {
            $0.action == .dryRunCreateCandidate
                || $0.action == .dryRunUpdateCandidate
                || $0.action == .dryRunLinkCandidate
                || $0.action == .dryRunTombstoneCandidate
        }
    }

    var writeCandidates: [PushCandidate] {
        candidates.filter {
            $0.action == .dryRunCreateCandidate
                || $0.action == .dryRunUpdateCandidate
                || $0.action == .dryRunLinkCandidate
                || $0.action == .dryRunTombstoneCandidate
        }
    }

    var planFingerprint: String {
        let candidateBody = candidates
            .map {
                [
                    $0.entityKind.rawValue,
                    $0.localID,
                    $0.remoteID?.uuidString.lowercased() ?? "nil",
                    $0.action.rawValue,
                    $0.fingerprint?.canonicalString ?? "nil"
                ].joined(separator: ":")
            }
            .sorted()
            .joined(separator: "|")
        let blockedBody = blockedReasons.map(\.rawValue).sorted().joined(separator: "|")
        let warningBody = warnings.map(\.rawValue).sorted().joined(separator: "|")
        return [
            "schema=\(fingerprintSchemaVersion)",
            "scope=\(scope.rawValue)",
            "owner=\(ownerUserID?.uuidString.lowercased() ?? "nil")",
            "baseline=\(baselineRunID?.uuidString.lowercased() ?? "nil")",
            "candidates=\(candidateBody)",
            "blocked=\(blockedBody)",
            "warnings=\(warningBody)",
            "future=\(futureEventChangedCount)"
        ].joined(separator: "||")
    }

    func count(entityKind: PushEntityKind, action: PushCandidateAction) -> Int {
        candidates.filter { $0.entityKind == entityKind && $0.action == action }.count
    }

    func changedCount(entityKind: PushEntityKind) -> Int {
        candidates.filter {
            $0.entityKind == entityKind
                && ($0.action == .dryRunCreateCandidate
                    || $0.action == .dryRunUpdateCandidate
                    || $0.action == .dryRunLinkCandidate
                    || $0.action == .dryRunTombstoneCandidate)
        }.count
    }

    var categoryCounts: [ManualPushPreflightCategory: Int] {
        var counts: [ManualPushPreflightCategory: Int] = [:]
        for candidate in candidates {
            counts[candidate.category, default: 0] += 1
        }
        for reason in blockedReasons {
            counts[reason.category, default: 0] += 1
        }
        for warning in warnings {
            guard let category = warning.category else { continue }
            counts[category, default: 0] += 1
        }
        if scope.isScopedTask045 && scopeSummary.blockedDependencies > 0 {
            counts[.blockedScopedDependency] = max(
                counts[.blockedScopedDependency, default: 0],
                scopeSummary.blockedDependencies
            )
        }
        return counts
    }
}

nonisolated struct ManualPushPreview: Sendable, Equatable {
    let generatedAt: Date
    let plan: ManualPushPlan

    var categoryCounts: [ManualPushPreflightCategory: Int] {
        plan.categoryCounts
    }

    var isDryRun: Bool {
        plan.isDryRun
    }

    var isSendable: Bool {
        plan.isSendable
    }
}
