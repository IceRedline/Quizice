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
    func preferencesRevision(locale: String) -> Int
}

extension OnboardingProgressStoring {
    func preferencesRevision(locale: String) -> Int { 0 }
}

final class OnboardingProgressStore: OnboardingProgressStoring {
    static let shared = OnboardingProgressStore(userIDProvider: {
        StoredBackendAccessTokenProvider().currentSession()?.userID
    })

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
    private let userIDProvider: () -> String?

    init(userDefaults: UserDefaults = .standard, userIDProvider: @escaping () -> String? = { nil }) {
        self.userDefaults = userDefaults
        self.userIDProvider = userIDProvider
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
        let localizedKey = scopedKey(Keys.preferredThemeIDs(locale: locale))
        // Only an explicit, newly completed guest selection can be claimed,
        // once, by the first account. Ambiguous legacy data never gets uploaded.
        let claimKey = "quizice.preferences.unclaimedGuest." + locale
        if userIDProvider() != nil, userDefaults.bool(forKey: claimKey),
           let guestIDs = userDefaults.stringArray(forKey: Keys.preferredThemeIDs(locale: locale)) {
            userDefaults.set(false, forKey: claimKey)
            userDefaults.set(guestIDs, forKey: localizedKey)
            userDefaults.set(true, forKey: scopedKey(Keys.pendingThemePreferences(locale: locale)))
            advanceRevision(locale: locale)
            return Self.normalizedThemeIDs(guestIDs)
        }

        if let localizedIDs = userDefaults.stringArray(forKey: localizedKey) {
            return Self.normalizedThemeIDs(localizedIDs)
        }

        // Unowned legacy preferences belong to the guest. Never upload another
        // player's historical selection to the next account on this device.
        guard userIDProvider() == nil,
              let storedLegacyIDs = userDefaults.stringArray(forKey: Keys.preferredThemeIDs) else {
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
        userDefaults.set(normalizedIDs, forKey: scopedKey(Keys.preferredThemeIDs(locale: locale)))
        if userIDProvider() == nil {
            userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs)
            userDefaults.set(locale, forKey: Keys.legacyPreferencesMigrationLocale)
            userDefaults.set(true, forKey: "quizice.preferences.unclaimedGuest." + locale)
        }
        userDefaults.set(true, forKey: scopedKey(Keys.pendingThemePreferences(locale: locale)))
        advanceRevision(locale: locale)
        userDefaults.set(Self.currentVersion, forKey: Keys.completedVersion)
    }

    func applyRemotePreferredThemeIDs(_ preferredThemeIDs: [String], locale: String) {
        let normalizedIDs = Self.normalizedThemeIDs(preferredThemeIDs)
        userDefaults.set(normalizedIDs, forKey: scopedKey(Keys.preferredThemeIDs(locale: locale)))
        if userIDProvider() == nil, locale == AppLocalizationStore.shared.resolvedLanguageCode {
            userDefaults.set(normalizedIDs, forKey: Keys.preferredThemeIDs)
            userDefaults.set(locale, forKey: Keys.legacyPreferencesMigrationLocale)
        }
        userDefaults.set(false, forKey: scopedKey(Keys.pendingThemePreferences(locale: locale)))
        advanceRevision(locale: locale)
    }

    func hasPendingThemePreferences(locale: String) -> Bool {
        _ = storedPreferredThemeIDs(locale: locale)
        return userDefaults.bool(forKey: scopedKey(Keys.pendingThemePreferences(locale: locale)))
    }

    func preferencesRevision(locale: String) -> Int {
        userDefaults.integer(forKey: scopedKey("quizice.preferences.revision." + locale))
    }

    /// Removes favorites for the deleted account in every language. Guest
    /// snapshots can contain copies claimed by that account, so erase those too.
    /// Onboarding completion, language, appearance and other accounts are kept.
    func eraseData(for userID: String) {
        let suffix = ".user." + Data(userID.utf8).base64EncodedString()
        let preferencePrefixes = [
            Keys.localizedPreferredThemeIDsPrefix,
            Keys.pendingThemePreferencesPrefix,
            "quizice.preferences.revision.",
            "quizice.preferences.unclaimedGuest."
        ]
        for key in userDefaults.dictionaryRepresentation().keys {
            let isPreference = preferencePrefixes.contains { key.hasPrefix($0) }
            let isDeletedAccount = key.hasSuffix(suffix)
            let isGuest = !key.contains(".user.")
            if isPreference && (isDeletedAccount || isGuest) {
                userDefaults.removeObject(forKey: key)
            }
        }
        userDefaults.removeObject(forKey: Keys.preferredThemeIDs)
        userDefaults.removeObject(forKey: Keys.legacyPreferencesMigrationLocale)
    }

    private func advanceRevision(locale: String) {
        userDefaults.set(preferencesRevision(locale: locale) + 1,
                         forKey: scopedKey("quizice.preferences.revision." + locale))
    }

    private func scopedKey(_ key: String) -> String {
        guard let userID = userIDProvider() else { return key }
        return key + ".user." + Data(userID.utf8).base64EncodedString()
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
