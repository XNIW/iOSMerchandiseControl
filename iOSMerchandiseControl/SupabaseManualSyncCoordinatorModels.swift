import Foundation

// MARK: - Run mode

nonisolated enum SupabaseManualSyncRunMode: Equatable, Sendable {
    case dryRun
    case guidedManual
    case debugDiagnostics
    case automatic
}

// MARK: - Phases

nonisolated enum SupabaseManualSyncPhase: Int, CaseIterable, Equatable, Sendable {
    case authCheck = 0
    case baselineCheck
    case localPendingCheck
    case remotePreview
    case userConfirmation
    case catalogPush
    case productPricePush
    case pendingEventsFlush
    case finalRefresh
    case summary
}

// MARK: - Phase outcome

nonisolated enum SupabaseManualSyncPhaseOutcome: Equatable, Sendable {
    case skippedNoWork
    case completed
    case partial
    case blocked
    case failedRetryable
    case failedNonRetryable
    case cancelled
}

// MARK: - Summary

nonisolated enum SupabaseManualSyncFinalUserState: Equatable, Sendable {
    case allUpToDate
    case completedSuccessfully
    case partialSync
    case blocked
    case connectivityIssue
    case technicalReviewNeeded
    case cancelled
    case concurrentRunNotAllowed
    case modeNotSupportedInThisSlice
}

nonisolated struct SupabaseManualSyncPrivacyCounts: Equatable, Sendable {
    var pendingCatalogChangeCount: Int = 0
    var pendingPriceChangeCount: Int = 0
    /// Count of locally queued cloud-bound operations (aggregate only — no identifiers).
    var pendingQueuedCloudOperationCount: Int = 0

    var hasAnyPendingWork: Bool {
        pendingCatalogChangeCount > 0 || pendingPriceChangeCount > 0 || pendingQueuedCloudOperationCount > 0
    }
}

nonisolated struct SupabaseManualSyncRunSummary: Equatable, Sendable {
    var finalState: SupabaseManualSyncFinalUserState
    /// Short UX headline — must remain free of developer jargon (TASK-063 §4.c / TASK-065).
    var userFacingHeadline: String
    var executedPhases: [SupabaseManualSyncPhase]
    var skippedPhases: [SupabaseManualSyncPhase]
    var countsSnapshot: SupabaseManualSyncPrivacyCounts
    var suggestedNextStep: String?
    var detailMessage: String?
    var remotePreviewSummary: SupabaseManualSyncRemotePreviewSummary? = nil
}

// MARK: - Gates (dry-run environment)

nonisolated enum SupabaseManualSyncAuthGateResult: Equatable, Sendable {
    case authenticated
    case sessionExpiredOrSignedOut
}

nonisolated enum SupabaseManualSyncBaselineGateResult: Equatable, Sendable {
    case valid
    case missingOrInvalid
}

// MARK: - User-facing copy (Italian, non-technical strings only)

nonisolated enum SupabaseManualSyncUserFacingCopy {
    static let signInAgain = "Serve accedere di nuovo"
    static let realignFromCloud = "Serve riallineare i dati dal cloud"
    static let allUpToDate = "Nessuna modifica da sincronizzare."
    static let connectivityRetry = "Connessione non riuscita. Puoi riprovare."
    static let partialSync = "Sincronizzazione parziale"
    static let technicalFollowUp = "Sincronizzazione non completata. Serve un controllo tecnico."
    static let cancelled = "Sincronizzazione annullata"
    static let unexpected = "Errore imprevisto durante la sincronizzazione"
    static let syncFinishedSuccessfully = "Sincronizzazione completata."
    static let cloudCheckNoAction = "Controllo cloud completato. Nessuna azione richiesta."
    static let alreadyRunning = "Un'altra sincronizzazione è già in corso."
    static let sliceModeUnavailable = "Questa modalità non è disponibile in questa versione."
    static let automaticUnavailable = "La sincronizzazione automatica non è disponibile."
    static let partialSuggestion = "Alcune modifiche sono state inviate, ma resta qualcosa da completare. Puoi riprovare."
    static let retryConnectivitySuggestion = "Controlla la connessione e riprova tra poco."
}
