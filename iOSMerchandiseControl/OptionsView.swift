import SwiftUI

struct OptionsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    @AppStorage("appLanguage") private var appLanguage: String = "system"

    var body: some View {
        Form {
            Section("Tema") {
                Picker("Tema", selection: $appTheme) {
                    Text("Automatico").tag("system")
                    Text("Chiaro").tag("light")
                    Text("Scuro").tag("dark")
                }
                .pickerStyle(.segmented)
            }

            Section("Lingua") {
                Picker("Lingua", selection: $appLanguage) {
                    Text("Sistema").tag("system")
                    Text("中文").tag("zh")
                    Text("Italiano").tag("it")
                    Text("Español").tag("es")
                    Text("English").tag("en")
                }
            }

            Section {
                Text("Le modifiche alla lingua potrebbero richiedere il riavvio dell’app.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Opzioni")
    }
}

#Preview {
    OptionsView()
}
