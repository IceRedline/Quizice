import Foundation

protocol OnboardingProgressStoring: AnyObject {
    var needsOnboarding: Bool { get }
    var preferredThemeIDs: Set<String> { get }

    func complete(preferredThemeIDs: Set<String>)
    func storedPreferredThemeIDs(locale: String) -> [String]?
    func orderedPreferredThemeIDs(locale: String) -> [String]
    func complete(preferredThemeIDs: [String], locale: String)
    func applyRemotePreferredThemeIDs(_ preferredThemeIDs: [String], locale: String)
    func hasPendingThemePreferences(locale: String) -> Bool
}

final class OnboardingProgressStore: OnboardingProgressStoring {
    static let shared = OnboardingProgressStore()

    enum Keys {
        static let completedVersion = "quizice.onboarding.completedVersion"
        static let preferredThemeIDs = "quizice.onboarding.preferredThemeIDs"
        static let legacyPreferencesMigrationLocale = "quizice.onboarding.preferencesMigrationLocale"
        static let localizedPreferredThemeIDsPrefix = "quizice.onboarding.preferredThemeIDs."
        static let pendingThemePreferencesPrefix = "quizice.onboarding.themePreferencesPending."

        static func preferredThemeIDs(locale: String) -> String {
            localizedPreferredThemeIDsPrefix + locale
        }

        static func pendingThemePreferences(locale: String) -> String {
            pendingThemePreferencesPrefix + locale
        }
    }

    static let currentVersion = 1

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var needsOnboarding: Bool {
        userDefaults.integer(forKey: Keys.completedVersion) < Self.currentVersion
    }

    var preferredThemeIDs: Set<String> {
        Set(orderedPreferredThemeIDs(locale: AppLocalizationStore.shared.resolvedLanguageCode))
    }

    func complete(preferredThemeIDs: Set<String>) {
        complete(
            preferredThemeIDs: preferredThemeIDs.sorted(),
            locale: AppLocalizationStore.shared.resolvedLanguageCode
        )
    }

    func orderedPreferredThemeIDs(locale: String) -> [String] {
        storedPreferredThemeIDs(locale: locale) ?? []
    }

    func storedPreferredThemeIDs(locale: String) -> [String]? {
        let localizedKey = Keys.preferredThemeIDs(locale: locale)
        if let localizedIDs = userDefaults.stringArray(forKey: localizedKey) {
            return Self.normalizedThemeIDs(localizedIDs)
        }

        guard let storedLegacyIDs = userDefaults.stringArray(forKey: Keys.preferredThemeIDs) else {
            return nil
        }
        let legacyIDs = Self.normalizedThemeIDs(storedLegacyIDs)
        if let migrationLocale = userDefaults.string(forKey: Keys.legacyPreferencesMigrationLocale) {
            guard migrationLocale == locale else { return nil }
        } else {
            userDefaults.set(locale, forKey: Keys.legacyPreferencesMigrationLocale)
        }
        userDefaults.set(legacyIDs, forKey: localizedKey)
        return legacyIDs
    }

    func complete(preferredThemeIDs: [String], locale: String) {
        let normalizedIDs = Self.normalizedThemeIDs(preferredThemeIDs)
        userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs(locale: locale))
        userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs)
        userDefaults.set(locale, forKey: Keys.legacyPreferencesMigrationLocale)
        userDefaults.set(true, forKey: Keys.pendingThemePreferences(locale: locale))
        userDefaults.set(Self.currentVersion, forKey: Keys.completedVersion)
    }

    func applyRemotePreferredThemeIDs(_ preferredThemeIDs: [String], locale: String) {
        let normalizedIDs = Self.normalizedThemeIDs(preferredThemeIDs)
        userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs(locale: locale))
        if locale == AppLocalizationStore.shared.resolvedLanguageCode {
            userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs)
            userDefaults.set(locale, forKey: Keys.legacyPreferencesMigrationLocale)
        }
        userDefaults.set(false, forKey: Keys.pendingThemePreferences(locale: locale))
    }

    func hasPendingThemePreferences(locale: String) -> Bool {
        userDefaults.bool(forKey: Keys.pendingThemePreferences(locale: locale))
    }

    private static func normalizedThemeIDs(_ themeIDs: [String]) -> [String] {
        var seenIDs = Set<String>()
        return themeIDs.compactMap { themeID in
            let normalizedID = themeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty, seenIDs.insert(normalizedID).inserted else { return nil }
            return normalizedID
        }
    }
}
