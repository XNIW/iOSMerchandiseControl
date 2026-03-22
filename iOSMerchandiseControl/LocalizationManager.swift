import Foundation
import SwiftUI

func currentAppLanguageSelection() -> String {
    UserDefaults.standard.string(forKey: "appLanguage") ?? "system"
}

func appLocale() -> Locale {
    Locale(identifier: Bundle.resolvedLanguageCode(for: currentAppLanguageSelection()))
}

func L(_ key: String, _ args: CVarArg...) -> String {
    let bundle = Bundle.forLanguage(currentAppLanguageSelection())
    var format = bundle.localizedString(forKey: key, value: key, table: nil)

    if format == key {
        let itBundle = Bundle.forLanguage("it")
        format = itBundle.localizedString(forKey: key, value: key, table: nil)
    }

    if args.isEmpty {
        return format
    }

    return String(format: format, locale: appLocale(), arguments: args)
}

extension Bundle {
    static func resolvedLanguageCode(for code: String) -> String {
        let supported = ["it", "en", "zh-Hans", "es"]

        if code == "system" {
            for language in Locale.preferredLanguages {
                let canonical: String
                if language.hasPrefix("zh") {
                    canonical = "zh-Hans"
                } else {
                    canonical = String(language.prefix(2))
                }

                if supported.contains(canonical) {
                    return canonical
                }
            }

            return "it"
        }

        let appleCode = code == "zh" ? "zh-Hans" : code
        return supported.contains(appleCode) ? appleCode : "it"
    }

    static func forLanguage(_ code: String) -> Bundle {
        let resolved = Bundle.resolvedLanguageCode(for: code)

        if let path = Bundle.main.path(forResource: resolved, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        if let path = Bundle.main.path(forResource: "it", ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }

        return .main
    }
}

extension View {
    func localeOverride(for languageCode: String) -> some View {
        let resolved = Bundle.resolvedLanguageCode(for: languageCode)
        return self.environment(\.locale, Locale(identifier: resolved))
    }
}
