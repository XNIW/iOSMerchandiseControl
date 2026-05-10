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
    case cooldown
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

    var foregroundCooldown: TimeInterval

    init(foregroundCooldown: TimeInterval = Self.defaultForegroundCooldown) {
        self.foregroundCooldown = max(0, foregroundCooldown)
    }

    func foregroundCheckDecision(
        now: Date,
        lastCheckAt: Date?,
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
        if let lastCheckAt,
           now.timeIntervalSince(lastCheckAt) < foregroundCooldown {
            return .blocked(.cooldown)
        }
        return .allowed
    }
}
