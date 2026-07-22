import XCTest
@testable import Quizice

final class OnboardingProgressStoreTests: XCTestCase {
    func testFreshStoreRequiresOnboarding() {
        withStore { store, _ in
            XCTAssertTrue(store.needsOnboarding)
            XCTAssertTrue(store.preferredThemeIDs.isEmpty)
        }
    }

    func testCompletionPersistsVersionAndPreferredThemesAcrossStoreInstances() {
        withStore { store, defaults in
            store.complete(preferredThemeIDs: ["technology", "music"])

            let reopenedStore = OnboardingProgressStore(userDefaults: defaults)

            XCTAssertFalse(reopenedStore.needsOnboarding)
            XCTAssertEqual(reopenedStore.preferredThemeIDs, ["music", "technology"])
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
