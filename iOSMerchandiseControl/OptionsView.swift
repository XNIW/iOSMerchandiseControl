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

    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
#if DEBUG
    @EnvironmentObject private var supabaseAuthViewModel: SupabaseAuthViewModel
    @AppStorage("supabaseLastLinkedUserID") private var supabaseLastLinkedUserID: String = ""
    @State private var isRunningSupabaseDiagnostic = false
    @State private var supabaseDiagnosticMessage: String?
    @State private var supabaseDiagnosticIsError = false
    @State private var isShowingSupabasePullPreview = false
    @State private var supabasePullPreviewState: SupabasePullPreviewViewState = .idle
    @StateObject private var pushPreflightViewModel = SupabasePushPreflightViewModel()
#endif

    init(
        supabaseInventoryService: SupabaseInventoryService? = nil,
        supabasePullPreviewService: SupabasePullPreviewService? = nil
    ) {
        self.supabaseInventoryService = supabaseInventoryService
        self.supabasePullPreviewService = supabasePullPreviewService
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
            } header: {
                SectionHeader(title: L("options.supabase.auth.header"), systemImage: "person.crop.circle.badge.checkmark")
            } footer: {
                Text(L("options.supabase.auth.footer"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                preflightStateRow

                Button {
                    runSupabasePushPreflight()
                } label: {
                    Label(L("options.supabase.pushpreflight.run"), systemImage: "checklist")
                }
                .disabled(pushPreflightViewModel.isRunning || !isPushPreflightAccountReady)

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
                    Text(L("options.supabase.pushpreflight.copy.noRemoteWrite"))
                    Text(L("options.supabase.pushpreflight.copy.noLocalRemoteMutation"))
                    Text(L("options.supabase.pushpreflight.copy.futureTask"))
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
            pushPreflightViewModel.cancel()
        }
        .sheet(isPresented: $isShowingSupabasePullPreview) {
            SupabasePullPreviewSheet(
                state: supabasePullPreviewState,
                isAuthenticated: supabaseAuthViewModel.isSignedIn,
                currentUserID: supabaseAuthViewModel.sessionInfo?.userID
            ) {
                isShowingSupabasePullPreview = false
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

    private var isPushPreflightAccountReady: Bool {
        supabaseAuthViewModel.isSignedIn
            && supabaseAuthViewModel.sessionInfo?.isExpired == false
            && UUID(uuidString: supabaseLastLinkedUserID) != nil
            && supabaseAuthViewModel.sessionInfo?.userID == UUID(uuidString: supabaseLastLinkedUserID)
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

    private func runSupabasePushPreflight() {
        pushPreflightViewModel.runLocalCheck(
            context: modelContext,
            isSignedIn: supabaseAuthViewModel.isSignedIn && !supabaseAuthViewModel.isTransitioning,
            currentUserID: supabaseAuthViewModel.sessionInfo?.userID,
            lastLinkedUserID: UUID(uuidString: supabaseLastLinkedUserID)
        )
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
        case .completedNoWork:
            return "options.supabase.pushpreflight.state.completedNoWork"
        case .completedBlocked:
            return "options.supabase.pushpreflight.state.completedBlocked"
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
        case .completedSafe, .completedNoWork:
            return "checkmark.circle.fill"
        case .completedBlocked:
            return "exclamationmark.triangle.fill"
        case .failedLocalError:
            return "xmark.octagon.fill"
        }
    }

    private func preflightStateColor(_ state: SupabasePushPreflightViewModel.ViewState) -> Color {
        switch state {
        case .completedSafe, .completedNoWork:
            return .green
        case .completedBlocked, .accountNotLinked:
            return .orange
        case .failedLocalError:
            return .red
        case .idle, .running:
            return .secondary
        }
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
private struct SupabasePullPreviewSheet: View {
    private let rowLimit = 100

    @Environment(\.modelContext) private var modelContext
    @AppStorage("supabaseLastLinkedUserID") private var supabaseLastLinkedUserID: String = ""
    @State private var isApplyingLocalPreview = false
    @State private var isShowingApplyConfirmation = false
    @State private var pendingApplyPlan: SupabasePullApplyPlan?
    @State private var applyStatusMessage: String?
    @State private var applyErrorMessage: String?

    let state: SupabasePullPreviewViewState
    let isAuthenticated: Bool
    let currentUserID: UUID?
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
                applyLocalPreview(plan)
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

    private func applyLocalPreview(_ plan: SupabasePullApplyPlan) {
        guard !isApplyingLocalPreview else { return }

        isApplyingLocalPreview = true
        applyStatusMessage = nil
        applyErrorMessage = nil

        Task { @MainActor in
            await Task.yield()

            do {
                let result = try SupabasePullApplyService().apply(plan: plan, context: modelContext)
                applyStatusMessage = L("options.supabase.apply.success", result.inserted, result.updated)
                applyErrorMessage = nil
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
#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        OptionsView()
    }
}
