import XCTest
@testable import Quizice

final class OnboardingProgressStoreTests: XCTestCase {
    func testFreshStoreRequiresOnboarding() {
        withStore { store, _ in
            XCTAssertTrue(store.needsOnboarding)
            XCTAssertTrue(store.preferredThemeIDs.isEmpty)
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))
        }
    }

    func testCompletionPersistsVersionAndPreferredThemesAcrossStoreInstances() {
        withStore { store, defaults in
            store.complete(
                preferredThemeIDs: ["technology", "music"],
                locale: "ru"
            )

            let reopenedStore = OnboardingProgressStore(userDefaults: defaults)

            XCTAssertFalse(reopenedStore.needsOnboarding)
            XCTAssertEqual(
                reopenedStore.orderedPreferredThemeIDs(locale: "ru"),
                ["technology", "music"]
            )
            XCTAssertTrue(reopenedStore.hasPendingThemePreferences(locale: "ru"))
            XCTAssertEqual(
                defaults.integer(forKey: OnboardingProgressStore.Keys.completedVersion),
                OnboardingProgressStore.currentVersion
            )
        }
    }

    func testReadingPreferencesForManualReplayDoesNotResetCompletion() {
        withStore { store, defaults in
            store.complete(preferredThemeIDs: ["history_culture"])

            _ = store.preferredThemeIDs

            XCTAssertFalse(store.needsOnboarding)
            XCTAssertEqual(
                defaults.integer(forKey: OnboardingProgressStore.Keys.completedVersion),
                OnboardingProgressStore.currentVersion
            )
        }
    }

    func testPreferencesAreIndependentForEachLocale() {
        withStore { store, _ in
            store.complete(preferredThemeIDs: ["music", "space"], locale: "ru")
            store.applyRemotePreferredThemeIDs(["cinema"], locale: "en")

            XCTAssertEqual(
                store.orderedPreferredThemeIDs(locale: "ru"),
                ["music", "space"]
            )
            XCTAssertEqual(
                store.orderedPreferredThemeIDs(locale: "en"),
                ["cinema"]
            )
            XCTAssertTrue(store.hasPendingThemePreferences(locale: "ru"))
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "en"))
        }
    }

    func testRemotePreferencesReplaceLocalOrderAndClearPendingFlag() {
        withStore { store, _ in
            store.complete(preferredThemeIDs: ["music", "space"], locale: "ru")

            store.applyRemotePreferredThemeIDs(
                ["space", "cinema", "music"],
                locale: "ru"
            )

            XCTAssertEqual(
                store.orderedPreferredThemeIDs(locale: "ru"),
                ["space", "cinema", "music"]
            )
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "ru"))
        }
    }

    func testExplicitEmptySelectionIsDifferentFromMissingPreferences() {
        withStore { store, _ in
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))

            store.complete(preferredThemeIDs: [], locale: "ru")

            XCTAssertEqual(store.storedPreferredThemeIDs(locale: "ru"), [])
            XCTAssertTrue(store.hasPendingThemePreferences(locale: "ru"))
        }
    }

    private func withStore(
        _ operation: (OnboardingProgressStore, UserDefaults) throws -> Void
    ) rethrows {
        let suiteName = "OnboardingProgressStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }

        try operation(OnboardingProgressStore(userDefaults: defaults), defaults)
    }
}

extension OnboardingProgressStoreTests {
    func testNewGuestChoiceIsClaimedOnceAndAccountPreferencesStayIsolated() {
        withStore { _, defaults in
            var userID: String?
            let store = OnboardingProgressStore(userDefaults: defaults, userIDProvider: { userID })
            store.complete(preferredThemeIDs: ["music"], locale: "ru")
            userID = "A"
            XCTAssertEqual(store.orderedPreferredThemeIDs(locale: "ru"), ["music"])
            XCTAssertTrue(store.hasPendingThemePreferences(locale: "ru"))
            store.applyRemotePreferredThemeIDs(["space"], locale: "ru")
            userID = "B"
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "ru"))
            store.complete(preferredThemeIDs: ["cinema"], locale: "ru")
            userID = "A"
            XCTAssertEqual(store.orderedPreferredThemeIDs(locale: "ru"), ["space"])
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "ru"))
        }
    }

    func testUnownedLegacyPreferencesAreNeverClaimedByAnAccount() {
        withStore { _, defaults in
            defaults.set(["music"], forKey: OnboardingProgressStore.Keys.preferredThemeIDs)
            defaults.set(["music"], forKey: OnboardingProgressStore.Keys.preferredThemeIDs(locale: "ru"))
            defaults.set(true, forKey: OnboardingProgressStore.Keys.pendingThemePreferences(locale: "ru"))
            let store = OnboardingProgressStore(userDefaults: defaults, userIDProvider: { "new-account" })
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "ru"))
        }
    }
}

extension OnboardingProgressStoreTests {
    func testGuestSelectionIsConsumedByFirstReturningAccountEvenIfItHasPreferences() {
        withStore { _, defaults in
            var userID: String? = "A"
            let store = OnboardingProgressStore(userDefaults: defaults, userIDProvider: { userID })
            store.applyRemotePreferredThemeIDs(["technology"], locale: "ru")
            userID = nil
            store.complete(preferredThemeIDs: ["music"], locale: "ru")
            userID = "A"
            XCTAssertEqual(store.orderedPreferredThemeIDs(locale: "ru"), ["music"])
            XCTAssertTrue(store.hasPendingThemePreferences(locale: "ru"))
            userID = "B"
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))
            XCTAssertFalse(store.hasPendingThemePreferences(locale: "ru"))
        }
    }

    func testDeletingAccountRemovesEveryLocaleAndGuestCopiesButPreservesOtherAccountsAndSettings() {
        withStore { _, defaults in
            var userID: String?
            let store = OnboardingProgressStore(userDefaults: defaults, userIDProvider: { userID })
            store.complete(preferredThemeIDs: ["guest-choice"], locale: "ru")
            userID = "A"
            _ = store.orderedPreferredThemeIDs(locale: "ru")
            store.complete(preferredThemeIDs: ["space"], locale: "en")
            userID = "B"
            store.complete(preferredThemeIDs: ["cinema"], locale: "ru")
            defaults.set("de", forKey: "language-setting")

            store.eraseData(for: "A")

            XCTAssertEqual(store.orderedPreferredThemeIDs(locale: "ru"), ["cinema"])
            XCTAssertTrue(store.hasPendingThemePreferences(locale: "ru"))
            userID = "A"
            for locale in ["ru", "en"] {
                XCTAssertNil(store.storedPreferredThemeIDs(locale: locale))
                XCTAssertFalse(store.hasPendingThemePreferences(locale: locale))
            }
            userID = nil
            XCTAssertNil(store.storedPreferredThemeIDs(locale: "ru"))
            XCTAssertFalse(store.needsOnboarding)
            XCTAssertEqual(defaults.string(forKey: "language-setting"), "de")
        }
    }
}
