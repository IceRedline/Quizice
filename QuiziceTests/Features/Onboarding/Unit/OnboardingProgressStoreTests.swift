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
            XCTAssertEqual(reopenedStore.preferredThemeIDs, ["music", "technology"])
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
