import Foundation
import SwiftData

nonisolated enum SupabaseCatalogBaselineWriterError: Error, Sendable, Equatable {
    case partialPreview
    case sourceErrorsPresent
    case conflictsPresent
    case priceHistoryIncomplete
    case duplicateRecord(entityType: SupabaseCatalogBaselineEntityType, remoteID: UUID)
    case recordCountMismatch(expected: Int, actual: Int)
}

nonisolated struct SupabaseCatalogBaselineCommitResult: Sendable, Equatable {
    let baselineRunID: UUID
    let ownerUserUUID: UUID
    let appliedAt: Date
    let productCount: Int
    let supplierCount: Int
    let categoryCount: Int
    let tombstoneCount: Int
}

@MainActor
struct SupabaseCatalogBaselineWriter {
    private let now: () -> Date
    private let recordBatchSize: Int

    init(
        now: @escaping () -> Date = Date.init,
        recordBatchSize: Int = 1_000
    ) {
        self.now = now
        self.recordBatchSize = max(1, recordBatchSize)
    }

    func commitAfterSuccessfulFullPullApply(
        preview: SyncPreview,
        context: ModelContext,
        ownerUserUUID: UUID
    ) throws -> SupabaseCatalogBaselineCommitResult {
        guard preview.outcome == .success else {
            throw SupabaseCatalogBaselineWriterError.partialPreview
        }
        guard preview.sourceErrors.isEmpty else {
            throw SupabaseCatalogBaselineWriterError.sourceErrorsPresent
        }
        guard !containsPriceHistoryIncomplete(preview) else {
            throw SupabaseCatalogBaselineWriterError.priceHistoryIncomplete
        }
        guard preview.conflicts.isEmpty else {
            throw SupabaseCatalogBaselineWriterError.conflictsPresent
        }

        return try commitLatestBaseline(
            context: context,
            ownerUserUUID: ownerUserUUID,
            source: .fullPullApply
        )
    }

    private func containsPriceHistoryIncomplete(_ preview: SyncPreview) -> Bool {
        (preview.warnings + preview.sourceErrors).contains { $0.code == .priceHistoryIncomplete }
    }

    func commitLatestBaseline(
        context: ModelContext,
        ownerUserUUID: UUID,
        source: SupabaseCatalogBaselineSource = .fullPullApply
    ) throws -> SupabaseCatalogBaselineCommitResult {
        let createdAt = now()
        let runID = UUID()
        let run = SupabaseCatalogBaselineRun(
            baselineRunID: runID,
            ownerUserUUID: ownerUserUUID,
            fingerprintSchemaVersion: SupabaseCatalogFingerprintSchema.currentVersion,
            source: source,
            status: .building,
            createdAt: createdAt,
            updatedAt: createdAt
        )
        context.insert(run)

        do {
            try context.save()

            let seeds = try makeRecordSeeds(
                context: context,
                baselineRunID: runID,
                ownerUserUUID: ownerUserUUID,
                source: source,
                timestamp: createdAt
            )

            run.productCount = seeds.filter { $0.entityType == .product }.count
            run.supplierCount = seeds.filter { $0.entityType == .supplier }.count
            run.categoryCount = seeds.filter { $0.entityType == .productCategory }.count
            run.tombstoneCount = seeds.filter { $0.remoteDeletedAt != nil }.count
            run.updatedAt = now()
            try context.save()

            var nextIndex = seeds.startIndex
            while nextIndex < seeds.endIndex {
                let upperBound = min(nextIndex + recordBatchSize, seeds.endIndex)
                for seed in seeds[nextIndex..<upperBound] {
                    context.insert(seed.makeRecord())
                }
                try context.save()
                nextIndex = upperBound
            }

            let persistedRecordCount = try context.fetchCount(
                FetchDescriptor<SupabaseCatalogBaselineRecord>(
                    predicate: #Predicate { $0.baselineRunID == runID }
                )
            )
            guard persistedRecordCount == seeds.count else {
                throw SupabaseCatalogBaselineWriterError.recordCountMismatch(
                    expected: seeds.count,
                    actual: persistedRecordCount
                )
            }

            let appliedAt = now()
            run.status = SupabaseCatalogBaselineStatus.valid.rawValue
            run.appliedAt = appliedAt
            run.updatedAt = appliedAt
            try context.save()

            return SupabaseCatalogBaselineCommitResult(
                baselineRunID: runID,
                ownerUserUUID: ownerUserUUID,
                appliedAt: appliedAt,
                productCount: run.productCount ?? 0,
                supplierCount: run.supplierCount ?? 0,
                categoryCount: run.categoryCount ?? 0,
                tombstoneCount: run.tombstoneCount ?? 0
            )
        } catch {
            context.rollback()
            run.status = SupabaseCatalogBaselineStatus.partialRejected.rawValue
            run.updatedAt = now()
            try? context.save()
            throw error
        }
    }

