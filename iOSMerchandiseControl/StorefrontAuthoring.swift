import Combine
import Foundation

nonisolated enum StorefrontPublicationStatus: String, Codable, CaseIterable, Sendable {
    case unpublished
    case draft
    case scheduled
    case published
    case hidden = "paused"
    case archived = "ended"

    init(wireValue: String?) {
        self = StorefrontPublicationStatus(rawValue: wireValue ?? "") ?? .unpublished
    }
}

nonisolated enum StorefrontMutationOperation: String, Codable, Sendable {
    case saveDraft = "save_draft"
    case publish
    case schedule
    case hide
    case archive
}

nonisolated enum StorefrontListFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case published
    case unpublished
    case draft
    case scheduled
    case hidden
    case needsUpdate = "needs_update"
    case conflict

    var id: String { rawValue }
}

nonisolated enum StorefrontAvailability: String, Codable, CaseIterable, Sendable {
    case available
    case lowStock = "low_stock"
    case unavailable
    case reservationOnly = "reservation_only"
    case pickupOnly = "pickup_only"
    case deliveryOnly = "delivery_only"
}

nonisolated struct StorefrontScope: Hashable, Sendable {
    let accountID: UUID
    let shopID: UUID

    var cacheNamespace: String {
        let accountHash = AccountBindingStore.accountHash(for: accountID)
        return "\(accountHash).\(shopID.uuidString.lowercased())"
    }
}

nonisolated struct StorefrontPublication: Codable, Equatable, Sendable {
    let publicationId: UUID
    let sourceProductId: UUID
    let status: String
    let publicName: String
    let publicDescription: String?
    let storefrontCategoryId: UUID?
    let publicBrand: String?
    let publicPrice: Int64
    let compareAtPrice: Int64?
    let priceSourceMode: String
    let promotionStartsAt: String?
    let promotionEndsAt: String?
    let featured: Bool
    let homeOrder: Int64
    let pickupEnabled: Bool
    let deliveryEnabled: Bool
    let reservationEnabled: Bool
    let availability: String
    let publicImageId: UUID?
    let publicImageThumbnailUrl: String?
    let publicImageDetailUrl: String?
    let version: Int64
    let updatedAt: String
    let mutationSource: String
    let changedFields: [String]

    var publicationStatus: StorefrontPublicationStatus {
        StorefrontPublicationStatus(wireValue: status)
    }

    private enum CodingKeys: String, CodingKey {
        case publicationId, sourceProductId, status, publicName, publicDescription
        case storefrontCategoryId, publicBrand, publicPrice, compareAtPrice, priceSourceMode
        case promotionStartsAt, promotionEndsAt, featured, homeOrder, pickupEnabled
        case deliveryEnabled, reservationEnabled, availability, publicImageId
        case publicImageThumbnailUrl, publicImageDetailUrl, version, updatedAt
        case mutationSource, changedFields
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        publicationId = try values.decode(UUID.self, forKey: .publicationId)
        sourceProductId = try values.decode(UUID.self, forKey: .sourceProductId)
        status = try values.decode(String.self, forKey: .status)
        publicName = try values.decode(String.self, forKey: .publicName)
        publicDescription = try values.decodeIfPresent(String.self, forKey: .publicDescription)
        storefrontCategoryId = try values.decodeIfPresent(UUID.self, forKey: .storefrontCategoryId)
        publicBrand = try values.decodeIfPresent(String.self, forKey: .publicBrand)
        publicPrice = try values.decode(Int64.self, forKey: .publicPrice)
        compareAtPrice = try values.decodeIfPresent(Int64.self, forKey: .compareAtPrice)
        priceSourceMode = try values.decodeIfPresent(String.self, forKey: .priceSourceMode) ?? "override"
        promotionStartsAt = try values.decodeIfPresent(String.self, forKey: .promotionStartsAt)
        promotionEndsAt = try values.decodeIfPresent(String.self, forKey: .promotionEndsAt)
        featured = try values.decodeIfPresent(Bool.self, forKey: .featured) ?? false
        homeOrder = try values.decodeIfPresent(Int64.self, forKey: .homeOrder) ?? 0
        pickupEnabled = try values.decodeIfPresent(Bool.self, forKey: .pickupEnabled) ?? false
        deliveryEnabled = try values.decodeIfPresent(Bool.self, forKey: .deliveryEnabled) ?? false
        reservationEnabled = try values.decodeIfPresent(Bool.self, forKey: .reservationEnabled) ?? false
        availability = try values.decodeIfPresent(String.self, forKey: .availability) ?? "available"
        publicImageId = try values.decodeIfPresent(UUID.self, forKey: .publicImageId)
        publicImageThumbnailUrl = try values.decodeIfPresent(String.self, forKey: .publicImageThumbnailUrl)
        publicImageDetailUrl = try values.decodeIfPresent(String.self, forKey: .publicImageDetailUrl)
        version = try values.decode(Int64.self, forKey: .version)
        updatedAt = try values.decode(String.self, forKey: .updatedAt)
        mutationSource = try values.decodeIfPresent(String.self, forKey: .mutationSource) ?? "system"
        changedFields = try values.decodeIfPresent([String].self, forKey: .changedFields) ?? []
    }
}

nonisolated struct StorefrontCategory: Codable, Equatable, Identifiable, Sendable {
    let categoryId: UUID
    let sourceCategoryId: UUID?
    let publicName: String
    let status: String
    let updatedAt: String

    var id: UUID { categoryId }
}

nonisolated struct StorefrontEditorDraft: Codable, Equatable, Sendable {
    var publicName = ""
    var publicDescription = ""
    var storefrontCategoryId: UUID?
    var publicBrand = ""
    var publicPrice: Int64?
    var compareAtPrice: Int64?
    var priceSourceMode = "override"
    var promotionStartsAt: String?
    var promotionEndsAt: String?
    var featured = false
    var homeOrder: Int64 = 0
    var pickupEnabled = true
    var deliveryEnabled = false
    var reservationEnabled = false
    var availability = StorefrontAvailability.available
    var publicImageId: UUID?

    init() {}

    init(publication: StorefrontPublication) {
        publicName = publication.publicName
        publicDescription = publication.publicDescription ?? ""
        storefrontCategoryId = publication.storefrontCategoryId
        publicBrand = publication.publicBrand ?? ""
        publicPrice = publication.publicPrice
        compareAtPrice = publication.compareAtPrice
        priceSourceMode = publication.priceSourceMode
        promotionStartsAt = publication.promotionStartsAt
        promotionEndsAt = publication.promotionEndsAt
        featured = publication.featured
        homeOrder = publication.homeOrder
        pickupEnabled = publication.pickupEnabled
        deliveryEnabled = publication.deliveryEnabled
        reservationEnabled = publication.reservationEnabled
        availability = StorefrontAvailability(rawValue: publication.availability) ?? .available
        publicImageId = publication.publicImageId
    }
}

