import Foundation

struct SyncDecisionInput: Equatable {
    var trigger: SyncTrigger
    var isAuthenticated: Bool
    var isNetworkAvailable: Bool
    var requiresAccountDecision: Bool
    var hasPendingLocalChanges: Bool
    var hasRemoteSyncEvent: Bool
    var hasRemoteVerificationDrift: Bool
    var requiresBootstrap: Bool
    var requiresFullRecovery: Bool
    var fullRecoveryContext: SyncFullRecoveryContext
    var isSyncBusy: Bool

    init(
        trigger: SyncTrigger,
        isAuthenticated: Bool,
        isNetworkAvailable: Bool,
        requiresAccountDecision: Bool = false,
        hasPendingLocalChanges: Bool = false,
        hasRemoteSyncEvent: Bool = false,
        hasRemoteVerificationDrift: Bool = false,
        requiresBootstrap: Bool = false,
        requiresFullRecovery: Bool = false,
        fullRecoveryContext: SyncFullRecoveryContext = .normalForeground,
        isSyncBusy: Bool = false
    ) {
        self.trigger = trigger
        self.isAuthenticated = isAuthenticated
        self.isNetworkAvailable = isNetworkAvailable
        self.requiresAccountDecision = requiresAccountDecision
        self.hasPendingLocalChanges = hasPendingLocalChanges
        self.hasRemoteSyncEvent = hasRemoteSyncEvent
        self.hasRemoteVerificationDrift = hasRemoteVerificationDrift
        self.requiresBootstrap = requiresBootstrap
        self.requiresFullRecovery = requiresFullRecovery
        self.fullRecoveryContext = fullRecoveryContext
        self.isSyncBusy = isSyncBusy
    }
}

enum SyncFullRecoveryContext: Equatable {
    case normalForeground
    case bootstrap
    case recovery
    case manual
    case harness

    var allowsFullRecovery: Bool {
        switch self {
        case .bootstrap, .recovery, .manual, .harness:
            return true
        case .normalForeground:
            return false
        }
    }
}

enum SyncBlockReason: Equatable {
    case authRequired
    case networkUnavailable
    case accountDecisionRequired
}

indirect enum SyncAction: Equatable {
    case noOp
    case pushPending
    case drainEvents
    case lightReconcile
    case bootstrap
    case fullRecovery
    case requestRecovery
    case retryAfterBusy
    case blocked(SyncBlockReason)
    case sequence([SyncAction])

    var containsFullRecovery: Bool {
        switch self {
        case .fullRecovery:
            return true
        case .sequence(let actions):
            return actions.contains { $0.containsFullRecovery }
        case .noOp, .pushPending, .drainEvents, .lightReconcile, .bootstrap,
             .requestRecovery, .retryAfterBusy, .blocked:
            return false
        }
    }
}

enum SyncDecisionEngine {
    static func decide(_ input: SyncDecisionInput) -> SyncAction {
        guard input.isAuthenticated else {
            return .blocked(.authRequired)
        }
        guard input.isNetworkAvailable else {
            return .blocked(.networkUnavailable)
        }
        if input.requiresAccountDecision {
            return .blocked(.accountDecisionRequired)
        }
        if input.isSyncBusy {
            return .retryAfterBusy
        }
        if input.requiresBootstrap {
            return .bootstrap
        }
        if input.requiresFullRecovery {
            return input.fullRecoveryContext.allowsFullRecovery ? .fullRecovery : .requestRecovery
        }

        var actions: [SyncAction] = []
        if input.hasPendingLocalChanges {
            actions.append(.pushPending)
        }
        if input.hasRemoteSyncEvent || input.trigger == .remoteSyncEvent {
            actions.append(.drainEvents)
        }
        if input.hasRemoteVerificationDrift {
            actions.append(.lightReconcile)
        }

        switch actions.count {
        case 0:
            return .noOp
        case 1:
            return actions[0]
        default:
            return .sequence(actions)
        }
    }
}
