import Foundation

protocol SyncAutomaticCatalogRemoteWriting: Sendable {
    func createSuppliers(_ payloads: [SyncAutomaticSupplierCreatePayload]) async throws -> [RemoteInventorySupplierRow]
    func updateSupplier(id: UUID, payload: SyncAutomaticSupplierUpdatePayload) async throws -> RemoteInventorySupplierRow
    func createCategories(_ payloads: [SyncAutomaticCategoryCreatePayload]) async throws -> [RemoteInventoryCategoryRow]
    func updateCategory(id: UUID, payload: SyncAutomaticCategoryUpdatePayload) async throws -> RemoteInventoryCategoryRow
    func createProducts(_ payloads: [SyncAutomaticProductCreatePayload]) async throws -> [RemoteInventoryProductRow]
    func updateProduct(id: UUID, payload: SyncAutomaticProductUpdatePayload) async throws -> RemoteInventoryProductRow
    func updateProductConditionally(
        id: UUID, payload: SyncAutomaticProductUpdatePayload,
        expectedVersion: SyncCatalogConditionalVersion, changedFields: [String]
    ) async throws -> [RemoteInventoryProductRow]
}

extension SyncAutomaticCatalogRemoteWriting {
    func updateProductConditionally(
        id: UUID, payload: SyncAutomaticProductUpdatePayload,
        expectedVersion: SyncCatalogConditionalVersion, changedFields: [String]
    ) async throws -> [RemoteInventoryProductRow] {
        // An old adapter must never silently turn a conditional successor into an ordinary write.
        throw SupabaseTransportClientError.schemaDrift(message: "Conditional catalog writes are unavailable.")
    }
}

/// Raw server versions are part of the sealed call. Never round-trip them through Date.
nonisolated struct SyncCatalogConditionalVersion: Codable, Equatable, Sendable {
    let expectedUpdatedAt: String
    let expectedDeletedAt: String?

    func validate() throws {
        guard Self.isValidTimestamp(expectedUpdatedAt),
              expectedDeletedAt.map(Self.isValidTimestamp) ?? true else {
            throw SupabaseTransportClientError.schemaDrift(message: "Invalid conditional catalog version.")
        }
    }

    static func isValidTimestamp(_ value: String) -> Bool {
        value.range(of: #"^[0-9]{4}-(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](\.[0-9]{1,6})?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$"#,
                    options: .regularExpression) != nil
    }
}

/// Only an actual atomic catalog response may produce this classification.
/// The writer must bind and persist it with the exact attempt before retiring replay.
nonisolated struct SyncCatalogWriteRejectedWithoutCommit: Error, Equatable, Sendable {
    let sqlstate: String

    static func classify(_ code: String?) -> Self? {
        guard let code, code == "23503" || code == "23505" else { return nil }
        return Self(sqlstate: code)
    }
}

/// The seal stores values and mask separately; only the HTTP body uses this encoder.
nonisolated struct SyncCatalogConditionalProductWirePayload: Encodable, Sendable {
    let payload: SyncAutomaticProductUpdatePayload
    let changedFields: [String]

    init(payload: SyncAutomaticProductUpdatePayload, changedFields: [String]) throws {
        let supported: Set<String> = ["barcode", "itemNumber", "productName", "secondProductName",
                                      "purchasePrice", "retailPrice", "supplierID", "categoryID", "stockQuantity"]
        guard !changedFields.isEmpty, Set(changedFields).count == changedFields.count,
              Set(changedFields).isSubset(of: supported),
              !changedFields.contains("barcode") || payload.barcode != nil else {
            throw SupabaseTransportClientError.schemaDrift(message: "Invalid conditional catalog field mask.")
        }
        self.payload = payload
        self.changedFields = changedFields
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: SyncAutomaticProductUpdatePayload.CodingKeys.self)
        for field in changedFields {
            // encode(Optional) deliberately writes JSON null for a selected nullable field.
            switch field {
            case "barcode": try container.encode(payload.barcode, forKey: .barcode)
            case "itemNumber": try container.encode(payload.itemNumber, forKey: .itemNumber)
            case "productName": try container.encode(payload.productName, forKey: .productName)
            case "secondProductName": try container.encode(payload.secondProductName, forKey: .secondProductName)
            case "purchasePrice": try container.encode(payload.purchasePrice, forKey: .purchasePrice)
            case "retailPrice": try container.encode(payload.retailPrice, forKey: .retailPrice)
            case "supplierID": try container.encode(payload.supplierID, forKey: .supplierID)
            case "categoryID": try container.encode(payload.categoryID, forKey: .categoryID)
            case "stockQuantity": try container.encode(payload.stockQuantity, forKey: .stockQuantity)
            default: throw SupabaseTransportClientError.schemaDrift(message: "Invalid conditional catalog field mask.")
            }
        }
    }
}
