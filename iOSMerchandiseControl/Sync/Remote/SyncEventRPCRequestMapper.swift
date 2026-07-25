import Foundation

nonisolated enum SyncEventRPCRequestMapper {
    static let functionName = "record_sync_event_v6"
    static let legacyFunctionName = "record_sync_event"
    private static let maxChangedCount = 250
    private static let maxHistoryChangedCount = 25
    private static let maxClientEventIDLength = 160
    private static let maxSourceDeviceIDLength = 160

    static func parameters(from request: SyncEventRecordRequest) throws -> SyncEventRPCRequestParameters {
        let domain = trimmed(request.domain)
        guard !domain.isEmpty else {
            throw contract("missing_domain", "domain is required.")
        }

        let eventType = trimmed(request.eventType)
        guard !eventType.isEmpty else {
            throw contract("missing_event_type", "eventType is required.")
        }
        try validateConfirmedDomain(domain, eventType: eventType)

        let changedCountLimit = domain == "history" ? maxHistoryChangedCount : maxChangedCount
        guard (0...changedCountLimit).contains(request.changedCount) else {
            throw contract("changed_count_limit", "changedCount exceeds the confirmed domain limit.")
        }

        let clientEventID = trimmed(request.clientEventID)
        guard !clientEventID.isEmpty else {
            throw contract("missing_client_event_id", "clientEventID is required.")
        }
        guard clientEventID.count <= maxClientEventIDLength else {
            throw contract("client_event_id_length", "clientEventID must be at most 160 characters.")
        }

        let entityIDs = try entityIDsParameter(from: request.entityIDs)
        let metadata = try metadataParameter(from: request.metadata)
        let sourceDeviceID = try sourceDeviceIDParameter(from: request.sourceDeviceID)

        return SyncEventRPCRequestParameters(
            pDomain: domain,
            pEventType: eventType,
            pChangedCount: request.changedCount,
            pEntityIDs: entityIDs,
            pStoreID: nil,
            pSource: trimmedOptional(request.source),
            pSourceDeviceID: sourceDeviceID,
            pBatchID: request.batchID,
            pClientEventID: clientEventID,
            pMetadata: metadata,
            pShopID: request.shopID
        )
    }

    private static func entityIDsParameter(from value: SyncEventJSONValue) throws -> SyncEventRPCJSONValue? {
        switch value {
        case .null:
            return nil
        case .object:
            return SyncEventRPCJSONValue(value)
        case .array, .string, .number, .bool:
            throw contract("entity_ids_shape", "entityIDs must be a JSON object or null.")
        }
    }

    private static func metadataParameter(from value: SyncEventJSONValue) throws -> SyncEventRPCJSONValue {
        guard case .object = value else {
            throw contract("metadata_shape", "metadata must be a JSON object.")
        }
        return SyncEventRPCJSONValue(value)
    }

    private static func sourceDeviceIDParameter(from value: String?) throws -> String? {
        guard let sourceDeviceID = trimmedOptional(value) else {
            return nil
        }
        guard sourceDeviceID.count <= maxSourceDeviceIDLength else {
            throw contract("source_device_id_length", "sourceDeviceID must be at most 160 characters.")
        }
        return sourceDeviceID
    }

    private static func validateConfirmedDomain(_ domain: String, eventType: String) throws {
        switch domain {
        case "catalog":
            guard eventType == "catalog_changed" || eventType == "catalog_tombstone" else {
                try validateKnownEventType(eventType)
                throw contract("event_type_domain_mismatch", "eventType is not valid for catalog.")
            }
        case "prices":
            guard eventType == "prices_changed" else {
                try validateKnownEventType(eventType)
                throw contract("event_type_domain_mismatch", "eventType is not valid for prices.")
            }
        case "history":
            guard eventType == "history_changed" || eventType == "history_tombstone" else {
                try validateKnownEventType(eventType)
                throw contract("event_type_domain_mismatch", "eventType is not valid for history.")
            }
        default:
            throw contract("unsupported_domain", "domain is not supported by the confirmed RPC contract.")
        }
    }

    private static func validateKnownEventType(_ eventType: String) throws {
        switch eventType {
        case "catalog_changed",
             "catalog_tombstone",
             "prices_changed",
             "history_changed",
             "history_tombstone":
            return
        default:
            throw contract("unsupported_event_type", "eventType is not supported by the confirmed RPC contract.")
        }
    }

    private static func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func contract(_ code: String, _ message: String) -> SyncEventRecordError {
        .contract(SyncEventRecordFailure(code: code, message: message))
    }

    static func legacyParametersIfCompatible(
        _ parameters: SyncEventRPCRequestParameters,
        hasAutomaticShopScope: Bool
    ) -> SyncEventLegacyRPCRequestParameters? {
        guard !hasAutomaticShopScope,
              parameters.pShopID == nil,
              parameters.pStoreID.map(isLegacyUUID) ?? true,
              parameters.pBatchID.map(isLegacyUUID) ?? true,
              legacyJSONUUIDsAreCompatible(parameters.pEntityIDs) else {
            return nil
        }
        return SyncEventLegacyRPCRequestParameters(
            pDomain: parameters.pDomain,
            pEventType: parameters.pEventType,
            pChangedCount: parameters.pChangedCount,
            pEntityIDs: parameters.pEntityIDs,
            pStoreID: parameters.pStoreID,
            pSource: parameters.pSource,
            pSourceDeviceID: parameters.pSourceDeviceID,
            pBatchID: parameters.pBatchID,
            pClientEventID: parameters.pClientEventID,
            pMetadata: parameters.pMetadata
        )
    }

    private static func isLegacyUUID(_ value: UUID) -> Bool {
        let bytes = value.uuid
        let version = (bytes.6 & 0xF0) >> 4
        let variant = bytes.8 & 0xC0
        return (1...5).contains(version)
            && variant == 0x80
            && value != UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    }

    private static func legacyJSONUUIDsAreCompatible(
        _ value: SyncEventRPCJSONValue?
    ) -> Bool {
        guard let value else { return true }
        switch value {
        case .object(let object):
            return object.values.allSatisfy(legacyJSONUUIDsAreCompatible)
        case .array(let values):
            return values.allSatisfy(legacyJSONUUIDsAreCompatible)
        case .string(let string):
            guard let uuid = UUID(uuidString: string) else { return true }
            return isLegacyUUID(uuid)
        case .number, .bool, .null:
            return true
        }
    }
}

