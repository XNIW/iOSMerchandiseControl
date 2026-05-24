import Foundation

nonisolated enum CloudSyncOAuthStatus: Equatable, Sendable {
    case unavailable
    case signedOut
    case transitioning
    case signedIn
}

nonisolated enum CloudSyncRemoteAccessStatus: Equatable, Sendable {
    case unknown
    case available
    case accountNeedsCheck
    case cloudPermission
    case networkOffline
    case localSnapshotFailed
    case unknownFailure
}

nonisolated enum CloudSyncBaselineStatus: Equatable, Sendable {
    case unknown
    case absent
    case valid
    case stale
    case accountMismatch
    case incomplete
}

nonisolated enum CloudSyncReleaseErrorCategory: String, CaseIterable, Equatable, Sendable {
    case accountRequired
    case accountNeedsCheck
    case cloudPermission
    case networkOffline
    case localNeedsDownload
    case localPending
    case needsReview
    case ready
}

nonisolated enum CloudSyncOverviewPrimaryAction: Equatable, Sendable {
    case signIn
    case checkCloud
    case downloadDatabase
    case reviewItems
    case sendChanges
    case none
}

nonisolated struct CloudSyncOverviewInput: Equatable, Sendable {
    var oauthStatus: CloudSyncOAuthStatus
    var remoteAccessStatus: CloudSyncRemoteAccessStatus
    var baselineStatus: CloudSyncBaselineStatus
    var hasLocalPending: Bool
    var reviewItemCount: Int
    var isRunning: Bool

    init(
        oauthStatus: CloudSyncOAuthStatus,
        remoteAccessStatus: CloudSyncRemoteAccessStatus = .unknown,
        baselineStatus: CloudSyncBaselineStatus = .unknown,
        hasLocalPending: Bool = false,
        reviewItemCount: Int = 0,
        isRunning: Bool = false
    ) {
        self.oauthStatus = oauthStatus
        self.remoteAccessStatus = remoteAccessStatus
        self.baselineStatus = baselineStatus
        self.hasLocalPending = hasLocalPending
        self.reviewItemCount = max(0, reviewItemCount)
        self.isRunning = isRunning
    }
}

nonisolated struct CloudSyncOverviewState: Equatable, Sendable {
    var category: CloudSyncReleaseErrorCategory
    var primaryAction: CloudSyncOverviewPrimaryAction
    var allowsLocalWork: Bool
    var isBlocking: Bool
}

nonisolated enum CloudSyncProgressDomain: String, Equatable, Sendable {
    case catalog
    case prices
    case history
    case pending
    case outbox
}

nonisolated enum CloudSyncProgressPhase: String, Equatable, Sendable {
    case idle
    case checkingCloud
    case fetchingRemoteCounts
    case reviewingChanges
    case downloadingSuppliers
    case downloadingCategories
    case downloadingProducts
    case downloadingPriceHistory
    case applyingLocalDatabase
    case syncingHistorySessions
    case sendingLocalChanges
    case drainingSyncEvents
    case completed
    case completedWithWarnings
    case failed
    case cancelled
}

