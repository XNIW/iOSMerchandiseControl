import SwiftUI
import SwiftData

// MARK: - Modelli per le opzioni

struct ThemeOption: Identifiable {
    let id: String          // "system" | "light" | "dark"
    let title: String
    let subtitle: String
}

struct LanguageOption: Identifiable {
    let id: String          // "system" | "zh" | "it" | "es" | "en"
    let title: String
    let subtitle: String
}

// MARK: - View principale

struct OptionsView: View {
    private let remoteCountFetcher: (any OptionsSyncRemoteCountFetching)?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let accountSyncChoiceBindingApplier: AccountSyncChoiceBindingApplier
    private let requestAutomaticCloudCheck: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @ObservedObject private var syncStateStore: SyncStateStore
    @StateObject private var syncSummaryProvider = OptionsSyncSummaryProvider()
    @State private var isAccountDecisionSheetPresented = false
    @State private var cloudCheckRequestTask: Task<Void, Never>?
    @State private var lastAutomaticCloudCheckRequestedAt: Date?

    @MainActor
    init(
        remoteCountFetcher: (any OptionsSyncRemoteCountFetching)? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        syncStateStore: SyncStateStore,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil,
        accountSyncChoiceBindingApplier: AccountSyncChoiceBindingApplier = AccountSyncChoiceBindingApplier(),
        requestAutomaticCloudCheck: (() -> Void)? = nil
    ) {
        self.remoteCountFetcher = remoteCountFetcher
        self.supabasePullPreviewService = supabasePullPreviewService
        _syncStateStore = ObservedObject(wrappedValue: syncStateStore)
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.accountSyncChoiceBindingApplier = accountSyncChoiceBindingApplier
        self.requestAutomaticCloudCheck = requestAutomaticCloudCheck
    }

    // Opzioni tema (equivalenti alle scelte Android)
    private var themeOptions: [ThemeOption] {
        [
            ThemeOption(
                id: "system",
                title: L("options.theme.auto.title"),
                subtitle: L("options.theme.auto.subtitle")
            ),
            ThemeOption(
                id: "light",
                title: L("options.theme.light.title"),
                subtitle: L("options.theme.light.subtitle")
            ),
            ThemeOption(
                id: "dark",
                title: L("options.theme.dark.title"),
                subtitle: L("options.theme.dark.subtitle")
            )
        ]
    }

    // Opzioni lingua (simili al menu della versione Android)
    private var languageOptions: [LanguageOption] {
        [
            LanguageOption(
                id: "system",
                title: L("options.language.system.title"),
                subtitle: L("options.language.system.subtitle")
            ),
            LanguageOption(
                id: "zh",
                title: "中文",
                subtitle: L("options.language.zh.subtitle")
            ),
            LanguageOption(
                id: "it",
                title: "Italiano",
                subtitle: L("options.language.it.subtitle")
            ),
            LanguageOption(
                id: "es",
                title: "Español",
                subtitle: L("options.language.es.subtitle")
            ),
            LanguageOption(
                id: "en",
                title: "English",
                subtitle: L("options.language.en.subtitle")
            )
        ]
    }

