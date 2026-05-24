import Foundation

nonisolated enum SyncEventOutboxStatus: String, Sendable, Equatable, CaseIterable {
    case pending
    case sending
    case sent
    case failedRetryable
    case blockedContract
    case blockedAuth
    case blockedSchema
    case dead
    case localOnly
}

nonisolated enum SyncEventOutboxErrorKind: String, Sendable, Equatable, CaseIterable {
    case network
    case offline
    case timeout
    case auth
    case schema
    case contract
    case unknown
    case none
}

nonisolated struct SyncEventOutboxFailure: Sendable, Equatable {
    let kind: SyncEventOutboxErrorKind
    let code: String?
    let message: String?

    init(
        kind: SyncEventOutboxErrorKind,
        code: String? = nil,
        message: String? = nil
    ) {
        self.kind = kind
        self.code = code
        self.message = message
    }
}

nonisolated struct SyncEventOutboxSendingRecoveryResult: Sendable, Equatable {
    let scannedCount: Int
    let recoveredCount: Int
    let exhaustedCount: Int
    let skippedFreshSendingCount: Int

    init(
        scannedCount: Int = 0,
        recoveredCount: Int = 0,
        exhaustedCount: Int = 0,
        skippedFreshSendingCount: Int = 0
    ) {
        self.scannedCount = scannedCount
        self.recoveredCount = recoveredCount
        self.exhaustedCount = exhaustedCount
        self.skippedFreshSendingCount = skippedFreshSendingCount
    }

    var hasChanges: Bool {
        recoveredCount > 0 || exhaustedCount > 0
    }
}

nonisolated struct SyncEventOutboxState: Sendable, Equatable {
    let status: SyncEventOutboxStatus
    let attemptCount: Int
    let maxAttempts: Int
    let nextRetryAt: Date
    let lastAttemptAt: Date?
    let lastErrorCode: String?
    let lastErrorKind: SyncEventOutboxErrorKind
    let lastErrorMessageSanitized: String?
    let updatedAt: Date
    let sentAt: Date?

    init(
        status: SyncEventOutboxStatus,
        attemptCount: Int,
        maxAttempts: Int,
        nextRetryAt: Date,
        lastAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        lastErrorKind: SyncEventOutboxErrorKind = .none,
        lastErrorMessageSanitized: String? = nil,
        updatedAt: Date,
        sentAt: Date? = nil
    ) {
        self.status = status
        self.attemptCount = attemptCount
        self.maxAttempts = max(1, maxAttempts)
        self.nextRetryAt = nextRetryAt
        self.lastAttemptAt = lastAttemptAt
        self.lastErrorCode = lastErrorCode
        self.lastErrorKind = lastErrorKind
        self.lastErrorMessageSanitized = lastErrorMessageSanitized
        self.updatedAt = updatedAt
        self.sentAt = sentAt
    }
}

