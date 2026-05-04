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
    @Environment(\.modelContext) private var modelContext
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
#if DEBUG
    @State private var isRunningSupabaseDiagnostic = false
    @State private var supabaseDiagnosticMessage: String?
    @State private var supabaseDiagnosticIsError = false
    @State private var isShowingSupabasePullPreview = false
    @State private var supabasePullPreviewState: SupabasePullPreviewViewState = .idle
#endif

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
                Button {
                    runSupabaseDiagnostic()
                } label: {
                    Label(L("options.supabase.diagnostic.button"), systemImage: "network")
                }
                .disabled(isRunningSupabaseDiagnostic)

                Button {
                    runSupabasePullPreview()
                } label: {
                    Label(L("options.supabase.preview.button"), systemImage: "doc.text.magnifyingglass")
                }
                .disabled(isSupabasePullPreviewLoading)

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
                SectionHeader(title: L("options.supabase.diagnostic.header"), systemImage: "server.rack")
            } footer: {
                Text(L("options.supabase.diagnostic.footer"))
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
        .sheet(isPresented: $isShowingSupabasePullPreview) {
            SupabasePullPreviewSheet(state: supabasePullPreviewState) {
                isShowingSupabasePullPreview = false
            }
        }
#endif
    }

#if DEBUG
    private var isSupabasePullPreviewLoading: Bool {
        if case .loading = supabasePullPreviewState {
            return true
        }
        return false
    }

    private func runSupabaseDiagnostic() {
        guard !isRunningSupabaseDiagnostic else { return }

        isRunningSupabaseDiagnostic = true
        supabaseDiagnosticMessage = nil
        supabaseDiagnosticIsError = false

        Task {
            let service = SupabaseInventoryService()

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

        supabasePullPreviewState = .loading(progressMessage: L("options.supabase.preview.loading"))
        isShowingSupabasePullPreview = true

        Task {
            let service = SupabasePullPreviewService()
            supabasePullPreviewState = await service.generatePreview(context: modelContext)
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

    let state: SupabasePullPreviewViewState
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
        Form {
            summarySection(preview, isPartial: isPartial)
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

            ForEach(preview.metrics) { metric in
                HStack {
                    Text(L(metric.labelKey))
                    Spacer()
                    Text(metric.value)
                        .fontWeight(.semibold)
                }
            }
        } header: {
            SectionHeader(title: L("options.supabase.preview.summary.header"), systemImage: "chart.bar.doc.horizontal")
        }
    }

    private func conflictsSection(_ conflicts: [SyncPreviewConflict]) -> some View {
        Section {
            if conflicts.isEmpty {
                emptyRow()
            } else {
                ForEach(Array(conflicts.prefix(rowLimit))) { conflict in
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
                hiddenRowsText(totalCount: conflicts.count)
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

    private func hiddenRowsText(totalCount: Int) -> some View {
        let hiddenCount = max(0, totalCount - rowLimit)
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
#endif

// MARK: - Preview

#Preview {
    NavigationStack {
        OptionsView()
    }
}
