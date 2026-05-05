import Foundation
import SwiftData

nonisolated enum SupabaseCatalogBaselineReadResult: Sendable, Equatable {
    case available(SupabaseCatalogManualPushBaseline)
    case missing
    case accountMismatch
    case staleSchema
    case incomplete
}

nonisolated struct SupabaseCatalogManualPushBaseline: Sendable, Equatable {
    let runID: UUID
    let ownerUserUUID: UUID
    let appliedAt: Date?
    let baseline: ManualPushBaseline
}

nonisolated enum SupabaseCatalogBaselineDebugStatus: String, Sendable, Equatable {
    case absent
    case valid
    case stale
    case accountMismatch
    case incomplete
}

nonisolated struct SupabaseCatalogBaselineDebugSummary: Sendable, Equatable {
    let status: SupabaseCatalogBaselineDebugStatus
    let appliedAt: Date?
    let ownerUserUUID: UUID?
    let accountAbbreviation: String?
    let fingerprintSchemaVersion: Int?
    let productCount: Int?
    let supplierCount: Int?
    let categoryCount: Int?
    let tombstoneCount: Int?

    static let absent = SupabaseCatalogBaselineDebugSummary(
        status: .absent,
        appliedAt: nil,
        ownerUserUUID: nil,
        accountAbbreviation: nil,
        fingerprintSchemaVersion: nil,
        productCount: nil,
        supplierCount: nil,
        categoryCount: nil,
        tombstoneCount: nil
    )
}

struct SupabaseCatalogBaselineReader {
    nonisolated init() {}

    @MainActor
    func readManualPushBaseline(
        context: ModelContext,
        ownerUserUUID: UUID
    ) throws -> SupabaseCatalogBaselineReadResult {
        let runs = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>())
        guard let run = latestValidRun(from: runs, ownerUserUUID: ownerUserUUID) else {
            if hasStaleRun(in: runs, ownerUserUUID: ownerUserUUID) {
                return .staleSchema
            }
            if hasIncompleteRun(in: runs, ownerUserUUID: ownerUserUUID) {
                return .incomplete
            }
            if hasOtherAccountValidRun(in: runs, ownerUserUUID: ownerUserUUID) {
                return .accountMismatch
            }
            return .missing
        }

        let runID = run.baselineRunID
        let records = try context.fetch(
            FetchDescriptor<SupabaseCatalogBaselineRecord>(
                predicate: #Predicate { $0.baselineRunID == runID }
            )
        )

