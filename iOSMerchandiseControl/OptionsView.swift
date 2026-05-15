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
    private let supabaseInventoryService: SupabaseInventoryService?
    private let supabasePullPreviewService: SupabasePullPreviewService?
    private let supabaseManualPushService: SupabaseManualPushService?
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
    private let manualSyncViewModel: SupabaseManualSyncViewModel?
    private let manualSyncCancelHandler: (() -> Void)?

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
    @Query private var localPendingChanges: [LocalPendingChange]
    @State private var supabaseBaselineSummary: SupabaseCatalogBaselineDebugSummary = .absent
    @State private var localDatabaseSummary: LocalDatabasePublicSummary = .empty

    init(
        supabaseInventoryService: SupabaseInventoryService? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        supabaseManualPushService: SupabaseManualPushService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil,
        manualSyncViewModel: SupabaseManualSyncViewModel? = nil,
        manualSyncCancelHandler: (() -> Void)? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
        self.supabaseManualPushService = supabaseManualPushService
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        self.manualSyncViewModel = manualSyncViewModel
        self.manualSyncCancelHandler = manualSyncCancelHandler
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

            // Piccola sezione di “aiuto” in fondo
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("options.tip.header"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(L("options.tip.body"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(L("options.title"))
        .onAppear {
            refreshLocalDatabaseSummary()
            refreshSupabaseBaselineSummary()
        }
        .task(id: supabaseAuthViewModel.sessionInfo?.userID) {
            refreshLocalDatabaseSummary()
            refreshSupabaseBaselineSummary()
        }
        .onReceive(NotificationCenter.default.publisher(for: .historySessionsDidChange)) { _ in
            refreshLocalDatabaseSummary()
            refreshSupabaseBaselineSummary()
        }
    }

    private var cloudAccountAndSyncPublicCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cloudAccountPublicHeader

            if supabaseAuthViewModel.isSignedIn || supabaseAuthViewModel.isTransitioning {
                Divider()

                SupabaseManualSyncReleaseCard(
                    context: modelContext,
                    authViewModel: supabaseAuthViewModel,
                    inventoryService: supabaseInventoryService,
                    pullPreviewService: supabasePullPreviewService,
                    manualPushService: supabaseManualPushService,
                    activityRecorder: syncEventOutboxDrainRecorder,
                    viewModel: manualSyncViewModel,
                    cancelHandler: manualSyncCancelHandler,
                    baselineDidChange: {
                        refreshLocalDatabaseSummary()
                        refreshSupabaseBaselineSummary()
                    }
                )
            }
        }
        .padding(.vertical, 4)
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
                    Text(L("options.supabase.manualSync.action.signIn"))
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
                LabeledContent(L("options.localDatabase.products"), value: "\(localDatabaseSummary.products)")
                LabeledContent(L("options.localDatabase.suppliers"), value: "\(localDatabaseSummary.suppliers)")
                LabeledContent(L("options.localDatabase.categories"), value: "\(localDatabaseSummary.categories)")
                LabeledContent(L("options.localDatabase.prices"), value: "\(localDatabaseSummary.productPrices)")
                LabeledContent(L("options.localDatabase.historySessions"), value: "\(localDatabaseSummary.historySessions)")

                if localPendingAttentionCount > 0 {
                    LabeledContent(
                        L("options.localDatabase.pending"),
                        value: "\(localPendingAttentionCount)"
                    )
                }

                if let appliedAt = supabaseBaselineSummary.appliedAt {
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

    private var localDatabaseTitle: String {
        if localDatabaseSummary.isCatalogEmpty {
            return L("options.localDatabase.empty.title")
        }
        if localPendingAttentionCount > 0 {
            return L("options.localDatabase.pending.title")
        }
        switch supabaseBaselineSummary.status {
        case .absent:
            return L("options.localDatabase.needsDownload.title")
        case .valid:
            return L("options.localDatabase.ready.title")
        case .stale, .accountMismatch, .incomplete:
            return L("options.localDatabase.needsCheck.title")
        }
    }

    private var localDatabaseDetail: String {
        if localDatabaseSummary.isCatalogEmpty {
            return L("options.localDatabase.empty.detail")
        }
        if localPendingAttentionCount > 0 {
            return L("options.localDatabase.pending.detail")
        }
        switch supabaseBaselineSummary.status {
        case .absent:
            return L("options.localDatabase.needsDownload.detail")
        case .valid:
            return L("options.localDatabase.ready.detail")
        case .stale, .accountMismatch, .incomplete:
            return L("options.localDatabase.needsCheck.detail")
        }
    }

    private var localDatabaseSystemImage: String {
        if localDatabaseSummary.isCatalogEmpty {
            return "tray"
        }
        switch supabaseBaselineSummary.status {
        case .valid where localPendingAttentionCount == 0:
            return "checkmark.seal.fill"
        case .absent:
            return "arrow.down.circle.fill"
        case .stale, .accountMismatch, .incomplete:
            return "exclamationmark.triangle.fill"
        case .valid:
            return "paperplane.circle.fill"
        }
    }

    private var localDatabaseColor: Color {
        if localDatabaseSummary.isCatalogEmpty {
            return .secondary
        }
        if localPendingAttentionCount > 0 {
            return .orange
        }
        switch supabaseBaselineSummary.status {
        case .valid:
            return .green
        case .absent:
            return .secondary
        case .stale, .accountMismatch, .incomplete:
            return .orange
        }
    }

    private var localPendingAttentionCount: Int {
        localPendingChanges.filter(isLocalPendingChangeRelevantToCurrentAccount).count
    }

    private func isLocalPendingChangeRelevantToCurrentAccount(_ change: LocalPendingChange) -> Bool {
        guard !change.status.isTerminal else { return false }
        guard let currentOwner = supabaseAuthViewModel.sessionInfo?.userID.uuidString.lowercased() else {
            return change.ownerUserID == nil
        }
        return change.ownerUserID == currentOwner
    }

    private func refreshSupabaseBaselineSummary() {
        do {
            supabaseBaselineSummary = try SupabaseCatalogBaselineReader().debugSummary(
                context: modelContext,
                currentUserUUID: supabaseAuthViewModel.sessionInfo?.userID
            )
        } catch {
            supabaseBaselineSummary = .absent
        }
    }

    private func refreshLocalDatabaseSummary() {
        do {
            localDatabaseSummary = try LocalDatabasePublicSummary.make(context: modelContext)
        } catch {
            localDatabaseSummary = .empty
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
        LocalDatabasePublicSummary(
            products: try context.fetchCount(FetchDescriptor<Product>()),
            suppliers: try context.fetchCount(FetchDescriptor<Supplier>()),
            categories: try context.fetchCount(FetchDescriptor<ProductCategory>()),
            productPrices: try context.fetchCount(FetchDescriptor<ProductPrice>()),
            historySessions: try context.fetchCount(FetchDescriptor<HistoryEntry>())
        )
    }
}

// MARK: - Release manual sync surface

private struct SupabaseManualSyncReleaseCard: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var authViewModel: SupabaseAuthViewModel
    @StateObject private var viewModel: SupabaseManualSyncViewModel
    private let cancelHandler: (() -> Void)?
    @State private var activeRunTask: Task<Void, Never>?
    @State private var isReviewSheetPresented = false
    @State private var isApplyConfirmationPresented = false
    @State private var isSendConfirmationPresented = false
    @State private var isActivityRegistrationConfirmationPresented = false
    @State private var activeApplyTask: Task<Void, Never>?
    @State private var activeSendTask: Task<Void, Never>?
    @State private var activeActivityRegistrationTask: Task<Void, Never>?
    private let baselineDidChange: () -> Void

    init(
        context: ModelContext,
        authViewModel: SupabaseAuthViewModel,
        inventoryService: SupabaseInventoryService?,
        pullPreviewService: SupabasePullPreviewService?,
        manualPushService: SupabaseManualPushService?,
        activityRecorder: (any SyncEventRecording)?,
        viewModel: SupabaseManualSyncViewModel? = nil,
        cancelHandler: (() -> Void)? = nil,
        baselineDidChange: @escaping () -> Void = {}
    ) {
        self.authViewModel = authViewModel
        self.cancelHandler = cancelHandler
        self.baselineDidChange = baselineDidChange
        let resolvedViewModel = viewModel ?? SupabaseManualSyncReleaseFactory.makeViewModel(
            context: context,
            authViewModel: authViewModel,
            inventoryService: inventoryService,
            pullPreviewService: pullPreviewService,
            manualPushService: manualPushService,
            activityRecorder: activityRecorder
        )
        _viewModel = StateObject(
            wrappedValue: resolvedViewModel
        )
    }

    var body: some View {
        let presentation = viewModel.presentationState

        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(presentation.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    statusBadge(presentation)
                }

                if let subtitle = presentation.subtitle,
                   !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(presentation.accessibilityLabel)
            .accessibilityHint(presentation.accessibilityHint ?? "")

            if let statusDetailText = presentation.statusDetailText,
               !statusDetailText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(statusDetailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }

            if let summary = presentation.userFacingSummary,
               !summary.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(summary.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }

            if presentation.progressState.isActive || presentation.progressState.phase == .completedWithWarnings {
                CloudSyncProgressInlineView(state: presentation.progressState)
            } else if presentation.isRunning {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(L("options.supabase.manualSync.state.running.inline"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
            }

            if let primaryAction = presentation.primaryAction {
                Button {
                    handle(action: primaryAction)
                } label: {
                    actionLabel(primaryAction)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!primaryAction.isEnabled)
                .accessibilityLabel(primaryAction.accessibilityLabel)
                .accessibilityHint(primaryAction.accessibilityHint ?? "")
            }

            if let secondaryAction = presentation.secondaryAction {
                Button {
                    handle(action: secondaryAction)
                } label: {
                    actionLabel(secondaryAction)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(!secondaryAction.isEnabled)
                .accessibilityLabel(secondaryAction.accessibilityLabel)
                .accessibilityHint(secondaryAction.accessibilityHint ?? "")
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            syncAuthPresentationContext()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                syncAuthPresentationContext()
            } else if phase == .background {
                cancelActiveRun()
            }
        }
        .onChange(of: authViewModel.isTransitioning) { _, _ in
            syncAuthPresentationContext()
        }
        .onChange(of: authViewModel.canSignIn) { _, _ in
            syncAuthPresentationContext()
        }
        .onChange(of: authViewModel.sessionInfo?.userID) { _, _ in
            resetAfterAccountChange()
        }
        .onChange(of: authViewModel.isSignedIn) { _, _ in
            resetAfterAccountChange()
        }
        .onChange(of: viewModel.presentationState.reviewSheet) { _, reviewSheet in
            if reviewSheet == nil {
                isReviewSheetPresented = false
            }
        }
        .onDisappear {
            activeRunTask?.cancel()
            activeRunTask = nil
            activeApplyTask?.cancel()
            activeApplyTask = nil
            activeSendTask?.cancel()
            activeSendTask = nil
            activeActivityRegistrationTask?.cancel()
            activeActivityRegistrationTask = nil
            isApplyConfirmationPresented = false
            isSendConfirmationPresented = false
            isActivityRegistrationConfirmationPresented = false
        }
        .sheet(
            isPresented: $isReviewSheetPresented,
            onDismiss: { viewModel.markReviewDismissedWithoutDiscard() }
        ) {
            if let review = viewModel.presentationState.reviewSheet {
                SupabaseManualSyncReviewSheet(
                    review: review,
                    primaryAction: {
                        handle(reviewPrimaryAction: review.primaryActionID)
                    },
                    dismiss: {
                        if viewModel.isApplyingLocalChanges {
                            activeApplyTask?.cancel()
                            activeApplyTask = nil
                            return
                        }
                        confirmDiscardReview()
                    }
                )
                .interactiveDismissDisabled(
                    viewModel.isReviewMutationInProgress
                )
            }
        }
        .confirmationDialog(
            L("options.supabase.manualSync.confirm.updateDevice.title"),
            isPresented: $isApplyConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.manualSync.confirm.updateDevice.cancel"), role: .cancel) {}
            Button(L("options.supabase.manualSync.confirm.updateDevice.update")) {
                startLocalApply()
            }
        } message: {
            Text(L("options.supabase.manualSync.confirm.updateDevice.message"))
        }
        .confirmationDialog(
            L("options.supabase.manualSync.confirm.send.title"),
            isPresented: $isSendConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.manualSync.confirm.send.cancel"), role: .cancel) {}
            Button(L("options.supabase.manualSync.confirm.send.send")) {
                startCatalogSend()
            }
        } message: {
            Text(L("options.supabase.manualSync.confirm.send.message"))
        }
        .confirmationDialog(
            L("options.supabase.manualSync.confirm.activity.title"),
            isPresented: $isActivityRegistrationConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.manualSync.confirm.activity.cancel"), role: .cancel) {}
            Button(L("options.supabase.manualSync.confirm.activity.register")) {
                startActivityRegistration()
            }
        } message: {
            Text(L("options.supabase.manualSync.confirm.activity.message"))
        }
        .foregroundCloudWorkflowActivity(.manualSyncSheet, isActive: isReviewSheetPresented)
        .foregroundCloudWorkflowActivity(
            .confirmationDialog,
            isActive: isApplyConfirmationPresented
                || isSendConfirmationPresented
                || isActivityRegistrationConfirmationPresented
        )
    }

    private func handle(reviewPrimaryAction actionID: SupabaseManualSyncReviewPrimaryActionID) {
        switch actionID {
        case .updateDevice:
            isApplyConfirmationPresented = true
        case .sendCloudChanges:
            isSendConfirmationPresented = true
        case .registerCloudActivity:
            isActivityRegistrationConfirmationPresented = true
        case .recheck:
            isReviewSheetPresented = false
            startRun(for: .checkCloud)
        case .signInAgain:
            isReviewSheetPresented = false
            authViewModel.signInWithGoogle()
        case .openDatabase:
            isReviewSheetPresented = false
            NotificationCenter.default.post(name: .openDatabaseTabRequested, object: nil)
        case .none:
            break
        }
    }

    private func startLocalApply() {
        guard activeApplyTask == nil else { return }

        activeApplyTask = Task { @MainActor in
            await viewModel.applyStagedLocalChanges()
            baselineDidChange()
            activeApplyTask = nil
            if !viewModel.isApplyingLocalChanges,
               viewModel.presentationState.reviewSheet == nil {
                isReviewSheetPresented = false
            }
        }
    }

    private func startCatalogSend() {
        guard activeSendTask == nil else { return }

        activeSendTask = Task { @MainActor in
            await viewModel.sendConfirmedCatalogChanges()
            activeSendTask = nil
        }
    }

    private func startActivityRegistration() {
        guard activeActivityRegistrationTask == nil else { return }

        activeActivityRegistrationTask = Task { @MainActor in
            await viewModel.confirmActivityRegistration()
            activeActivityRegistrationTask = nil
        }
    }

    @ViewBuilder
    private func statusBadge(_ presentation: SupabaseManualSyncPresentationState) -> some View {
        HStack(spacing: 4) {
            if let symbol = presentation.statusBadgeSystemImage {
                Image(systemName: symbol)
                    .imageScale(.small)
            }
            Text(presentation.statusBadgeText)
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

    private func actionLabel(_ action: SupabaseManualSyncPresentationAction) -> some View {
        HStack(spacing: 8) {
            if let systemImage = action.systemImage {
                Image(systemName: systemImage)
            }
            Text(action.title)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func handle(action: SupabaseManualSyncPresentationAction) {
        guard action.isEnabled else { return }

        if action.id == .signIn {
            authViewModel.signInWithGoogle()
            return
        }

        if action.id == .cancel {
            cancelActiveRun()
            return
        }

        if action.id == .reviewChanges {
            viewModel.markReviewingSemiAutomaticPlan()
            isReviewSheetPresented = viewModel.presentationState.reviewSheet != nil
            return
        }

        startRun(for: action.id)
    }

    private func startRun(for actionID: SupabaseManualSyncPresentationActionID) {
        guard viewModel.canStart,
              let mode = viewModel.runMode(for: actionID) else { return }

        activeRunTask?.cancel()
        activeRunTask = Task { @MainActor in
            let directSync = actionID == .syncNow || actionID == .checkCloud || actionID == .downloadCloudDatabase
            await viewModel.start(with: mode, syncHistoryAfterRun: directSync)
            if directSync {
                let hasPendingLocalWork = viewModel.privacySafeAggregatesSnapshot?.hasAnyPendingWork == true
                if !hasPendingLocalWork {
                    await viewModel.applyStagedLocalChangesIfNeeded()
                }
                await viewModel.prepareCatalogPushPlanForReview()
                await viewModel.prepareProductPricePlansForReview()
                if hasPendingLocalWork,
                   viewModel.presentationState.reviewSheet != nil {
                    isReviewSheetPresented = true
                }
                if !viewModel.isApplyingLocalChanges,
                   viewModel.presentationState.reviewSheet == nil {
                    isReviewSheetPresented = false
                }
            }
            baselineDidChange()
            activeRunTask = nil
        }
    }

    private func cancelActiveRun() {
        viewModel.requestLifecycleInterruptionForBackground()
        activeRunTask?.cancel()
        activeRunTask = nil
        cancelHandler?()
        activeApplyTask?.cancel()
        activeApplyTask = nil
        activeSendTask?.cancel()
        activeSendTask = nil
        activeActivityRegistrationTask?.cancel()
        activeActivityRegistrationTask = nil
    }

    private func resetAfterAccountChange() {
        activeRunTask?.cancel()
        activeRunTask = nil
        activeApplyTask?.cancel()
        activeApplyTask = nil
        activeSendTask?.cancel()
        activeSendTask = nil
        activeActivityRegistrationTask?.cancel()
        activeActivityRegistrationTask = nil
        isApplyConfirmationPresented = false
        isSendConfirmationPresented = false
        isActivityRegistrationConfirmationPresented = false
        isReviewSheetPresented = false
        viewModel.resetPresentationToIdleReady()
        syncAuthPresentationContext()
    }

    private func confirmDiscardReview() {
        viewModel.cancelReviewFlow()
        isReviewSheetPresented = false
    }

    private func syncAuthPresentationContext() {
        viewModel.applyAuthPresentationContext(
            SupabaseManualSyncAuthPresentationContext(
                isSignedIn: authViewModel.isSignedIn,
                canSignIn: authViewModel.canSignIn,
                isTransitioning: authViewModel.isTransitioning
            )
        )
    }
}

private struct SupabaseManualSyncReviewSheet: View {
    let review: SupabaseManualSyncReviewSheetState
    let primaryAction: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(review.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(review.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    summaryCard

                    if let progress = review.progressState {
                        CloudSyncProgressInlineView(state: progress)
                    }

                    ForEach(review.sections) { section in
                        reviewSection(section)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 18)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text(review.footerMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if review.primaryActionID != .none {
                    Button {
                        primaryAction()
                    } label: {
                        HStack(spacing: 8) {
                            if review.primaryActionIsLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: review.primaryActionSystemImage)
                            }
                            Text(review.primaryActionTitle)
                        }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!review.primaryActionIsEnabled)
                    .accessibilityLabel(review.primaryActionTitle)
                }

                Button(review.secondaryActionTitle) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(review.secondaryActionTitle)
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .accessibilityElement(children: .contain)
        .accessibilityLabel(review.accessibilityLabel)
    }

    private func reviewSection(_ section: SupabaseManualSyncReviewSectionState) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: section.systemImage)
                .font(.subheadline)
                .foregroundStyle(tint(for: section.tone))
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(section.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Text(section.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: review.summarySystemImage)
                .font(.headline)
                .foregroundStyle(tint(for: review.summaryTone))
                .frame(width: 26, height: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(review.summaryTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)

                Text(review.summaryMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func tint(for tone: SupabaseManualSyncReviewSectionTone) -> Color {
        switch tone {
        case .neutral:
            return .accentColor
        case .success:
            return .green
        case .attention:
            return .orange
        case .blocked:
            return .red
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
        OptionsView()
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
