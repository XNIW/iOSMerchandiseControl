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
    case noOpAlreadySynced
    case blockedNoRemoteID
    case blockedAccountMismatch
    case blockedPartialPull
    case blockedMissingBaseline
    case blockedRemoteConflict
    case blockedTombstoneConflict
    case blockedMissingSupplierCategoryRemoteID
    case warningLocalOnlySupplierCategory
    case warningStaleRemote
    case futurePricePushCandidate

    var severity: PushSeverity {
        switch self {
        case .blockedNoRemoteID,
             .blockedAccountMismatch,
             .blockedPartialPull,
             .blockedMissingBaseline,
             .blockedRemoteConflict,
             .blockedTombstoneConflict,
             .blockedMissingSupplierCategoryRemoteID:
            return .blocker
        case .warningLocalOnlySupplierCategory,
             .warningStaleRemote:
            return .warning
        case .noOpAlreadySynced:
            return .info
        case .futurePricePushCandidate:
            return .futureOnly
        case .dryRunCreateCandidate,
             .dryRunUpdateCandidate:
            return .info
        }
    }
}

nonisolated enum PushCandidateAction: String, Sendable, Equatable, CaseIterable {
    case dryRunCreateCandidate
    case dryRunUpdateCandidate
    case noOpAlreadySynced
    case futurePricePushCandidate

    var category: ManualPushPreflightCategory {
        switch self {
        case .dryRunCreateCandidate:
            return .dryRunCreateCandidate
        case .dryRunUpdateCandidate:
            return .dryRunUpdateCandidate
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
    case blockedRemoteConflict
    case blockedTombstoneConflict
    case blockedMissingSupplierCategoryRemoteID

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
        case .blockedRemoteConflict:
            return .blockedRemoteConflict
        case .blockedTombstoneConflict:
            return .blockedTombstoneConflict
        case .blockedMissingSupplierCategoryRemoteID:
            return .blockedMissingSupplierCategoryRemoteID
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
    static let version = 1

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
        fingerprint(
            entityKind: .product,
            fields: [
                ManualPushFingerprintField("barcode", .string(barcode)),
                ManualPushFingerprintField("itemNumber", .string(itemNumber)),
                ManualPushFingerprintField("productName", .string(productName)),
                ManualPushFingerprintField("secondProductName", .string(secondProductName)),
                ManualPushFingerprintField("purchasePrice", .number(purchasePrice)),
                ManualPushFingerprintField("retailPrice", .number(retailPrice)),
                ManualPushFingerprintField("stockQuantity", .number(stockQuantity)),
                ManualPushFingerprintField("supplierRemoteID", .uuid(supplierRemoteID)),
                ManualPushFingerprintField("categoryRemoteID", .uuid(categoryRemoteID))
            ]
        )
    }

    static func supplier(name: String?) -> ManualPushFingerprint {
        fingerprint(
            entityKind: .supplier,
            fields: [
                ManualPushFingerprintField("name", .string(name))
            ]
        )
    }

    static func category(name: String?) -> ManualPushFingerprint {
        fingerprint(
            entityKind: .productCategory,
            fields: [
                ManualPushFingerprintField("name", .string(name))
            ]
        )
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
            guard number.isFinite else { return "number:invalid" }
            return "number:\(normalizedNumber(number))"
        case .uuid(let uuid):
            guard let uuid else { return "uuid:nil" }
            return "uuid:\(uuid.uuidString.lowercased())"
        }
    }

    private static func normalizedNumber(_ value: Double) -> String {
        let scaled = (abs(value) < 0.0000005 ? 0 : value)
        let rounded = (scaled * 1_000_000).rounded() / 1_000_000
        var text = String(format: "%.6f", locale: Locale(identifier: "en_US_POSIX"), rounded)
        while text.last == "0" {
            text.removeLast()
        }
        if text.last == "." {
            text.removeLast()
        }
        return text.isEmpty ? "0" : text
    }

    private static func escaped(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "|", with: "\\|")
            .replacingOccurrences(of: "=", with: "\\=")
            .replacingOccurrences(of: "\n", with: "\\n")
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
    static let futureEventSplitThreshold = 1_000

    let generatedAt: Date
    let candidates: [PushCandidate]
    let blockedReasons: [PushBlockedReason]
    let warnings: [PushWarning]
    let futureEventChangedCount: Int

    var isDryRun: Bool { true }
    var isSendable: Bool { false }

    var hasBlockers: Bool {
        !blockedReasons.isEmpty
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