nonisolated enum SyncEventOutboxStateMachine {
    static let defaultSendingStaleInterval: TimeInterval = 10 * 60
    static let staleSendingRecoveryErrorCode = "sending_stale_recovered"
    private static let staleSendingRecoveryFailure = SyncEventOutboxFailure(
        kind: .timeout,
        code: staleSendingRecoveryErrorCode,
        message: "Stale sending outbox entry recovered locally."
    )

    static func isRetryable(
        status: SyncEventOutboxStatus,
        attemptCount: Int,
        maxAttempts: Int,
        nextRetryAt: Date,
        now: Date,
        entryOwnerUserID: String,
        currentOwnerUserID: String
    ) -> Bool {
        guard entryOwnerUserID == currentOwnerUserID else { return false }
        guard status == .pending || status == .failedRetryable else { return false }
        guard attemptCount < maxAttempts else { return false }
        return nextRetryAt <= now
    }

    static func isRetryable(
        state: SyncEventOutboxState,
        entryOwnerUserID: String,
        currentOwnerUserID: String,
        now: Date
    ) -> Bool {
        isRetryable(
            status: state.status,
            attemptCount: state.attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            now: now,
            entryOwnerUserID: entryOwnerUserID,
            currentOwnerUserID: currentOwnerUserID
        )
    }

    static func isTerminal(_ status: SyncEventOutboxStatus) -> Bool {
        switch status {
        case .sent, .blockedContract, .blockedAuth, .blockedSchema, .dead, .localOnly:
            return true
        case .pending, .sending, .failedRetryable:
            return false
        }
    }

    static func isSendingStale(
        _ state: SyncEventOutboxState,
        now: Date,
        staleInterval: TimeInterval = defaultSendingStaleInterval
    ) -> Bool {
        guard state.status == .sending else { return false }
        let referenceDate = state.lastAttemptAt ?? state.updatedAt
        return now.timeIntervalSince(referenceDate) >= max(0, staleInterval)
    }

    static func recoverStaleSending(_ state: SyncEventOutboxState, now: Date) -> SyncEventOutboxState {
        guard state.status == .sending else { return state }
        guard state.attemptCount < state.maxAttempts else {
            return toDeadWhenAttemptsExhausted(
                state,
                failure: staleSendingRecoveryFailure,
                now: now
            )
        }

        return SyncEventOutboxState(
            status: .failedRetryable,
            attemptCount: state.attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: now,
            lastAttemptAt: state.lastAttemptAt,
            lastErrorCode: staleSendingRecoveryFailure.code,
            lastErrorKind: staleSendingRecoveryFailure.kind,
            lastErrorMessageSanitized: SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(
                staleSendingRecoveryFailure.message
            ),
            updatedAt: now,
            sentAt: nil
        )
    }

    static func toSending(_ state: SyncEventOutboxState, now: Date) -> SyncEventOutboxState {
        SyncEventOutboxState(
            status: .sending,
            attemptCount: state.attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            lastAttemptAt: now,
            lastErrorCode: nil,
            lastErrorKind: .none,
            lastErrorMessageSanitized: nil,
            updatedAt: now,
            sentAt: state.sentAt
        )
    }

    static func toSent(_ state: SyncEventOutboxState, now: Date) -> SyncEventOutboxState {
        SyncEventOutboxState(
            status: .sent,
            attemptCount: state.attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            lastAttemptAt: state.lastAttemptAt,
            lastErrorCode: nil,
            lastErrorKind: .none,
            lastErrorMessageSanitized: nil,
            updatedAt: now,
            sentAt: now
        )
    }

    static func toFailedRetryable(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date,
        nextRetryAt: Date
    ) -> SyncEventOutboxState {
        let nextAttemptCount = state.attemptCount + 1
        if nextAttemptCount >= state.maxAttempts {
            return toDead(
                state,
                failure: failure,
                now: now,
                attemptCount: nextAttemptCount
            )
        }

        return SyncEventOutboxState(
            status: .failedRetryable,
            attemptCount: nextAttemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: nextRetryAt,
            lastAttemptAt: now,
            lastErrorCode: failure.code,
            lastErrorKind: failure.kind,
            lastErrorMessageSanitized: SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(failure.message),
            updatedAt: now,
            sentAt: nil
        )
    }

    static func toBlockedContract(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date
    ) -> SyncEventOutboxState {
        blockedState(.blockedContract, state: state, failure: failure, now: now)
    }

    static func toBlockedAuth(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date
    ) -> SyncEventOutboxState {
        blockedState(.blockedAuth, state: state, failure: failure, now: now)
    }

    static func toBlockedSchema(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date
    ) -> SyncEventOutboxState {
        blockedState(.blockedSchema, state: state, failure: failure, now: now)
    }

    static func toDeadWhenAttemptsExhausted(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date
    ) -> SyncEventOutboxState {
        guard state.attemptCount >= state.maxAttempts else {
            return state
        }
        return toDead(state, failure: failure, now: now, attemptCount: state.attemptCount)
    }

    static func transitionAfterFailure(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date,
        retryDelay: TimeInterval = 60
    ) -> SyncEventOutboxState {
        switch failure.kind {
        case .network, .offline, .timeout, .unknown:
            return toFailedRetryable(
                state,
                failure: failure,
                now: now,
                nextRetryAt: now.addingTimeInterval(retryDelay)
            )
        case .auth:
            return toBlockedAuth(state, failure: failure, now: now)
        case .schema:
            return toBlockedSchema(state, failure: failure, now: now)
        case .contract:
            return toBlockedContract(state, failure: failure, now: now)
        case .none:
            return toFailedRetryable(
                state,
                failure: SyncEventOutboxFailure(kind: .unknown, code: failure.code, message: failure.message),
                now: now,
                nextRetryAt: now.addingTimeInterval(retryDelay)
            )
        }
    }

    static func resetLocalOnly(_ state: SyncEventOutboxState, now: Date) -> SyncEventOutboxState {
        SyncEventOutboxState(
            status: .localOnly,
            attemptCount: state.attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            lastAttemptAt: state.lastAttemptAt,
            lastErrorCode: state.lastErrorCode,
            lastErrorKind: state.lastErrorKind,
            lastErrorMessageSanitized: state.lastErrorMessageSanitized,
            updatedAt: now,
            sentAt: state.sentAt
        )
    }

    private static func blockedState(
        _ status: SyncEventOutboxStatus,
        state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date
    ) -> SyncEventOutboxState {
        SyncEventOutboxState(
            status: status,
            attemptCount: state.attemptCount + 1,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            lastAttemptAt: now,
            lastErrorCode: failure.code,
            lastErrorKind: failure.kind,
            lastErrorMessageSanitized: SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(failure.message),
            updatedAt: now,
            sentAt: nil
        )
    }

    private static func toDead(
        _ state: SyncEventOutboxState,
        failure: SyncEventOutboxFailure,
        now: Date,
        attemptCount: Int
    ) -> SyncEventOutboxState {
        SyncEventOutboxState(
            status: .dead,
            attemptCount: attemptCount,
            maxAttempts: state.maxAttempts,
            nextRetryAt: state.nextRetryAt,
            lastAttemptAt: now,
            lastErrorCode: failure.code,
            lastErrorKind: failure.kind,
            lastErrorMessageSanitized: SyncEventOutboxPrivacySanitizer.sanitizeErrorMessage(failure.message),
            updatedAt: now,
            sentAt: nil
        )
    }
}

