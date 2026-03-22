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