nonisolated struct SyncEventRPCRequestParameters: Encodable, Sendable, Equatable {
    let pDomain: String
    let pEventType: String
    let pChangedCount: Int
    let pEntityIDs: SyncEventRPCJSONValue?
    let pStoreID: UUID?
    let pSource: String?
    let pSourceDeviceID: String?
    let pBatchID: UUID?
    let pClientEventID: String
    let pMetadata: SyncEventRPCJSONValue
    let pShopID: UUID?

    enum CodingKeys: String, CodingKey {
        case pDomain = "p_domain"
        case pEventType = "p_event_type"
        case pChangedCount = "p_changed_count"
        case pEntityIDs = "p_entity_ids"
        case pStoreID = "p_store_id"
        case pSource = "p_source"
        case pSourceDeviceID = "p_source_device_id"
        case pBatchID = "p_batch_id"
        case pClientEventID = "p_client_event_id"
        case pMetadata = "p_metadata"
        case pShopID = "p_shop_id"
    }

    init(
        pDomain: String,
        pEventType: String,
        pChangedCount: Int,
        pEntityIDs: SyncEventRPCJSONValue?,
        pStoreID: UUID?,
        pSource: String?,
        pSourceDeviceID: String?,
        pBatchID: UUID?,
        pClientEventID: String,
        pMetadata: SyncEventRPCJSONValue,
        pShopID: UUID?
    ) {
        self.pDomain = pDomain
        self.pEventType = pEventType
        self.pChangedCount = pChangedCount
        self.pEntityIDs = pEntityIDs
        self.pStoreID = pStoreID
        self.pSource = pSource
        self.pSourceDeviceID = pSourceDeviceID
        self.pBatchID = pBatchID
        self.pClientEventID = pClientEventID
        self.pMetadata = pMetadata
        self.pShopID = pShopID
    }
}

nonisolated struct SyncEventLegacyRPCRequestParameters: Encodable, Sendable, Equatable {
    let pDomain: String
    let pEventType: String
    let pChangedCount: Int
    let pEntityIDs: SyncEventRPCJSONValue?
    let pStoreID: UUID?
    let pSource: String?
    let pSourceDeviceID: String?
    let pBatchID: UUID?
    let pClientEventID: String
    let pMetadata: SyncEventRPCJSONValue

    enum CodingKeys: String, CodingKey {
        case pDomain = "p_domain"
        case pEventType = "p_event_type"
        case pChangedCount = "p_changed_count"
        case pEntityIDs = "p_entity_ids"
        case pStoreID = "p_store_id"
        case pSource = "p_source"
        case pSourceDeviceID = "p_source_device_id"
        case pBatchID = "p_batch_id"
        case pClientEventID = "p_client_event_id"
        case pMetadata = "p_metadata"
    }
}

nonisolated indirect enum SyncEventRPCJSONValue: Encodable, Sendable, Equatable {
    case object([String: SyncEventRPCJSONValue])
    case array([SyncEventRPCJSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init(_ value: SyncEventJSONValue) {
        switch value {
        case .object(let object):
            self = .object(object.mapValues(SyncEventRPCJSONValue.init))
        case .array(let array):
            self = .array(array.map(SyncEventRPCJSONValue.init))
        case .string(let string):
            self = .string(string)
        case .number(let number):
            self = .number(number)
        case .bool(let bool):
            self = .bool(bool)
        case .null:
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .object(let object):
            try container.encode(object)
        case .array(let array):
            try container.encode(array)
        case .string(let string):
            try container.encode(string)
        case .number(let number):
            try container.encode(number)
        case .bool(let bool):
            try container.encode(bool)
        case .null:
            try container.encodeNil()
        }
    }
}
