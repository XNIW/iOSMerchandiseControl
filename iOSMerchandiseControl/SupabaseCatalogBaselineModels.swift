import Foundation
import SwiftData

nonisolated enum SupabaseCatalogBaselineStatus: String, Sendable, Equatable, CaseIterable {
    case building
    case valid
    case invalidated
    case stale
    case partialRejected
}

nonisolated enum SupabaseCatalogBaselineSource: String, Sendable, Equatable, CaseIterable {
    case fullPullApply
}

nonisolated enum SupabaseCatalogBaselineEntityType: String, Sendable, Equatable, CaseIterable {
    case product
    case supplier
    case productCategory
}

@Model
final class SupabaseCatalogBaselineRun {
    @Attribute(.unique) var runKey: String
    var baselineRunID: UUID
    var ownerUserUUID: UUID
    var fingerprintSchemaVersion: Int
    var source: String
    var status: String
    var createdAt: Date
    var updatedAt: Date
    var appliedAt: Date?
    var productCount: Int?
    var supplierCount: Int?
    var categoryCount: Int?
    var tombstoneCount: Int?

    init(
        baselineRunID: UUID = UUID(),
        ownerUserUUID: UUID,
        fingerprintSchemaVersion: Int = SupabaseCatalogFingerprintSchema.currentVersion,
        source: SupabaseCatalogBaselineSource = .fullPullApply,
        status: SupabaseCatalogBaselineStatus = .building,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        appliedAt: Date? = nil,
        productCount: Int? = nil,
        supplierCount: Int? = nil,
        categoryCount: Int? = nil,
        tombstoneCount: Int? = nil
    ) {
        self.baselineRunID = baselineRunID
        self.runKey = Self.makeRunKey(ownerUserUUID: ownerUserUUID, baselineRunID: baselineRunID)
        self.ownerUserUUID = ownerUserUUID
        self.fingerprintSchemaVersion = fingerprintSchemaVersion
        self.source = source.rawValue
        self.status = status.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.appliedAt = appliedAt
        self.productCount = productCount
        self.supplierCount = supplierCount
        self.categoryCount = categoryCount
        self.tombstoneCount = tombstoneCount
    }

    static func makeRunKey(ownerUserUUID: UUID, baselineRunID: UUID) -> String {
        "\(ownerUserUUID.uuidString.lowercased())|\(baselineRunID.uuidString.lowercased())"
    }
}

@Model
final class SupabaseCatalogBaselineRecord {
    @Attribute(.unique) var recordKey: String
    var baselineRunID: UUID
    var ownerUserUUID: UUID
    var fingerprintSchemaVersion: Int
    var entityType: String
    var remoteID: UUID
    var remoteUpdatedAt: Date?
    var remoteDeletedAt: Date?
    var localModelID: String?
    var fingerprintCanonical: String
    var source: String
    var createdAt: Date
    var updatedAt: Date
    var barcodeCanonical: String?
    var lookupNameCanonical: String?

    init(
        baselineRunID: UUID,
        ownerUserUUID: UUID,
        fingerprintSchemaVersion: Int = SupabaseCatalogFingerprintSchema.currentVersion,
        entityType: SupabaseCatalogBaselineEntityType,
        remoteID: UUID,
        remoteUpdatedAt: Date? = nil,
        remoteDeletedAt: Date? = nil,
        localModelID: String? = nil,
        fingerprintCanonical: String,
        source: SupabaseCatalogBaselineSource = .fullPullApply,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        barcodeCanonical: String? = nil,
        lookupNameCanonical: String? = nil
    ) {
        self.baselineRunID = baselineRunID
        self.ownerUserUUID = ownerUserUUID
        self.fingerprintSchemaVersion = fingerprintSchemaVersion
        self.entityType = entityType.rawValue
        self.remoteID = remoteID
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteDeletedAt = remoteDeletedAt
        self.localModelID = localModelID
        self.fingerprintCanonical = fingerprintCanonical
        self.source = source.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.barcodeCanonical = barcodeCanonical
        self.lookupNameCanonical = lookupNameCanonical
        self.recordKey = Self.makeRecordKey(
            baselineRunID: baselineRunID,
            entityType: entityType,
            remoteID: remoteID
        )
    }

    static func makeRecordKey(
        baselineRunID: UUID,
        entityType: SupabaseCatalogBaselineEntityType,
        remoteID: UUID
    ) -> String {
        "\(baselineRunID.uuidString.lowercased())|\(entityType.rawValue)|\(remoteID.uuidString.lowercased())"
    }
}