nonisolated enum StorefrontDraftField: Hashable, Sendable {
    case publicName, publicDescription, storefrontCategory, publicBrand
    case publicPrice, compareAtPrice, priceSourceMode, promotionStart, promotionEnd
    case featured, homeOrder, pickup, delivery, reservation, availability, publicImage
}

nonisolated func storefrontChangedFields(
    base: StorefrontEditorDraft,
    draft: StorefrontEditorDraft
) -> Set<StorefrontDraftField> {
    var fields = Set<StorefrontDraftField>()
    if base.publicName != draft.publicName { fields.insert(.publicName) }
    if base.publicDescription != draft.publicDescription { fields.insert(.publicDescription) }
    if base.storefrontCategoryId != draft.storefrontCategoryId { fields.insert(.storefrontCategory) }
    if base.publicBrand != draft.publicBrand { fields.insert(.publicBrand) }
    if base.publicPrice != draft.publicPrice { fields.insert(.publicPrice) }
    if base.compareAtPrice != draft.compareAtPrice { fields.insert(.compareAtPrice) }
    if base.priceSourceMode != draft.priceSourceMode { fields.insert(.priceSourceMode) }
    if base.promotionStartsAt != draft.promotionStartsAt { fields.insert(.promotionStart) }
    if base.promotionEndsAt != draft.promotionEndsAt { fields.insert(.promotionEnd) }
    if base.featured != draft.featured { fields.insert(.featured) }
    if base.homeOrder != draft.homeOrder { fields.insert(.homeOrder) }
    if base.pickupEnabled != draft.pickupEnabled { fields.insert(.pickup) }
    if base.deliveryEnabled != draft.deliveryEnabled { fields.insert(.delivery) }
    if base.reservationEnabled != draft.reservationEnabled { fields.insert(.reservation) }
    if base.availability != draft.availability { fields.insert(.availability) }
    if base.publicImageId != draft.publicImageId { fields.insert(.publicImage) }
    return fields
}

nonisolated func storefrontOverlay(
    server: StorefrontEditorDraft,
    local: StorefrontEditorDraft,
    fields: Set<StorefrontDraftField>
) -> StorefrontEditorDraft {
    var value = server
    if fields.contains(.publicName) { value.publicName = local.publicName }
    if fields.contains(.publicDescription) { value.publicDescription = local.publicDescription }
    if fields.contains(.storefrontCategory) { value.storefrontCategoryId = local.storefrontCategoryId }
    if fields.contains(.publicBrand) { value.publicBrand = local.publicBrand }
    if fields.contains(.publicPrice) { value.publicPrice = local.publicPrice }
    if fields.contains(.compareAtPrice) { value.compareAtPrice = local.compareAtPrice }
    if fields.contains(.priceSourceMode) { value.priceSourceMode = local.priceSourceMode }
    if fields.contains(.promotionStart) { value.promotionStartsAt = local.promotionStartsAt }
    if fields.contains(.promotionEnd) { value.promotionEndsAt = local.promotionEndsAt }
    if fields.contains(.featured) { value.featured = local.featured }
    if fields.contains(.homeOrder) { value.homeOrder = local.homeOrder }
    if fields.contains(.pickup) { value.pickupEnabled = local.pickupEnabled }
    if fields.contains(.delivery) { value.deliveryEnabled = local.deliveryEnabled }
    if fields.contains(.reservation) { value.reservationEnabled = local.reservationEnabled }
    if fields.contains(.availability) { value.availability = local.availability }
    if fields.contains(.publicImage) { value.publicImageId = local.publicImageId }
    return value
}

nonisolated func storefrontAlignedDraft(
    _ draft: StorefrontEditorDraft,
    operationalName: String,
    operationalRetailPrice: Double?,
    operationalCategoryRemoteID: UUID?,
    categories: [StorefrontCategory]
) -> StorefrontEditorDraft {
    var value = draft
    value.publicName = operationalName.trimmingCharacters(in: .whitespacesAndNewlines)
    if let price = operationalRetailPrice,
       price.isFinite,
       price >= 0,
       price.rounded() == price,
       price <= Double(Int64.max) {
        value.publicPrice = Int64(price)
    }
    if let operationalCategoryRemoteID,
       let mapped = categories.first(where: {
           $0.sourceCategoryId == operationalCategoryRemoteID && $0.status == "active"
       }) {
        value.storefrontCategoryId = mapped.categoryId
    }
    return value
}

nonisolated struct StorefrontPublicPreviewPayload: Encodable, Sendable {
    let publicationId: UUID?
    let status: String
    let name: String
    let description: String?
    let categoryId: UUID?
    let brand: String?
    let price: Int64?
    let compareAtPrice: Int64?
    let featured: Bool
    let homeOrder: Int64
    let pickupEnabled: Bool
    let deliveryEnabled: Bool
    let reservationEnabled: Bool
    let availability: String
    let imageId: UUID?
    let version: Int64?
    let updatedAt: String?
}

nonisolated func storefrontPublicPreviewPayload(
    draft: StorefrontEditorDraft,
    publication: StorefrontPublication?
) -> StorefrontPublicPreviewPayload {
    StorefrontPublicPreviewPayload(
        publicationId: publication?.publicationId,
        status: publication?.status ?? StorefrontPublicationStatus.unpublished.rawValue,
        name: draft.publicName,
        description: draft.publicDescription.isEmpty ? nil : draft.publicDescription,
        categoryId: draft.storefrontCategoryId,
        brand: draft.publicBrand.isEmpty ? nil : draft.publicBrand,
        price: draft.publicPrice,
        compareAtPrice: draft.compareAtPrice,
        featured: draft.featured,
        homeOrder: draft.homeOrder,
        pickupEnabled: draft.pickupEnabled,
        deliveryEnabled: draft.deliveryEnabled,
        reservationEnabled: draft.reservationEnabled,
        availability: draft.availability.rawValue,
        imageId: draft.publicImageId,
        version: publication?.version,
        updatedAt: publication?.updatedAt
    )
}

nonisolated func storefrontDraftValidationCode(
    _ draft: StorefrontEditorDraft,
    operation: StorefrontMutationOperation
) -> String? {
    if operation == .hide || operation == .archive { return nil }
    let name = draft.publicName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !name.isEmpty,
          name.count <= 200,
          draft.publicDescription.count <= 5_000,
          draft.publicBrand.count <= 120,
          let price = draft.publicPrice,
          price >= 0,
          price <= 999_999_999_999,
          draft.compareAtPrice.map({ $0 >= price && $0 <= 999_999_999_999 }) ?? true,
          ["operational", "override", "promotion"].contains(draft.priceSourceMode) else {
        return "validation"
    }
    if operation == .publish || operation == .schedule {
        guard draft.storefrontCategoryId != nil,
              draft.pickupEnabled || draft.deliveryEnabled || draft.reservationEnabled else {
            return "validation"
        }
    }
    let starts = draft.promotionStartsAt?.trimmingCharacters(in: .whitespacesAndNewlines)
    let ends = draft.promotionEndsAt?.trimmingCharacters(in: .whitespacesAndNewlines)
    guard (starts?.isEmpty == false) == (ends?.isEmpty == false) else {
        return "schedule"
    }
    if let starts, !starts.isEmpty, let ends, !ends.isEmpty {
        let formatter = ISO8601DateFormatter()
        guard let startDate = formatter.date(from: starts),
              let endDate = formatter.date(from: ends),
              startDate < endDate else {
            return "schedule"
        }
    } else if operation == .schedule {
        return "schedule"
    }
    return nil
}

