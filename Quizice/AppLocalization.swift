import Foundation

enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case russian = "ru"
    case english = "en"
    case spanish = "es"
    case german = "de"
    case italian = "it"
    case french = "fr"

    static let fallbackLanguageCode = AppLanguagePreference.english.rawValue

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.Settings.Language.system
        case .russian:
            return "Русский"
        case .english:
            return "English"
        case .spanish:
            return "Español"
        case .german:
            return "Deutsch"
        case .italian:
            return "Italiano"
        case .french:
            return "Français"
        }
    }

    var languageCode: String? {
        switch self {
        case .system:
            return nil
        case .russian, .english, .spanish, .german, .italian, .french:
            return rawValue
        }
    }

    static func explicitPreference(for languageCode: String) -> AppLanguagePreference? {
        allCases.first { $0.languageCode == languageCode }
    }
}

extension Notification.Name {
    static let appLocalizationDidChange = Notification.Name("quizice.appLocalizationDidChange")
}

final class AppLocalizationStore {
    enum Keys {
        static let language = "quizice.settings.language"
    }

    static let shared = AppLocalizationStore()

    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter
    private let preferredLanguagesProvider: () -> [String]

    init(
        userDefaults: UserDefaults = .standard,
        notificationCenter: NotificationCenter = .default,
        preferredLanguagesProvider: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
        self.preferredLanguagesProvider = preferredLanguagesProvider
    }

    var languagePreference: AppLanguagePreference {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.language),
                let preference = AppLanguagePreference(rawValue: rawValue)
            else { return .system }
            return preference
        }
        set {
            guard languagePreference != newValue else { return }
            userDefaults.set(newValue.rawValue, forKey: Keys.language)
            notifyChange()
        }
    }

    var resolvedLanguageCode: String {
        if let languageCode = languagePreference.languageCode {
            return languageCode
        }
        return Self.resolveSystemLanguageCode(preferredLanguages: preferredLanguagesProvider())
    }

    var resolvedLocale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    var localizedBundle: Bundle {
        guard
            let path = Bundle.main.path(forResource: resolvedLanguageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return .main }
        return bundle
    }

    func notifyChange() {
        notificationCenter.post(name: .appLocalizationDidChange, object: self)
    }

    static func resolveSystemLanguageCode(preferredLanguages: [String]) -> String {
        for identifier in preferredLanguages {
            let languageCode = Locale(identifier: identifier).language.languageCode?.identifier ?? identifier
            if AppLanguagePreference.explicitPreference(for: languageCode) != nil {
                return languageCode
            }
        }
        return AppLanguagePreference.fallbackLanguageCode
    }
}