        return .available(
            SupabaseCatalogManualPushBaseline(
                runID: run.baselineRunID,
                ownerUserUUID: run.ownerUserUUID,
                appliedAt: run.appliedAt,
                baseline: makeManualPushBaseline(from: records)
            )
        )
    }

    @MainActor
    func debugSummary(
        context: ModelContext,
        currentUserUUID: UUID?
    ) throws -> SupabaseCatalogBaselineDebugSummary {
        let runs = try context.fetch(FetchDescriptor<SupabaseCatalogBaselineRun>())
        if let currentUserUUID,
           let run = latestValidRun(from: runs, ownerUserUUID: currentUserUUID) {
            return summary(status: .valid, run: run)
        }

        if let currentUserUUID,
           let staleRun = latestRun(
                from: runs.filter {
                    $0.ownerUserUUID == currentUserUUID
                        && isStaleRun($0)
                }
           ) {
            return summary(status: .stale, run: staleRun)
        }

        if let currentUserUUID,
           let incompleteRun = latestRun(
                from: runs.filter {
                    $0.ownerUserUUID == currentUserUUID
                        && $0.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue
                        && ($0.status == SupabaseCatalogBaselineStatus.building.rawValue
                            || $0.status == SupabaseCatalogBaselineStatus.partialRejected.rawValue)
                }
           ) {
            return summary(status: .incomplete, run: incompleteRun)
        }

        if let otherValid = latestRun(
            from: runs.filter {
                $0.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue
                    && $0.status == SupabaseCatalogBaselineStatus.valid.rawValue
                    && $0.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion
                    && (currentUserUUID == nil || $0.ownerUserUUID != currentUserUUID)
            }
        ) {
            return summary(status: .accountMismatch, run: otherValid)
        }

        return .absent
    }

    private func makeManualPushBaseline(from records: [SupabaseCatalogBaselineRecord]) -> ManualPushBaseline {
        var productFingerprintsByRemoteID: [UUID: ManualPushFingerprint] = [:]
        var remoteProductIDsByBarcode: [String: UUID] = [:]
        var remoteUpdatedAtByProductID: [UUID: Date] = [:]
        var remoteDeletedAtByProductID: [UUID: Date] = [:]

        for record in records where record.entityType == SupabaseCatalogBaselineEntityType.product.rawValue {
            productFingerprintsByRemoteID[record.remoteID] = ManualPushFingerprint(
                entityKind: .product,
                version: record.fingerprintSchemaVersion,
                canonicalString: record.fingerprintCanonical
            )
            if let barcode = record.barcodeCanonical {
                remoteProductIDsByBarcode[barcode] = record.remoteID
            }
            if let remoteUpdatedAt = record.remoteUpdatedAt {
                remoteUpdatedAtByProductID[record.remoteID] = remoteUpdatedAt
            }
            if let remoteDeletedAt = record.remoteDeletedAt {
                remoteDeletedAtByProductID[record.remoteID] = remoteDeletedAt
            }
        }

        return ManualPushBaseline(
            productFingerprintsByRemoteID: productFingerprintsByRemoteID,
            remoteProductIDsByBarcode: remoteProductIDsByBarcode,
            remoteUpdatedAtByProductID: remoteUpdatedAtByProductID,
            remoteDeletedAtByProductID: remoteDeletedAtByProductID
        )
    }

    private func latestValidRun(
        from runs: [SupabaseCatalogBaselineRun],
        ownerUserUUID: UUID
    ) -> SupabaseCatalogBaselineRun? {
        latestRun(
            from: runs.filter {
                $0.ownerUserUUID == ownerUserUUID
                    && $0.status == SupabaseCatalogBaselineStatus.valid.rawValue
                    && $0.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue
                    && $0.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion
            }
        )
    }

    private func latestRun(from runs: [SupabaseCatalogBaselineRun]) -> SupabaseCatalogBaselineRun? {
        runs.max { lhs, rhs in
            let lhsDate = lhs.appliedAt ?? lhs.createdAt
            let rhsDate = rhs.appliedAt ?? rhs.createdAt
            if lhsDate == rhsDate {
                return lhs.baselineRunID.uuidString < rhs.baselineRunID.uuidString
            }
            return lhsDate < rhsDate
        }
    }

    private func hasStaleRun(in runs: [SupabaseCatalogBaselineRun], ownerUserUUID: UUID) -> Bool {
        runs.contains {
            $0.ownerUserUUID == ownerUserUUID
                && isStaleRun($0)
        }
    }

    private func isStaleRun(_ run: SupabaseCatalogBaselineRun) -> Bool {
        guard run.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue else {
            return false
        }
        if run.status == SupabaseCatalogBaselineStatus.stale.rawValue {
            return true
        }
        return run.status == SupabaseCatalogBaselineStatus.valid.rawValue
            && run.fingerprintSchemaVersion != SupabaseCatalogFingerprintSchema.currentVersion
    }

    private func hasIncompleteRun(in runs: [SupabaseCatalogBaselineRun], ownerUserUUID: UUID) -> Bool {
        runs.contains {
            $0.ownerUserUUID == ownerUserUUID
                && $0.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue
                && ($0.status == SupabaseCatalogBaselineStatus.building.rawValue
                    || $0.status == SupabaseCatalogBaselineStatus.partialRejected.rawValue)
        }
    }

    private func hasOtherAccountValidRun(in runs: [SupabaseCatalogBaselineRun], ownerUserUUID: UUID) -> Bool {
        runs.contains {
            $0.ownerUserUUID != ownerUserUUID
                && $0.source == SupabaseCatalogBaselineSource.fullPullApply.rawValue
                && $0.status == SupabaseCatalogBaselineStatus.valid.rawValue
                && $0.fingerprintSchemaVersion == SupabaseCatalogFingerprintSchema.currentVersion
        }
    }

    private func summary(
        status: SupabaseCatalogBaselineDebugStatus,
        run: SupabaseCatalogBaselineRun
    ) -> SupabaseCatalogBaselineDebugSummary {
        SupabaseCatalogBaselineDebugSummary(
            status: status,
            appliedAt: run.appliedAt,
            ownerUserUUID: run.ownerUserUUID,
            accountAbbreviation: abbreviate(run.ownerUserUUID),
            fingerprintSchemaVersion: run.fingerprintSchemaVersion,
            productCount: run.productCount,
            supplierCount: run.supplierCount,
            categoryCount: run.categoryCount,
            tombstoneCount: run.tombstoneCount
        )
    }

    private func abbreviate(_ uuid: UUID) -> String {
        String(uuid.uuidString.prefix(8)).lowercased() + "..."
    }
}
