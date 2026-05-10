import Foundation

nonisolated enum SupabaseManualSyncSemiAutomaticState: String, Equatable, Sendable, CaseIterable {
    case idle
    case suggestedCheck
    case checking
    case noChanges
    case changesFound
    case reviewing
    case blockedAuth
    case staleOrConflict
    case recoverableError
}

nonisolated enum SupabaseManualSyncSemiAutomaticBlockReason: Equatable, Sendable {
    case noCloudCheckCapability
    case debounce
    case cooldown
    case recoverableErrorBackoff
    case running
    case authOrOwnerMissing
    case stagedPlanUnresolved
}

nonisolated enum SupabaseManualSyncSemiAutomaticDecision: Equatable, Sendable {
    case allowed
    case blocked(SupabaseManualSyncSemiAutomaticBlockReason)
}

nonisolated struct SupabaseManualSyncSemiAutomaticPolicy: Equatable, Sendable {
    static let defaultForegroundCooldown: TimeInterval = 30 * 60
    static let defaultForegroundDebounce: TimeInterval = 2
    static let defaultRecoverableErrorBackoff: TimeInterval = 10 * 60

    var foregroundCooldown: TimeInterval
    var foregroundDebounce: TimeInterval
    var recoverableErrorBackoff: TimeInterval

    init(
        foregroundCooldown: TimeInterval = Self.defaultForegroundCooldown,
        foregroundDebounce: TimeInterval = Self.defaultForegroundDebounce,
        recoverableErrorBackoff: TimeInterval = Self.defaultRecoverableErrorBackoff
    ) {
        self.foregroundCooldown = max(0, foregroundCooldown)
        self.foregroundDebounce = max(0, foregroundDebounce)
        self.recoverableErrorBackoff = max(0, recoverableErrorBackoff)
    }

    func foregroundCheckDecision(
        now: Date,
        lastCheckAt: Date?,
        lastAttemptAt: Date?,
        lastRecoverableErrorAt: Date?,
        supportsCloudCheck: Bool,
        isRunning: Bool,
        isAuthenticated: Bool,
        ownerUserID: UUID?,
        hasUnresolvedStagedPlan: Bool
    ) -> SupabaseManualSyncSemiAutomaticDecision {
        guard supportsCloudCheck else {
            return .blocked(.noCloudCheckCapability)
        }
        guard !isRunning else {
            return .blocked(.running)
        }
        guard isAuthenticated, ownerUserID != nil else {
            return .blocked(.authOrOwnerMissing)
        }
        guard !hasUnresolvedStagedPlan else {
            return .blocked(.stagedPlanUnresolved)
        }
        if let lastAttemptAt,
           now.timeIntervalSince(lastAttemptAt) < foregroundDebounce {
            return .blocked(.debounce)
        }
        if let lastRecoverableErrorAt,
           now.timeIntervalSince(lastRecoverableErrorAt) < recoverableErrorBackoff {
            return .blocked(.recoverableErrorBackoff)
        }
        if let lastCheckAt,
           now.timeIntervalSince(lastCheckAt) < foregroundCooldown {
            return .blocked(.cooldown)
        }
        return .allowed
    }
}
