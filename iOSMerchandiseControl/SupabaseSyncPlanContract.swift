import Foundation

nonisolated enum SupabaseSyncPlanState: String, Sendable, Equatable, CaseIterable {
    case ready
    case needsReview
    case blocked
    case stale
    case partial
    case failed
}

nonisolated enum SupabaseSyncPlanPrimaryAction: String, Sendable, Equatable, CaseIterable {
    case apply
    case recheck
    case openDatabase
    case signInAgain
    case none
}

nonisolated enum SupabaseSyncPlanSectionID: String, Sendable, Equatable, Hashable, CaseIterable {
    case attention
    case cloud = "fromCloud"
    case device = "fromDevice"
    case prices
    case activity
}

nonisolated enum SupabaseSyncPlanBlockingReason: String, Sendable, Equatable, Hashable, CaseIterable {
    case invalidLocalData
    case cloudConflict
    case accessOrSync
    case changedData
    case partialSync
}

nonisolated struct SupabaseSyncPlanCounters: Sendable, Equatable {
    var toApply: Int
    var applied: Int
    var skipped: Int
    var reviewNeeded: Int
    var blocked: Int
    var stale: Int
    var failed: Int

    init(
        toApply: Int = 0,
        applied: Int = 0,
        skipped: Int = 0,
        reviewNeeded: Int = 0,
        blocked: Int = 0,
        stale: Int = 0,
        failed: Int = 0
    ) {
        self.toApply = max(0, toApply)
        self.applied = max(0, applied)
        self.skipped = max(0, skipped)
        self.reviewNeeded = max(0, reviewNeeded)
        self.blocked = max(0, blocked)
        self.stale = max(0, stale)
        self.failed = max(0, failed)
    }
}

nonisolated struct SupabaseSyncPlanSection: Sendable, Equatable, Identifiable {
    var id: SupabaseSyncPlanSectionID
}

nonisolated struct SupabaseSyncPlan: Sendable, Equatable {
    var state: SupabaseSyncPlanState
    var canApply: Bool
    var primaryAction: SupabaseSyncPlanPrimaryAction
    var counters: SupabaseSyncPlanCounters
    var sections: [SupabaseSyncPlanSection]
    var blockingReasons: [SupabaseSyncPlanBlockingReason]
    var planFingerprint: String?
}

nonisolated enum SupabaseSyncPlanResolver {
    static func makePlan(
        counters: SupabaseSyncPlanCounters,
        requestedSections: [SupabaseSyncPlanSectionID],
        blockingReasons: [SupabaseSyncPlanBlockingReason] = [],
        explicitState: SupabaseSyncPlanState? = nil,
        planFingerprint: String? = nil
    ) -> SupabaseSyncPlan {
        let state = resolveState(
            counters: counters,
            explicitState: explicitState
        )
        let safeReasons = Array(Set(blockingReasons)).sorted { $0.rawValue < $1.rawValue }
        let sections = resolvedSections(
            state: state,
            requestedSections: requestedSections
        )
        let primaryAction = resolvePrimaryAction(
            state: state,
            counters: counters,
            blockingReasons: safeReasons
        )

        return SupabaseSyncPlan(
            state: state,
            canApply: state == .ready,
            primaryAction: primaryAction,
            counters: counters,
            sections: sections.map { SupabaseSyncPlanSection(id: $0) },
            blockingReasons: safeReasons,
            planFingerprint: planFingerprint
        )
    }

    static func resolveState(
        counters: SupabaseSyncPlanCounters,
        explicitState: SupabaseSyncPlanState? = nil
    ) -> SupabaseSyncPlanState {
        let explicit = explicitState.map { countersForExplicitState($0) } ?? SupabaseSyncPlanCounters()
        let merged = SupabaseSyncPlanCounters(
            toApply: counters.toApply,
            applied: counters.applied,
            skipped: counters.skipped,
            reviewNeeded: counters.reviewNeeded + explicit.reviewNeeded,
            blocked: counters.blocked + explicit.blocked,
            stale: counters.stale + explicit.stale,
            failed: counters.failed + explicit.failed
        )

        if merged.failed > 0 { return .failed }
        if explicitState == .partial { return .partial }
        if merged.stale > 0 { return .stale }
        if merged.blocked > 0 { return .blocked }
        if merged.reviewNeeded > 0 { return .needsReview }
        return .ready
    }

    private static func countersForExplicitState(_ state: SupabaseSyncPlanState) -> SupabaseSyncPlanCounters {
        switch state {
        case .failed:
            return SupabaseSyncPlanCounters(failed: 1)
        case .partial:
            return SupabaseSyncPlanCounters()
        case .stale:
            return SupabaseSyncPlanCounters(stale: 1)
        case .blocked:
            return SupabaseSyncPlanCounters(blocked: 1)
        case .needsReview:
            return SupabaseSyncPlanCounters(reviewNeeded: 1)
        case .ready:
            return SupabaseSyncPlanCounters()
        }
    }

    private static func resolvePrimaryAction(
        state: SupabaseSyncPlanState,
        counters: SupabaseSyncPlanCounters,
        blockingReasons: [SupabaseSyncPlanBlockingReason]
    ) -> SupabaseSyncPlanPrimaryAction {
        switch state {
        case .ready:
            return counters.toApply > 0 ? .apply : .none
        case .failed:
            return blockingReasons.contains(.accessOrSync) ? .signInAgain : .recheck
        case .partial, .stale:
            return .recheck
        case .blocked:
            if blockingReasons.contains(.accessOrSync) {
                return .signInAgain
            }
            if blockingReasons.contains(.invalidLocalData) {
                return .openDatabase
            }
            return .recheck
        case .needsReview:
            return .recheck
        }
    }

    private static func resolvedSections(
        state: SupabaseSyncPlanState,
        requestedSections: [SupabaseSyncPlanSectionID]
    ) -> [SupabaseSyncPlanSectionID] {
        var seen = Set<SupabaseSyncPlanSectionID>()
        var result: [SupabaseSyncPlanSectionID] = []

        func append(_ section: SupabaseSyncPlanSectionID) {
            guard seen.insert(section).inserted else { return }
            result.append(section)
        }

        if state != .ready {
            append(.attention)
        }
        for section in requestedSections {
            append(section)
        }
        return result
    }
}
