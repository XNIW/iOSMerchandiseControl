import Foundation

protocol SyncEventRecording: Sendable {
    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult
}

nonisolated struct SyncEventRecordRequest: Sendable, Equatable {
    let domain: String
    let eventType: String
    let changedCount: Int
    let entityIDs: SyncEventJSONValue
    let metadata: SyncEventJSONValue
    let source: String?
    let sourceDeviceID: String?
    let batchID: UUID?
    let clientEventID: String

    init(
        domain: String,
        eventType: String,
        changedCount: Int,
        entityIDs: SyncEventJSONValue,
        metadata: SyncEventJSONValue,
        source: String? = nil,
        sourceDeviceID: String? = nil,
        batchID: UUID? = nil,
        clientEventID: String
    ) {
        self.domain = domain
        self.eventType = eventType
        self.changedCount = changedCount
        self.entityIDs = entityIDs
        self.metadata = metadata
        self.source = source
        self.sourceDeviceID = sourceDeviceID
        self.batchID = batchID
        self.clientEventID = clientEventID
    }
}

nonisolated enum SyncEventRecordResult: Sendable, Equatable {
    case recorded(RemoteSyncEventRow)
    case noOp(RemoteSyncEventRow)

    var row: RemoteSyncEventRow {
        switch self {
        case .recorded(let row), .noOp(let row):
            return row
        }
    }

    var plannedOutboxStatus: SyncEventOutboxStatus {
        .sent
    }
}

