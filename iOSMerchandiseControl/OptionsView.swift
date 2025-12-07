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
    private let themeOptions: [ThemeOption] = [
        ThemeOption(
            id: "system",
            title: "Automatico",
            subtitle: "Usa lo stesso tema (chiaro/scuro) impostato in iOS."
        ),
        ThemeOption(
            id: "light",
            title: "Chiaro",
            subtitle: "Sfondo chiaro, ideale in ambienti molto illuminati."
        ),
        ThemeOption(
            id: "dark",
            title: "Scuro",
            subtitle: "Sfondo scuro, più riposante al chiuso o di sera."
        )
    ]

    // Opzioni lingua (simili al menu della versione Android)
    private let languageOptions: [LanguageOption] = [
        LanguageOption(
            id: "system",
            title: "Sistema",
            subtitle: "Usa la lingua predefinita del dispositivo."
        ),
        LanguageOption(
            id: "zh",
            title: "中文",
            subtitle: "Cinese (semplificato)."
        ),
        LanguageOption(
            id: "it",
            title: "Italiano",
            subtitle: "Lingua principale consigliata per questa installazione."
        ),
        LanguageOption(
            id: "es",
            title: "Español",
            subtitle: "Per negozi e personale di lingua spagnola."
        ),
        LanguageOption(
            id: "en",
            title: "English",
            subtitle: "Interfaccia internazionale di base."
        )
    ]

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
                SectionHeader(title: "Tema", systemImage: "paintbrush.fill")
            } footer: {
                Text("Se scegli \"Automatico\" l’app seguirà il tema impostato in iOS (chiaro o scuro).")
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
                SectionHeader(title: "Lingua", systemImage: "globe")
            } footer: {
                Text("Le modifiche alla lingua potrebbero richiedere il riavvio dell’app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            // Piccola sezione di “aiuto” in fondo
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Suggerimento")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Puoi cambiare tema e lingua in qualsiasi momento dalla tab \"Opzioni\".")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Opzioni")
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
                            Text("Attuale")
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
