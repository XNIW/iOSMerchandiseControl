import Foundation
import SwiftData

/// TASK-114: confronto conteggi locali vs remoti (stessa definizione di Supabase/Android Options).
nonisolated struct SyncInventoryCountSnapshot: Equatable, Sendable {
    var products: Int
    var suppliers: Int
    var categories: Int
    var productPrices: Int
    var historySessions: Int

    static let zero = SyncInventoryCountSnapshot(
        products: 0,
        suppliers: 0,
        categories: 0,
        productPrices: 0,
        historySessions: 0
    )
}

nonisolated enum SyncCountDriftKind: String, Sendable {
    case products
    case suppliers
    case categories
    case productPrices
    case historySessions
}

nonisolated struct SyncCountDriftReport: Equatable, Sendable {
    var local: SyncInventoryCountSnapshot
    var remote: SyncInventoryCountSnapshot
    var mismatches: [SyncCountDriftKind]

    var isAligned: Bool { mismatches.isEmpty }

    static func compare(local: SyncInventoryCountSnapshot, remote: SyncInventoryCountSnapshot) -> SyncCountDriftReport {
        var mismatches: [SyncCountDriftKind] = []
        if local.products != remote.products { mismatches.append(.products) }
        if local.suppliers != remote.suppliers { mismatches.append(.suppliers) }
        if local.categories != remote.categories { mismatches.append(.categories) }
        if local.productPrices != remote.productPrices { mismatches.append(.productPrices) }
        if local.historySessions != remote.historySessions { mismatches.append(.historySessions) }
        return SyncCountDriftReport(local: local, remote: remote, mismatches: mismatches)
    }
}

nonisolated enum LocalHistorySessionCounting {
    /// Allineato ad Android `USER_VISIBLE_HISTORY_WHERE_CLAUSE`.
    static func isUserVisibleSession(id: String, remoteDeletedAt: Date?) -> Bool {
        isUserVisibleSession(id: id, title: "", remoteDeletedAt: remoteDeletedAt)
    }

    static func isUserVisibleSession(id: String, title: String, remoteDeletedAt: Date?) -> Bool {
        guard HistorySessionDisplayFormatter.isUserFacingIdentifier(id),
              HistorySessionDisplayFormatter.isUserFacingIdentifier(title) else {
            return false
        }
        return remoteDeletedAt == nil
    }

    static func countUserVisible(in entries: [HistoryEntry]) -> Int {
        entries.filter {
            isUserVisibleSession(id: $0.id, title: $0.title, remoteDeletedAt: $0.remoteDeletedAt)
        }.count
    }

    static func fetchUserVisibleCount(context: ModelContext) throws -> Int {
        let entries = try context.fetch(FetchDescriptor<HistoryEntry>())
        return countUserVisible(in: entries)
    }
}

nonisolated enum HistorySessionDisplayFormatter {
    private static let spreadsheetExtensions = [".xlsx", ".xlsm", ".xls"]

    static func isRawUUID(_ value: String) -> Bool {
        UUID(uuidString: value.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
    }

    static func isUserFacingIdentifier(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return true
        }
        let uppercased = trimmed.uppercased()
        if uppercased.hasPrefix("APPLY_IMPORT_") || uppercased.hasPrefix("FULL_IMPORT_") {
            return false
        }
        if uppercased.hasPrefix("TASK") {
            return false
        }
        return true
    }

    static func displayTitle(
        id: String,
        title: String,
        supplier: String,
        isManualEntry: Bool,
        timestamp: Date,
        locale: Locale
    ) -> String {
        if let semanticTitle = semanticUserFacingTitle(title) {
            return semanticTitle
        }
        if isManualEntry {
            return "Manual - \(contextTimestamp(timestamp, locale: locale))"
        }
        if let supplierTitle = semanticUserFacingTitle(supplier) {
            return "\(supplierTitle) - \(contextTimestamp(timestamp, locale: locale))"
        }
        if let semanticID = semanticUserFacingTitle(cleanedHistoryIdentifier(id)) {
            return semanticID
        }
        return "History - \(contextTimestamp(timestamp, locale: locale))"
    }

    static func shouldShowSecondaryIdentifier(id: String, displayTitle: String) -> Bool {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = displayTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedID.isEmpty,
              !trimmedTitle.isEmpty,
              trimmedID != trimmedTitle,
              !isRawUUID(trimmedID),
              isUserFacingIdentifier(trimmedID),
              isUserFacingIdentifier(trimmedTitle) else {
            return false
        }

        return !normalizeForComparison(trimmedID).contains(normalizeForComparison(trimmedTitle))
    }

    private static func semanticUserFacingTitle(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !isRawUUID(trimmed),
              isUserFacingIdentifier(trimmed) else {
            return nil
        }
        return trimmed
    }

    private static func contextTimestamp(_ timestamp: Date, locale: Locale) -> String {
        timestamp.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
    }

    private static func cleanedHistoryIdentifier(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        for suffix in spreadsheetExtensions where result.lowercased().hasSuffix(suffix) {
            result.removeLast(suffix.count)
            break
        }

        let technicalPrefixes = [
            #"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}-\d{3}_"#,
            #"^\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}_"#,
            #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}_"#,
            #"^\d{4}-\d{2}-\d{2}_\d{2}:\d{2}:\d{2}_"#
        ]
        for pattern in technicalPrefixes {
            if let range = result.range(of: pattern, options: .regularExpression),
               range.lowerBound == result.startIndex {
                result.removeSubrange(range)
                break
            }
        }

        if let separatorIndex = result.firstIndex(of: "_") {
            let firstSegment = String(result[..<separatorIndex])
            if looksLikeTechnicalToken(firstSegment) {
                result = String(result[result.index(after: separatorIndex)...])
            }
        }

        return result.replacingOccurrences(of: "_+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func looksLikeTechnicalToken(_ value: String) -> Bool {
        guard value.count >= 10 else {
            return false
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return false
        }
        let hasLetter = value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
        let hasDigit = value.unicodeScalars.contains { CharacterSet.decimalDigits.contains($0) }
        let numericOrDash = value.unicodeScalars.allSatisfy {
            CharacterSet.decimalDigits.union(CharacterSet(charactersIn: "-")).contains($0)
        }
        return hasDigit && (hasLetter || (numericOrDash && value.count >= 12))
    }

    private static func normalizeForComparison(_ value: String) -> String {
        cleanedHistoryIdentifier(value)
            .lowercased()
            .replacingOccurrences(of: #"[_\-\s]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension LocalDatabasePublicSummary {
    nonisolated static func makeReconciliationAware(context: ModelContext) throws -> SyncInventoryCountSnapshot {
        SyncInventoryCountSnapshot(
            products: try context.fetchCount(FetchDescriptor<Product>(
                predicate: #Predicate<Product> { $0.remoteDeletedAt == nil }
            )),
            suppliers: try context.fetchCount(FetchDescriptor<Supplier>(
                predicate: #Predicate<Supplier> { $0.remoteDeletedAt == nil }
            )),
            categories: try context.fetchCount(FetchDescriptor<ProductCategory>(
                predicate: #Predicate<ProductCategory> { $0.remoteDeletedAt == nil }
            )),
            productPrices: try context.fetchCount(FetchDescriptor<ProductPrice>(
                predicate: #Predicate<ProductPrice> { price in
                    price.product != nil && price.product?.remoteDeletedAt == nil
                }
            )),
            historySessions: try context.fetchCount(FetchDescriptor<HistoryEntry>(
                predicate: #Predicate<HistoryEntry> { $0.remoteDeletedAt == nil }
            ))
        )
    }
}
