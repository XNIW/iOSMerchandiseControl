import Foundation

/// Durable retry decisions use structured transport facts, never diagnostics.
nonisolated struct AutomaticSyncFailure: Error, Codable, Equatable, Sendable {
    enum Disposition: String, Codable, Sendable { case transient, stable, unknown }
    enum Category: String, Codable, Sendable {
        case network, timeout, rateLimited, server, authentication, authorization
        case schema, payload, integrity, cancelled, unknown
    }

    let disposition: Disposition
    let category: Category
    let httpStatus: Int?
    let urlErrorCode: Int?
    let sqlState: String?
    let retryAfterUntil: Date?

    init(disposition: Disposition, category: Category, httpStatus: Int? = nil,
         urlErrorCode: Int? = nil, sqlState: String? = nil, retryAfterUntil: Date? = nil) {
        self.disposition = disposition
        self.category = category
        self.httpStatus = httpStatus
        self.urlErrorCode = urlErrorCode
        self.sqlState = sqlState
        self.retryAfterUntil = retryAfterUntil
    }

    static func http(status: Int, retryAfterUntil: Date? = nil) -> Self {
        let disposition: Disposition
        let category: Category
        switch status {
        case 408: disposition = .transient; category = .timeout
        case 429: disposition = .transient; category = .rateLimited
        case 500, 502, 503, 504: disposition = .transient; category = .server
        case 401: disposition = .stable; category = .authentication
        case 403: disposition = .stable; category = .authorization
        case 400..<500: disposition = .stable; category = .payload
        default: disposition = .unknown; category = .unknown
        }
        return Self(disposition: disposition, category: category, httpStatus: status,
            retryAfterUntil: retryAfterUntil)
    }

    static func classify(_ error: any Error) -> Self {
        if let failure = error as? Self { return failure }
        if error is CancellationError { return Self(disposition: .stable, category: .cancelled) }
        if let error = error as? URLError {
            let category: Category
            let disposition: Disposition
            switch error.code {
            case .timedOut: disposition = .transient; category = .timeout
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff,
                 .dataNotAllowed, .callIsActive:
                disposition = .transient; category = .network
            case .cancelled: disposition = .stable; category = .cancelled
            default: disposition = .unknown; category = .unknown
            }
            return Self(disposition: disposition, category: category, urlErrorCode: error.code.rawValue)
        }
        if let error = error as? SupabaseTransportClientError {
            switch error {
            case .networkError(let status, _):
                if let status { return .http(status: status) }
                // Legacy network wrappers have no URL error code. They prove
                // a network failure, but never infer its subtype from text.
                return Self(disposition: .transient, category: .network)
            case .permissionDeniedOrRLS(let status, let code, _):
                return Self(disposition: .stable, category: .authorization, httpStatus: status, sqlState: code)
            case .sessionMissing: return Self(disposition: .stable, category: .authentication)
            case .schemaDrift, .decodingError, .configMissing, .invalidConfig:
                return Self(disposition: .stable, category: .schema)
            case .unknown: return Self(disposition: .unknown, category: .unknown)
            }
        }
        if error is Task126OwnerStoreGateError || error is ShopSyncRecoveryContractError
            || error is AtomicGenerationRecoveryError || error is SyncStoreGenerationError {
            return Self(disposition: .stable, category: .integrity)
        }
        if error is DecodingError || error is EncodingError {
            return Self(disposition: .stable, category: .payload)
        }
        return Self(disposition: .unknown, category: .unknown)
    }

    var hasValidPersistentFacts: Bool {
        guard retryAfterUntil.map({ $0.timeIntervalSince1970.isFinite && $0.timeIntervalSince1970 > 0 }) ?? true,
              sqlState.map({ $0.count <= 16 && !$0.isEmpty && $0.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber) } }) ?? true else {
            return false
        }
        if let httpStatus {
            let expected = Self.http(status: httpStatus)
            guard expected.disposition == disposition, expected.category == category else { return false }
        }
        if let urlErrorCode {
            let expected = Self.classify(URLError(URLError.Code(rawValue: urlErrorCode)))
            guard expected.disposition == disposition, expected.category == category else { return false }
        }
        switch disposition {
        case .transient: return [.network, .timeout, .rateLimited, .server].contains(category)
        case .unknown: return category == .unknown
        case .stable: return ![.network, .timeout, .rateLimited, .server, .unknown].contains(category)
        }
    }
}

nonisolated struct AutomaticSyncRetryDecision: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case none
        case retryAfter(TimeInterval)
    }

    let action: Action
    let reason: String

    static func none(_ reason: String) -> AutomaticSyncRetryDecision {
        AutomaticSyncRetryDecision(action: .none, reason: reason)
    }

    static func retry(after delay: TimeInterval, reason: String) -> AutomaticSyncRetryDecision {
        AutomaticSyncRetryDecision(action: .retryAfter(delay), reason: reason)
    }
}

nonisolated struct AutomaticSyncRetryPolicy: Sendable {
    typealias Sleeper = @Sendable (UInt64) async throws -> Void

    let maxBusyAttempts: Int
    let busyDelay: TimeInterval
    let sleeper: Sleeper

    init(
        maxBusyAttempts: Int = 1,
        busyDelay: TimeInterval = 2,
        sleeper: @escaping Sleeper = { nanoseconds in
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    ) {
        self.maxBusyAttempts = maxBusyAttempts
        self.busyDelay = busyDelay
        self.sleeper = sleeper
    }

    func decisionForBusy(attempt: Int, isBackground: Bool) -> AutomaticSyncRetryDecision {
        guard !isBackground else { return .none("background") }
        guard attempt < maxBusyAttempts else { return .none("max_busy_attempts") }
        return .retry(after: busyDelay, reason: "busy")
    }

    func decisionForAuthBlocked() -> AutomaticSyncRetryDecision {
        .none("auth_blocked")
    }

    func sleep(for decision: AutomaticSyncRetryDecision) async throws {
        guard case .retryAfter(let delay) = decision.action else { return }
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await sleeper(nanoseconds)
    }
}