    var body: some View {
        Form {
            // --- Sezione TEMA ---
            Section {
                ForEach(themeOptions) { option in
                    OptionRow(
                        title: option.title,
                        subtitle: option.subtitle,
                        isSelected: appTheme == option.id
                    ) {
                        appTheme = option.id
                    }
                }
            } header: {
                SectionHeader(title: L("options.theme.header"), systemImage: "paintbrush.fill")
            } footer: {
                Text(L("options.theme.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // --- Sezione LINGUA ---
            Section {
                ForEach(languageOptions) { option in
                    OptionRow(
                        title: option.title,
                        subtitle: option.subtitle,
                        isSelected: appLanguage == option.id
                    ) {
                        appLanguage = option.id
                    }
                }
            } header: {
                SectionHeader(title: L("options.language.header"), systemImage: "globe")
            } footer: {
                Text(L("options.language.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                cloudAccountAndSyncPublicCard
            } header: {
                SectionHeader(title: L("options.cloud.section.header"), systemImage: "icloud")
            } footer: {
                Text(L("options.cloud.section.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                localDatabaseStatusPublicCard
            } header: {
                SectionHeader(title: L("options.localDatabase.header"), systemImage: "externaldrive")
            } footer: {
                Text(L("options.localDatabase.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L("options.title"))
        .onAppear {
            refreshOptionsSummaryProvider()
        }
        .onDisappear {
            cloudCheckRequestTask?.cancel()
            cloudCheckRequestTask = nil
        }
        .task(id: supabaseAuthViewModel.sessionInfo?.userID) {
            refreshOptionsSummaryProvider()
        }
        .onChange(of: localDatabaseStatus) { _, _ in
            scheduleAutomaticCloudCheckIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historySessionsDidChange)) { _ in
            refreshOptionsSummaryProvider()
        }
        .onReceive(NotificationCenter.default.publisher(for: .localPendingChangesDidChange)) { _ in
            refreshOptionsSummaryProvider()
        }
        .sheet(isPresented: $isAccountDecisionSheetPresented) {
            if let accountSyncDecision = syncSummaryProvider.accountSyncDecision {
                AccountSyncDecisionView(
                    decision: accountSyncDecision,
                    localSummary: syncSummaryProvider.localDatabaseSummary,
                    onChoose: handleAccountSyncChoice
                )
            }
        }
    }

    private var cloudAccountAndSyncPublicCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cloudAccountPublicHeader

            Divider()

            if let accountSyncDecision = syncSummaryProvider.accountSyncDecision {
                accountSyncDecisionBanner(accountSyncDecision)
                Divider()
            }

            SupabaseAutomaticSyncStatusCard(
                authViewModel: supabaseAuthViewModel,
                syncState: syncStateStore.state,
                pendingCount: syncSummaryProvider.localPendingAttentionCount,
                baselineSummary: syncSummaryProvider.supabaseBaselineSummary
            )
        }
        .padding(.vertical, 4)
    }

    private func accountSyncDecisionBanner(_ decision: AccountSyncDecision) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundStyle(.orange)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(accountDecisionTitle(decision))
                    .font(.subheadline.weight(.semibold))
                Text(L("options.accountDecision.banner.detail"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                isAccountDecisionSheetPresented = true
            } label: {
                Label(L("options.accountDecision.review"), systemImage: "checkmark.shield")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .accessibilityElement(children: .combine)
    }

    private var cloudAccountPublicHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                cloudAccountStatusLabel
                Spacer(minLength: 12)
                cloudAccountActionButton
            }

            VStack(alignment: .leading, spacing: 12) {
                cloudAccountStatusLabel
                cloudAccountActionButton
            }
        }
    }

    private var cloudAccountStatusLabel: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(cloudAccountTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Text(cloudAccountDetail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(cloudAccountColor.opacity(0.14))
                Image(systemName: cloudAccountSystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(cloudAccountColor)
            }
            .frame(width: 36, height: 36)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var cloudAccountActionButton: some View {
        if supabaseAuthViewModel.isSignedIn {
            Button(role: .destructive) {
                supabaseAuthViewModel.signOut()
            } label: {
                Label(L("options.supabase.auth.signOut"), systemImage: "rectangle.portrait.and.arrow.right")
            }
            .buttonStyle(.borderless)
            .font(.subheadline.weight(.semibold))
            .disabled(!supabaseAuthViewModel.canSignOut)
        } else if supabaseAuthViewModel.isTransitioning {
            HStack(spacing: 10) {
                ProgressView()
                Text(L("options.cloud.account.transitioning"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            Button {
                supabaseAuthViewModel.signInWithGoogle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                    Text(L("options.cloud.account.action.signIn"))
                }
                .frame(minWidth: 112, alignment: .center)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.blue)
            .disabled(!supabaseAuthViewModel.canSignIn)
        }
    }

    private var localDatabaseStatusPublicCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localDatabaseTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(localDatabaseDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: localDatabaseSystemImage)
                    .foregroundStyle(localDatabaseColor)
            }
            .accessibilityElement(children: .combine)

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(L("options.localDatabase.products"), value: "\(syncSummaryProvider.localDatabaseSummary.products)")
                LabeledContent(L("options.localDatabase.suppliers"), value: "\(syncSummaryProvider.localDatabaseSummary.suppliers)")
                LabeledContent(L("options.localDatabase.categories"), value: "\(syncSummaryProvider.localDatabaseSummary.categories)")
                LabeledContent(L("options.localDatabase.prices"), value: "\(syncSummaryProvider.localDatabaseSummary.productPrices)")
                LabeledContent(L("options.localDatabase.historySessions"), value: "\(syncSummaryProvider.localDatabaseSummary.historySessions)")

                if let appliedAt = syncSummaryProvider.supabaseBaselineSummary.appliedAt {
                    LabeledContent(
                        L("options.supabase.baseline.lastPull"),
                        value: appliedAt.formatted(date: .abbreviated, time: .shortened)
                    )
                }
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    private var cloudAccountTitle: String {
        switch supabaseAuthViewModel.state {
        case .unconfigured:
            return L("options.cloud.account.unconfigured.title")
        case .signedOut:
            return L("options.cloud.account.signedOut.title")
        case .signingIn:
            return L("options.cloud.account.signingIn.title")
        case .signedIn:
            return L("options.cloud.account.signedIn.title")
        case .signingOut:
            return L("options.cloud.account.signingOut.title")
        case .failed:
            return L("options.cloud.account.failed.title")
        }
    }

    private var cloudAccountDetail: String {
        switch supabaseAuthViewModel.state {
        case .unconfigured:
            return L("options.cloud.account.unconfigured.detail")
        case .signedOut:
            return L("options.cloud.account.signedOut.detail")
        case .signingIn:
            return L("options.cloud.account.signingIn.detail")
        case .signedIn:
            if let email = supabaseAuthViewModel.sessionInfo?.privacySafeDisplayEmail {
                return L("options.cloud.account.signedIn.email", email)
            }
            return L("options.cloud.account.signedIn.detail")
        case .signingOut:
            return L("options.cloud.account.signingOut.detail")
        case .failed:
            return L("options.cloud.account.failed.detail")
        }
    }

    private var cloudAccountSystemImage: String {
        switch supabaseAuthViewModel.state {
        case .unconfigured, .failed:
            return "exclamationmark.triangle.fill"
        case .signedOut:
            return "person.crop.circle.badge.plus"
        case .signingIn, .signingOut:
            return "hourglass"
        case .signedIn:
            return "person.crop.circle.badge.checkmark"
        }
    }

    private var cloudAccountColor: Color {
        switch supabaseAuthViewModel.state {
        case .signedIn:
            return .green
        case .failed, .unconfigured:
            return .orange
        case .signedOut:
            return .blue
        case .signingIn, .signingOut:
            return .secondary
        }
    }

    private var hasSyncCountDrift: Bool {
        syncSummaryProvider.hasSyncCountDrift
    }

    private var localDatabaseStatus: LocalDatabaseCloudStatus {
        LocalDatabaseCloudStatusResolver.resolve(
            LocalDatabaseCloudStatusInput(
                isSignedIn: supabaseAuthViewModel.isSignedIn,
                isAuthFailed: cloudAuthHasFailed,
                isLoading: syncSummaryProvider.isLoading,
                localSummary: syncSummaryProvider.localDatabaseSummary,
                pendingCount: syncSummaryProvider.localPendingAttentionCount,
                baselineStatus: syncSummaryProvider.supabaseBaselineSummary.status,
                hasAccountDecision: syncSummaryProvider.accountSyncDecision != nil,
                hasAlignedCounts: syncSummaryProvider.syncCountDriftReport?.isAligned == true,
                hasCountDrift: hasSyncCountDrift,
                syncCountDriftCheckFailed: syncSummaryProvider.syncCountDriftCheckFailed,
                needsRemoteCountVerification: syncSummaryProvider.needsRemoteCountVerification,
                isCheckingRemoteCounts: syncSummaryProvider.isCheckingRemoteCounts,
                syncPhase: syncStateStore.state.phase,
                lastOutcome: syncStateStore.state.lastOutcome
            )
        )
    }

    private var localDatabaseTitle: String {
        L(localDatabaseStatus.titleKey)
    }

    private var localDatabaseDetail: String {
        L(localDatabaseStatus.detailKey)
    }

    private var localDatabaseSystemImage: String {
        switch localDatabaseStatus {
        case .empty:
            return "tray"
        case .loading, .checkingCloud:
            return "arrow.triangle.2.circlepath.icloud"
        case .reconciling:
            return "arrow.triangle.2.circlepath"
        case .upToDate:
            return "checkmark.seal.fill"
        case .needsDownload:
            return "arrow.down.circle.fill"
        case .offlineCloudCheckPending:
            return "wifi.slash"
        case .requiresUserAction:
            return "exclamationmark.triangle.fill"
        case .pendingLocalChanges:
            return "paperplane.circle.fill"
        }
    }

    private var localDatabaseColor: Color {
        switch localDatabaseStatus {
        case .empty, .needsDownload:
            return .secondary
        case .loading:
            return .secondary
        case .checkingCloud, .reconciling:
            return .accentColor
        case .upToDate:
            return .green
        case .pendingLocalChanges, .offlineCloudCheckPending:
            return .orange
        case .requiresUserAction:
            return .red
        }
    }

    private var shouldRequestAutomaticCloudCheck: Bool {
        LocalDatabaseCloudStatusResolver.shouldRequestAutomaticCloudCheck(
            LocalDatabaseCloudStatusInput(
                isSignedIn: supabaseAuthViewModel.isSignedIn,
                isAuthFailed: cloudAuthHasFailed,
                isLoading: syncSummaryProvider.isLoading,
                localSummary: syncSummaryProvider.localDatabaseSummary,
                pendingCount: syncSummaryProvider.localPendingAttentionCount,
                baselineStatus: syncSummaryProvider.supabaseBaselineSummary.status,
                hasAccountDecision: syncSummaryProvider.accountSyncDecision != nil,
                hasAlignedCounts: syncSummaryProvider.syncCountDriftReport?.isAligned == true,
                hasCountDrift: hasSyncCountDrift,
                syncCountDriftCheckFailed: syncSummaryProvider.syncCountDriftCheckFailed,
                needsRemoteCountVerification: syncSummaryProvider.needsRemoteCountVerification,
                isCheckingRemoteCounts: syncSummaryProvider.isCheckingRemoteCounts,
                syncPhase: syncStateStore.state.phase,
                lastOutcome: syncStateStore.state.lastOutcome
            )
        )
    }

    private var cloudAuthHasFailed: Bool {
        if case .failed = supabaseAuthViewModel.state {
            return true
        }
        return false
    }

    private func handleAccountSyncChoice(_ choice: AccountSyncUserChoice) {
        switch choice {
        case .cancel, .exportAndCancel:
            isAccountDecisionSheetPresented = false
        case .merge,
             .replaceLocalWithCloud,
             .uploadLocalToCloud,
             .switchStore,
             .createStoreAndPull:
            accountSyncChoiceBindingApplier.applyConfirmedRelationship(
                choice: choice,
                userID: supabaseAuthViewModel.sessionInfo?.userID
            )
            isAccountDecisionSheetPresented = false
            refreshOptionsSummaryProvider()
        }
    }

    private func refreshOptionsSummaryProvider() {
        syncSummaryProvider.refreshAll(
            context: modelContext,
            authViewModel: supabaseAuthViewModel,
            remoteCountFetcher: remoteCountFetcher,
            refreshReason: "options-view"
        )
        if syncSummaryProvider.accountSyncDecision == nil {
            isAccountDecisionSheetPresented = false
        }
        scheduleAutomaticCloudCheckIfNeeded()
    }

    private func scheduleAutomaticCloudCheckIfNeeded() {
        cloudCheckRequestTask?.cancel()
        cloudCheckRequestTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            requestAutomaticCloudCheckIfNeeded()
        }
    }

    private func requestAutomaticCloudCheckIfNeeded(now: Date = Date()) {
        guard shouldRequestAutomaticCloudCheck else {
            return
        }
        if let lastAutomaticCloudCheckRequestedAt,
           now.timeIntervalSince(lastAutomaticCloudCheckRequestedAt) < 2 {
            return
        }
        lastAutomaticCloudCheckRequestedAt = now
        if let requestAutomaticCloudCheck {
            requestAutomaticCloudCheck()
        } else {
            NotificationCenter.default.post(name: .automaticCloudCheckRequested, object: nil)
        }
    }

    private func accountDecisionTitle(_ decision: AccountSyncDecision) -> String {
        switch decision.action {
        case .promptBootstrapUpload:
            return L("options.accountDecision.bootstrap.title")
        case .promptMergeReplaceUploadExportCancel:
            return L("options.accountDecision.merge.title")
        case .promptRemoteVerification:
            return L("options.accountDecision.verify.title")
        case .promptSwitchStoreOrCreateStore:
            return L("options.accountDecision.switch.title")
        case .noOp,
             .pushPendingDrainEventsLightReconcile,
             .markConflictStale,
             .applyRemoteTombstone,
             .dedupeHistoryFingerprint,
             .useRemoteOrdering,
             .drainEventsLightReconcile,
             .keepAnonymousOrPreviousOwnerBound:
            return L("options.accountDecision.title")
        }
    }

}

struct LocalDatabasePublicSummary: Equatable {
    var products: Int
    var suppliers: Int
    var categories: Int
    var productPrices: Int
    var historySessions: Int

    static let empty = LocalDatabasePublicSummary(
        products: 0,
        suppliers: 0,
        categories: 0,
        productPrices: 0,
        historySessions: 0
    )

    var isCatalogEmpty: Bool {
        products == 0 && suppliers == 0 && categories == 0
    }

    static func make(context: ModelContext) throws -> LocalDatabasePublicSummary {
        let snapshot = try makeReconciliationAware(context: context)
        return LocalDatabasePublicSummary(
            products: snapshot.products,
            suppliers: snapshot.suppliers,
            categories: snapshot.categories,
            productPrices: snapshot.productPrices,
            historySessions: snapshot.historySessions
        )
    }
}

enum LocalDatabaseCloudStatus: Equatable {
    case loading
    case empty
    case pendingLocalChanges
    case checkingCloud
    case reconciling
    case upToDate
    case needsDownload
    case offlineCloudCheckPending
    case requiresUserAction(LocalDatabaseUserActionReason)

    var titleKey: String {
        switch self {
        case .loading:
            return "options.localDatabase.loading.title"
        case .empty:
            return "options.localDatabase.empty.title"
        case .pendingLocalChanges:
            return "options.localDatabase.pending.title"
        case .checkingCloud:
            return "options.localDatabase.checking.title"
        case .reconciling:
            return "options.localDatabase.reconciling.title"
        case .upToDate:
            return "options.localDatabase.ready.title"
        case .needsDownload:
            return "options.localDatabase.needsDownload.title"
        case .offlineCloudCheckPending:
            return "options.localDatabase.offline.title"
        case .requiresUserAction(let reason):
            return reason.titleKey
        }
    }

    var detailKey: String {
        switch self {
        case .loading:
            return "options.localDatabase.loading.detail"
        case .empty:
            return "options.localDatabase.empty.detail"
        case .pendingLocalChanges:
            return "options.localDatabase.pending.detail"
        case .checkingCloud:
            return "options.localDatabase.checking.detail"
        case .reconciling:
            return "options.localDatabase.reconciling.detail"
        case .upToDate:
            return "options.localDatabase.ready.detail"
        case .needsDownload:
            return "options.localDatabase.needsDownload.detail"
        case .offlineCloudCheckPending:
            return "options.localDatabase.offline.detail"
        case .requiresUserAction(let reason):
            return reason.detailKey
        }
    }
}

enum LocalDatabaseUserActionReason: Equatable {
    case signInRequired
    case cloudPermissionProblem
    case accountMismatch
    case localStateUnavailable
    case requiresChoice

    var titleKey: String {
        switch self {
        case .signInRequired:
            return "options.localDatabase.signInRequired.title"
        case .cloudPermissionProblem:
            return "options.localDatabase.permissionProblem.title"
        case .accountMismatch:
            return "options.localDatabase.accountMismatch.title"
        case .localStateUnavailable:
            return "options.localDatabase.localStateProblem.title"
        case .requiresChoice:
            return "options.localDatabase.conflictReview.title"
        }
    }

    var detailKey: String {
        switch self {
        case .signInRequired:
            return "options.localDatabase.signInRequired.detail"
        case .cloudPermissionProblem:
            return "options.localDatabase.permissionProblem.detail"
        case .accountMismatch:
            return "options.localDatabase.accountMismatch.detail"
        case .localStateUnavailable:
            return "options.localDatabase.localStateProblem.detail"
        case .requiresChoice:
            return "options.localDatabase.conflictReview.detail"
        }
    }
}

struct LocalDatabaseCloudStatusInput: Equatable {
    var isSignedIn: Bool
    var isAuthFailed: Bool
    var isLoading: Bool
    var localSummary: LocalDatabasePublicSummary
    var pendingCount: Int
    var baselineStatus: SupabaseCatalogBaselineDebugStatus
    var hasAccountDecision: Bool
    var hasAlignedCounts: Bool
    var hasCountDrift: Bool
    var syncCountDriftCheckFailed: Bool
    var needsRemoteCountVerification: Bool
    var isCheckingRemoteCounts: Bool
    var syncPhase: SyncPhase
    var lastOutcome: SyncOutcome?
}

enum LocalDatabaseCloudStatusResolver {
    static func resolve(_ input: LocalDatabaseCloudStatusInput) -> LocalDatabaseCloudStatus {
        if input.isLoading {
            return .loading
        }
        if input.localSummary.isCatalogEmpty {
            return .empty
        }
        if !input.isSignedIn {
            return .requiresUserAction(.signInRequired)
        }
        if input.isAuthFailed {
            return .requiresUserAction(.cloudPermissionProblem)
        }
        if input.isNetworkBlocked {
            return .offlineCloudCheckPending
        }
        if input.hasAccountDecision {
            return .requiresUserAction(.requiresChoice)
        }
        if input.baselineStatus == .accountMismatch {
            return .requiresUserAction(.accountMismatch)
        }
        if let blockingReason = input.blockingReason {
            return .requiresUserAction(userActionReason(for: blockingReason))
        }
        if input.isAutomaticWorkActive {
            return input.syncPhase == .checking ? .checkingCloud : .reconciling
        }
        if input.syncPhase == .failed || input.lastOutcome == .failed || input.syncCountDriftCheckFailed {
            return .requiresUserAction(.cloudPermissionProblem)
        }
        if input.pendingCount > 0 {
            return .pendingLocalChanges
        }
        if input.hasCountDrift {
            return .reconciling
        }
        if input.isCheckingRemoteCounts {
            return .checkingCloud
        }
        if input.baselineStatus == .valid
            && (input.hasAlignedCounts
                || input.lastOutcome == .noWork
                || input.lastOutcome == .succeeded
                || !input.needsRemoteCountVerification) {
            return .upToDate
        }
        if input.baselineStatus == .stale || input.baselineStatus == .incomplete {
            return .reconciling
        }
        if input.needsRemoteCountVerification {
            return .checkingCloud
        }

        switch input.baselineStatus {
        case .valid:
            return .upToDate
        case .absent:
            return .checkingCloud
        case .stale, .incomplete:
            return .reconciling
        case .accountMismatch:
            return .requiresUserAction(.accountMismatch)
        }
    }

    static func shouldRequestAutomaticCloudCheck(_ input: LocalDatabaseCloudStatusInput) -> Bool {
        guard input.isSignedIn,
              !input.isAuthFailed,
              !input.localSummary.isCatalogEmpty,
              input.pendingCount == 0,
              !input.hasAccountDecision,
              !input.isNetworkBlocked,
              !input.isAutomaticWorkActive,
              input.blockingReason == nil,
              input.syncPhase != .failed,
              input.lastOutcome != .failed,
              !input.isCheckingRemoteCounts,
              !input.syncCountDriftCheckFailed else {
            return false
        }
        if input.baselineStatus == .valid && (input.hasAlignedCounts || input.lastOutcome == .noWork || input.lastOutcome == .succeeded) {
            return false
        }
        if input.hasCountDrift {
            return true
        }
        switch input.baselineStatus {
        case .absent, .stale, .incomplete:
            return true
        case .valid, .accountMismatch:
            return false
        }
    }

    private static func userActionReason(for blockReason: SyncBlockReason) -> LocalDatabaseUserActionReason {
        switch blockReason {
        case .authRequired:
            return .signInRequired
        case .networkUnavailable:
            return .cloudPermissionProblem
        case .accountDecisionRequired:
            return .requiresChoice
        case .localStateUnavailable:
            return .localStateUnavailable
        }
    }
}

private extension LocalDatabaseCloudStatusInput {
    var isAutomaticWorkActive: Bool {
        syncPhase.isAutomaticWorkActive
    }

    var isNetworkBlocked: Bool {
        if case .blocked(.networkUnavailable) = syncPhase {
            return true
        }
        if case .blocked(.networkUnavailable)? = lastOutcome {
            return true
        }
        return false
    }

    var blockingReason: SyncBlockReason? {
        if case .blocked(let reason) = syncPhase {
            return reason == .networkUnavailable ? nil : reason
        }
        if case .blocked(let reason)? = lastOutcome {
            return reason == .networkUnavailable ? nil : reason
        }
        return nil
    }
}

// MARK: - Release automatic sync status surface

private struct SupabaseAutomaticSyncStatusCard: View {
    @ObservedObject private var authViewModel: SupabaseAuthViewModel

    private let syncState: SyncState
    private let pendingCount: Int
    private let baselineSummary: SupabaseCatalogBaselineDebugSummary

    init(
        authViewModel: SupabaseAuthViewModel,
        syncState: SyncState,
        pendingCount: Int,
        baselineSummary: SupabaseCatalogBaselineDebugSummary
    ) {
        self.authViewModel = authViewModel
        self.syncState = syncState
        self.pendingCount = pendingCount
        self.baselineSummary = baselineSummary
    }

    var body: some View {
        let progress = progressState
        let isRunning = authViewModel.isTransitioning || syncState.phase.isAutomaticWorkActive
        let visibleProgress = progress.flatMap(SyncStatusPresenter.visibleProgress(from:))

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title(isRunning: isRunning))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail(isRunning: isRunning))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } icon: {
                    Image(systemName: systemImage(isRunning: isRunning))
                        .foregroundStyle(tint(isRunning: isRunning))
                }
                .accessibilityElement(children: .combine)

                Spacer(minLength: 8)

                statusBadge(isRunning: isRunning)
            }

            if let visibleProgress {
                CloudSyncProgressInlineView(state: visibleProgress)
            } else if let progress,
                      SyncStatusPresenter.shouldShowFallbackSpinner(
                        isRunning: isRunning,
                        progress: progress
                      ) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("options.supabase.automaticSync.running.inline"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(
                    L("options.supabase.automaticSync.lastSuccess"),
                    value: lastSuccessText
                )
            }
            .font(.footnote)
        }
        .padding(.vertical, 4)
    }

    private var progressState: CloudSyncProgressState? {
        guard syncState.phase.isAutomaticWorkActive else { return nil }
        let progress = syncState.progress
        return CloudSyncProgressState.running(
            phase: syncState.phase.cloudProgressPhase,
            domain: nil,
            current: progress?.current,
            total: progress?.total,
            message: L("options.supabase.automaticSync.running.inline"),
            canCancel: false,
            isBlockingApply: false,
            allowsLocalWork: true
        )
    }

    private var lastSuccessText: String {
        guard let appliedAt = baselineSummary.appliedAt,
              baselineSummary.status == .valid else {
            return L("options.supabase.automaticSync.lastSuccess.none")
        }
        return appliedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private func title(isRunning: Bool) -> String {
        if isRunning {
            return L("options.supabase.automaticSync.running.title")
        }
        guard authViewModel.isSignedIn else {
            return L("options.supabase.automaticSync.signedOut.title")
        }
        switch syncState.lastOutcome {
        case .failed:
            return L("options.supabase.automaticSync.failed.title")
        case .blocked:
            return L("options.supabase.automaticSync.blocked.title")
        case .scheduledRetry:
            return L("options.supabase.automaticSync.retry.title")
        case .busy:
            return L("options.supabase.automaticSync.busy.title")
        case .cancelled:
            return L("options.supabase.automaticSync.cancelled.title")
        case .succeeded, .noWork, .none:
            break
        }
        return L("options.supabase.automaticSync.active.title")
    }

    private func detail(isRunning: Bool) -> String {
        if isRunning {
            return L("options.supabase.automaticSync.running.detail")
        }
        guard authViewModel.isSignedIn else {
            return L("options.supabase.automaticSync.signedOut.detail")
        }
        switch syncState.lastOutcome {
        case .failed:
            return L("options.supabase.automaticSync.failed.detail")
        case .blocked:
            return L("options.supabase.automaticSync.blocked.detail")
        case .scheduledRetry:
            return L("options.supabase.automaticSync.retry.detail")
        case .busy:
            return L("options.supabase.automaticSync.busy.detail")
        case .cancelled:
            return L("options.supabase.automaticSync.cancelled.detail")
        case .noWork where baselineSummary.status == .valid:
            return L("options.supabase.automaticSync.noWork.detail")
        case .noWork, .succeeded, .none:
            break
        }
        if pendingCount > 0 {
            return L("options.supabase.automaticSync.pending.detail")
        }
        switch baselineSummary.status {
        case .valid:
            return L("options.supabase.automaticSync.active.detail")
        case .absent:
            return L("options.supabase.automaticSync.bootstrap.detail")
        case .stale, .accountMismatch, .incomplete:
            return L("options.supabase.automaticSync.actionNeeded.detail")
        }
    }

    private func systemImage(isRunning: Bool) -> String {
        if !authViewModel.isSignedIn {
            return "icloud.slash"
        }
        if isRunning {
            return "arrow.triangle.2.circlepath.icloud"
        }
        if pendingCount > 0 {
            return "icloud.and.arrow.up"
        }
        switch baselineSummary.status {
        case .valid:
            return "checkmark.seal.fill"
        case .absent:
            return "icloud"
        case .stale, .accountMismatch, .incomplete:
            return "exclamationmark.icloud"
        }
    }

    private func tint(isRunning: Bool) -> Color {
        if !authViewModel.isSignedIn {
            return .secondary
        }
        if isRunning {
            return .accentColor
        }
        switch syncState.lastOutcome {
        case .failed, .blocked:
            return .red
        case .scheduledRetry, .busy:
            return .orange
        case .cancelled:
            return .secondary
        case .noWork, .succeeded, .none:
            break
        }
        if pendingCount > 0 {
            return .orange
        }
        switch baselineSummary.status {
        case .valid:
            return .green
        case .absent:
            return .secondary
        case .stale, .accountMismatch, .incomplete:
            return .orange
        }
    }

    @ViewBuilder
    private func statusBadge(isRunning: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: statusBadgeSystemImage(isRunning: isRunning))
                .imageScale(.small)
            Text(statusBadgeText(isRunning: isRunning))
                .lineLimit(1)
        }
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }

    private func statusBadgeText(isRunning: Bool) -> String {
        if !authViewModel.isSignedIn {
            return L("options.supabase.automaticSync.badge.signedOut")
        }
        if isRunning {
            return L("options.supabase.automaticSync.badge.running")
        }
        switch syncState.lastOutcome {
        case .failed:
            return L("options.supabase.automaticSync.badge.failed")
        case .blocked:
            return L("options.supabase.automaticSync.badge.blocked")
        case .scheduledRetry:
            return L("options.supabase.automaticSync.badge.retry")
        case .busy:
            return L("options.supabase.automaticSync.badge.busy")
        case .cancelled:
            return L("options.supabase.automaticSync.badge.cancelled")
        case .noWork where baselineSummary.status == .valid:
            return L("options.supabase.automaticSync.badge.noWork")
        case .noWork, .succeeded, .none:
            break
        }
        if pendingCount > 0 {
            return L("options.supabase.automaticSync.badge.pending")
        }
        switch baselineSummary.status {
        case .valid:
            return L("options.supabase.automaticSync.badge.active")
        case .absent:
            return L("options.supabase.automaticSync.badge.scheduled")
        case .stale, .accountMismatch, .incomplete:
            return L("options.supabase.automaticSync.badge.actionNeeded")
        }
    }

    private func statusBadgeSystemImage(isRunning: Bool) -> String {
        if !authViewModel.isSignedIn {
            return "person.crop.circle.badge.exclamationmark"
        }
        if isRunning {
            return "arrow.triangle.2.circlepath"
        }
        switch syncState.lastOutcome {
        case .failed:
            return "exclamationmark.triangle.fill"
        case .blocked:
            return "hand.raised.fill"
        case .scheduledRetry:
            return "clock.arrow.circlepath"
        case .busy:
            return "hourglass"
        case .cancelled:
            return "xmark.circle"
        case .noWork where baselineSummary.status == .valid:
            return "checkmark.circle"
        case .noWork, .succeeded, .none:
            break
        }
        if pendingCount > 0 {
            return "clock"
        }
        switch baselineSummary.status {
        case .valid:
            return "checkmark"
        case .absent:
            return "calendar.badge.clock"
        case .stale, .accountMismatch, .incomplete:
            return "exclamationmark.triangle"
        }
    }
}


private struct CloudSyncProgressInlineView: View {
    let state: CloudSyncProgressState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(state.message)
                    .font(.footnote.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if let countText = state.countText {
                    Text(countText)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if let percentage = state.percentage {
                ProgressView(value: percentage)
                    .progressViewStyle(.linear)
            } else if state.isActive {
                ProgressView()
                    .controlSize(.small)
            }

            if let detail = state.detailMessage,
               !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Header di sezione con icona rotonda

struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label {
            Text(title)
                .font(.headline)
        } icon: {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 28, height: 28)
                Image(systemName: systemImage)
                    .font(.subheadline)
                    // QUI il fix: usiamo Color.accentColor invece di .accentColor
                    .foregroundStyle(Color.accentColor)
            }
        }
    }
}

// MARK: - Riga singola “radio” con descrizione

struct OptionRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.body)
                            .fontWeight(isSelected ? .semibold : .regular)

                        if isSelected {
                            Text(L("options.option.current"))
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.accentColor.opacity(0.16))
                                )
                        }
                    }

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    // Altro fix: usiamo Color.accentColor / Color.secondary
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


// MARK: - Preview

#Preview {
    NavigationStack {
        OptionsView(syncStateStore: SyncStateStore())
    }
    .environmentObject(SupabaseAuthViewModel(authService: nil))
    .modelContainer(
        for: [
            Product.self,
            Supplier.self,
            ProductCategory.self,
            HistoryEntry.self,
            ProductPrice.self,
            SupabaseCatalogBaselineRun.self,
            SupabaseCatalogBaselineRecord.self,
            SyncEventOutboxEntry.self,
            LocalPendingChange.self
        ],
        inMemory: true
    )
}