nonisolated struct StorefrontPagination: Codable, Equatable, Sendable {
    let page: Int
    let pageSize: Int
    let total: Int
    let totalPages: Int

    init(page: Int = 1, pageSize: Int = 100, total: Int = 0, totalPages: Int = 1) {
        self.page = page
        self.pageSize = pageSize
        self.total = total
        self.totalPages = totalPages
    }
}

nonisolated struct StorefrontAuthoringReadResponse: Codable, Sendable {
    let ok: Bool
    let code: String
    let shopId: UUID?
    let rows: [StorefrontPublication]
    let categories: [StorefrontCategory]
    let pagination: StorefrontPagination

    private enum CodingKeys: String, CodingKey {
        case ok, code, rows, categories, pagination
        case shopId = "shop_id"
    }
}

nonisolated struct StorefrontPublicationSummary: Codable, Equatable, Sendable {
    let sourceProductId: UUID
    let status: String
    let publicName: String?
    let publicPrice: Int64?
    let storefrontCategoryId: UUID?
    let publicImageId: UUID?
    let version: Int64?
    let updatedAt: String?
    let differsFromOperational: Bool

    var publicationStatus: StorefrontPublicationStatus {
        StorefrontPublicationStatus(wireValue: status)
    }
}

nonisolated struct StorefrontAuthoringSummaryResponse: Codable, Sendable {
    let ok: Bool
    let code: String
    let shopId: UUID?
    let rows: [StorefrontPublicationSummary]
    let pagination: StorefrontPagination

    private enum CodingKeys: String, CodingKey {
        case ok, code, rows, pagination
        case shopId = "shop_id"
    }
}

nonisolated struct StorefrontAuthoringMutationResponse: Codable, Sendable {
    let ok: Bool
    let code: String
    let shopId: UUID?
    let targetId: UUID?
    let idempotent: Bool
    let payload: StorefrontPublication?
    let server: StorefrontPublication?

    private enum CodingKeys: String, CodingKey {
        case ok, code, idempotent, payload, server
        case shopId = "shop_id"
        case targetId = "target_id"
    }
}

nonisolated enum StorefrontAuthoringError: Error, Equatable, Sendable {
    case unavailable
    case invalidScope
    case invalidInput
    case unauthenticated
    case permissionDenied
    case conflict(StorefrontPublication?)
    case offline
    case server(code: String)
    case contractInvalid
    case localPersistence
}

nonisolated func storefrontMutationFailure(
    code: String,
    server: StorefrontPublication?
) -> StorefrontAuthoringError {
    switch code {
    case "conflict", "stale_version", "stale_revision":
        .conflict(server)
    case "permission_denied", "forbidden", "rls_denied":
        .permissionDenied
    default:
        .server(code: code)
    }
}

protocol StorefrontAuthoringServicing: Sendable {
    func read(scope: StorefrontScope, productIDs: [UUID]) async throws -> StorefrontAuthoringReadResponse
    func readSummary(
        scope: StorefrontScope,
        filter: StorefrontListFilter,
        query: String?,
        productIDs: [UUID]?,
        page: Int
    ) async throws -> StorefrontAuthoringSummaryResponse
    func mutate(
        scope: StorefrontScope,
        productID: UUID,
        operation: StorefrontMutationOperation,
        draft: StorefrontEditorDraft,
        expectedVersion: Int64,
        idempotencyKey: UUID
    ) async throws -> StorefrontAuthoringMutationResponse
}

