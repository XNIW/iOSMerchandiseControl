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
    private let supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService?
#if DEBUG
    private let syncEventOutboxDrainRecorder: (any SyncEventRecording)?
#endif

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
#if DEBUG
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @AppStorage("supabaseLastLinkedUserID") private var supabaseLastLinkedUserID: String = ""
    @State private var isRunningSupabaseDiagnostic = false
    @State private var supabaseDiagnosticMessage: String?
    @State private var supabaseDiagnosticIsError = false
    @State private var supabaseBaselineSummary: SupabaseCatalogBaselineDebugSummary = .absent
    @State private var isShowingSupabasePullPreview = false
    @State private var supabasePullPreviewState: SupabasePullPreviewViewState = .idle
    @State private var productPricePreviewState: ProductPricePreviewViewState = .idle
    @State private var productPricePreviewTask: Task<Void, Never>?
    @State private var productPricePreviewRequestID: UUID?
    @State private var productPriceApplyState: ProductPriceApplyViewState = .idle
    @State private var productPriceApplyTask: Task<Void, Never>?
    @State private var productPriceApplyRequestID: UUID?
    @State private var pendingProductPriceApplyPlan: ProductPriceApplyPlan?
    @State private var isShowingProductPriceApplyConfirmation = false
    @StateObject private var productPriceManualPushViewModel: ProductPriceManualPushDebugViewModel
    @StateObject private var syncEventDebugViewModel: SupabaseSyncEventDebugViewModel
    @State private var isShowingProductPriceManualPushConfirmation = false
    @StateObject private var pushPreflightViewModel: SupabasePushPreflightViewModel
    @State private var selectedPushPreflightScope: ManualPushPreflightScope = .global
    @State private var isRunningTask045RemoteCollisionCheck = false
    @State private var task045RemoteCollisionMessage: String?
    @State private var task045RemoteCollisionIsError = false
    @State private var task045RemoteCollisionGatePassed = false
    @State private var pendingManualPushPlan: ManualPushPlan?
    @State private var isShowingManualPushConfirmation = false