nonisolated struct SyncEventRecordFailure: Sendable, Equatable {
    let code: String?
    let message: String

    init(code: String? = nil, message: String) {
        self.code = Self.trimmedOptional(code)
        self.message = SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(message)
            ?? "Sync event recorder error."
    }

    private static func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

nonisolated enum SyncEventRecordError: Error, Sendable, Equatable {
    case auth(SyncEventRecordFailure)
    case schema(SyncEventRecordFailure)
    case contract(SyncEventRecordFailure)
    case network(SyncEventRecordFailure)
    case unknown(SyncEventRecordFailure)

    nonisolated enum Kind: String, Sendable, Equatable {
        case auth
        case schema
        case contract
        case network
        case unknown
    }

    var kind: Kind {
        switch self {
        case .auth:
            return .auth
        case .schema:
            return .schema
        case .contract:
            return .contract
        case .network:
            return .network
        case .unknown:
            return .unknown
        }
    }

    var failure: SyncEventRecordFailure {
        switch self {
        case .auth(let failure),
             .schema(let failure),
             .contract(let failure),
             .network(let failure),
             .unknown(let failure):
            return failure
        }
    }

    var plannedOutboxStatus: SyncEventOutboxStatus {
        switch self {
        case .contract:
            return .blockedContract
        case .auth:
            return .blockedAuth
        case .schema:
            return .blockedSchema
        case .network, .unknown:
            return .failedRetryable
        }
    }

    var plannedOutboxErrorKind: SyncEventOutboxErrorKind {
        switch self {
        case .contract:
            return .contract
        case .auth:
            return .auth
        case .schema:
            return .schema
        case .network:
            return .network
        case .unknown:
            return .unknown
        }
    }

    static func classified(code: String? = nil, message: String) -> SyncEventRecordError {
        let failure = SyncEventRecordFailure(code: code, message: message)
        let normalizedCode = (failure.code ?? "").lowercased()
        let normalizedMessage = failure.message.lowercased()
        let normalized = "\(normalizedCode) \(normalizedMessage)"

        if normalizedCode == "401"
            || normalizedCode == "403"
            || normalizedCode == "42501"
            || normalized.contains("session missing")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden")
            || normalized.contains("permission denied")
            || normalized.contains("row-level security")
            || normalized.contains("rls") {
            return .auth(failure)
        }

        if normalizedCode == "42883"
            || normalizedCode == "42p01"
            || normalizedCode == "42703"
            || normalizedCode == "pgrst202"
            || normalizedCode == "pgrst204"
            || normalized.contains("function missing")
            || normalized.contains("missing function")
            || normalized.contains("column missing")
            || normalized.contains("missing column")
            || normalized.contains("missing required")
            || normalized.contains("decode")
            || normalized.contains("decoding") {
            return .schema(failure)
        }

        if normalizedCode == "22023"
            || normalizedCode == "payloadvalidation"
            || normalized.contains("payloadvalidation")
            || normalized.contains("payload validation")
            || normalized.contains("changed_count")
            || normalized.contains("validator")
            || normalized.contains("contract") {
            return .contract(failure)
        }

        if normalized.contains("timeout")
            || normalized.contains("offline")
            || normalized.contains("not connected")
            || normalized.contains("network")
            || normalizedCode.hasPrefix("5") {
            return .network(failure)
        }

        return .unknown(failure)
    }
}

nonisolated struct SyncEventRecordValidationPolicy: Sendable, Equatable {
    static let standard = SyncEventRecordValidationPolicy()

    let maxJSONDepth: Int
    let maxTopLevelKeys: Int
    let maxEstimatedBytes: Int
    let maxEntityIDsEstimatedBytes: Int
    let maxArrayElements: Int
    let maxEntityIDsArrayElements: Int
    let massiveIdentifierListThreshold: Int

    init(
        maxJSONDepth: Int = 3,
        maxTopLevelKeys: Int = 20,
        maxEstimatedBytes: Int = 4 * 1_024,
        maxEntityIDsEstimatedBytes: Int = 16 * 1_024,
        maxArrayElements: Int = 100,
        maxEntityIDsArrayElements: Int = 250,
        massiveIdentifierListThreshold: Int = 20
    ) {
        self.maxJSONDepth = max(1, maxJSONDepth)
        self.maxTopLevelKeys = max(1, maxTopLevelKeys)
        self.maxEstimatedBytes = max(1, maxEstimatedBytes)
        self.maxEntityIDsEstimatedBytes = max(1, maxEntityIDsEstimatedBytes)
        self.maxArrayElements = max(0, maxArrayElements)
        self.maxEntityIDsArrayElements = max(0, maxEntityIDsArrayElements)
        self.massiveIdentifierListThreshold = max(2, massiveIdentifierListThreshold)
    }
}

nonisolated struct SyncEventRecordValidator: Sendable, Equatable {
    private static let maxClientEventIDLength = 160
    private static let maxSourceDeviceIDLength = 160

    let policy: SyncEventRecordValidationPolicy

    init(policy: SyncEventRecordValidationPolicy = .standard) {
        self.policy = policy
    }

    func validate(_ request: SyncEventRecordRequest) throws {
        guard !trimmed(request.domain).isEmpty else {
            throw contract("missing_domain", "domain is required.")
        }

        guard !trimmed(request.eventType).isEmpty else {
            throw contract("missing_event_type", "eventType is required.")
        }

        guard (0...1_000).contains(request.changedCount) else {
            throw contract("changed_count_limit", "changedCount must be between 0 and 1000.")
        }

        guard !trimmed(request.clientEventID).isEmpty else {
            throw contract("missing_client_event_id", "clientEventID is required.")
        }

        guard trimmed(request.clientEventID).count <= Self.maxClientEventIDLength else {
            throw contract("client_event_id_length", "clientEventID must be at most 160 characters.")
        }

        if let sourceDeviceID = trimmedOptional(request.sourceDeviceID),
           sourceDeviceID.count > Self.maxSourceDeviceIDLength {
            throw contract("source_device_id_length", "sourceDeviceID must be at most 160 characters.")
        }

        try validateEntityIDsContract(request.entityIDs)
        try validateMetadataContract(request.metadata)
        try validateJSON(request.entityIDs, fieldName: "entity_ids")
        try validateJSON(request.metadata, fieldName: "metadata")
    }

    private func validateEntityIDsContract(_ value: SyncEventJSONValue) throws {
        switch value {
        case .null:
            return
        case .object(let object):
            for (key, child) in object {
                guard isAllowedEntityIDsKey(key) else {
                    throw contract("entity_ids_key", "entity_ids contains an unsupported key.")
                }

                guard case .array(let array) = child else {
                    throw contract("entity_ids_shape", "entity_ids values must be arrays.")
                }

                guard array.count <= policy.maxEntityIDsArrayElements else {
                    throw contract("entity_ids_array_budget", "entity_ids exceeds array element budget.")
                }

                for value in array {
                    guard case .string(let id) = value, isRPCUUID(id) else {
                        throw contract("entity_ids_uuid", "entity_ids values must be UUID strings.")
                    }
                }
            }
        case .array, .string, .number, .bool:
            throw contract("entity_ids_shape", "entity_ids must be a JSON object or null.")
        }
    }

    private func validateMetadataContract(_ value: SyncEventJSONValue) throws {
        guard case .object = value else {
            throw contract("metadata_shape", "metadata must be a JSON object.")
        }
    }

    private func validateJSON(_ value: SyncEventJSONValue, fieldName: String) throws {
        if case .object(let object) = value, object.count > policy.maxTopLevelKeys {
            throw contract(
                "\(fieldName)_top_level_keys",
                "\(fieldName) exceeds top-level key budget."
            )
        }

        let estimatedBytes = estimatedByteCount(value)
        let byteBudget = fieldName == "entity_ids"
            ? policy.maxEntityIDsEstimatedBytes
            : policy.maxEstimatedBytes
        guard estimatedBytes <= byteBudget else {
            throw contract(
                "\(fieldName)_byte_budget",
                "\(fieldName) exceeds local byte budget."
            )
        }

        try walk(value, fieldName: fieldName, depth: 1)
    }

    private func walk(
        _ value: SyncEventJSONValue,
        fieldName: String,
        depth: Int
    ) throws {
        guard depth <= policy.maxJSONDepth else {
            throw contract(
                "\(fieldName)_depth",
                "\(fieldName) exceeds local depth budget."
            )
        }

        switch value {
        case .object(let object):
            for (key, child) in object {
                if fieldName == "metadata", isForbiddenMetadataKey(key) {
                    throw contract(
                        "metadata_forbidden_key",
                        "metadata contains a forbidden key."
                    )
                }
                if containsSensitiveToken(key) {
                    throw contract(
                        "\(fieldName)_sensitive_key",
                        "\(fieldName) contains a sensitive key."
                    )
                }
                try walk(child, fieldName: fieldName, depth: depth + 1)
            }
        case .array(let array):
            let arrayBudget = fieldName == "entity_ids"
                ? policy.maxEntityIDsArrayElements
                : policy.maxArrayElements
            guard array.count <= arrayBudget else {
                throw contract(
                    "\(fieldName)_array_budget",
                    "\(fieldName) exceeds array element budget."
                )
            }
            if fieldName != "entity_ids", isMassiveIdentifierList(array) {
                throw contract(
                    "\(fieldName)_identifier_list",
                    "\(fieldName) contains a massive business identifier list."
                )
            }
            for child in array {
                try walk(child, fieldName: fieldName, depth: depth + 1)
            }
        case .string(let string):
            if containsSensitiveToken(string) || containsQueryString(string) {
                throw contract(
                    "\(fieldName)_sensitive_value",
                    "\(fieldName) contains sensitive transport data."
                )
            }
        case .number, .bool, .null:
            break
        }
    }

    private func isAllowedEntityIDsKey(_ value: String) -> Bool {
        switch value {
        case "supplier_ids", "category_ids", "product_ids", "price_ids":
            return true
        default:
            return false
        }
    }

    private func isForbiddenMetadataKey(_ value: String) -> Bool {
        switch value.lowercased() {
        case "barcode",
             "email",
             "excel",
             "path",
             "price",
             "product_name",
             "supplier_name",
             "category_name",
             "token":
            return true
        default:
            return false
        }
    }

    private func isMassiveIdentifierList(_ array: [SyncEventJSONValue]) -> Bool {
        let strings = array.compactMap { value -> String? in
            guard case .string(let string) = value else { return nil }
            return trimmed(string)
        }
        guard strings.count == array.count,
              strings.count >= policy.massiveIdentifierListThreshold else {
            return false
        }

        let identifierCount = strings.filter { isUUID($0) || isBarcodeLike($0) }.count
        return identifierCount >= policy.massiveIdentifierListThreshold
    }

    private func estimatedByteCount(_ value: SyncEventJSONValue) -> Int {
        switch value {
        case .object(let object):
            let entries = object.map { key, child in
                stringByteCount(key) + 1 + estimatedByteCount(child)
            }
            return 2 + entries.reduce(0, +) + max(0, entries.count - 1)
        case .array(let array):
            let entries = array.map(estimatedByteCount)
            return 2 + entries.reduce(0, +) + max(0, entries.count - 1)
        case .string(let string):
            return stringByteCount(string)
        case .number(let number):
            return String(number).utf8.count
        case .bool(let bool):
            return bool ? 4 : 5
        case .null:
            return 4
        }
    }

    private func stringByteCount(_ value: String) -> Int {
        let escapedByteCount = value.utf8.reduce(0) { total, byte in
            switch byte {
            case 0x22, 0x5C:
                return total + 2
            case 0x00...0x1F:
                return total + 6
            default:
                return total + 1
            }
        }
        return escapedByteCount + 2
    }

    private func containsSensitiveToken(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        if lowercased.contains("authorization")
            || lowercased.contains("bearer")
            || lowercased.contains("apikey")
            || lowercased.contains("api_key")
            || lowercased.contains("access_token")
            || lowercased.contains("refresh_token")
            || lowercased.contains("jwt")
            || lowercased.contains("token")
            || lowercased.contains("token=") {
            return true
        }

        return value.range(
            of: #"\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#,
            options: .regularExpression
        ) != nil
    }

    private func containsQueryString(_ value: String) -> Bool {
        value.range(
            of: #"[?&][A-Za-z0-9_.~-]+="#,
            options: .regularExpression
        ) != nil
    }

    private func isUUID(_ value: String) -> Bool {
        value.range(
            of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
            options: .regularExpression
        ) != nil
    }

    private func isRPCUUID(_ value: String) -> Bool {
        value.range(
            of: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$"#,
            options: .regularExpression
        ) != nil
    }

    private func isBarcodeLike(_ value: String) -> Bool {
        value.range(of: #"^\d{8,}$"#, options: .regularExpression) != nil
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func trimmedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = trimmed(value)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func contract(_ code: String, _ message: String) -> SyncEventRecordError {
        .contract(SyncEventRecordFailure(code: code, message: message))
    }
}

nonisolated struct SyncEventRecordDryRunRecorder: SyncEventRecording, Sendable, Equatable {
    nonisolated enum ResponsePolicy: Sendable, Equatable {
        case recorded
        case idempotentNoOp
    }

    nonisolated enum Fixture: Sendable, Equatable {
        case responseJSON(String, ResponsePolicy)
        case failure(SyncEventRecordError)
        case classifiedFailure(code: String?, message: String)
    }

    let fixture: Fixture
    let validator: SyncEventRecordValidator

    init(
        fixture: Fixture,
        validator: SyncEventRecordValidator = SyncEventRecordValidator()
    ) {
        self.fixture = fixture
        self.validator = validator
    }

    init(
        responseJSON: String,
        responsePolicy: ResponsePolicy = .recorded,
        validator: SyncEventRecordValidator = SyncEventRecordValidator()
    ) {
        self.init(
            fixture: .responseJSON(responseJSON, responsePolicy),
            validator: validator
        )
    }

    func record(_ request: SyncEventRecordRequest) async throws -> SyncEventRecordResult {
        try validator.validate(request)

        switch fixture {
        case .responseJSON(let json, let responsePolicy):
            return try Self.decodeResult(
                from: json,
                request: request,
                responsePolicy: responsePolicy
            )
        case .failure(let error):
            throw error
        case .classifiedFailure(let code, let message):
            throw SyncEventRecordError.classified(code: code, message: message)
        }
    }

    private static func decodeResult(
        from json: String,
        request: SyncEventRecordRequest,
        responsePolicy: ResponsePolicy
    ) throws -> SyncEventRecordResult {
        let response: SyncEventRowsResponse
        do {
            response = try JSONDecoder().decode(SyncEventRowsResponse.self, from: Data(json.utf8))
        } catch {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(code: "response_decode", message: "Unable to decode sync event response.")
            )
        }

        guard let firstRow = response.rows.first else {
            throw SyncEventRecordError.schema(
                SyncEventRecordFailure(code: "empty_response", message: "Sync event response contained no rows.")
            )
        }

        try validateClientEventIDs(in: response.rows, request: request)

        switch responsePolicy {
        case .recorded:
            return .recorded(firstRow)
        case .idempotentNoOp:
            guard firstRow.clientEventID == request.clientEventID else {
                return .recorded(firstRow)
            }
            return .noOp(firstRow)
        }
    }

    private static func validateClientEventIDs(
        in rows: [RemoteSyncEventRow],
        request: SyncEventRecordRequest
    ) throws {
        if rows.count == 1 {
            guard let clientEventID = rows[0].clientEventID else {
                return
            }
            guard clientEventID == request.clientEventID else {
                throw clientEventIDMismatch()
            }
            return
        }

        guard rows.allSatisfy({ $0.clientEventID == request.clientEventID }) else {
            throw clientEventIDMismatch()
        }
    }

    private static func clientEventIDMismatch() -> SyncEventRecordError {
        .schema(
            SyncEventRecordFailure(
                code: "client_event_id_mismatch",
                message: "Response client event id did not match the request."
            )
        )
    }
}