actor SupabaseStorefrontAuthoringService: StorefrontAuthoringServicing {
    private struct ReadParameters: Encodable, Sendable {
        let p_shop_id: UUID
        let p_source_product_ids: [UUID]
        let p_status: String? = nil
        let p_page = 1
        let p_page_size = 100
    }

    private struct SummaryParameters: Encodable, Sendable {
        let p_shop_id: UUID
        let p_filter: String
        let p_query: String?
        let p_source_product_ids: [UUID]?
        let p_page: Int
        let p_page_size = 100
    }

    private struct BindParameters: Encodable, Sendable {}
    private struct BindResponse: Decodable, Sendable {
        let ok: Bool
        let code: String
        let source: String?
    }

    private struct MutationPayload: Encodable, Sendable {
        let includesEditableFields: Bool
        let sourceProductId: UUID
        let publicName: String?
        let publicDescription: String?
        let storefrontCategoryId: UUID?
        let publicBrand: String?
        let publicPrice: Int64?
        let compareAtPrice: Int64?
        let priceSourceMode: String?
        let promotionStartsAt: String?
        let promotionEndsAt: String?
        let featured: Bool?
        let homeOrder: Int64?
        let pickupEnabled: Bool?
        let deliveryEnabled: Bool?
        let reservationEnabled: Bool?
        let availability: String?
        let publicImageId: UUID?

        private enum CodingKeys: String, CodingKey {
            case sourceProductId, publicName, publicDescription, storefrontCategoryId
            case publicBrand, publicPrice, compareAtPrice, priceSourceMode
            case promotionStartsAt, promotionEndsAt, featured, homeOrder
            case pickupEnabled, deliveryEnabled, reservationEnabled, availability
            case publicImageId
        }

        func encode(to encoder: Encoder) throws {
            var values = encoder.container(keyedBy: CodingKeys.self)
            try values.encode(sourceProductId, forKey: .sourceProductId)
            guard includesEditableFields else { return }
            try values.encode(publicName ?? "", forKey: .publicName)
            try values.encode(publicDescription ?? "", forKey: .publicDescription)
            try values.encodeIfPresent(publicBrand, forKey: .publicBrand)
            try values.encodeIfPresent(publicPrice, forKey: .publicPrice)
            try values.encodeIfPresent(priceSourceMode, forKey: .priceSourceMode)
            try values.encodeIfPresent(featured, forKey: .featured)
            try values.encodeIfPresent(homeOrder, forKey: .homeOrder)
            try values.encodeIfPresent(pickupEnabled, forKey: .pickupEnabled)
            try values.encodeIfPresent(deliveryEnabled, forKey: .deliveryEnabled)
            try values.encodeIfPresent(reservationEnabled, forKey: .reservationEnabled)
            try values.encodeIfPresent(availability, forKey: .availability)
            try encodeNullable(storefrontCategoryId, forKey: .storefrontCategoryId, into: &values)
            try encodeNullable(compareAtPrice, forKey: .compareAtPrice, into: &values)
            try encodeNullable(promotionStartsAt, forKey: .promotionStartsAt, into: &values)
            try encodeNullable(promotionEndsAt, forKey: .promotionEndsAt, into: &values)
            try encodeNullable(publicImageId, forKey: .publicImageId, into: &values)
        }

        private func encodeNullable<Value: Encodable>(
            _ value: Value?,
            forKey key: CodingKeys,
            into values: inout KeyedEncodingContainer<CodingKeys>
        ) throws {
            if let value {
                try values.encode(value, forKey: key)
            } else {
                try values.encodeNil(forKey: key)
            }
        }
    }

    private struct MutationParameters: Encodable, Sendable {
        let p_shop_id: UUID
        let p_operation: String
        let p_payload: MutationPayload
        let p_idempotency_key: UUID
        let p_expected_version: Int64
    }

    private let transport: SupabaseTransportClient
    private let decoder = JSONDecoder()

    init(transport: SupabaseTransportClient) {
        self.transport = transport
    }

    func read(scope: StorefrontScope, productIDs: [UUID]) async throws -> StorefrontAuthoringReadResponse {
        guard !productIDs.isEmpty, productIDs.count <= 100, Set(productIDs).count == productIDs.count else {
            throw StorefrontAuthoringError.invalidInput
        }
        try await verifyAccount(scope)
        let data = try await rpc(
            "storefront_publications_authoring_read_v1",
            parameters: ReadParameters(p_shop_id: scope.shopID, p_source_product_ids: productIDs),
            maximumResponseBytes: 1_500_000
        )
        let response = try decode(StorefrontAuthoringReadResponse.self, from: data)
        try await verifyAccount(scope)
        guard response.shopId == nil || response.shopId == scope.shopID else {
            throw StorefrontAuthoringError.invalidScope
        }
        return response
    }

    func readSummary(
        scope: StorefrontScope,
        filter: StorefrontListFilter,
        query: String?,
        productIDs: [UUID]?,
        page: Int
    ) async throws -> StorefrontAuthoringSummaryResponse {
        let trimmedQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard filter != .conflict,
              page >= 1, page <= 10_000,
              trimmedQuery?.count ?? 0 <= 120,
              productIDs == nil || (productIDs?.isEmpty == false && productIDs!.count <= 100),
              productIDs == nil || Set(productIDs!).count == productIDs!.count else {
            throw StorefrontAuthoringError.invalidInput
        }
        try await verifyAccount(scope)
        let data = try await rpc(
            "storefront_publications_authoring_summary_v1",
            parameters: SummaryParameters(
                p_shop_id: scope.shopID,
                p_filter: filter.rawValue,
                p_query: trimmedQuery?.isEmpty == false ? trimmedQuery : nil,
                p_source_product_ids: productIDs,
                p_page: page
            ),
            maximumResponseBytes: 256_000
        )
        let response = try decode(StorefrontAuthoringSummaryResponse.self, from: data)
        try await verifyAccount(scope)
        guard response.shopId == nil || response.shopId == scope.shopID else {
            throw StorefrontAuthoringError.invalidScope
        }
        return response
    }

    func mutate(
        scope: StorefrontScope,
        productID: UUID,
        operation: StorefrontMutationOperation,
        draft: StorefrontEditorDraft,
        expectedVersion: Int64,
        idempotencyKey: UUID
    ) async throws -> StorefrontAuthoringMutationResponse {
        guard expectedVersion >= 0 else { throw StorefrontAuthoringError.invalidInput }
        try await verifyAccount(scope)
        let bindData = try await rpc(
            "storefront_authoring_bind_ios_session_v1",
            parameters: BindParameters(),
            maximumResponseBytes: 8_192
        )
        let binding = try decode(BindResponse.self, from: bindData)
        guard binding.ok, binding.source == "ios" else {
            throw StorefrontAuthoringError.server(code: binding.code)
        }
        try await verifyAccount(scope)

        let omitsEditableFields = operation == .hide || operation == .archive
        let payload = MutationPayload(
            includesEditableFields: !omitsEditableFields,
            sourceProductId: productID,
            publicName: omitsEditableFields ? nil : draft.publicName.trimmingCharacters(in: .whitespacesAndNewlines),
            publicDescription: omitsEditableFields ? nil : draft.publicDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            storefrontCategoryId: omitsEditableFields ? nil : draft.storefrontCategoryId,
            publicBrand: omitsEditableFields ? nil : draft.publicBrand.trimmingCharacters(in: .whitespacesAndNewlines),
            publicPrice: omitsEditableFields ? nil : draft.publicPrice,
            compareAtPrice: omitsEditableFields ? nil : draft.compareAtPrice,
            priceSourceMode: omitsEditableFields ? nil : draft.priceSourceMode,
            promotionStartsAt: omitsEditableFields ? nil : draft.promotionStartsAt,
            promotionEndsAt: omitsEditableFields ? nil : draft.promotionEndsAt,
            featured: omitsEditableFields ? nil : draft.featured,
            homeOrder: omitsEditableFields ? nil : draft.homeOrder,
            pickupEnabled: omitsEditableFields ? nil : draft.pickupEnabled,
            deliveryEnabled: omitsEditableFields ? nil : draft.deliveryEnabled,
            reservationEnabled: omitsEditableFields ? nil : draft.reservationEnabled,
            availability: omitsEditableFields ? nil : draft.availability.rawValue,
            publicImageId: omitsEditableFields ? nil : draft.publicImageId
        )
        let data = try await rpc(
            "storefront_publication_authoring_mutate_v1",
            parameters: MutationParameters(
                p_shop_id: scope.shopID,
                p_operation: operation.rawValue,
                p_payload: payload,
                p_idempotency_key: idempotencyKey,
                p_expected_version: expectedVersion
            ),
            maximumResponseBytes: 512_000
        )
        let response = try decode(StorefrontAuthoringMutationResponse.self, from: data)
        try await verifyAccount(scope)
        guard response.shopId == nil || response.shopId == scope.shopID else {
            throw StorefrontAuthoringError.invalidScope
        }
        if response.ok { return response }
        throw storefrontMutationFailure(code: response.code, server: response.server)
    }

    private func rpc<Parameters: Encodable & Sendable>(
        _ function: String,
        parameters: Parameters,
        maximumResponseBytes: Int
    ) async throws -> Data {
        do {
            return try await transport.boundedRPC(
                function,
                parameters: parameters,
                maximumResponseBytes: maximumResponseBytes
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as SupabaseTransportClientError {
            switch error {
            case .sessionMissing:
                throw StorefrontAuthoringError.unauthenticated
            case .permissionDeniedOrRLS:
                throw StorefrontAuthoringError.permissionDenied
            case .networkError:
                throw StorefrontAuthoringError.offline
            case .configMissing, .invalidConfig:
                throw StorefrontAuthoringError.unavailable
            case .decodingError, .schemaDrift, .unknown:
                throw StorefrontAuthoringError.contractInvalid
            }
        }
    }

    private func verifyAccount(_ scope: StorefrontScope) async throws {
        do {
            guard try await transport.authenticatedUserID() == scope.accountID else {
                throw StorefrontAuthoringError.invalidScope
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as StorefrontAuthoringError {
            throw error
        } catch {
            throw StorefrontAuthoringError.unauthenticated
        }
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) throws -> Value {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw StorefrontAuthoringError.contractInvalid
        }
    }
}

@MainActor
protocol StorefrontPendingPersisting {
    func read(key: String) throws -> Data?
    func write(_ data: Data, key: String) throws
    func remove(key: String) throws
}

@MainActor
final class StorefrontPendingFileStorage: StorefrontPendingPersisting {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory
            .appendingPathComponent("StorefrontPending", isDirectory: true)
    }

    func read(key: String) throws -> Data? {
        let url = directory.appendingPathComponent(key).appendingPathExtension("json")
        do { return try Data(contentsOf: url) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
    }

    func remove(key: String) throws {
        let url = directory.appendingPathComponent(key).appendingPathExtension("json")
        do { try FileManager.default.removeItem(at: url) }
        catch let error as CocoaError where error.code == .fileNoSuchFile { }
    }

    func write(_ data: Data, key: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(
            to: directory.appendingPathComponent(key).appendingPathExtension("json"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}

@MainActor
final class StorefrontAuthoringStore: ObservableObject {
    struct EditorSnapshot: Codable, Equatable, Sendable {
        let publication: StorefrontPublication?
        let categories: [StorefrontCategory]
        let draft: StorefrontEditorDraft
        let baseDraft: StorefrontEditorDraft
        let isLocalDraft: Bool
        let isServerVerified: Bool
        let conflict: StorefrontPublication?
        var localExpectedVersion: Int64? = nil
    }

    private struct LocalDraftRecord: Codable, Sendable {
        let draft: StorefrontEditorDraft
        let baseDraft: StorefrontEditorDraft
        let expectedVersion: Int64
        let idempotencyKey: UUID?
    }

    private struct MutationIntent: Codable {
        let operation: StorefrontMutationOperation
        let draft: StorefrontEditorDraft
        let expectedVersion: Int64
        let idempotencyKey: UUID
        let createdAt: Date
    }

    private struct IntentAcknowledgement {
        let receipt: StorefrontPublication
        let current: StorefrontPublication
    }

    private struct PendingJournal: Codable {
        var draft: LocalDraftRecord?
        var intent: MutationIntent?
    }

    static let editorCacheMaximum = 24
    private static let editorCacheIndexKey = "storefront.editor.v1.index"

    @Published private(set) var summaries: [UUID: StorefrontPublicationSummary] = [:]
    @Published private(set) var filteredProductIDs: Set<UUID> = []
    @Published private(set) var conflictedProductIDs: Set<UUID> = []
    @Published private(set) var isFilterLoading = false
    @Published private(set) var filterHasNextPage = false
    @Published private(set) var errorCode: String?

    let isAvailable: Bool
    private let service: (any StorefrontAuthoringServicing)?
    private let defaults: UserDefaults
    private let pendingStorage: any StorefrontPendingPersisting
    private var mutatingProducts = Set<String>()
    private var editorReceiptBase: (scope: StorefrontScope, productID: UUID, publication: StorefrontPublication)?
    private var filterGeneration = 0
    private var activeScope: StorefrontScope?
    private var generation = 0
    private var pendingSummaryIDs = Set<UUID>()
    private var pendingSummaryTask: Task<Void, Never>?
    private(set) var filterTask: Task<Void, Never>?
    private var currentFilter: StorefrontListFilter = .all
    private var currentQuery: String?
    private var currentFilterPage = 0

    init(
        service: (any StorefrontAuthoringServicing)?,
        defaults: UserDefaults = .standard,
        pendingStorage: (any StorefrontPendingPersisting)? = nil
    ) {
        self.service = service
        self.defaults = defaults
        self.pendingStorage = pendingStorage ?? StorefrontPendingFileStorage()
        self.isAvailable = service != nil
    }

    deinit {
        pendingSummaryTask?.cancel()
        filterTask?.cancel()
    }

    func activate(scope: StorefrontScope?) {
        guard activeScope != scope else { return }
        generation &+= 1
        filterGeneration &+= 1
        activeScope = scope
        editorReceiptBase = nil
        pendingSummaryTask?.cancel()
        filterTask?.cancel()
        pendingSummaryTask = nil
        filterTask = nil
        pendingSummaryIDs.removeAll()
        summaries.removeAll()
        filteredProductIDs.removeAll()
        conflictedProductIDs.removeAll()
        currentFilterPage = 0
        filterHasNextPage = false
        isFilterLoading = false
        errorCode = nil
    }

    func summary(for productID: UUID) -> StorefrontPublicationSummary? {
        summaries[productID]
    }

    func requestVisibleSummary(productID: UUID, scope: StorefrontScope) {
        guard service != nil, activeScope == scope, summaries[productID] == nil else { return }
        pendingSummaryIDs.insert(productID)
        guard pendingSummaryTask == nil else { return }
        let expectedGeneration = generation
        pendingSummaryTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(60))
            guard !Task.isCancelled else { return }
            await self?.flushVisibleSummaries(scope: scope, generation: expectedGeneration)
        }
    }

    func resetFilter(_ filter: StorefrontListFilter, query: String?, scope: StorefrontScope) {
        guard activeScope == scope else { return }
        filterGeneration &+= 1
        filterTask?.cancel()
        filterTask = nil
        isFilterLoading = false
        currentFilter = filter
        currentQuery = query
        currentFilterPage = 0
        filteredProductIDs.removeAll()
        filterHasNextPage = filter != .all && filter != .conflict
        errorCode = nil
        guard filter != .all else { return }
        if filter == .conflict {
            filteredProductIDs = conflictedProductIDs
            return
        }
        loadNextFilterPage(scope: scope)
    }

    func loadNextFilterPage(scope: StorefrontScope) {
        guard let service,
              activeScope == scope,
              currentFilter != .all,
              currentFilter != .conflict,
              !isFilterLoading,
              currentFilterPage == 0 || filterHasNextPage else { return }
        isFilterLoading = true
        let expectedGeneration = generation
        let expectedFilterGeneration = filterGeneration
        let page = currentFilterPage + 1
        let filter = currentFilter
        let query = currentQuery
        filterTask = Task { [weak self] in
            defer {
                if let self, self.generation == expectedGeneration,
                   self.filterGeneration == expectedFilterGeneration, self.activeScope == scope {
                    self.isFilterLoading = false
                    self.filterTask = nil
                }
            }
            do {
                let response = try await service.readSummary(
                    scope: scope,
                    filter: filter,
                    query: query,
                    productIDs: nil,
                    page: page
                )
                guard let self,
                      !Task.isCancelled,
                      self.generation == expectedGeneration,
                      self.filterGeneration == expectedFilterGeneration,
                      self.activeScope == scope,
                      self.currentFilter == filter,
                      self.currentQuery == query else { return }
                guard response.ok else {
                    self.errorCode = response.code
                    self.isFilterLoading = false
                    return
                }
                for row in response.rows {
                    self.summaries[row.sourceProductId] = row
                    self.filteredProductIDs.insert(row.sourceProductId)
                }
                self.currentFilterPage = page
                self.filterHasNextPage = page < response.pagination.totalPages
                self.isFilterLoading = false
            } catch is CancellationError {
            } catch let error as StorefrontAuthoringError {
                guard let self, !Task.isCancelled, self.generation == expectedGeneration, self.filterGeneration == expectedFilterGeneration, self.activeScope == scope else { return }
                self.errorCode = self.code(for: error)
                self.isFilterLoading = false
            } catch {
                guard let self, !Task.isCancelled, self.generation == expectedGeneration, self.filterGeneration == expectedFilterGeneration, self.activeScope == scope else { return }
                self.errorCode = "unknown"
                self.isFilterLoading = false
            }
        }
    }

    func loadEditor(scope: StorefrontScope, productID: UUID) async throws -> EditorSnapshot {
        guard activeScope == scope else { throw StorefrontAuthoringError.invalidScope }
        guard let service else {
            if let cached = try cachedEditor(scope: scope, productID: productID) { return cached }
            throw StorefrontAuthoringError.unavailable
        }
        let expectedGeneration = generation
        do {
            var response = try await service.read(scope: scope, productIDs: [productID])
            try validateCurrentScope(scope, generation: expectedGeneration)
            guard response.ok else { throw StorefrontAuthoringError.server(code: response.code) }
            var journal = try pendingJournal(scope: scope, productID: productID)
            // A sent draft can have committed with its ACK lost. Resolve its receipt
            // before comparing versions; a version increment alone is not a conflict.
            if let intent = journal.intent, intent.operation == .saveDraft {
                do {
                    _ = try await sendIntent(intent, scope: scope, productID: productID, generation: expectedGeneration, reconciling: true)
                    response = try await service.read(scope: scope, productIDs: [productID])
                    try validateCurrentScope(scope, generation: expectedGeneration)
                    guard response.ok else { throw StorefrontAuthoringError.server(code: response.code) }
                    journal = try pendingJournal(scope: scope, productID: productID)
                } catch StorefrontAuthoringError.conflict { /* retain the draft for explicit reapply */
                    journal = try pendingJournal(scope: scope, productID: productID)
                } catch StorefrontAuthoringError.offline { }
                catch StorefrontAuthoringError.unavailable { }
            }
            var publication = response.rows.first(where: { $0.sourceProductId == productID })
            var local = journal.draft
            if journal.intent == nil, let record = local,
               record.expectedVersion == publication?.version ?? 0 {
                do {
                    publication = try await mutate(
                        scope: scope, productID: productID, operation: .saveDraft,
                        draft: record.draft, expectedVersion: record.expectedVersion, baseDraft: record.baseDraft
                    )
                    local = try pendingJournal(scope: scope, productID: productID).draft
                } catch StorefrontAuthoringError.offline { }
                catch StorefrontAuthoringError.unavailable { }
                catch StorefrontAuthoringError.conflict(let server) { publication = server ?? publication }
            }
            let serverDraft = publication.map(StorefrontEditorDraft.init(publication:)) ?? StorefrontEditorDraft()
            let snapshot = EditorSnapshot(
                publication: publication, categories: response.categories,
                draft: local?.draft ?? serverDraft, baseDraft: local?.baseDraft ?? serverDraft,
                isLocalDraft: local != nil, isServerVerified: true,
                conflict: local.flatMap { $0.expectedVersion == publication?.version ?? 0 ? nil : publication },
                localExpectedVersion: local?.expectedVersion
            )
            cacheEditor(snapshot, scope: scope, productID: productID)
            return snapshot
        } catch is CancellationError { throw CancellationError() }
        catch let error as StorefrontAuthoringError {
            try validateCurrentScope(scope, generation: expectedGeneration)
            if error == .offline || error == .unavailable,
               let cached = try cachedEditor(scope: scope, productID: productID) { return cached }
            throw error
        }
    }

    func validateOperationalDeletion(scope: StorefrontScope, productIDs: [UUID]) async throws -> Bool {
        guard let service,
              activeScope == scope,
              !productIDs.isEmpty,
              productIDs.count <= 100 else {
            throw StorefrontAuthoringError.unavailable
        }
        let expectedGeneration = generation
        let response = try await service.read(scope: scope, productIDs: productIDs)
        guard generation == expectedGeneration, activeScope == scope else {
            throw CancellationError()
        }
        guard response.ok else { throw StorefrontAuthoringError.server(code: response.code) }
        let deletable: Set<StorefrontPublicationStatus> = [.unpublished, .hidden, .archived]
        return response.rows.allSatisfy { deletable.contains($0.publicationStatus) }
    }

    func needsUpdateCount(scope: StorefrontScope) async throws -> Int {
        guard let service, activeScope == scope else { throw StorefrontAuthoringError.unavailable }
        let expectedGeneration = generation
        let response = try await service.readSummary(
            scope: scope,
            filter: .needsUpdate,
            query: nil,
            productIDs: nil,
            page: 1
        )
        guard generation == expectedGeneration, activeScope == scope else {
            throw CancellationError()
        }
        guard response.ok else { throw StorefrontAuthoringError.server(code: response.code) }
        return response.pagination.total
    }

    func mutate(
        scope: StorefrontScope,
        productID: UUID,
        operation: StorefrontMutationOperation,
        draft: StorefrontEditorDraft,
        expectedVersion: Int64,
        baseDraft: StorefrontEditorDraft? = nil
    ) async throws -> StorefrontPublication {
        guard service != nil, activeScope == scope else { throw StorefrontAuthoringError.unavailable }
        let key = localDraftKey(scope: scope, productID: productID)
        guard mutatingProducts.insert(key).inserted else { throw StorefrontAuthoringError.unavailable }
        defer { mutatingProducts.remove(key) }
        let expectedGeneration = generation
        editorReceiptBase = nil
        let canonical = canonicalDraft(draft, operation: operation)
        var nextVersion = expectedVersion
        var journal = try pendingJournal(scope: scope, productID: productID)
        if let old = journal.intent {
            if operation == .saveDraft {
                journal.draft = LocalDraftRecord(draft: draft, baseDraft: baseDraft ?? journal.draft?.baseDraft ?? draft,
                                                expectedVersion: expectedVersion, idempotencyKey: nil)
                try writeJournal(journal, scope: scope, productID: productID)
            }
            let same = old.operation == operation && old.draft == canonical && old.expectedVersion == expectedVersion
            do {
                let acknowledged = try await sendIntent(old, scope: scope, productID: productID, generation: expectedGeneration, reconciling: true)
                if same { return acknowledged.current }
                if expectedVersion == old.expectedVersion {
                    nextVersion = acknowledged.receipt.version
                    editorReceiptBase = (scope, productID, acknowledged.receipt)
                }
                if acknowledged.current.version != acknowledged.receipt.version,
                   expectedVersion != acknowledged.current.version {
                    conflictedProductIDs.insert(productID)
                    throw StorefrontAuthoringError.conflict(acknowledged.current)
                }
            } catch let error as StorefrontAuthoringError {
                // A definitive rejection resolves uncertainty. An explicit edited
                // request may proceed; an unknown outcome must never be overwritten.
                guard !same, isDefinitiveRejection(error),
                      try pendingJournal(scope: scope, productID: productID).intent == nil else { throw error }
                if case .conflict = error, expectedVersion == old.expectedVersion { throw error }
            }
            journal = try pendingJournal(scope: scope, productID: productID)
        }
        let intent = MutationIntent(operation: operation, draft: canonical, expectedVersion: nextVersion,
                                    idempotencyKey: UUID(), createdAt: Date())
        journal.intent = intent
        if operation == .saveDraft {
            let acknowledgedBase = reconciledBase(scope: scope, productID: productID).flatMap {
                expectedVersion < $0.version ? StorefrontEditorDraft(publication: $0) : nil
            }
            journal.draft = LocalDraftRecord(draft: draft, baseDraft: acknowledgedBase ?? baseDraft ?? journal.draft?.baseDraft ?? draft,
                                            expectedVersion: nextVersion, idempotencyKey: intent.idempotencyKey)
        }
        try writeJournal(journal, scope: scope, productID: productID)
        return try await sendIntent(intent, scope: scope, productID: productID, generation: expectedGeneration).current
    }

    func reconciledBase(scope: StorefrontScope, productID: UUID) -> StorefrontPublication? {
        guard activeScope == scope, let base = editorReceiptBase,
              base.scope == scope, base.productID == productID else { return nil }
        return base.publication
    }

    func saveLocalDraft(
        _ draft: StorefrontEditorDraft,
        baseDraft: StorefrontEditorDraft,
        expectedVersion: Int64,
        scope: StorefrontScope,
        productID: UUID
    ) throws {
        guard activeScope == scope else { throw StorefrontAuthoringError.invalidScope }
        var journal = try pendingJournal(scope: scope, productID: productID)
        journal.draft = LocalDraftRecord(draft: draft, baseDraft: baseDraft, expectedVersion: expectedVersion,
                                        idempotencyKey: nil)
        try writeJournal(journal, scope: scope, productID: productID)
    }

    func clearLocalDraft(scope: StorefrontScope, productID: UUID) throws {
        guard activeScope == scope else { throw StorefrontAuthoringError.invalidScope }
        var journal = try pendingJournal(scope: scope, productID: productID)
        // Conflict reload is an intentional discard, but an uncertain sent
        // mutation must first be reconciled and cannot be silently forgotten.
        guard journal.intent == nil else { throw StorefrontAuthoringError.unavailable }
        journal.draft = nil
        try writeJournal(journal, scope: scope, productID: productID)
    }

    private func validateCurrentScope(_ scope: StorefrontScope, generation expected: Int) throws {
        guard !Task.isCancelled, activeScope == scope, generation == expected else { throw CancellationError() }
    }

    private func canonicalDraft(_ draft: StorefrontEditorDraft, operation: StorefrontMutationOperation) -> StorefrontEditorDraft {
        if operation == .hide || operation == .archive { return StorefrontEditorDraft() }
        var result = draft
        result.publicName = result.publicName.trimmingCharacters(in: .whitespacesAndNewlines)
        result.publicDescription = result.publicDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        result.publicBrand = result.publicBrand.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }

    private func isDefinitiveRejection(_ error: StorefrontAuthoringError) -> Bool {
        switch error {
        case .conflict, .invalidInput, .permissionDenied: true
        case .server(let code): ["validation_failed", "invalid_state", "not_found", "stale_revision", "permission_denied"].contains(code)
        default: false
        }
    }

    private func sendIntent(_ intent: MutationIntent, scope: StorefrontScope, productID: UUID,
                            generation expectedGeneration: Int, reconciling: Bool = false) async throws -> IntentAcknowledgement {
        guard let service else { throw StorefrontAuthoringError.unavailable }
        do {
            if Date().timeIntervalSince(intent.createdAt) >= 7 * 24 * 60 * 60 {
                let read = try await service.read(scope: scope, productIDs: [productID])
                try validateCurrentScope(scope, generation: expectedGeneration)
                guard read.ok else { throw StorefrontAuthoringError.contractInvalid }
                let server = read.rows.first { $0.sourceProductId == productID }
                guard server?.version ?? 0 == intent.expectedVersion else { throw StorefrontAuthoringError.conflict(server) }
            }
            let response = try await service.mutate(scope: scope, productID: productID, operation: intent.operation,
                                                    draft: intent.draft, expectedVersion: intent.expectedVersion,
                                                    idempotencyKey: intent.idempotencyKey)
            try validateCurrentScope(scope, generation: expectedGeneration)
            guard response.ok, let publication = response.payload else { throw StorefrontAuthoringError.contractInvalid }
            var journal = try pendingJournal(scope: scope, productID: productID)
            guard journal.intent?.idempotencyKey == intent.idempotencyKey else { throw CancellationError() }
            journal.intent = nil
            if let local = journal.draft {
                if local.expectedVersion == intent.expectedVersion,
                   canonicalDraft(local.draft, operation: intent.operation) == intent.draft,
                   intent.operation != .hide && intent.operation != .archive {
                    journal.draft = nil
                } else if local.expectedVersion == intent.expectedVersion {
                    journal.draft = LocalDraftRecord(draft: local.draft, baseDraft: StorefrontEditorDraft(publication: publication),
                                                    expectedVersion: publication.version, idempotencyKey: nil)
                }
            }
            try writeJournal(journal, scope: scope, productID: productID)
            if reconciling { editorReceiptBase = (scope, productID, publication) }
            // Settle the receipt durably before reading a potentially newer row:
            // the acknowledged A becomes the base of any saved successor B.
            var current = publication
            if response.idempotent {
                do {
                    let read = try await service.read(scope: scope, productIDs: [productID])
                    try validateCurrentScope(scope, generation: expectedGeneration)
                    guard read.ok else { throw StorefrontAuthoringError.contractInvalid }
                    guard let latest = read.rows.first(where: { $0.sourceProductId == productID }) else {
                        throw StorefrontAuthoringError.conflict(nil)
                    }
                    current = latest
                } catch StorefrontAuthoringError.offline {
                    // The receipt itself is an ACK. A successor still uses its
                    // exact version and is protected by the server version check.
                } catch StorefrontAuthoringError.unavailable { }
            }
            try validateCurrentScope(scope, generation: expectedGeneration)
            conflictedProductIDs.remove(productID)
            updateSummary(current, productID: productID)
            return IntentAcknowledgement(receipt: publication, current: current)
        } catch let error as StorefrontAuthoringError {
            try validateCurrentScope(scope, generation: expectedGeneration)
            let observedConflict: Bool
            if case .conflict = error { observedConflict = true } else { observedConflict = false }
            // Authorization/resource/payload prechecks happen before receipt lookup.
            // Their rejection cannot resolve an earlier request with an unknown ACK.
            if observedConflict || (!reconciling && isDefinitiveRejection(error)) {
                var journal = try pendingJournal(scope: scope, productID: productID)
                if journal.intent?.idempotencyKey == intent.idempotencyKey {
                    journal.intent = nil
                    try writeJournal(journal, scope: scope, productID: productID)
                }
            }
            if case .conflict = error { conflictedProductIDs.insert(productID) }
            throw error
        }
    }

    private func flushVisibleSummaries(scope: StorefrontScope, generation expectedGeneration: Int) async {
        pendingSummaryTask = nil
        guard let service, activeScope == scope, generation == expectedGeneration else { return }
        let ids = Array(pendingSummaryIDs.prefix(100))
        pendingSummaryIDs.subtract(ids)
        guard !ids.isEmpty else { return }
        do {
            let response = try await service.readSummary(
                scope: scope,
                filter: .all,
                query: nil,
                productIDs: ids,
                page: 1
            )
            guard !Task.isCancelled, activeScope == scope, generation == expectedGeneration else { return }
            if response.ok {
                for row in response.rows { summaries[row.sourceProductId] = row }
            } else {
                errorCode = response.code
            }
        } catch is CancellationError {
        } catch let error as StorefrontAuthoringError {
            guard generation == expectedGeneration else { return }
            errorCode = code(for: error)
        } catch {
            guard generation == expectedGeneration else { return }
            errorCode = "unknown"
        }
        if !pendingSummaryIDs.isEmpty {
            requestVisibleSummary(productID: pendingSummaryIDs.first!, scope: scope)
        }
    }

    private func cacheEditor(_ value: EditorSnapshot, scope: StorefrontScope, productID: UUID) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        let key = editorCacheKey(scope: scope, productID: productID)
        defaults.set(data, forKey: key)
        touchEditorCacheKey(key)
    }

    private func cachedEditor(scope: StorefrontScope, productID: UUID) throws -> EditorSnapshot? {
        let key = editorCacheKey(scope: scope, productID: productID)
        let local = try pendingJournal(scope: scope, productID: productID).draft
        let cached = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(EditorSnapshot.self, from: $0) }
        guard cached != nil || local != nil else { removeEditorCacheKey(key); return nil }
        if cached != nil { touchEditorCacheKey(key) }
        let serverDraft = cached?.draft ?? StorefrontEditorDraft()
        return EditorSnapshot(publication: cached?.publication, categories: cached?.categories ?? [],
                              draft: local?.draft ?? serverDraft, baseDraft: local?.baseDraft ?? cached?.baseDraft ?? serverDraft,
                              isLocalDraft: local != nil, isServerVerified: false,
                              conflict: cached?.conflict, localExpectedVersion: local?.expectedVersion)
    }

    private func pendingJournal(scope: StorefrontScope, productID: UUID) throws -> PendingJournal {
        let key = localDraftKey(scope: scope, productID: productID)
        do {
            if let data = try pendingStorage.read(key: key) {
                return try JSONDecoder().decode(PendingJournal.self, from: data)
            }
            // Upgrade atomically before removing the legacy UserDefaults record.
            if let legacy = defaults.data(forKey: key) {
                let draft = try JSONDecoder().decode(LocalDraftRecord.self, from: legacy)
                let intent = draft.idempotencyKey.map {
                    MutationIntent(operation: .saveDraft, draft: canonicalDraft(draft.draft, operation: .saveDraft),
                                   expectedVersion: draft.expectedVersion, idempotencyKey: $0, createdAt: .distantPast)
                }
                let journal = PendingJournal(draft: draft, intent: intent)
                try writeJournal(journal, scope: scope, productID: productID)
                return journal
            }
            return PendingJournal()
        } catch { throw StorefrontAuthoringError.localPersistence }
    }

    private func writeJournal(_ journal: PendingJournal, scope: StorefrontScope, productID: UUID) throws {
        let key = localDraftKey(scope: scope, productID: productID)
        do {
            if journal.draft == nil && journal.intent == nil {
                try pendingStorage.remove(key: key)
            } else {
                try pendingStorage.write(JSONEncoder().encode(journal), key: key)
            }
            defaults.removeObject(forKey: key)
        } catch { throw StorefrontAuthoringError.localPersistence }
    }

    private func updateSummary(_ publication: StorefrontPublication, productID: UUID) {
        summaries[productID] = StorefrontPublicationSummary(
            sourceProductId: productID,
            status: publication.status,
            publicName: publication.publicName,
            publicPrice: publication.publicPrice,
            storefrontCategoryId: publication.storefrontCategoryId,
            publicImageId: publication.publicImageId,
            version: publication.version,
            updatedAt: publication.updatedAt,
            differsFromOperational: false
        )
    }

    private func touchEditorCacheKey(_ key: String) {
        var keys = defaults.stringArray(forKey: Self.editorCacheIndexKey) ?? []
        keys.removeAll { $0 == key }
        keys.append(key)
        while keys.count > Self.editorCacheMaximum {
            defaults.removeObject(forKey: keys.removeFirst())
        }
        defaults.set(keys, forKey: Self.editorCacheIndexKey)
    }

    private func removeEditorCacheKey(_ key: String) {
        defaults.removeObject(forKey: key)
        var keys = defaults.stringArray(forKey: Self.editorCacheIndexKey) ?? []
        keys.removeAll { $0 == key }
        defaults.set(keys, forKey: Self.editorCacheIndexKey)
    }

    private func editorCacheKey(scope: StorefrontScope, productID: UUID) -> String {
        "storefront.editor.v1.\(scope.cacheNamespace).\(productID.uuidString.lowercased())"
    }

    private func localDraftKey(scope: StorefrontScope, productID: UUID) -> String {
        "storefront.draft.v1.\(scope.cacheNamespace).\(productID.uuidString.lowercased())"
    }

    private func code(for error: StorefrontAuthoringError) -> String {
        switch error {
        case .unavailable: "unavailable"
        case .invalidScope: "invalid_scope"
        case .invalidInput: "invalid_input"
        case .unauthenticated: "unauthenticated"
        case .permissionDenied: "permission_denied"
        case .conflict: "conflict"
        case .offline: "offline"
        case .server(let code): code
        case .contractInvalid: "contract_invalid"
        case .localPersistence: "local_persistence"
        }
    }
}
