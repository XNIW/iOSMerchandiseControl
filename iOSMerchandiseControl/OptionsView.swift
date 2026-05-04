import SwiftUI

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
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"
#if DEBUG
    @State private var isRunningSupabaseDiagnostic = false
    @State private var supabaseDiagnosticMessage: String?
    @State private var supabaseDiagnosticIsError = false
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
    }

#if DEBUG
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

// MARK: - Preview

#Preview {
    NavigationStack {
        OptionsView()
    }
}