nonisolated enum SyncEventOutboxPrivacySanitizer {
    static let defaultMessageLimit = 160
    static let defaultShapeLimit = 160

    static func sanitizeErrorMessage(_ value: String?, maxLength: Int = defaultMessageLimit) -> String? {
        guard let value else { return nil }
        var sanitized = normalizeWhitespace(value)
        guard !sanitized.isEmpty else { return nil }

        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"(?i)bearer\s+[A-Za-z0-9._~+/\-=]+"#,
            with: "[redacted]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"(?i)(authorization|access_token|refresh_token|apikey|api_key|jwt|token)\s*[:=]\s*[^\s&]+"#,
            with: "[redacted]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"\b[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\b"#,
            with: "[redacted]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            with: "[redacted-email]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"https?://[^\s]+"#,
            with: "[redacted-url]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"(?i)(^|[\s?&])([A-Za-z0-9_.~-]*(?:token|apikey|api_key|key|select|filter|eq)[A-Za-z0-9_.~-]*)=[^\s&]+"#,
            with: "$1[redacted-query]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#,
            with: "[redacted-id]"
        )
        sanitized = replacingMatches(
            in: sanitized,
            pattern: #"\b\d{8,}\b"#,
            with: "[redacted-id]"
        )

        sanitized = normalizeWhitespace(sanitized)
        guard !sanitized.isEmpty else { return nil }
        return capped(sanitized, maxLength: maxLength)
    }

    static func sanitizedShape(
        _ value: String,
        fallback: String,
        maxLength: Int = defaultShapeLimit
    ) -> (shape: String, wasRedacted: Bool) {
        let normalized = normalizeWhitespace(value)
        guard !normalized.isEmpty else {
            return ("empty", false)
        }

        if containsSuspiciousRawPayload(normalized) {
            return (fallback, true)
        }

        return (capped(normalized, maxLength: maxLength), false)
    }

    static func containsSuspiciousRawPayload(_ value: String) -> Bool {
        let normalized = normalizeWhitespace(value)
        let lowercased = normalized.lowercased()

        if lowercased.contains("authorization")
            || lowercased.contains("bearer")
            || lowercased.contains("apikey")
            || lowercased.contains("api_key")
            || lowercased.contains("jwt")
            || lowercased.contains("token")
            || lowercased.contains("access_token")
            || lowercased.contains("refresh_token") {
            return true
        }

        if normalized.range(
            of: #"\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b"#,
            options: [.regularExpression, .caseInsensitive]
        ) != nil {
            return true
        }

        if normalized.range(of: #"https?://"#, options: [.regularExpression, .caseInsensitive]) != nil
            || normalized.contains("?")
            || normalized.range(of: #"[?&][A-Za-z0-9_.~-]+="#, options: .regularExpression) != nil {
            return true
        }

        if matchCount(in: normalized, pattern: #"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}"#) > 0 {
            return true
        }

        if matchCount(in: normalized, pattern: #"\b\d{8,}\b"#) > 0 {
            return true
        }

        if normalized.count > 512 {
            return true
        }

        return normalized.contains("[") && normalized.contains(",")
    }

    static func countShape(kind: String, count: Int) -> String {
        let safeKind = normalizeWhitespace(kind)
            .filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "-" }
        let normalizedKind = safeKind.isEmpty ? "items" : safeKind
        return "\(normalizedKind):count=\(max(0, count))"
    }

    private static func capped(_ value: String, maxLength: Int) -> String {
        let safeMaxLength = max(1, maxLength)
        guard value.count > safeMaxLength else { return value }
        guard safeMaxLength > 3 else { return String(value.prefix(safeMaxLength)) }
        return String(value.prefix(safeMaxLength - 3)) + "..."
    }

    private static func normalizeWhitespace(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacingMatches(in value: String, pattern: String, with replacement: String) -> String {
        value.replacingOccurrences(
            of: pattern,
            with: replacement,
            options: .regularExpression
        )
    }

    private static func matchCount(in value: String, pattern: String) -> Int {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 0
        }

        return regex.numberOfMatches(
            in: value,
            range: NSRange(value.startIndex..<value.endIndex, in: value)
        )
    }
}