    private func makeRecordSeeds(
        context: ModelContext,
        baselineRunID: UUID,
        ownerUserUUID: UUID,
        source: SupabaseCatalogBaselineSource,
        timestamp: Date
    ) throws -> [BaselineRecordSeed] {
        let products = try context.fetch(FetchDescriptor<Product>(sortBy: [SortDescriptor(\Product.barcode)]))
        let suppliers = try context.fetch(FetchDescriptor<Supplier>(sortBy: [SortDescriptor(\Supplier.name)]))
        let categories = try context.fetch(FetchDescriptor<ProductCategory>(sortBy: [SortDescriptor(\ProductCategory.name)]))

        var seeds: [BaselineRecordSeed] = []
        var logicalKeys: Set<String> = []

        for supplier in suppliers {
            guard let remoteID = supplier.remoteID else { continue }
            try appendSeed(
                BaselineRecordSeed(
                    baselineRunID: baselineRunID,
                    ownerUserUUID: ownerUserUUID,
                    entityType: .supplier,
                    remoteID: remoteID,
                    remoteUpdatedAt: supplier.remoteUpdatedAt,
                    remoteDeletedAt: supplier.remoteDeletedAt,
                    localModelID: String(describing: supplier.persistentModelID),
                    fingerprintCanonical: ManualPushFingerprintNormalizer.supplier(
                        remoteID: remoteID,
                        name: supplier.name
                    ).canonicalString,
                    source: source,
                    createdAt: timestamp,
                    updatedAt: timestamp,
                    barcodeCanonical: nil,
                    lookupNameCanonical: SupabasePullPreviewNormalizer.normalizedLookupName(supplier.name)
                ),
                logicalKeys: &logicalKeys,
                seeds: &seeds
            )
        }

        for category in categories {
            guard let remoteID = category.remoteID else { continue }
            try appendSeed(
                BaselineRecordSeed(
                    baselineRunID: baselineRunID,
                    ownerUserUUID: ownerUserUUID,
                    entityType: .productCategory,
                    remoteID: remoteID,
                    remoteUpdatedAt: category.remoteUpdatedAt,
                    remoteDeletedAt: category.remoteDeletedAt,
                    localModelID: String(describing: category.persistentModelID),
                    fingerprintCanonical: ManualPushFingerprintNormalizer.category(
                        remoteID: remoteID,
                        name: category.name
                    ).canonicalString,
                    source: source,
                    createdAt: timestamp,
                    updatedAt: timestamp,
                    barcodeCanonical: nil,
                    lookupNameCanonical: SupabasePullPreviewNormalizer.normalizedLookupName(category.name)
                ),
                logicalKeys: &logicalKeys,
                seeds: &seeds
            )
        }

        for product in products {
            guard let remoteID = product.remoteID else { continue }
            try appendSeed(
                BaselineRecordSeed(
                    baselineRunID: baselineRunID,
                    ownerUserUUID: ownerUserUUID,
                    entityType: .product,
                    remoteID: remoteID,
                    remoteUpdatedAt: product.remoteUpdatedAt,
                    remoteDeletedAt: product.remoteDeletedAt,
                    localModelID: String(describing: product.persistentModelID),
                    fingerprintCanonical: ManualPushFingerprintNormalizer.product(
                        barcode: product.barcode,
                        itemNumber: product.itemNumber,
                        productName: product.productName,
                        secondProductName: product.secondProductName,
                        purchasePrice: product.purchasePrice,
                        retailPrice: product.retailPrice,
                        stockQuantity: product.stockQuantity,
                        supplierRemoteID: product.supplier?.remoteID,
                        categoryRemoteID: product.category?.remoteID
                    ).canonicalString,
                    source: source,
                    createdAt: timestamp,
                    updatedAt: timestamp,
                    barcodeCanonical: ManualPushFingerprintNormalizer.semanticString(product.barcode),
                    lookupNameCanonical: nil
                ),
                logicalKeys: &logicalKeys,
                seeds: &seeds
            )
        }

        return seeds
    }

    private func appendSeed(
        _ seed: BaselineRecordSeed,
        logicalKeys: inout Set<String>,
        seeds: inout [BaselineRecordSeed]
    ) throws {
        let logicalKey = "\(seed.entityType.rawValue)|\(seed.remoteID.uuidString.lowercased())"
        guard logicalKeys.insert(logicalKey).inserted else {
            throw SupabaseCatalogBaselineWriterError.duplicateRecord(
                entityType: seed.entityType,
                remoteID: seed.remoteID
            )
        }
        seeds.append(seed)
    }
}

private struct BaselineRecordSeed {
    let baselineRunID: UUID
    let ownerUserUUID: UUID
    let entityType: SupabaseCatalogBaselineEntityType
    let remoteID: UUID
    let remoteUpdatedAt: Date?
    let remoteDeletedAt: Date?
    let localModelID: String?
    let fingerprintCanonical: String
    let source: SupabaseCatalogBaselineSource
    let createdAt: Date
    let updatedAt: Date
    let barcodeCanonical: String?
    let lookupNameCanonical: String?

    func makeRecord() -> SupabaseCatalogBaselineRecord {
        SupabaseCatalogBaselineRecord(
            baselineRunID: baselineRunID,
            ownerUserUUID: ownerUserUUID,
            entityType: entityType,
            remoteID: remoteID,
            remoteUpdatedAt: remoteUpdatedAt,
            remoteDeletedAt: remoteDeletedAt,
            localModelID: localModelID,
            fingerprintCanonical: fingerprintCanonical,
            source: source,
            createdAt: createdAt,
            updatedAt: updatedAt,
            barcodeCanonical: barcodeCanonical,
            lookupNameCanonical: lookupNameCanonical
        )
    }
}