#endif

    init(
        supabaseInventoryService: SupabaseInventoryService? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil,
        supabaseSyncEventPreviewService: SupabaseSyncEventPreviewService? = nil,
        supabaseManualPushService: SupabaseManualPushService? = nil,
        syncEventOutboxDrainRecorder: (any SyncEventRecording)? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
        self.supabaseSyncEventPreviewService = supabaseSyncEventPreviewService
#if DEBUG
        self.syncEventOutboxDrainRecorder = syncEventOutboxDrainRecorder
        _productPriceManualPushViewModel = StateObject(
            wrappedValue: ProductPriceManualPushDebugViewModel(remote: supabaseInventoryService)
        )
        _syncEventDebugViewModel = StateObject(
            wrappedValue: SupabaseSyncEventDebugViewModel(service: supabaseSyncEventPreviewService)
        )
        _pushPreflightViewModel = StateObject(
            wrappedValue: SupabasePushPreflightViewModel(manualPushService: supabaseManualPushService)
        )
#endif
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

#if DEBUG
            Section {
                supabaseAuthStatusRow

                if supabaseAuthViewModel.isTransitioning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(L("options.supabase.auth.transitioning"))
                            .foregroundStyle(.secondary)
                    }
                }

                if supabaseAuthViewModel.isSignedIn {
                    Button(role: .destructive) {
                        supabaseAuthViewModel.signOut()
                    } label: {
                        Label(L("options.supabase.auth.signOut"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .disabled(!supabaseAuthViewModel.canSignOut)
                } else {
                    Button {
                        supabaseAuthViewModel.signInWithGoogle()
                    } label: {
                        Label(L("options.supabase.auth.signInGoogle"), systemImage: "person.crop.circle.badge.plus")
                    }
                    .disabled(!supabaseAuthViewModel.canSignIn)
                }

                Button {
                    runSupabaseDiagnostic()
                } label: {
                    Label(L("options.supabase.diagnostic.button"), systemImage: "network")
                }
                .disabled(!canRunAuthenticatedSupabaseActions || isRunningSupabaseDiagnostic)

                Button {
                    runSupabasePullPreview()
                } label: {
                    Label(L("options.supabase.preview.button"), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canRunAuthenticatedSupabaseActions || isSupabasePullPreviewLoading)

                if !supabaseAuthViewModel.isSignedIn {
                    Label {
                        Text(L("options.supabase.auth.sessionRequired"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } icon: {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.orange)
                    }
                }

                if supabaseAuthViewModel.isSignedIn,
                   let sessionInfo = supabaseAuthViewModel.sessionInfo {
                    DisclosureGroup(L("options.supabase.auth.debugDetails")) {
                        LabeledContent(
                            L("options.supabase.auth.debug.userId"),
                            value: sessionInfo.userID.uuidString
                        )
                        LabeledContent(
                            L("options.supabase.auth.debug.provider"),
                            value: sessionInfo.provider ?? L("options.supabase.auth.providerUnknown")
                        )
                        LabeledContent(
                            L("options.supabase.auth.debug.email"),
                            value: sessionInfo.displayEmail ?? L("options.supabase.preview.valueMissing")
                        )
                    }
                }

                if isRunningSupabaseDiagnostic {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(L("options.supabase.diagnostic.running"))
                            .foregroundStyle(.secondary)
                    }
                }

                if let supabaseDiagnosticMessage {
                    Label {
                        Text(supabaseDiagnosticMessage)
                            .font(.footnote)
                            .foregroundStyle(supabaseDiagnosticIsError ? Color.red : Color.secondary)
                    } icon: {
                        Image(systemName: supabaseDiagnosticIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(supabaseDiagnosticIsError ? Color.orange : Color.green)
                    }
                }

                productPricePreviewCard
                productPriceApplyCard
            } header: {
                SectionHeader(title: L("options.supabase.auth.header"), systemImage: "person.crop.circle.badge.checkmark")
            } footer: {
                Text(L("options.supabase.auth.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                DisclosureGroup {
                    productPriceManualPushCard
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(L("options.supabase.priceManualPush.title"))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        productPriceApplyBadge("options.supabase.priceManualPush.badge.manual", color: .blue)
                            .accessibilityLabel(L("options.supabase.priceManualPush.accessibility.manual"))
                        productPriceApplyBadge("options.supabase.priceManualPush.badge.debug", color: .orange)
                            .accessibilityLabel(L("options.supabase.priceManualPush.accessibility.debug"))
                    }
                }

                SyncEventOutboxDrainDebugCard(
                    context: modelContext,
                    recorder: syncEventOutboxDrainRecorder,
                    isAuthenticated: hasSyncEventsSession,
                    ownerUserID: supabaseAuthViewModel.sessionInfo?.userID.uuidString
                )
            } header: {
                SectionHeader(title: L("options.advanced.header"), systemImage: "wrench.and.screwdriver.fill")
            } footer: {
                Text(L("options.supabase.priceManualPush.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                baselineStatusRow
                if supabaseBaselineSummary.status != .absent {
                    if let appliedAt = supabaseBaselineSummary.appliedAt {
                        LabeledContent(
                            L("options.supabase.baseline.lastPull"),
                            value: appliedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                    LabeledContent(
                        L("options.supabase.baseline.account"),
                        value: supabaseBaselineSummary.accountAbbreviation ?? L("options.supabase.preview.valueMissing")
                    )
                    LabeledContent(
                        L("options.supabase.baseline.counts.products"),
                        value: "\(supabaseBaselineSummary.productCount ?? 0)"
                    )
                    LabeledContent(
                        L("options.supabase.baseline.counts.suppliers"),
                        value: "\(supabaseBaselineSummary.supplierCount ?? 0)"
                    )
                    LabeledContent(
                        L("options.supabase.baseline.counts.categories"),
                        value: "\(supabaseBaselineSummary.categoryCount ?? 0)"
                    )
                    LabeledContent(
                        L("options.supabase.baseline.schemaVersion"),
                        value: "\(supabaseBaselineSummary.fingerprintSchemaVersion ?? 0)"
                    )
                    LabeledContent(
                        L("options.supabase.baseline.tombstones"),
                        value: "\(supabaseBaselineSummary.tombstoneCount ?? 0)"
                    )
                }
            } header: {
                SectionHeader(title: L("options.supabase.baseline.header"), systemImage: "externaldrive.badge.checkmark")
            } footer: {
                Text(L("options.supabase.baseline.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            syncEventsSection

            Section {
                preflightStateRow

                Picker(
                    L("options.supabase.pushpreflight.scope.label"),
                    selection: $selectedPushPreflightScope
                ) {
                    Text(L("options.supabase.pushpreflight.scope.global"))
                        .tag(ManualPushPreflightScope.global)
                    Text(L("options.supabase.pushpreflight.scope.task045"))
                        .tag(ManualPushPreflightScope.scopedTask045)
                }
                .pickerStyle(.segmented)
                .disabled(pushPreflightViewModel.isRunning)

                if selectedPushPreflightScope == .scopedTask045 {
                    Button {
                        runTask045RemoteCollisionCheck()
                    } label: {
                        Label(
                            L("options.supabase.pushpreflight.collision.task045.button"),
                            systemImage: "magnifyingglass.circle"
                        )
                    }
                    .disabled(
                        isRunningTask045RemoteCollisionCheck
                            || pushPreflightViewModel.isRunning
                            || !isPushPreflightAccountReady
                            || supabaseInventoryService == nil
                    )
                }

                if isRunningTask045RemoteCollisionCheck {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(L("options.supabase.pushpreflight.collision.task045.running"))
                            .foregroundStyle(.secondary)
                    }
                }

                if let task045RemoteCollisionMessage {
                    Label {
                        Text(task045RemoteCollisionMessage)
                            .font(.footnote)
                            .foregroundStyle(task045RemoteCollisionIsError ? Color.red : Color.secondary)
                    } icon: {
                        Image(systemName: task045RemoteCollisionIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(task045RemoteCollisionIsError ? Color.orange : Color.green)
                    }
                }

                Button {
                    runSupabasePushPreflight()
                } label: {
                    Label(
                        L(pushPreflightRunButtonKey),
                        systemImage: selectedPushPreflightScope == .scopedTask045
                            ? "line.3.horizontal.decrease.circle"
                            : "checklist"
                    )
                }
                .disabled(pushPreflightViewModel.isRunning || !canRunSelectedPushPreflight)

                if canRunManualPush {
                    Button(role: .destructive) {
                        prepareManualPushConfirmation()
                    } label: {
                        Label(L("options.supabase.manualpush.button"), systemImage: "arrow.up.circle.fill")
                    }
                    .accessibilityLabel(L("options.supabase.manualpush.accessibility"))
                }

                if pushPreflightViewModel.isRunning {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(L("options.supabase.pushpreflight.running"))
                            .foregroundStyle(.secondary)
                    }
                }

                if isPushPreflightAccountReady {
                    if case .completedSafe(let summary) = pushPreflightViewModel.state {
                        preflightSummaryCard(
                            titleKey: "options.supabase.pushpreflight.state.completedSafe",
                            icon: "checkmark.shield.fill",
                            color: .green,
                            summary: summary
                        )
                    } else if case .completedScopedSafe(let summary) = pushPreflightViewModel.state {
                        preflightSummaryCard(
                            titleKey: "options.supabase.pushpreflight.state.completedScopedSafe",
                            icon: "checkmark.shield.fill",
                            color: .green,
                            summary: summary
                        )
                    } else if case .completedScopedBlocked(let summary) = pushPreflightViewModel.state {
                        preflightSummaryCard(
                            titleKey: "options.supabase.pushpreflight.state.completedScopedBlocked",
                            icon: "xmark.shield.fill",
                            color: .orange,
                            summary: summary
                        )
                    } else if case .completedNoWork(let summary) = pushPreflightViewModel.state {
                        preflightSummaryCard(
                            titleKey: "options.supabase.pushpreflight.state.completedNoWork",
                            icon: "checkmark.circle.fill",
                            color: .green,
                            summary: summary
                        )
                    } else if case .completedBlocked(let summary) = pushPreflightViewModel.state {
                        preflightSummaryCard(
                            titleKey: "options.supabase.pushpreflight.state.completedBlocked",
                            icon: "exclamationmark.triangle.fill",
                            color: .orange,
                            summary: summary
                        )
                    } else if let execution = manualPushExecutionSummary {
                        manualPushResultCard(execution)
                    } else if case .failedLocalError = pushPreflightViewModel.state {
                        Label {
                            Text(L("options.supabase.pushpreflight.state.failedLocalError"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: "xmark.octagon.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            } header: {
                SectionHeader(title: L("options.supabase.pushpreflight.header"), systemImage: "shippingbox")
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L("options.supabase.pushpreflight.copy.dryRun"))
                    Text(L("options.supabase.pushpreflight.copy.scopedTask045"))
                    Text(L("options.supabase.manualpush.copy.noProductPrice"))
                    Text(L("options.supabase.manualpush.copy.noRemoteDelete"))
                    Text(L("options.supabase.manualpush.copy.noAutomaticSync"))
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
#endif

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
#if DEBUG
        .onDisappear {
            resetProductPricePreview()
            resetProductPriceApply()
            resetProductPriceManualPush()
            syncEventDebugViewModel.cancel()
            pushPreflightViewModel.cancel()
        }
        .task(id: supabaseAuthViewModel.sessionInfo?.userID) {
            refreshSupabaseBaselineSummary()
        }
        .onChange(of: pushPreflightViewModel.state) { _, state in
            switch state {
            case .completed, .completedBaselineRefreshFailed, .partial:
                refreshSupabaseBaselineSummary()
            case .idle,
                 .accountNotLinked,
                 .running,
                 .completedSafe,
                 .completedScopedSafe,
                 .completedScopedBlocked,
                 .completedNoWork,
                 .completedBlocked,
                 .failedBeforeWrite,
                 .blockedBeforeWrite,
                 .failedLocalError:
                break
            }
        }
        .onChange(of: selectedPushPreflightScope) { _, _ in
            resetTask045RemoteCollisionGate()
        }
        .onChange(of: supabaseAuthViewModel.sessionInfo?.userID) { _, _ in
            resetProductPricePreview()
            resetProductPriceApply()
            resetProductPriceManualPush()
            syncEventDebugViewModel.reset()
        }
        .onChange(of: supabaseAuthViewModel.isSignedIn) { _, isSignedIn in
            if !isSignedIn {
                resetProductPricePreview()
                resetProductPriceApply()
                resetProductPriceManualPush()
                syncEventDebugViewModel.reset()
            }
        }
        .sheet(isPresented: $isShowingSupabasePullPreview) {
            SupabasePullPreviewSheet(
                state: supabasePullPreviewState,
                isAuthenticated: supabaseAuthViewModel.isSignedIn,
                currentUserID: supabaseAuthViewModel.sessionInfo?.userID,
                baselineDidChange: {
                    refreshSupabaseBaselineSummary()
                },
                close: {
                    isShowingSupabasePullPreview = false
                }
            )
        }
        .confirmationDialog(
            L("options.supabase.priceApply.confirm.title"),
            isPresented: $isShowingProductPriceApplyConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.priceApply.confirm.apply")) {
                runConfirmedProductPriceApply()
            }
            Button(L("common.cancel"), role: .cancel) {
                pendingProductPriceApplyPlan = nil
            }
        } message: {
            if let pendingProductPriceApplyPlan {
                Text(productPriceApplyConfirmationMessage(for: pendingProductPriceApplyPlan))
            }
        }
        .confirmationDialog(
            L("options.supabase.priceManualPush.confirm.title"),
            isPresented: $isShowingProductPriceManualPushConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.priceManualPush.confirm.push")) {
                runConfirmedProductPriceManualPush()
            }
            Button(L("common.cancel"), role: .cancel) {}
        } message: {
            Text(productPriceManualPushConfirmationMessage())
        }
        .confirmationDialog(
            L("options.supabase.manualpush.confirm.title"),
            isPresented: $isShowingManualPushConfirmation,
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.manualpush.confirm.write"), role: .destructive) {
                runConfirmedManualPush()
            }
            Button(L("common.cancel"), role: .cancel) {
                pushPreflightViewModel.clearFrozenConfirmationPlan()
                pendingManualPushPlan = nil
            }
        } message: {
            if let pendingManualPushPlan {
                Text(manualPushConfirmationMessage(for: pendingManualPushPlan))
            }
        }
#endif
    }

#if DEBUG
    private var canRunAuthenticatedSupabaseActions: Bool {
        supabaseAuthViewModel.isSignedIn
            && !supabaseAuthViewModel.isTransitioning
            && supabaseInventoryService != nil
            && supabasePullPreviewService != nil
    }

    private var hasSyncEventsSession: Bool {
        supabaseAuthViewModel.isSignedIn
            && supabaseAuthViewModel.sessionInfo?.isExpired == false
            && supabaseAuthViewModel.sessionInfo?.userID != nil
    }

    private var canRunSyncEventsDebugActions: Bool {
        hasSyncEventsSession
            && !supabaseAuthViewModel.isTransitioning
            && supabaseSyncEventPreviewService != nil
            && !syncEventDebugViewModel.isLoading
    }

    private var displayedSyncEventsState: SupabaseSyncEventDebugViewModel.ViewState {
        guard supabaseSyncEventPreviewService != nil else { return .notConfigured }
        guard hasSyncEventsSession else { return .noSession }
        return syncEventDebugViewModel.state
    }

    private var syncEventsButtonKey: String {
        syncEventDebugViewModel.state.canRefresh
            ? "options.supabase.syncEvents.button.refresh"
            : "options.supabase.syncEvents.button.load"
    }

    private var isPushPreflightAccountReady: Bool {
        supabaseAuthViewModel.isSignedIn
            && supabaseAuthViewModel.sessionInfo?.isExpired == false
            && supabaseAuthViewModel.sessionInfo?.userID != nil
    }

    private var canRunSelectedPushPreflight: Bool {
        guard isPushPreflightAccountReady else { return false }
        guard selectedPushPreflightScope.isScopedTask045 else { return true }
        return task045RemoteCollisionGatePassed
    }

    private var canRunManualPush: Bool {
        guard isPushPreflightAccountReady,
              !pushPreflightViewModel.isRunning,
              task045RemoteCollisionGatePassed,
              hasCompletedScopedSafePreflight,
              let plan = pushPreflightViewModel.lastPreview?.plan else {
            return false
        }
        return plan.scope.isScopedTask045
            && plan.isSendable
            && !plan.hasBlockers
            && !plan.scopeSummary.hasScopedBlocker
    }

    private var hasCompletedScopedSafePreflight: Bool {
        if case .completedScopedSafe = pushPreflightViewModel.state {
            return true
        }
        return false
    }

    private var manualPushExecutionSummary: SupabasePushPreflightViewModel.ExecutionSummary? {
        switch pushPreflightViewModel.state {
        case .completed(let summary),
             .completedBaselineRefreshFailed(let summary),
             .partial(let summary),
             .failedBeforeWrite(let summary),
             .blockedBeforeWrite(let summary):
            return summary
        case .idle,
             .accountNotLinked,
             .running,
             .completedSafe,
             .completedScopedSafe,
             .completedScopedBlocked,
             .completedNoWork,
             .completedBlocked,
             .failedLocalError:
            return nil
        }
    }

    private var displayedPushPreflightState: SupabasePushPreflightViewModel.ViewState {
        if isPushPreflightAccountReady || pushPreflightViewModel.isRunning {
            return pushPreflightViewModel.state
        }
        return .accountNotLinked
    }

    private var isSupabasePullPreviewLoading: Bool {
        if case .loading = supabasePullPreviewState {
            return true
        }
        return false
    }

    private var isProductPricePreviewLoading: Bool {
        if case .loading = productPricePreviewState {
            return true
        }
        return false
    }

    private var productPricePreviewSummary: ProductPricePreviewSummary? {
        if case .loaded(let summary) = productPricePreviewState {
            return summary
        }
        return nil
    }

    private var canRunProductPricePreview: Bool {
        isPushPreflightAccountReady
            && supabaseInventoryService != nil
            && !isProductPricePreviewLoading
    }

    private var productPricePreviewButtonKey: String {
        productPricePreviewSummary == nil
            ? "options.supabase.pricePreview.button.load"
            : "options.supabase.pricePreview.button.refresh"
    }

    private var isProductPriceApplyRunning: Bool {
        switch productPriceApplyState {
        case .loading, .applying(_):
            return true
        case .idle, .ready(_), .applied(_), .failed(_):
            return false
        }
    }

    private var productPriceApplyPlan: ProductPriceApplyPlan? {
        switch productPriceApplyState {
        case .ready(let plan), .applying(let plan):
            return plan
        case .idle, .loading, .applied(_), .failed(_):
            return nil
        }
    }

    private var canRunProductPriceApplyDryRun: Bool {
        isPushPreflightAccountReady
            && supabaseInventoryService != nil
            && !isProductPriceApplyRunning
    }

    private var canConfirmProductPriceApply: Bool {
        guard case .ready(let plan) = productPriceApplyState else {
            return false
        }
        return plan.isApplyAllowed && !isProductPriceApplyRunning
    }

    private var isProductPricePushDryRunLoading: Bool {
        productPriceManualPushViewModel.state.kind == .dryRunRunning
    }

    private var productPricePushDryRunPlan: ProductPricePushDryRunPlan? {
        productPriceManualPushViewModel.state.plan
    }

    private var canRunProductPricePushDryRun: Bool {
        isPushPreflightAccountReady
            && supabaseInventoryService != nil
            && productPriceManualPushViewModel.canCalculatePreview
    }

    private var canRunProductPriceManualPush: Bool {
        isPushPreflightAccountReady
            && productPriceManualPushViewModel.canPush
    }

    private var productPriceManualPushSnapshot: ProductPriceManualPushSnapshot? {
        productPriceManualPushViewModel.state.snapshot
    }

    private var pushPreflightRunButtonKey: String {
        selectedPushPreflightScope == .scopedTask045
            ? "options.supabase.pushpreflight.run.scopedTask045"
            : "options.supabase.pushpreflight.run"
    }

    private var supabaseAuthStatusRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(localizedSupabaseAuthStatus)
                if case .failed(let error) = supabaseAuthViewModel.state {
                    Text(localizedSupabaseAuthError(error))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: supabaseAuthStatusSystemImage)
                .foregroundStyle(supabaseAuthStatusColor)
        }
    }

    private var baselineStatusRow: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(L("options.supabase.baseline.status.label"))
                Text(L("options.supabase.baseline.status.\(supabaseBaselineSummary.status.rawValue)"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: baselineStatusSymbol(supabaseBaselineSummary.status))
                .foregroundStyle(baselineStatusColor(supabaseBaselineSummary.status))
        }
        .accessibilityElement(children: .combine)
    }

    private var syncEventsSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    productPriceApplyBadge("options.supabase.syncEvents.badge.readOnly", color: .orange)
                    Spacer()
                }

                if displayedSyncEventsState == .idle {
                    Text(L("options.supabase.syncEvents.state.idle"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await syncEventDebugViewModel.loadLatestEvents()
                    }
                } label: {
                    Label(L(syncEventsButtonKey), systemImage: "arrow.clockwise.circle")
                }
                .disabled(!canRunSyncEventsDebugActions)
                .accessibilityLabel(L(syncEventsButtonKey))
                .accessibilityHint(L("options.supabase.syncEvents.button.hint"))

                syncEventsStatusRow

                if let summary = syncEventDebugViewModel.summary,
                   displayedSyncEventsState == .successEmpty || displayedSyncEventsState == .successWithEvents {
                    syncEventsSummaryRows(summary)
                }

                if displayedSyncEventsState == .successWithEvents {
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(syncEventDebugViewModel.displayRows) { row in
                                syncEventDisplayRow(row)
                            }
                            Text(L(
                                "options.supabase.syncEvents.summary.displayedCount",
                                syncEventDebugViewModel.summary?.displayedCount ?? 0,
                                syncEventDebugViewModel.summary?.loadedCount ?? 0
                            ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(.top, 4)
                    } label: {
                        Label(L("options.supabase.syncEvents.list.title"), systemImage: "list.bullet.rectangle")
                    }
                    .accessibilityLabel(L("options.supabase.syncEvents.list.title"))
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .contain)
        } header: {
            SectionHeader(title: L("options.supabase.syncEvents.header"), systemImage: "clock.arrow.circlepath")
        } footer: {
            Text(L("options.supabase.syncEvents.footer"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var syncEventsStatusRow: some View {
        switch displayedSyncEventsState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.syncEvents.state.loading"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .successEmpty:
            Label {
                Text(L("options.supabase.syncEvents.state.empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "tray")
                    .foregroundStyle(.secondary)
            }
        case .successWithEvents:
            EmptyView()
        case .error(let message):
            Label {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .noSession:
            Label {
                Text(L("options.supabase.syncEvents.state.noSession"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "lock.fill")
                    .foregroundStyle(Color.orange)
            }
        case .notConfigured:
            Label {
                Text(L("options.supabase.syncEvents.state.notConfigured"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "wrench.and.screwdriver")
                    .foregroundStyle(Color.orange)
            }
        }
    }

    private func syncEventsSummaryRows(_ summary: SyncEventDebugDisplaySummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(
                L("options.supabase.syncEvents.summary.loadedCount"),
                value: "\(summary.loadedCount)"
            )

            if let latestEventDescription = summary.latestEventDescription {
                LabeledContent(
                    L("options.supabase.syncEvents.summary.latestEvent"),
                    value: latestEventDescription
                )
            }

            if let latestCreatedAtFormatted = summary.latestCreatedAtFormatted {
                LabeledContent(
                    L("options.supabase.syncEvents.field.createdAt"),
                    value: latestCreatedAtFormatted
                )
            }

            LabeledContent(
                L("options.supabase.syncEvents.summary.effectiveLimit"),
                value: summary.isLimitClamped
                    ? L("options.supabase.syncEvents.summary.effectiveLimitClamped", summary.effectiveLimit)
                    : "\(summary.effectiveLimit)"
            )

            LabeledContent(
                L("options.supabase.syncEvents.summary.displayedCount.label"),
                value: L(
                    "options.supabase.syncEvents.summary.displayedCount",
                    summary.displayedCount,
                    summary.loadedCount
                )
            )
        }
    }

    private func syncEventDisplayRow(_ row: SyncEventDebugDisplayRow) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(row.domain)
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(row.eventType)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(row.changedCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let source = row.source {
                LabeledContent(L("options.supabase.syncEvents.field.source"), value: source)
                    .font(.caption)
            }

            LabeledContent(L("options.supabase.syncEvents.field.id"), value: "\(row.id)")
                .font(.caption)
            LabeledContent(L("options.supabase.syncEvents.field.changedCount"), value: "\(row.changedCount)")
                .font(.caption)
            LabeledContent(L("options.supabase.syncEvents.field.createdAt"), value: row.createdAtFormatted)
                .font(.caption)
            LabeledContent(L("options.supabase.syncEvents.field.entitiesSummary"), value: syncEventValueText(row.entities))
                .font(.caption)
            LabeledContent(L("options.supabase.syncEvents.field.payloadSummary"), value: syncEventValueText(row.payload))
                .font(.caption)

            if let sanitizedPreview = row.sanitizedPreview {
                LabeledContent(L("options.supabase.syncEvents.field.preview"), value: sanitizedPreview)
                    .font(.caption)
            }
        }
        .padding(.vertical, 3)
    }

    private func syncEventValueText(_ summary: SyncEventDebugValueSummary) -> String {
        "\(L(summary.shape.localizationKey)) · \(summary.countText)"
    }

    private var productPricePreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text(L("options.supabase.pricePreview.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                Text(L("options.supabase.pricePreview.badge.readOnly"))
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Color.accentColor.opacity(0.14))
                    )
                    .foregroundStyle(Color.accentColor)
            }

            Text(L("options.supabase.pricePreview.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button {
                    runProductPricePreview()
                } label: {
                    Label(L(productPricePreviewButtonKey), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(!canRunProductPricePreview)

                if isProductPricePreviewLoading {
                    Button(L("common.cancel")) {
                        cancelProductPricePreviewFetch()
                    }
                    .buttonStyle(.borderless)
                }
            }

            productPricePreviewStatusRow

            if let summary = productPricePreviewSummary {
                productPricePreviewSummaryRows(summary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var productPricePreviewStatusRow: some View {
        switch productPricePreviewState {
        case .idle:
            EmptyView()
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.pricePreview.loading"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .loaded(let summary):
            Label {
                Text(productPricePreviewStatusMessage(summary))
                    .font(.footnote)
                    .foregroundStyle(productPricePreviewStatusColor(summary))
            } icon: {
                Image(systemName: productPricePreviewStatusSymbol(summary))
                    .foregroundStyle(productPricePreviewStatusColor(summary))
            }
        case .failed(let error):
            Label {
                Text(localizedSupabaseDiagnosticMessage(for: error))
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        }
    }

    private func productPricePreviewSummaryRows(_ summary: ProductPricePreviewSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(L("options.supabase.pricePreview.metric.rowsFetched"), value: "\(summary.totalFetched)")
            LabeledContent(L("options.supabase.pricePreview.metric.pagesFetched"), value: "\(summary.pagesFetched)")
            LabeledContent(L("options.supabase.pricePreview.metric.samplesShown"), value: "\(summary.samples.count)")
            LabeledContent(L("options.supabase.pricePreview.metric.orphans"), value: "\(summary.orphanCount)")
            LabeledContent(L("options.supabase.pricePreview.metric.invalidTypes"), value: "\(summary.invalidTypeCount)")
            LabeledContent(L("options.supabase.pricePreview.metric.invalidDates"), value: "\(summary.invalidEffectiveAtCount)")
            LabeledContent(
                L("options.supabase.pricePreview.metric.capped"),
                value: summary.truncated ? L("common.yes") : L("common.no")
            )

            DisclosureGroup(L("options.supabase.pricePreview.details")) {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent(
                        L("options.supabase.pricePreview.metric.stopReason"),
                        value: L("options.supabase.pricePreview.stop.\(summary.stoppedReason.rawValue)")
                    )

                    if let diagnosticDetail = summary.diagnosticDetail {
                        Text(diagnosticDetail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    if summary.samples.isEmpty {
                        Text(L("options.supabase.pricePreview.samples.empty"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(summary.samples) { sample in
                            productPricePreviewSampleRow(sample)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func productPricePreviewSampleRow(_ sample: ProductPricePreviewSampleRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L("options.supabase.pricePreview.type.\(sample.normalizedType)"))
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(SupabasePullPreviewNormalizer.decimalDisplay(sample.price) ?? "\(sample.price)")
                    .font(.footnote)
                if sample.isOrphan {
                    Text(L("options.supabase.pricePreview.badge.orphan"))
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(Color.orange.opacity(0.14))
                        )
                        .foregroundStyle(Color.orange)
                }
            }

            Text(sample.productDisplayName ?? L("options.supabase.pricePreview.product.orphan", sample.abbreviatedProductID))
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(productPricePreviewEffectiveAtText(sample))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var productPriceApplyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Label {
                    Text(L("options.supabase.priceApply.title"))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } icon: {
                    Image(systemName: "tray.and.arrow.down")
                        .foregroundStyle(Color.accentColor)
                }

                Spacer()

                productPriceApplyBadge("options.supabase.priceApply.badge.debug", color: .orange)
            }

            HStack(spacing: 6) {
                productPriceApplyBadge("options.supabase.priceApply.badge.localOnly", color: .green)
                productPriceApplyBadge("options.supabase.priceApply.badge.noCloudWrite", color: .blue)
            }

            Text(L("options.supabase.priceApply.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Label(L("options.supabase.priceApply.copy.insertOnly"), systemImage: "plus.circle")
                Label(L("options.supabase.priceApply.copy.noCurrentPriceUpdate"), systemImage: "lock.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Button {
                    prepareProductPriceApplyConfirmation()
                } label: {
                    Label(L("options.supabase.priceApply.button.apply"), systemImage: "tray.and.arrow.down.fill")
                }
                .disabled(!canConfirmProductPriceApply)

                HStack(spacing: 8) {
                    Button {
                        runProductPriceApplyDryRun()
                    } label: {
                        Label(L("options.supabase.priceApply.button.dryRun"), systemImage: "arrow.clockwise")
                    }
                    .disabled(!canRunProductPriceApplyDryRun)

                    if isProductPriceApplyRunning {
                        Button(L("common.cancel")) {
                            cancelProductPriceApply()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            productPriceApplyStatusRow

            if let plan = productPriceApplyPlan {
                productPriceApplyPlanRows(plan)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func productPriceApplyBadge(_ key: String, color: Color) -> some View {
        Text(L(key))
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
            .foregroundStyle(color)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var productPriceApplyStatusRow: some View {
        switch productPriceApplyState {
        case .idle:
            Text(L("options.supabase.priceApply.status.idle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .loading:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.priceApply.loading"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .ready(let plan):
            Label {
                Text(productPriceApplyStatusMessage(for: plan))
                    .font(.footnote)
                    .foregroundStyle(productPriceApplyStatusColor(for: plan))
            } icon: {
                Image(systemName: productPriceApplyStatusSymbol(for: plan))
                    .foregroundStyle(productPriceApplyStatusColor(for: plan))
            }
        case .applying(_):
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.priceApply.applying"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .applied(let result):
            Label {
                Text(L("options.supabase.priceApply.status.applied"))
                    .font(.footnote)
                    .foregroundStyle(Color.green)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
            Text(L(
                "options.supabase.priceApply.result.counts",
                result.inserted,
                result.skippedExisting,
                result.totalConsidered
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .failed(let message):
            Label {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        }
    }

    private func productPriceApplyPlanRows(_ plan: ProductPriceApplyPlan) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent(L("options.supabase.priceApply.metric.remoteRead"), value: "\(plan.summary.remoteRead)")
            LabeledContent(L("options.supabase.priceApply.metric.toInsert"), value: "\(plan.summary.included)")
            LabeledContent(L("options.supabase.priceApply.metric.skippedExisting"), value: "\(plan.summary.skippedExisting)")
            LabeledContent(L("options.supabase.priceApply.metric.unmapped"), value: "\(plan.summary.unmapped)")
            LabeledContent(L("options.supabase.priceApply.metric.invalid"), value: "\(plan.summary.invalid)")
            LabeledContent(L("options.supabase.priceApply.metric.conflicts"), value: "\(plan.summary.conflicts)")
            LabeledContent(L("options.supabase.priceApply.metric.mappingConflicts"), value: "\(plan.summary.mappingConflicts)")
            LabeledContent(
                L("options.supabase.priceApply.metric.partial"),
                value: plan.summary.partial ? L("common.yes") : L("common.no")
            )
            LabeledContent(
                L("options.supabase.priceApply.metric.truncated"),
                value: plan.summary.truncated ? L("common.yes") : L("common.no")
            )

            if !plan.blockReasons.isEmpty {
                DisclosureGroup(L("options.supabase.priceApply.metric.blockReasons")) {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(plan.blockReasons, id: \.rawValue) { reason in
                            Text(localizedProductPriceApplyBlockReason(reason))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 4)
                }
            }

            if !plan.issues.isEmpty {
                DisclosureGroup(L("options.supabase.priceApply.metric.issues")) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(plan.issues) { issue in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(localizedProductPriceApplyIssueReason(issue.reason))
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                Text(issue.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private var productPriceManualPushCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("options.supabase.priceManualPush.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            productPriceManualPushActionButtons

            productPriceManualPushStatusRow

            if let snapshot = productPriceManualPushSnapshot {
                LabeledContent(
                    L("options.supabase.priceManualPush.fingerprint"),
                    value: snapshot.abbreviatedFingerprint
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            if let plan = productPricePushDryRunPlan {
                productPricePushDryRunSummaryRows(plan)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private var productPriceManualPushActionButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                productPriceManualPushPreviewButton
                productPriceManualPushCommitButton
                productPriceManualPushCancelButton
            }

            VStack(alignment: .leading, spacing: 8) {
                productPriceManualPushPreviewButton
                productPriceManualPushCommitButton
                productPriceManualPushCancelButton
            }
        }
    }

    private var productPriceManualPushPreviewButton: some View {
        Button {
            runProductPriceManualPushPreview()
        } label: {
            Label(L("options.supabase.priceManualPush.button.calculate"), systemImage: "doc.text.magnifyingglass")
        }
        .disabled(!canRunProductPricePushDryRun)
        .buttonStyle(.borderedProminent)
        .accessibilityHint(L("options.supabase.priceManualPush.accessibility.calculateHint"))
    }

    private var productPriceManualPushCommitButton: some View {
        Button {
            isShowingProductPriceManualPushConfirmation = true
        } label: {
            Label(L("options.supabase.priceManualPush.button.push"), systemImage: "paperplane")
        }
        .disabled(!canRunProductPriceManualPush)
        .buttonStyle(.bordered)
        .accessibilityHint(productPriceManualPushDisabledHint)
    }

    @ViewBuilder
    private var productPriceManualPushCancelButton: some View {
        if productPriceManualPushViewModel.state.isBusy {
            Button(L("common.cancel")) {
                cancelProductPriceManualPush()
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var productPriceManualPushStatusRow: some View {
        switch productPriceManualPushViewModel.state {
        case .idle:
            Text(L("options.supabase.priceManualPush.status.idle"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .dryRunRunning:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.priceManualPush.status.dryRunRunning"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .pushRunning:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.priceManualPush.status.pushRunning"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .readBackRunning:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.priceManualPush.status.readBackRunning"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .previewSafe(let plan, _), .pushReady(let plan, _):
            Label {
                Text(productPricePushDryRunStatusMessage(for: plan))
                    .font(.footnote)
                    .foregroundStyle(productPricePushDryRunStatusColor(for: plan))
            } icon: {
                Image(systemName: productPricePushDryRunStatusSymbol(for: plan))
                    .foregroundStyle(productPricePushDryRunStatusColor(for: plan))
            }
        case .previewUnsafe(let plan, let reason):
            Label {
                Text(productPriceManualPushPreviewUnsafeMessage(plan: plan, reason: reason))
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .snapshotStale:
            Label {
                Text(L("options.supabase.priceManualPush.status.snapshotStale"))
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } icon: {
                Image(systemName: "clock.badge.exclamationmark")
                    .foregroundStyle(Color.orange)
            }
        case .overBatchLimit(_, let limit, let actual):
            Label {
                Text(L("options.supabase.priceManualPush.status.overBatchLimit", actual, limit))
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .verifiedSuccess:
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("options.supabase.priceManualPush.status.verifiedSuccess"))
                    Text(L("options.supabase.priceManualPush.status.successHint"))
                        .foregroundStyle(.secondary)
                }
                .font(.footnote)
            } icon: {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(Color.green)
            }
        case .verificationUnknown:
            Label {
                Text(L("options.supabase.priceManualPush.status.verificationUnknown"))
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } icon: {
                Image(systemName: "questionmark.diamond.fill")
                    .foregroundStyle(Color.orange)
            }
        case .failedConflict:
            Label {
                Text(L("options.supabase.priceManualPush.status.failedConflict"))
                    .font(.footnote)
                    .foregroundStyle(Color.orange)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .failedValidation:
            Label {
                Text(L("options.supabase.priceManualPush.status.failedValidation"))
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } icon: {
                Image(systemName: "xmark.octagon.fill")
                    .foregroundStyle(Color.red)
            }
        case .failedNetwork:
            Label {
                Text(L("options.supabase.priceManualPush.status.failedNetwork"))
                    .font(.footnote)
                    .foregroundStyle(Color.red)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
            }
        case .cancelled:
            Text(L("options.supabase.priceManualPush.status.cancelled"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func productPricePushDryRunSummaryRows(_ plan: ProductPricePushDryRunPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            productPricePushDryRunSummaryChips(plan.summary)

            let dedupeMessage = productPricePushRemoteDedupeMessage(plan.remoteDedupeStatus)
            Label {
                Text(dedupeMessage)
                    .font(.footnote)
                    .foregroundStyle(plan.isRemoteDedupeSafe ? Color.green : Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } icon: {
                Image(systemName: plan.isRemoteDedupeSafe ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(plan.isRemoteDedupeSafe ? Color.green : Color.orange)
            }
            .accessibilityLabel(L("options.supabase.pricePushPreview.accessibility.dedupeStatus"))
            .accessibilityValue(dedupeMessage)

            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.candidates",
                total: plan.summary.readyCandidates,
                lines: plan.candidates
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.alreadyPresent",
                total: plan.summary.alreadyPresentRemote,
                lines: plan.alreadyPresentRemote
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.localDuplicates",
                total: plan.summary.localDuplicateSameKey,
                lines: plan.localDuplicateSameKey
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.localConflicts",
                total: plan.summary.localConflictSameKeyDifferentPrice,
                lines: plan.localConflictSameKeyDifferentPrice
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.blocked",
                total: plan.summary.blockedTotal,
                lines: plan.blockedNoRemoteID,
                messages: productPricePushGlobalBlockedMessages(plan.summary)
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.remoteConflicts",
                total: plan.summary.conflictSameKeyDifferentPrice,
                lines: plan.conflictSameKeyDifferentPrice
            )
            productPricePushBucketDisclosure(
                titleKey: "options.supabase.pricePushPreview.bucket.invalid",
                total: plan.summary.excludedInvalidLocal,
                lines: plan.excludedInvalidLocal
            )
        }
    }

    private func productPricePushDryRunSummaryChips(_ summary: ProductPricePushDryRunSummary) -> some View {
        let chips: [(String, Int, Color)] = [
            ("options.supabase.pricePushPreview.chip.ready", summary.readyCandidates, .green),
            ("options.supabase.pricePushPreview.chip.alreadyPresent", summary.alreadyPresentRemote, .blue),
            ("options.supabase.pricePushPreview.chip.localDuplicates", summary.localDuplicateSameKey, .orange),
            ("options.supabase.pricePushPreview.chip.localConflicts", summary.localConflictSameKeyDifferentPrice, .red),
            ("options.supabase.pricePushPreview.chip.blocked", summary.blockedTotal, .orange),
            ("options.supabase.pricePushPreview.chip.remoteConflicts", summary.conflictSameKeyDifferentPrice, .red)
        ]

        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 118), spacing: 8, alignment: .leading)],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                productPricePushChip(titleKey: chip.0, count: chip.1, color: chip.2)
            }
        }
    }

    private func productPricePushChip(titleKey: String, count: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Text(L(titleKey))
                .font(.caption)
                .fontWeight(.semibold)
                .lineLimit(2)
            Text("\(count)")
                .font(.caption)
                .monospacedDigit()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
        )
        .foregroundStyle(color)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func productPricePushBucketDisclosure(
        titleKey: String,
        total: Int,
        lines: [ProductPricePushDryRunLine],
        messages: [String] = []
    ) -> some View {
        if total > 0 {
            DisclosureGroup(L(titleKey, total)) {
                VStack(alignment: .leading, spacing: 8) {
                    let visibleMessages = Array(messages.prefix(20))
                    let remainingLineLimit = max(0, 20 - visibleMessages.count)
                    let visibleLines = Array(lines.prefix(remainingLineLimit))
                    Text(L(
                        "options.supabase.pricePushPreview.bucket.showing",
                        visibleMessages.count + visibleLines.count,
                        total
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    ForEach(visibleMessages, id: \.self) { message in
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(visibleLines) { line in
                        productPricePushLineRow(line)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    private func productPricePushGlobalBlockedMessages(_ summary: ProductPricePushDryRunSummary) -> [String] {
        var messages: [String] = []
        if summary.blockedNoAuth > 0 {
            messages.append(L("options.supabase.pricePushPreview.blocked.noAuth"))
        }
        if summary.blockedAccountMismatch > 0 {
            messages.append(L("options.supabase.pricePushPreview.blocked.accountMismatch"))
        }
        if summary.blockedBaselineMissing > 0 {
            messages.append(L("options.supabase.pricePushPreview.blocked.baselineMissing"))
        }
        if summary.blockedBaselineStale > 0 {
            messages.append(L("options.supabase.pricePushPreview.blocked.baselineStale"))
        }
        if summary.blockedBaselinePartial > 0 {
            messages.append(L("options.supabase.pricePushPreview.blocked.baselinePartial"))
        }
        return messages
    }

    private func productPricePushLineRow(_ line: ProductPricePushDryRunLine) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(L("options.supabase.pricePreview.type.\(line.type)"))
                    .font(.footnote)
                    .fontWeight(.semibold)
                Text(line.canonicalPrice?.value ?? L("options.supabase.preview.valueMissing"))
                    .font(.footnote)
                    .monospacedDigit()
            }

            Text(line.productDisplayName)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let effectiveAtCanonical = line.effectiveAtCanonical {
                Text(L("options.supabase.pricePushPreview.effectiveAt", effectiveAtCanonical))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var localizedSupabaseAuthStatus: String {
        switch supabaseAuthViewModel.state {
        case .unconfigured:
            return L("options.supabase.auth.status.unconfigured")
        case .signedOut:
            return L("options.supabase.auth.status.signedOut")
        case .signingIn:
            return L("options.supabase.auth.status.signingIn")
        case .signedIn:
            if let email = supabaseAuthViewModel.sessionInfo?.displayEmail {
                return L("options.supabase.auth.status.signedInEmail", email)
            }
            return L("options.supabase.auth.status.signedIn")
        case .signingOut:
            return L("options.supabase.auth.status.signingOut")
        case .failed:
            return L("options.supabase.auth.status.failed")
        }
    }

    private var supabaseAuthStatusSystemImage: String {
        switch supabaseAuthViewModel.state {
        case .unconfigured:
            return "exclamationmark.triangle"
        case .signedOut:
            return "person.crop.circle.badge.xmark"
        case .signingIn, .signingOut:
            return "hourglass"
        case .signedIn:
            return "person.crop.circle.badge.checkmark"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }

    private var supabaseAuthStatusColor: Color {
        switch supabaseAuthViewModel.state {
        case .signedIn:
            return .green
        case .failed, .unconfigured:
            return .orange
        case .signedOut, .signingIn, .signingOut:
            return .secondary
        }
    }

    private func runSupabaseDiagnostic() {
        guard !isRunningSupabaseDiagnostic else { return }
        guard supabaseAuthViewModel.isSignedIn else {
            supabaseDiagnosticMessage = localizedSupabaseDiagnosticMessage(for: .sessionMissing)
            supabaseDiagnosticIsError = true
            return
        }
        guard let service = supabaseInventoryService else {
            supabaseDiagnosticMessage = localizedSupabaseDiagnosticMessage(for: .configMissing)
            supabaseDiagnosticIsError = true
            return
        }

        isRunningSupabaseDiagnostic = true
        supabaseDiagnosticMessage = nil
        supabaseDiagnosticIsError = false

        Task {
            do {
                let result = try await service.testConnection()
                supabaseDiagnosticMessage = localizedSupabaseDiagnosticMessage(for: result)
                supabaseDiagnosticIsError = false
            } catch let error as SupabaseInventoryServiceError {
                supabaseDiagnosticMessage = localizedSupabaseDiagnosticMessage(for: error)
                supabaseDiagnosticIsError = true
            } catch {
                let serviceError = SupabaseInventoryServiceError.unknown(message: String(describing: error))
                supabaseDiagnosticMessage = localizedSupabaseDiagnosticMessage(for: serviceError)
                supabaseDiagnosticIsError = true
            }

            isRunningSupabaseDiagnostic = false
        }
    }

    private func runSupabasePullPreview() {
        guard !isSupabasePullPreviewLoading else { return }
        guard supabaseAuthViewModel.isSignedIn else {
            supabasePullPreviewState = .failed(.service(.sessionMissing))
            isShowingSupabasePullPreview = true
            return
        }
        guard let service = supabasePullPreviewService else {
            supabasePullPreviewState = .failed(.service(.configMissing))
            isShowingSupabasePullPreview = true
            return
        }

        supabasePullPreviewState = .loading(progressMessage: L("options.supabase.preview.loading"))
        isShowingSupabasePullPreview = true

        Task {
            supabasePullPreviewState = await service.generatePreview(context: modelContext)
        }
    }

    private func runProductPricePreview() {
        guard !isProductPricePreviewLoading else { return }
        guard isPushPreflightAccountReady,
              let expectedUserID = supabaseAuthViewModel.sessionInfo?.userID else {
            productPricePreviewState = .failed(.sessionMissing)
            return
        }
        guard let inventoryService = supabaseInventoryService else {
            productPricePreviewState = .failed(.configMissing)
            return
        }

        productPricePreviewTask?.cancel()
        let requestID = UUID()
        productPricePreviewRequestID = requestID
        productPricePreviewState = .loading

        productPricePreviewTask = Task { @MainActor in
            do {
                let lookup = try ProductPricePreviewLocalLookupBuilder.makeLookup(context: modelContext)
                let service = SupabaseProductPricePreviewService(fetcher: inventoryService)
                let summary = try await service.loadPreview(productLookup: lookup)
                guard productPricePreviewRequestID == requestID,
                      supabaseAuthViewModel.sessionInfo?.userID == expectedUserID,
                      supabaseAuthViewModel.isSignedIn else {
                    return
                }

                productPricePreviewState = .loaded(summary)
                productPricePreviewTask = nil
                productPricePreviewRequestID = nil
            } catch let error as SupabaseInventoryServiceError {
                guard productPricePreviewRequestID == requestID else { return }
                productPricePreviewState = .failed(error)
                productPricePreviewTask = nil
                productPricePreviewRequestID = nil
            } catch {
                guard productPricePreviewRequestID == requestID else { return }
                productPricePreviewState = .failed(.unknown(message: String(describing: error)))
                productPricePreviewTask = nil
                productPricePreviewRequestID = nil
            }
        }
    }

    private func cancelProductPricePreviewFetch() {
        productPricePreviewTask?.cancel()
    }

    private func ignoreProductPricePreviewResults() {
        productPricePreviewTask?.cancel()
        productPricePreviewTask = nil
        productPricePreviewRequestID = nil
    }

    private func resetProductPricePreview() {
        ignoreProductPricePreviewResults()
        productPricePreviewState = .idle
    }

    private func runProductPriceApplyDryRun() {
        guard canRunProductPriceApplyDryRun else { return }
        guard let expectedUserID = supabaseAuthViewModel.sessionInfo?.userID else {
            productPriceApplyState = .failed(L("options.supabase.priceApply.error.sessionMissing"))
            return
        }
        guard let inventoryService = supabaseInventoryService else {
            productPriceApplyState = .failed(L("options.supabase.priceApply.error.fetcherMissing"))
            return
        }

        pendingProductPriceApplyPlan = nil
        isShowingProductPriceApplyConfirmation = false
        productPriceApplyTask?.cancel()

        let requestID = UUID()
        productPriceApplyRequestID = requestID
        productPriceApplyState = .loading

        productPriceApplyTask = Task { @MainActor in
            do {
                let service = SupabaseProductPriceApplyService(fetcher: inventoryService)
                let plan = try await service.loadDryRun(
                    context: modelContext,
                    sessionSnapshot: ProductPriceApplySessionSnapshot(userID: expectedUserID)
                )
                guard productPriceApplyRequestID == requestID,
                      supabaseAuthViewModel.sessionInfo?.userID == expectedUserID,
                      supabaseAuthViewModel.isSignedIn else {
                    return
                }

                productPriceApplyState = .ready(plan)
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            } catch let error as ProductPriceApplyError {
                guard productPriceApplyRequestID == requestID else { return }
                productPriceApplyState = .failed(localizedProductPriceApplyError(error))
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            } catch {
                guard productPriceApplyRequestID == requestID else { return }
                productPriceApplyState = .failed(L(
                    "options.supabase.priceApply.error.unknown",
                    String(describing: error)
                ))
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            }
        }
    }

    private func prepareProductPriceApplyConfirmation() {
        guard case .ready(let plan) = productPriceApplyState,
              plan.isApplyAllowed else {
            return
        }

        pendingProductPriceApplyPlan = plan
        isShowingProductPriceApplyConfirmation = true
    }

    private func runConfirmedProductPriceApply() {
        guard let plan = pendingProductPriceApplyPlan,
              plan.isApplyAllowed,
              !isProductPriceApplyRunning else {
            pendingProductPriceApplyPlan = nil
            return
        }
        guard let currentUserID = supabaseAuthViewModel.sessionInfo?.userID,
              supabaseAuthViewModel.isSignedIn else {
            productPriceApplyState = .failed(L("options.supabase.priceApply.error.sessionMissing"))
            pendingProductPriceApplyPlan = nil
            return
        }

        let requestID = UUID()
        productPriceApplyRequestID = requestID
        productPriceApplyState = .applying(plan)
        pendingProductPriceApplyPlan = nil

        productPriceApplyTask = Task { @MainActor in
            do {
                let service = SupabaseProductPriceApplyService()
                let result = try service.apply(
                    plan: plan,
                    context: modelContext,
                    currentSessionSnapshot: ProductPriceApplySessionSnapshot(userID: currentUserID)
                )
                guard productPriceApplyRequestID == requestID,
                      supabaseAuthViewModel.sessionInfo?.userID == currentUserID,
                      supabaseAuthViewModel.isSignedIn else {
                    return
                }

                productPriceApplyState = .applied(result)
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            } catch let error as ProductPriceApplyError {
                guard productPriceApplyRequestID == requestID else { return }
                productPriceApplyState = .failed(localizedProductPriceApplyError(error))
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            } catch {
                guard productPriceApplyRequestID == requestID else { return }
                productPriceApplyState = .failed(L(
                    "options.supabase.priceApply.error.unknown",
                    String(describing: error)
                ))
                productPriceApplyTask = nil
                productPriceApplyRequestID = nil
            }
        }
    }

    private func cancelProductPriceApply() {
        productPriceApplyTask?.cancel()
        productPriceApplyTask = nil
        productPriceApplyRequestID = nil
        pendingProductPriceApplyPlan = nil
        productPriceApplyState = .idle
    }

    private func resetProductPriceApply() {
        cancelProductPriceApply()
    }

    private func runProductPriceManualPushPreview() {
        guard canRunProductPricePushDryRun else { return }
        let lastLinkedUserID = UUID(uuidString: supabaseLastLinkedUserID)
        productPriceManualPushViewModel.calculatePreview(
            context: modelContext,
            sessionSnapshot: ProductPricePushDryRunSessionSnapshot(
                userID: supabaseAuthViewModel.sessionInfo?.userID,
                lastLinkedUserID: lastLinkedUserID
            )
        )
    }

    private func cancelProductPriceManualPush() {
        productPriceManualPushViewModel.cancel()
    }

    private func resetProductPriceManualPush() {
        productPriceManualPushViewModel.reset()
    }

    private func runConfirmedProductPriceManualPush() {
        productPriceManualPushViewModel.confirmPush()
    }

    private func runSupabasePushPreflight() {
        guard canRunSelectedPushPreflight else { return }
        pushPreflightViewModel.runLocalCheck(
            context: modelContext,
            isSignedIn: supabaseAuthViewModel.isSignedIn && !supabaseAuthViewModel.isTransitioning,
            currentUserID: supabaseAuthViewModel.sessionInfo?.userID,
            lastLinkedUserID: UUID(uuidString: supabaseLastLinkedUserID),
            scope: selectedPushPreflightScope
        )
    }

    private func runTask045RemoteCollisionCheck() {
        guard selectedPushPreflightScope == .scopedTask045 else { return }
        guard !isRunningTask045RemoteCollisionCheck else { return }
        guard supabaseAuthViewModel.isSignedIn else {
            task045RemoteCollisionMessage = localizedSupabaseDiagnosticMessage(for: .sessionMissing)
            task045RemoteCollisionIsError = true
            task045RemoteCollisionGatePassed = false
            return
        }
        guard let service = supabaseInventoryService else {
            task045RemoteCollisionMessage = localizedSupabaseDiagnosticMessage(for: .configMissing)
            task045RemoteCollisionIsError = true
            task045RemoteCollisionGatePassed = false
            return
        }

        isRunningTask045RemoteCollisionCheck = true
        task045RemoteCollisionMessage = nil
        task045RemoteCollisionIsError = false
        task045RemoteCollisionGatePassed = false

        Task {
            do {
                let summary = try await service.fetchTask045RemoteCollisionSummary()
                task045RemoteCollisionMessage = L(
                    summary.isClear
                        ? "options.supabase.pushpreflight.collision.task045.clear"
                        : "options.supabase.pushpreflight.collision.task045.found",
                    summary.supplierCount,
                    summary.categoryCount,
                    summary.productCount
                )
                task045RemoteCollisionIsError = !summary.isClear
                task045RemoteCollisionGatePassed = summary.isClear
            } catch let error as SupabaseInventoryServiceError {
                task045RemoteCollisionMessage = localizedSupabaseDiagnosticMessage(for: error)
                task045RemoteCollisionIsError = true
                task045RemoteCollisionGatePassed = false
            } catch {
                let serviceError = SupabaseInventoryServiceError.unknown(message: String(describing: error))
                task045RemoteCollisionMessage = localizedSupabaseDiagnosticMessage(for: serviceError)
                task045RemoteCollisionIsError = true
                task045RemoteCollisionGatePassed = false
            }

            isRunningTask045RemoteCollisionCheck = false
        }
    }

    private func resetTask045RemoteCollisionGate() {
        isRunningTask045RemoteCollisionCheck = false
        task045RemoteCollisionMessage = nil
        task045RemoteCollisionIsError = false
        task045RemoteCollisionGatePassed = false
    }

    private func prepareManualPushConfirmation() {
        guard let plan = pushPreflightViewModel.freezeCurrentPlanForConfirmation() else {
            pendingManualPushPlan = nil
            return
        }
        pendingManualPushPlan = plan
        isShowingManualPushConfirmation = true
    }

    private func runConfirmedManualPush() {
        pushPreflightViewModel.runConfirmedPush(
            context: modelContext,
            isSignedIn: supabaseAuthViewModel.isSignedIn && !supabaseAuthViewModel.isTransitioning,
            currentUserID: supabaseAuthViewModel.sessionInfo?.userID,
            lastLinkedUserID: UUID(uuidString: supabaseLastLinkedUserID)
        )
        pendingManualPushPlan = nil
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

    @ViewBuilder
    private var preflightStateRow: some View {
        let state = displayedPushPreflightState
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(L(preflightStateTextKey(state)))
                if case .accountNotLinked = state {
                    Text(L("options.supabase.pushpreflight.accountRequired"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: preflightStateSymbol(state))
                .foregroundStyle(preflightStateColor(state))
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func preflightSummaryCard(
        titleKey: String,
        icon: String,
        color: Color,
        summary: SupabasePushPreflightViewModel.Summary
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(L(titleKey))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(color)
            }

            LabeledContent(L("options.supabase.pushpreflight.metric.candidates"), value: "\(summary.totalCandidates)")
            LabeledContent(L("options.supabase.pushpreflight.metric.blockers"), value: "\(summary.totalBlockers)")
            LabeledContent(L("options.supabase.pushpreflight.metric.warnings"), value: "\(summary.totalWarnings)")
            LabeledContent(L("options.supabase.pushpreflight.metric.futureOnly"), value: "\(summary.totalFutureOnly)")
            if summary.scopeSummary.mode.isScopedTask045 {
                LabeledContent(L("options.supabase.pushpreflight.metric.scopeIncluded"), value: "\(summary.scopeSummary.included)")
                LabeledContent(L("options.supabase.pushpreflight.metric.scopeExcluded"), value: "\(summary.scopeSummary.excludedOutsideScope)")
                LabeledContent(L("options.supabase.pushpreflight.metric.scopeBlockedDependencies"), value: "\(summary.scopeSummary.blockedDependencies)")
            }
            LabeledContent(
                L("options.supabase.manualpush.result.suppliers"),
                value: resultCounts(creates: summary.supplierCreates, updates: summary.supplierUpdates, links: summary.supplierLinks)
            )
            LabeledContent(
                L("options.supabase.manualpush.result.categories"),
                value: resultCounts(creates: summary.categoryCreates, updates: summary.categoryUpdates, links: summary.categoryLinks)
            )
            LabeledContent(
                L("options.supabase.manualpush.result.products"),
                value: resultCounts(creates: summary.productCreates, updates: summary.productUpdates, links: summary.productLinks)
            )

            DisclosureGroup(L("options.supabase.pushpreflight.details")) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(summary.groups) { group in
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text(L("options.supabase.pushpreflight.category.\(group.category.rawValue)", group.count))
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                            } icon: {
                                Image(systemName: severitySymbol(group.severity))
                                    .foregroundStyle(severityColor(group.severity))
                            }

                            ForEach(group.examples, id: \.self) { example in
                                Text(L("options.supabase.pushpreflight.example", example))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                            if group.hiddenCount > 0 {
                                Text(L("options.supabase.pushpreflight.more", group.hiddenCount))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
    }

    private func preflightStateTextKey(_ state: SupabasePushPreflightViewModel.ViewState) -> String {
        switch state {
        case .idle:
            return "options.supabase.pushpreflight.state.idle"
        case .accountNotLinked:
            return "options.supabase.pushpreflight.state.accountNotLinked"
        case .running:
            return "options.supabase.pushpreflight.state.running"
        case .completedSafe:
            return "options.supabase.pushpreflight.state.completedSafe"
        case .completedScopedSafe:
            return "options.supabase.pushpreflight.state.completedScopedSafe"
        case .completedScopedBlocked:
            return "options.supabase.pushpreflight.state.completedScopedBlocked"
        case .completedNoWork:
            return "options.supabase.pushpreflight.state.completedNoWork"
        case .completedBlocked:
            return "options.supabase.pushpreflight.state.completedBlocked"
        case .completed:
            return "options.supabase.manualpush.state.completed"
        case .completedBaselineRefreshFailed:
            return "options.supabase.manualpush.state.completedBaselineRefreshFailed"
        case .partial:
            return "options.supabase.manualpush.state.partial"
        case .failedBeforeWrite:
            return "options.supabase.manualpush.state.failedBeforeWrite"
        case .blockedBeforeWrite:
            return "options.supabase.manualpush.state.blockedBeforeWrite"
        case .failedLocalError:
            return "options.supabase.pushpreflight.state.failedLocalError"
        }
    }

    private func preflightStateSymbol(_ state: SupabasePushPreflightViewModel.ViewState) -> String {
        switch state {
        case .idle:
            return "checklist"
        case .accountNotLinked:
            return "lock.fill"
        case .running:
            return "hourglass"
        case .completedSafe, .completedScopedSafe, .completedNoWork, .completed:
            return "checkmark.circle.fill"
        case .completedScopedBlocked:
            return "xmark.shield.fill"
        case .completedBaselineRefreshFailed:
            return "externaldrive.badge.exclamationmark"
        case .partial:
            return "exclamationmark.triangle.fill"
        case .failedBeforeWrite:
            return "xmark.octagon.fill"
        case .blockedBeforeWrite:
            return "lock.fill"
        case .completedBlocked:
            return "exclamationmark.triangle.fill"
        case .failedLocalError:
            return "xmark.octagon.fill"
        }
    }

    private func preflightStateColor(_ state: SupabasePushPreflightViewModel.ViewState) -> Color {
        switch state {
        case .completedSafe, .completedScopedSafe, .completedNoWork, .completed:
            return .green
        case .completedBaselineRefreshFailed, .partial, .completedBlocked, .completedScopedBlocked, .accountNotLinked, .blockedBeforeWrite:
            return .orange
        case .failedLocalError, .failedBeforeWrite:
            return .red
        case .idle, .running:
            return .secondary
        }
    }

    @ViewBuilder
    private func manualPushResultCard(_ execution: SupabasePushPreflightViewModel.ExecutionSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                Text(L(preflightStateTextKey(pushPreflightViewModel.state)))
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } icon: {
                Image(systemName: preflightStateSymbol(pushPreflightViewModel.state))
                    .foregroundStyle(preflightStateColor(pushPreflightViewModel.state))
            }

            LabeledContent(L("options.supabase.manualpush.result.suppliers"), value: resultCounts(
                creates: execution.result.supplierCreates,
                updates: execution.result.supplierUpdates,
                links: execution.result.supplierLinks
            ))
            LabeledContent(L("options.supabase.manualpush.result.categories"), value: resultCounts(
                creates: execution.result.categoryCreates,
                updates: execution.result.categoryUpdates,
                links: execution.result.categoryLinks
            ))
            LabeledContent(L("options.supabase.manualpush.result.products"), value: resultCounts(
                creates: execution.result.productCreates,
                updates: execution.result.productUpdates,
                links: execution.result.productLinks
            ))
            Text(L(actionKey(for: execution.result.status)))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let message = execution.result.message, !message.isEmpty {
                DisclosureGroup(L("options.supabase.manualpush.result.details")) {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func resultCounts(creates: Int, updates: Int, links: Int) -> String {
        L("options.supabase.manualpush.result.counts", creates, updates, links)
    }

    private func actionKey(for status: SupabaseManualPushTerminalStatus) -> String {
        switch status {
        case .completed:
            return "options.supabase.manualpush.action.completed"
        case .completedBaselineRefreshFailed:
            return "options.supabase.manualpush.action.completedBaselineRefreshFailed"
        case .partial:
            return "options.supabase.manualpush.action.partial"
        case .failedBeforeWrite:
            return "options.supabase.manualpush.action.failedBeforeWrite"
        case .blockedBeforeWrite:
            return "options.supabase.manualpush.action.blockedBeforeWrite"
        }
    }

    private func manualPushConfirmationMessage(for plan: ManualPushPlan) -> String {
        let counts = [
            L("options.supabase.manualpush.confirm.suppliers", plan.count(entityKind: .supplier, action: .dryRunCreateCandidate), plan.count(entityKind: .supplier, action: .dryRunUpdateCandidate), plan.count(entityKind: .supplier, action: .dryRunLinkCandidate)),
            L("options.supabase.manualpush.confirm.categories", plan.count(entityKind: .productCategory, action: .dryRunCreateCandidate), plan.count(entityKind: .productCategory, action: .dryRunUpdateCandidate), plan.count(entityKind: .productCategory, action: .dryRunLinkCandidate)),
            L("options.supabase.manualpush.confirm.products", plan.count(entityKind: .product, action: .dryRunCreateCandidate), plan.count(entityKind: .product, action: .dryRunUpdateCandidate), plan.count(entityKind: .product, action: .dryRunLinkCandidate)),
            L("options.supabase.manualpush.confirm.writes"),
            L("options.supabase.manualpush.confirm.noProductPrice"),
            L("options.supabase.manualpush.confirm.noDelete"),
            L("options.supabase.manualpush.confirm.noAutoSync")
        ]
        return counts.joined(separator: "\n")
    }

    private func severitySymbol(_ severity: PushSeverity) -> String {
        switch severity {
        case .blocker:
            return "xmark.shield.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .futureOnly:
            return "clock.badge.exclamationmark"
        case .info:
            return "info.circle.fill"
        }
    }

    private func severityColor(_ severity: PushSeverity) -> Color {
        switch severity {
        case .blocker:
            return .orange
        case .warning:
            return .yellow
        case .futureOnly:
            return .purple
        case .info:
            return .secondary
        }
    }

    private func baselineStatusSymbol(_ status: SupabaseCatalogBaselineDebugStatus) -> String {
        switch status {
        case .absent:
            return "externaldrive.badge.questionmark"
        case .valid:
            return "checkmark.seal.fill"
        case .stale:
            return "clock.badge.exclamationmark"
        case .accountMismatch:
            return "person.crop.circle.badge.exclamationmark"
        case .incomplete:
            return "exclamationmark.triangle.fill"
        }
    }

    private func baselineStatusColor(_ status: SupabaseCatalogBaselineDebugStatus) -> Color {
        switch status {
        case .valid:
            return .green
        case .stale, .accountMismatch, .incomplete:
            return .orange
        case .absent:
            return .secondary
        }
    }

    private func localizedSupabaseDiagnosticMessage(for result: SupabaseInventoryDiagnosticResult) -> String {
        switch result {
        case .catalogProbeSucceeded(let rowCount):
            return L("options.supabase.diagnostic.success", rowCount)
        }
    }

    private func localizedSupabaseDiagnosticMessage(for error: SupabaseInventoryServiceError) -> String {
        let baseMessage: String

        switch error {
        case .configMissing:
            baseMessage = L("options.supabase.diagnostic.configMissing")
        case .invalidConfig:
            baseMessage = L("options.supabase.diagnostic.invalidConfig")
        case .sessionMissing:
            baseMessage = L("options.supabase.diagnostic.sessionMissing")
        case .networkError:
            baseMessage = L("options.supabase.diagnostic.networkError")
        case .permissionDeniedOrRLS:
            baseMessage = L("options.supabase.diagnostic.permissionDeniedOrRLS")
        case .decodingError:
            baseMessage = L("options.supabase.diagnostic.decodingError")
        case .schemaDrift:
            baseMessage = L("options.supabase.diagnostic.schemaDrift")
        case .unknown:
            baseMessage = L("options.supabase.diagnostic.unknown")
        }

        guard let detail = error.safeDiagnosticDetail else {
            return baseMessage
        }

        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }

    private func productPricePreviewStatusMessage(_ summary: ProductPricePreviewSummary) -> String {
        switch summary.stoppedReason {
        case .cancelled:
            return L("options.supabase.pricePreview.cancelled")
        case .error:
            return L("options.supabase.pricePreview.incomplete")
        case .maxRows, .maxPages:
            return L("options.supabase.pricePreview.capped")
        case .pageEmpty, .partialPage:
            if summary.totalFetched == 0 {
                return L("options.supabase.pricePreview.empty")
            }
            return L("options.supabase.pricePreview.success")
        }
    }

    private func productPricePreviewStatusSymbol(_ summary: ProductPricePreviewSummary) -> String {
        switch summary.stoppedReason {
        case .cancelled:
            return "xmark.circle.fill"
        case .error, .maxRows, .maxPages:
            return "exclamationmark.triangle.fill"
        case .pageEmpty, .partialPage:
            return summary.totalFetched == 0 ? "tray" : "checkmark.circle.fill"
        }
    }

    private func productPricePreviewStatusColor(_ summary: ProductPricePreviewSummary) -> Color {
        switch summary.stoppedReason {
        case .cancelled:
            return .secondary
        case .error, .maxRows, .maxPages:
            return .orange
        case .pageEmpty, .partialPage:
            return summary.totalFetched == 0 ? .secondary : .green
        }
    }

    private func productPricePreviewEffectiveAtText(_ sample: ProductPricePreviewSampleRow) -> String {
        if sample.effectiveAtRaw == sample.effectiveAtCanonical {
            return L("options.supabase.pricePreview.effectiveAt", sample.effectiveAtRaw)
        }

        return L(
            "options.supabase.pricePreview.effectiveAtWithCanonical",
            sample.effectiveAtRaw,
            sample.effectiveAtCanonical
        )
    }

    private func productPriceApplyStatusMessage(for plan: ProductPriceApplyPlan) -> String {
        if plan.isApplyAllowed {
            return L("options.supabase.priceApply.status.ready")
        }
        if plan.blockReasons == [.noApplicableRows] {
            return L("options.supabase.priceApply.status.noApplicableRows")
        }
        return L("options.supabase.priceApply.status.blocked")
    }

    private func productPriceApplyStatusSymbol(for plan: ProductPriceApplyPlan) -> String {
        if plan.isApplyAllowed {
            return "checkmark.shield.fill"
        }
        if plan.blockReasons == [.noApplicableRows] {
            return "tray"
        }
        return "xmark.shield.fill"
    }

    private func productPriceApplyStatusColor(for plan: ProductPriceApplyPlan) -> Color {
        if plan.isApplyAllowed {
            return .green
        }
        if plan.blockReasons == [.noApplicableRows] {
            return .secondary
        }
        return .orange
    }

    private func localizedProductPriceApplyBlockReason(_ reason: ProductPriceApplyBlockReason) -> String {
        L("options.supabase.priceApply.block.\(reason.rawValue)")
    }

    private func localizedProductPriceApplyIssueReason(_ reason: ProductPriceApplyIssueReason) -> String {
        L("options.supabase.priceApply.issue.\(reason.rawValue)")
    }

    private func localizedProductPriceApplyError(_ error: ProductPriceApplyError) -> String {
        switch error {
        case .fetcherMissing:
            return L("options.supabase.priceApply.error.fetcherMissing")
        case .sessionMismatch:
            return L("options.supabase.priceApply.error.sessionMismatch")
        case .policyBlocked(let reasons):
            let detail = reasons
                .map(localizedProductPriceApplyBlockReason)
                .joined(separator: ", ")
            return L("options.supabase.priceApply.error.policyBlocked", detail)
        case .localSnapshotFailed(let message):
            return detailMessage(
                baseKey: "options.supabase.priceApply.error.localSnapshot",
                detail: message
            )
        case .saveFailed(let message):
            return detailMessage(
                baseKey: "options.supabase.priceApply.error.saveFailed",
                detail: message
            )
        case .verificationFailed:
            return L("options.supabase.priceApply.error.verificationFailed")
        }
    }

    private func detailMessage(baseKey: String, detail: String?) -> String {
        let baseMessage = L(baseKey)
        guard let detail, !detail.isEmpty else {
            return baseMessage
        }
        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }

    private func productPriceApplyConfirmationMessage(for plan: ProductPriceApplyPlan) -> String {
        [
            L("options.supabase.priceApply.confirm.message"),
            L(
                "options.supabase.priceApply.result.counts",
                plan.summary.included,
                plan.summary.skippedExisting,
                plan.summary.remoteRead
            )
        ].joined(separator: "\n")
    }

    private var productPriceManualPushDisabledHint: String {
        switch productPriceManualPushViewModel.state.kind {
        case .previewSafe, .pushReady:
            return L("options.supabase.priceManualPush.accessibility.pushHint")
        case .snapshotStale:
            return L("options.supabase.priceManualPush.disabled.snapshotStale")
        case .overBatchLimit:
            return L("options.supabase.priceManualPush.disabled.overBatchLimit")
        case .dryRunRunning, .pushRunning, .readBackRunning:
            return L("options.supabase.priceManualPush.disabled.running")
        case .verifiedSuccess:
            return L("options.supabase.priceManualPush.disabled.verifiedSuccess")
        case .idle,
             .previewUnsafe,
             .verificationUnknown,
             .failedConflict,
             .failedValidation,
             .failedNetwork,
             .cancelled:
            return L("options.supabase.priceManualPush.disabled.needsPreview")
        }
    }

    private func productPriceManualPushPreviewUnsafeMessage(
        plan: ProductPricePushDryRunPlan?,
        reason: ProductPriceManualPushDisabledReason
    ) -> String {
        if let plan {
            return productPricePushDryRunStatusMessage(for: plan)
        }
        return L("options.supabase.priceManualPush.disabled.\(reason.rawValue)")
    }

    private func productPriceManualPushConfirmationMessage() -> String {
        let count = productPriceManualPushSnapshot?.candidateCount ?? 0
        return L("options.supabase.priceManualPush.confirm.message", count)
    }

    private func productPricePushDryRunStatusMessage(for plan: ProductPricePushDryRunPlan) -> String {
        if !plan.isRemoteDedupeSafe {
            return L("options.supabase.pricePushPreview.status.unsafe")
        }
        if plan.summary.localPriceCount == 0 {
            return L("options.supabase.pricePushPreview.status.empty")
        }
        if plan.summary.readyCandidates > 0 {
            return L("options.supabase.pricePushPreview.status.ready")
        }
        if plan.summary.blockedTotal > 0 || plan.summary.excludedInvalidLocal > 0 || plan.summary.conflictSameKeyDifferentPrice > 0 {
            return L("options.supabase.pricePushPreview.status.blocked")
        }
        return L("options.supabase.pricePushPreview.status.noWork")
    }

    private func productPricePushDryRunStatusSymbol(for plan: ProductPricePushDryRunPlan) -> String {
        if !plan.isRemoteDedupeSafe {
            return "exclamationmark.triangle.fill"
        }
        if plan.summary.readyCandidates > 0 {
            return "checkmark.shield.fill"
        }
        if plan.summary.blockedTotal > 0 || plan.summary.excludedInvalidLocal > 0 || plan.summary.conflictSameKeyDifferentPrice > 0 {
            return "xmark.shield.fill"
        }
        return "tray"
    }

    private func productPricePushDryRunStatusColor(for plan: ProductPricePushDryRunPlan) -> Color {
        if !plan.isRemoteDedupeSafe {
            return .orange
        }
        if plan.summary.readyCandidates > 0 {
            return .green
        }
        if plan.summary.blockedTotal > 0 || plan.summary.excludedInvalidLocal > 0 || plan.summary.conflictSameKeyDifferentPrice > 0 {
            return .orange
        }
        return .secondary
    }

    private func productPricePushRemoteDedupeMessage(_ status: ProductPricePushRemoteDedupeStatus) -> String {
        switch status {
        case .notNeeded:
            return L("options.supabase.pricePushPreview.dedupe.notNeeded")
        case .complete:
            return L("options.supabase.pricePushPreview.dedupe.complete")
        case .unsafePartialRemoteDedupe(let reason):
            return L(
                "options.supabase.pricePushPreview.dedupe.unsafe",
                L("options.supabase.pricePushPreview.dedupe.reason.\(reason.rawValue)")
            )
        }
    }

    private func localizedSupabaseAuthError(_ error: SupabaseAuthServiceError) -> String {
        let baseMessage: String

        switch error {
        case .configMissing:
            baseMessage = L("options.supabase.diagnostic.configMissing")
        case .invalidConfig:
            baseMessage = L("options.supabase.diagnostic.invalidConfig")
        case .oauthCancelled:
            baseMessage = L("options.supabase.auth.error.oauthCancelled")
        case .callbackFailed:
            baseMessage = L("options.supabase.auth.error.callbackFailed")
        case .sessionMissing:
            baseMessage = L("options.supabase.diagnostic.sessionMissing")
        case .unknown:
            baseMessage = L("options.supabase.auth.error.unknown")
        }

        guard let detail = error.safeDiagnosticDetail else {
            return baseMessage
        }

        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }
#endif
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

#if DEBUG
private struct SyncEventOutboxDrainDebugCard: View {
    @StateObject private var viewModel: SyncEventOutboxDrainDebugViewModel

    let isAuthenticated: Bool
    let ownerUserID: String?

    init(
        context: ModelContext,
        recorder: (any SyncEventRecording)?,
        isAuthenticated: Bool,
        ownerUserID: String?
    ) {
        _viewModel = StateObject(
            wrappedValue: SyncEventOutboxDrainDebugViewModel(context: context, recorder: recorder)
        )
        self.isAuthenticated = isAuthenticated
        self.ownerUserID = ownerUserID
    }

    private var accessIssue: SyncEventOutboxDrainDebugViewModel.AccessIssue? {
        viewModel.accessIssue(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
    }

    private var canRefresh: Bool {
        accessIssue == nil && !viewModel.isBusy
    }

    private var canRequestDrain: Bool {
        accessIssue == nil && viewModel.canDrain
    }

    private var confirmationLimit: Int {
        let retryable = viewModel.retryableCount
        guard retryable > 0 else { return viewModel.selectedLimit }
        return min(viewModel.selectedLimit, retryable)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            Text(L("options.supabase.syncEventsOutbox.subtitle"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let accessIssue {
                accessIssueRow(accessIssue)
            }

            countsDisclosure

            Picker(
                L("options.supabase.syncEventsOutbox.limit"),
                selection: Binding(
                    get: { viewModel.selectedLimit },
                    set: { viewModel.selectLimit($0) }
                )
            ) {
                ForEach(SyncEventOutboxDrainDebugViewModel.allowedLimits, id: \.self) { limit in
                    Text("\(limit)").tag(limit)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isBusy)

            HStack {
                Button {
                    Task {
                        await viewModel.refreshCounts(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
                    }
                } label: {
                    Label(L("options.supabase.syncEventsOutbox.refresh"), systemImage: "arrow.clockwise.circle")
                }
                .disabled(!canRefresh)
                .accessibilityLabel(L("options.supabase.syncEventsOutbox.accessibility.refresh"))

                Spacer(minLength: 8)
            }

            Button {
                viewModel.requestDrainConfirmation(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
            } label: {
                Label(L("options.supabase.syncEventsOutbox.drain"), systemImage: "paperplane.circle.fill")
            }
            .disabled(!canRequestDrain)
            .accessibilityLabel(L("options.supabase.syncEventsOutbox.accessibility.drain"))

            statusRows
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .onAppear {
            viewModel.updateSession(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
            Task {
                await viewModel.refreshCountsIfNeeded(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
            }
        }
        .onChange(of: isAuthenticated) { _, _ in
            handleSessionChange()
        }
        .onChange(of: ownerUserID) { _, _ in
            handleSessionChange()
        }
        .onDisappear {
            viewModel.cancelInFlight()
        }
        .confirmationDialog(
            L("options.supabase.syncEventsOutbox.confirm.title"),
            isPresented: Binding(
                get: { viewModel.isShowingDrainConfirmation },
                set: { isPresented in
                    if !isPresented {
                        viewModel.dismissDrainConfirmation()
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(L("options.supabase.syncEventsOutbox.drain")) {
                Task {
                    await viewModel.confirmDrain(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
                }
            }
            Button(L("common.cancel"), role: .cancel) {
                viewModel.dismissDrainConfirmation()
            }
        } message: {
            Text(L("options.supabase.syncEventsOutbox.confirm.message", confirmationLimit))
        }
    }

    private var header: some View {
        Label {
            Text(L("options.supabase.syncEventsOutbox.title"))
                .font(.subheadline)
                .fontWeight(.semibold)
        } icon: {
            Image(systemName: "tray.full")
                .foregroundStyle(Color.accentColor)
        }
    }

    private var countsDisclosure: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                if let counts = viewModel.counts {
                    ForEach(localizedCountRows(counts), id: \.self) { row in
                        Text(row)
                    }
                    if let lastCountsRefreshAt = viewModel.lastCountsRefreshAt {
                        Text(L(
                            "options.supabase.syncEventsOutbox.counts.lastUpdated",
                            lastCountsRefreshAt.formatted(date: .omitted, time: .shortened)
                        ))
                        .foregroundStyle(.secondary)
                    }
                } else {
                    Text(L("options.supabase.syncEventsOutbox.counts.notLoaded"))
                        .foregroundStyle(.secondary)
                }

                if viewModel.didFailRefreshingCounts {
                    Label {
                        Text(L("options.supabase.syncEventsOutbox.counts.refreshFailed"))
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Color.orange)
                    }
                }
            }
            .font(.footnote)
            .padding(.top, 4)
        } label: {
            Label(
                viewModel.counts == nil
                    ? L("options.supabase.syncEventsOutbox.counts.notLoaded")
                    : L("options.supabase.syncEventsOutbox.accessibility.counts"),
                systemImage: "number.circle"
            )
        }
        .accessibilityLabel(L("options.supabase.syncEventsOutbox.accessibility.counts"))
    }

    @ViewBuilder
    private var statusRows: some View {
        switch viewModel.state {
        case .loadingCounts:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.syncEventsOutbox.loadingCounts"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .draining:
            HStack(spacing: 12) {
                ProgressView()
                Text(L("options.supabase.syncEventsOutbox.draining"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .idle, .result, .error:
            EmptyView()
        }

        if let counts = viewModel.counts, counts.retryable == 0 {
            Label {
                Text(L("options.supabase.syncEventsOutbox.empty"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            }
        }

        if let message = viewModel.lastDrainMessage {
            Label {
                Text(localizedDrainMessage(message))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: drainMessageIcon(message))
                    .foregroundStyle(drainMessageColor(message))
            }
        }
    }

    private func accessIssueRow(_ issue: SyncEventOutboxDrainDebugViewModel.AccessIssue) -> some View {
        Label {
            Text(accessIssueMessage(issue))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } icon: {
            Image(systemName: "lock.fill")
                .foregroundStyle(Color.orange)
        }
    }

    private func handleSessionChange() {
        viewModel.updateSession(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
        Task {
            await viewModel.refreshCountsIfNeeded(isAuthenticated: isAuthenticated, ownerUserID: ownerUserID)
        }
    }

    private func localizedCountRows(_ counts: SyncEventOutboxCounts) -> [String] {
        [
            L("options.supabase.syncEventsOutbox.count.pending", counts.pending),
            L("options.supabase.syncEventsOutbox.count.retryable", counts.retryable),
            L("options.supabase.syncEventsOutbox.count.blocked", counts.blocked),
            L("options.supabase.syncEventsOutbox.count.dead", counts.dead),
            L("options.supabase.syncEventsOutbox.count.sent", counts.sent),
            L("options.supabase.syncEventsOutbox.count.localOnly", counts.localOnly)
        ]
    }

    private func accessIssueMessage(_ issue: SyncEventOutboxDrainDebugViewModel.AccessIssue) -> String {
        switch issue {
        case .missingSession:
            return L("options.supabase.syncEventsOutbox.auth.missing")
        case .invalidOwner:
            return L("options.supabase.syncEventsOutbox.owner.invalid")
        }
    }

    private func localizedDrainMessage(_ message: SyncEventOutboxDrainDebugViewModel.DrainMessage) -> String {
        switch message {
        case .noWork:
            return L("options.supabase.syncEventsOutbox.result.noWork")
        case .drained(let sent):
            return L("options.supabase.syncEventsOutbox.result.drained", sent)
        case .partial(let sent, let retryScheduled, let blocked, let dead):
            return L("options.supabase.syncEventsOutbox.result.partial", sent, retryScheduled, blocked, dead)
        case .blocked:
            return L("options.supabase.syncEventsOutbox.result.blocked")
        case .alreadyRunning:
            return L("options.supabase.syncEventsOutbox.result.alreadyRunning")
        case .network:
            return L("options.supabase.syncEventsOutbox.result.network")
        case .cancelled:
            return L("options.supabase.syncEventsOutbox.result.cancelled")
        case .invalidOwner:
            return L("options.supabase.syncEventsOutbox.result.invalidOwner")
        case .localSaveFailed:
            return L("options.supabase.syncEventsOutbox.result.localSaveFailed")
        }
    }

    private func drainMessageIcon(_ message: SyncEventOutboxDrainDebugViewModel.DrainMessage) -> String {
        switch message {
        case .drained, .noWork:
            return "checkmark.circle.fill"
        case .partial, .alreadyRunning, .cancelled:
            return "exclamationmark.circle.fill"
        case .blocked, .network, .invalidOwner, .localSaveFailed:
            return "exclamationmark.triangle.fill"
        }
    }

    private func drainMessageColor(_ message: SyncEventOutboxDrainDebugViewModel.DrainMessage) -> Color {
        switch message {
        case .drained, .noWork:
            return .green
        case .partial, .alreadyRunning, .cancelled, .blocked, .network, .invalidOwner, .localSaveFailed:
            return .orange
        }
    }
}

private struct SupabasePullPreviewSheet: View {
    private let rowLimit = 100

    @Environment(\.modelContext) private var modelContext
    @AppStorage("supabaseLastLinkedUserID") private var supabaseLastLinkedUserID: String = ""
    @State private var isApplyingLocalPreview = false
    @State private var isShowingApplyConfirmation = false
    @State private var pendingApplyPlan: SupabasePullApplyPlan?
    @State private var pendingApplyPreview: SyncPreview?
    @State private var applyStatusMessage: String?
    @State private var applyErrorMessage: String?

    let state: SupabasePullPreviewViewState
    let isAuthenticated: Bool
    let currentUserID: UUID?
    let baselineDidChange: () -> Void
    let close: () -> Void

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(L("options.supabase.preview.title"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L("options.supabase.preview.close"), action: close)
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            Form {
                Section {
                    Text(L("options.supabase.preview.idle"))
                        .foregroundStyle(.secondary)
                } header: {
                    SectionHeader(title: L("options.supabase.preview.summary.header"), systemImage: "doc.text.magnifyingglass")
                }
            }
        case .loading(let progressMessage):
            Form {
                Section {
                    HStack(spacing: 12) {
                        ProgressView()
                        Text(progressMessage ?? L("options.supabase.preview.loading"))
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    SectionHeader(title: L("options.supabase.preview.summary.header"), systemImage: "doc.text.magnifyingglass")
                }
            }
        case .failed(let error):
            Form {
                Section {
                    Label(L("options.supabase.preview.failed"), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text(L("options.supabase.preview.noChanges"))
                        .foregroundStyle(.secondary)
                    Text(localizedError(error))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    SectionHeader(title: L("options.supabase.preview.summary.header"), systemImage: "doc.text.magnifyingglass")
                }
            }
        case .success(let preview):
            previewForm(preview, isPartial: false)
        case .partial(let preview, _, _):
            previewForm(preview, isPartial: true)
        }
    }

    private func previewForm(_ preview: SyncPreview, isPartial: Bool) -> some View {
        let readiness = applyReadiness(for: preview)

        return Form {
            summarySection(preview, isPartial: isPartial)
            remoteIdentitySection(preview)
            applySection(preview: preview, readiness: readiness)
            conflictsSection(preview.conflicts)
            productSection(
                titleKey: "options.supabase.preview.group.updateCandidates",
                systemImage: "square.and.pencil",
                products: preview.updateCandidates
            )
            productSection(
                titleKey: "options.supabase.preview.group.new",
                systemImage: "plus.circle",
                products: preview.newProducts
            )
            productSection(
                titleKey: "options.supabase.preview.group.tombstones",
                systemImage: "archivebox",
                products: preview.remoteTombstones
            )
            warningsSection(preview.warnings + preview.sourceErrors)
            productSection(
                titleKey: "options.supabase.preview.group.unchanged",
                systemImage: "checkmark.circle",
                products: preview.unchangedProducts
            )
        }
        .confirmationDialog(
            L("options.supabase.apply.confirm.title"),
            isPresented: $isShowingApplyConfirmation,
            presenting: pendingApplyPlan
        ) { plan in
            Button(L("options.supabase.apply.confirm.apply")) {
                applyLocalPreview(plan, preview: pendingApplyPreview)
            }
            Button(L("options.supabase.preview.close"), role: .cancel) {}
        } message: { _ in
            Text(L("options.supabase.apply.confirm.message"))
        }
    }

    private func summarySection(_ preview: SyncPreview, isPartial: Bool) -> some View {
        Section {
            Label(
                isPartial ? L("options.supabase.preview.partial") : L("options.supabase.preview.ready"),
                systemImage: isPartial ? "exclamationmark.triangle" : "doc.text.magnifyingglass"
            )
            .foregroundStyle(isPartial ? Color.orange : Color.accentColor)

            Text(L("options.supabase.preview.dryRun"))
                .font(.subheadline)
            Text(L("options.supabase.preview.noChanges"))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if preview.sourceErrors.contains(where: { $0.code == .priceHistoryIncomplete }) {
                Text(L("options.supabase.preview.priceHistoryIncomplete"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            metricRow("options.supabase.preview.metric.remoteProducts", "\(preview.remoteCounts.products)")
            metricRow("options.supabase.preview.metric.remoteSuppliers", "\(preview.remoteCounts.suppliers)")
            metricRow("options.supabase.preview.metric.remoteCategories", "\(preview.remoteCounts.categories)")
            metricRow("options.supabase.preview.metric.newProducts", "\(preview.newProducts.count)")
            metricRow("options.supabase.preview.metric.updateCandidates", "\(preview.updateCandidates.count)")
            metricRow("options.supabase.preview.metric.conflicts", "\(preview.conflicts.count)")
            metricRow("options.supabase.preview.metric.tombstones", "\(preview.remoteTombstones.count)")
        } header: {
            SectionHeader(title: L("options.supabase.preview.cloud.header"), systemImage: "chart.bar.doc.horizontal")
        }
    }

    private func remoteIdentitySection(_ preview: SyncPreview) -> some View {
        Section {
            metricRow(
                "options.supabase.preview.metric.linkedProducts",
                "\(preview.localCounts.linkedProducts) / \(preview.localCounts.products)"
            )
            metricRow(
                "options.supabase.preview.metric.linkedSuppliers",
                "\(preview.localCounts.linkedSuppliers) / \(preview.localCounts.suppliers)"
            )
            metricRow(
                "options.supabase.preview.metric.linkedCategories",
                "\(preview.localCounts.linkedCategories) / \(preview.localCounts.categories)"
            )
        } header: {
            SectionHeader(title: L("options.supabase.preview.identity.header"), systemImage: "link")
        }
    }

    private func metricRow(_ titleKey: String, _ value: String) -> some View {
        HStack {
            Text(L(titleKey))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private func applySection(
        preview: SyncPreview,
        readiness: SupabasePullPreviewApplyReadiness
    ) -> some View {
        Section {
            Button {
                prepareLocalApplyConfirmation(for: preview)
            } label: {
                Label(L("options.supabase.apply.button"), systemImage: "tray.and.arrow.down")
            }
            .disabled(!readiness.canApply || isApplyingLocalPreview)

            if isApplyingLocalPreview {
                HStack(spacing: 12) {
                    ProgressView()
                    Text(L("options.supabase.apply.applying"))
                        .foregroundStyle(.secondary)
                }
            }

            if let applyStatusMessage {
                Label {
                    Text(applyStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                }
            }

            if let applyErrorMessage {
                Label {
                    Text(applyErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }
            }
        } header: {
            SectionHeader(title: L("options.supabase.apply.header"), systemImage: "shippingbox.and.arrow.backward")
        } footer: {
            Text(applyFooter(readiness))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func conflictsSection(_ conflicts: [SyncPreviewConflict]) -> some View {
        Section {
            if conflicts.isEmpty {
                emptyRow()
            } else {
                ForEach(Array(conflicts.prefix(5))) { conflict in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L(conflictTitleKey(conflict.kind)))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let barcodeOrKey = conflict.barcodeOrKey {
                            Text(barcodeOrKey)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let detail = conflict.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let hintKey = conflict.hintKey {
                            Text(L(hintKey))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                hiddenRowsText(totalCount: conflicts.count, visibleLimit: 5)
            }
        } header: {
            SectionHeader(title: L("options.supabase.preview.group.conflicts"), systemImage: "exclamationmark.triangle")
        }
    }

    private func productSection(
        titleKey: String,
        systemImage: String,
        products: [SyncPreviewProductSummary]
    ) -> some View {
        Section {
            if products.isEmpty {
                emptyRow()
            } else {
                ForEach(Array(products.prefix(rowLimit))) { product in
                    productRow(product)
                }
                hiddenRowsText(totalCount: products.count)
            }
        } header: {
            SectionHeader(title: L(titleKey), systemImage: systemImage)
        }
    }

    private func warningsSection(_ warnings: [SyncPreviewWarning]) -> some View {
        Section {
            if warnings.isEmpty {
                emptyRow()
            } else {
                ForEach(Array(warnings.prefix(rowLimit))) { warning in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L(warning.messageKey))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        if let barcodeOrKey = warning.barcodeOrKey {
                            Text(barcodeOrKey)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let detail = warning.detail {
                            Text(detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                hiddenRowsText(totalCount: warnings.count)
            }
        } header: {
            SectionHeader(title: L("options.supabase.preview.group.warnings"), systemImage: "exclamationmark.bubble")
        }
    }

    private func productRow(_ product: SyncPreviewProductSummary) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(product.productName ?? L("options.supabase.preview.valueMissing"))
                .font(.subheadline)
                .fontWeight(.semibold)

            if let barcode = product.barcode {
                Text(L("options.supabase.preview.productBarcode", barcode))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let detail = product.detail {
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !product.fieldChanges.isEmpty {
                DisclosureGroup(L("options.supabase.preview.fieldChanges")) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(product.fieldChanges) { change in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L(fieldTitleKey(change.fieldKey)))
                                    .font(.footnote)
                                    .fontWeight(.semibold)
                                Text(L("options.supabase.preview.change.remote", displayValue(change.remoteDisplay)))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(L("options.supabase.preview.change.local", displayValue(change.localDisplay)))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func hiddenRowsText(totalCount: Int, visibleLimit: Int? = nil) -> some View {
        let hiddenCount = max(0, totalCount - (visibleLimit ?? rowLimit))
        return Group {
            if hiddenCount > 0 {
                Text(L("options.supabase.preview.moreHidden", hiddenCount))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func emptyRow() -> some View {
        Text(L("options.supabase.preview.emptyGroup"))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func displayValue(_ value: String?) -> String {
        value ?? L("options.supabase.preview.valueMissing")
    }

    private func applyReadiness(for preview: SyncPreview) -> SupabasePullPreviewApplyReadiness {
        do {
            let plan = try SupabasePullApplyService().prepareApplyPlan(
                preview: preview,
                context: modelContext,
                options: SupabasePullApplyOptions(),
                isAuthenticated: isAuthenticated,
                accountGuard: accountGuard
            )
            return SupabasePullPreviewApplyReadiness(plan: plan, disabledReason: nil)
        } catch let error as SupabasePullApplyError {
            return SupabasePullPreviewApplyReadiness(plan: nil, disabledReason: error.disabledReason)
        } catch {
            return SupabasePullPreviewApplyReadiness(plan: nil, disabledReason: .previewStale)
        }
    }

    private func prepareLocalApplyConfirmation(for preview: SyncPreview) {
        guard !isApplyingLocalPreview else { return }

        do {
            let plan = try SupabasePullApplyService().prepareApplyPlan(
                preview: preview,
                context: modelContext,
                options: SupabasePullApplyOptions(),
                isAuthenticated: isAuthenticated,
                accountGuard: accountGuard
            )
            pendingApplyPlan = plan
            pendingApplyPreview = preview
            applyStatusMessage = nil
            applyErrorMessage = nil
            isShowingApplyConfirmation = true
        } catch let error as SupabasePullApplyError {
            applyStatusMessage = nil
            applyErrorMessage = localizedApplyError(error)
        } catch {
            applyStatusMessage = nil
            applyErrorMessage = L("options.supabase.apply.error.generic")
        }
    }

    private func applyLocalPreview(_ plan: SupabasePullApplyPlan, preview: SyncPreview?) {
        guard !isApplyingLocalPreview else { return }

        isApplyingLocalPreview = true
        applyStatusMessage = nil
        applyErrorMessage = nil

        Task { @MainActor in
            await Task.yield()

            do {
                let result = try SupabasePullApplyService().apply(plan: plan, context: modelContext)
                var statusMessage = L("options.supabase.apply.success", result.inserted, result.updated)
                if let currentUserID, let preview {
                    do {
                        let baselineResult = try SupabaseCatalogBaselineWriter()
                            .commitAfterSuccessfulFullPullApply(
                                preview: preview,
                                context: modelContext,
                                ownerUserUUID: currentUserID
                            )
                        statusMessage += "\n" + L(
                            "options.supabase.baseline.commit.success",
                            baselineResult.productCount,
                            baselineResult.supplierCount,
                            baselineResult.categoryCount
                        )
                    } catch {
                        statusMessage += "\n" + L("options.supabase.baseline.commit.failed")
                    }
                }
                applyStatusMessage = statusMessage
                applyErrorMessage = nil
                baselineDidChange()
                if let currentUserID {
                    supabaseLastLinkedUserID = currentUserID.uuidString
                }
            } catch let error as SupabasePullApplyError {
                applyStatusMessage = nil
                applyErrorMessage = localizedApplyError(error)
            } catch {
                applyStatusMessage = nil
                applyErrorMessage = L("options.supabase.apply.error.generic")
            }

            pendingApplyPlan = nil
            pendingApplyPreview = nil
            isApplyingLocalPreview = false
        }
    }

    private func applyFooter(_ readiness: SupabasePullPreviewApplyReadiness) -> String {
        if let reason = readiness.disabledReason {
            return L("options.supabase.apply.disabled.\(reason.rawValue)")
        }

        guard let plan = readiness.plan else {
            return L("options.supabase.apply.disabled.noApplicableChanges")
        }

        return L(
            "options.supabase.apply.footer.ready",
            plan.plannedInsertedCount,
            plan.plannedUpdatedCount
        )
    }

    private func localizedApplyError(_ error: SupabasePullApplyError) -> String {
        let baseMessage: String

        switch error {
        case .saveFailed:
            baseMessage = L("options.supabase.apply.error.saveFailed")
        default:
            baseMessage = L("options.supabase.apply.disabled.\(error.disabledReason.rawValue)")
        }

        switch error {
        case .saveFailed(let message), .localSnapshotFailed(let message):
            guard let message, !message.isEmpty else {
                return baseMessage
            }
            return L("options.supabase.apply.error.withDetail", baseMessage, message)
        default:
            return baseMessage
        }
    }

    private var accountGuard: SupabasePullApplyAccountGuard {
        SupabasePullApplyAccountGuard(
            currentUserID: currentUserID,
            lastLinkedUserID: UUID(uuidString: supabaseLastLinkedUserID)
        )
    }

    private func localizedError(_ error: SupabasePullPreviewError) -> String {
        let baseMessage: String

        switch error {
        case .service(let serviceError):
            baseMessage = localizedServiceError(serviceError)
        case .localSnapshot:
            baseMessage = L("options.supabase.preview.error.localSnapshot")
        case .unknown:
            baseMessage = L("options.supabase.diagnostic.unknown")
        }

        guard let detail = error.safeDiagnosticDetail else {
            return baseMessage
        }

        return L("options.supabase.diagnostic.messageWithDetail", baseMessage, detail)
    }

    private func localizedServiceError(_ error: SupabaseInventoryServiceError) -> String {
        switch error {
        case .configMissing:
            return L("options.supabase.diagnostic.configMissing")
        case .invalidConfig:
            return L("options.supabase.diagnostic.invalidConfig")
        case .sessionMissing:
            return L("options.supabase.diagnostic.sessionMissing")
        case .networkError:
            return L("options.supabase.diagnostic.networkError")
        case .permissionDeniedOrRLS:
            return L("options.supabase.diagnostic.permissionDeniedOrRLS")
        case .decodingError:
            return L("options.supabase.diagnostic.decodingError")
        case .schemaDrift:
            return L("options.supabase.diagnostic.schemaDrift")
        case .unknown:
            return L("options.supabase.diagnostic.unknown")
        }
    }

    private func conflictTitleKey(_ kind: SyncPreviewConflictKind) -> String {
        "options.supabase.preview.conflict.\(kind.rawValue)"
    }

    private func fieldTitleKey(_ field: SyncPreviewFieldKey) -> String {
        "options.supabase.preview.field.\(field.rawValue)"
    }
}

private struct SupabasePullPreviewApplyReadiness {
    let plan: SupabasePullApplyPlan?
    let disabledReason: SupabasePullApplyDisabledReason?

    var canApply: Bool {
        plan != nil && disabledReason == nil
    }
}

private enum ProductPriceApplyViewState {
    case idle
    case loading
    case ready(ProductPriceApplyPlan)
    case applying(ProductPriceApplyPlan)
    case applied(ProductPriceApplyResult)
    case failed(String)
}

#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        OptionsView()
    }
}