nonisolated struct CloudSyncProgressState: Equatable, Sendable {
    var phase: CloudSyncProgressPhase
    var domain: CloudSyncProgressDomain?
    var current: Int?
    var total: Int?
    var message: String
    var detailMessage: String?
    var startedAt: Date?
    var lastUpdatedAt: Date?
    var canCancel: Bool
    var isBlockingApply: Bool
    var allowsLocalWork: Bool

    var isActive: Bool {
        switch phase {
        case .idle, .completed, .completedWithWarnings, .failed, .cancelled:
            return false
        case .checkingCloud,
             .fetchingRemoteCounts,
             .reviewingChanges,
             .downloadingSuppliers,
             .downloadingCategories,
             .downloadingProducts,
             .downloadingPriceHistory,
             .applyingLocalDatabase,
             .syncingHistorySessions,
             .sendingLocalChanges,
             .drainingSyncEvents:
            return true
        }
    }

    var percentage: Double? {
        guard let current,
              let total,
              total > 0 else {
            return nil
        }
        return min(max(Double(current) / Double(total), 0), 1)
    }

    var countText: String? {
        guard let current else { return nil }
        if let total, total > 0 {
            return "\(min(current, total)) / \(total)"
        }
        return "\(current)"
    }

    static func idle(now: Date = Date()) -> CloudSyncProgressState {
        CloudSyncProgressState(
            phase: .idle,
            domain: nil,
            current: nil,
            total: nil,
            message: "",
            detailMessage: nil,
            startedAt: nil,
            lastUpdatedAt: now,
            canCancel: false,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    static func running(
        phase: CloudSyncProgressPhase,
        domain: CloudSyncProgressDomain?,
        current: Int? = nil,
        total: Int? = nil,
        message: String,
        detailMessage: String? = nil,
        startedAt: Date? = nil,
        now: Date = Date(),
        canCancel: Bool = true,
        isBlockingApply: Bool = false,
        allowsLocalWork: Bool = true
    ) -> CloudSyncProgressState {
        CloudSyncProgressState(
            phase: phase,
            domain: domain,
            current: current.map { max(0, $0) },
            total: total.map { max(0, $0) },
            message: message,
            detailMessage: detailMessage,
            startedAt: startedAt ?? now,
            lastUpdatedAt: now,
            canCancel: canCancel,
            isBlockingApply: isBlockingApply,
            allowsLocalWork: allowsLocalWork
        )
    }
}

nonisolated enum CloudSyncOverviewReducer {
    static func reduce(_ input: CloudSyncOverviewInput) -> CloudSyncOverviewState {
        switch input.oauthStatus {
        case .unavailable, .signedOut:
            return CloudSyncOverviewState(
                category: .accountRequired,
                primaryAction: .signIn,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .transitioning:
            return CloudSyncOverviewState(
                category: .accountRequired,
                primaryAction: .none,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .signedIn:
            break
        }

        switch input.remoteAccessStatus {
        case .accountNeedsCheck:
            return CloudSyncOverviewState(
                category: .accountNeedsCheck,
                primaryAction: .checkCloud,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .cloudPermission:
            return CloudSyncOverviewState(
                category: .cloudPermission,
                primaryAction: .checkCloud,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .networkOffline:
            return CloudSyncOverviewState(
                category: .networkOffline,
                primaryAction: .checkCloud,
                allowsLocalWork: true,
                isBlocking: false
            )
        case .localSnapshotFailed, .unknownFailure:
            return CloudSyncOverviewState(
                category: .needsReview,
                primaryAction: .reviewItems,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .unknown, .available:
            break
        }

        if input.reviewItemCount > 0 {
            return CloudSyncOverviewState(
                category: .needsReview,
                primaryAction: .reviewItems,
                allowsLocalWork: true,
                isBlocking: true
            )
        }

        switch input.baselineStatus {
        case .absent, .incomplete:
            return CloudSyncOverviewState(
                category: .localNeedsDownload,
                primaryAction: .downloadDatabase,
                allowsLocalWork: true,
                isBlocking: false
            )
        case .stale, .accountMismatch:
            return CloudSyncOverviewState(
                category: .accountNeedsCheck,
                primaryAction: .checkCloud,
                allowsLocalWork: true,
                isBlocking: true
            )
        case .unknown, .valid:
            break
        }

        if input.hasLocalPending {
            return CloudSyncOverviewState(
                category: .localPending,
                primaryAction: .sendChanges,
                allowsLocalWork: true,
                isBlocking: false
            )
        }

        return CloudSyncOverviewState(
            category: .ready,
            primaryAction: .checkCloud,
            allowsLocalWork: true,
            isBlocking: false
        )
    }

    static func remoteAccessStatus(
        from failureCategory: SupabaseManualSyncRemotePreviewFailureCategory?
    ) -> CloudSyncRemoteAccessStatus {
        switch failureCategory {
        case .none:
            return .available
        case .auth:
            return .accountNeedsCheck
        case .permission, .schemaOrDecode:
            return .cloudPermission
        case .network:
            return .networkOffline
        case .localSnapshot:
            return .localSnapshotFailed
        case .unknown:
            return .unknownFailure
        }
    }

    static func baselineStatus(
        from summary: SupabaseCatalogBaselineDebugSummary?
    ) -> CloudSyncBaselineStatus {
        guard let summary else { return .unknown }
        switch summary.status {
        case .absent:
            return .absent
        case .valid:
            return .valid
        case .stale:
            return .stale
        case .accountMismatch:
            return .accountMismatch
        case .incomplete:
            return .incomplete
        }
    }
}
