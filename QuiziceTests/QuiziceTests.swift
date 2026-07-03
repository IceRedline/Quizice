import UIKit
import XCTest
@testable import Quizice

final class QuiziceTests: XCTestCase {
    func testQuiziceModuleLoads() {
        XCTAssertNotNil(Bundle.main.bundleIdentifier)
        XCTAssertNotNil(AppDelegate.self)
    }
}

final class AppAppearanceStoreTests: XCTestCase {
    func testDefaultsUseClassicDesignAndSystemCleanMode() {
        let harness = makeHarness()
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        XCTAssertEqual(store.designStyle, .classic)
        XCTAssertEqual(store.cleanColorSchemePreference, .system)
    }

    func testPersistsDesignAndCleanMode() {
        let harness = makeHarness()
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        store.designStyle = .radar
        store.cleanColorSchemePreference = .dark

        let reloadedStore = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)
        XCTAssertEqual(reloadedStore.designStyle, .radar)
        XCTAssertEqual(reloadedStore.cleanColorSchemePreference, .dark)
    }

    func testFallsBackFromInvalidStoredValues() {
        let harness = makeHarness()
        harness.defaults.set("invalid-design", forKey: AppAppearanceStore.Keys.designStyle)
        harness.defaults.set("invalid-theme", forKey: AppAppearanceStore.Keys.cleanColorScheme)

        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        XCTAssertEqual(store.designStyle, .classic)
        XCTAssertEqual(store.cleanColorSchemePreference, .system)
    }

    func testPixelDesignIsNotSelectableAndFallsBackToClassicInStore() {
        let harness = makeHarness()
        harness.defaults.set(AppDesignStyle.pixel.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        XCTAssertFalse(AppDesignStyle.pixel.isSelectable)
        XCTAssertTrue(AppDesignStyle.clean.isSelectable)
        XCTAssertTrue(AppDesignStyle.radar.isSelectable)
        XCTAssertTrue(AppDesignStyle.classic.isSelectable)
        XCTAssertEqual(store.designStyle, .classic)

        store.designStyle = .pixel

        XCTAssertEqual(store.designStyle, .classic)
    }

    func testSettingsDesignOrderAndTitles() {
        XCTAssertEqual(AppDesignStyle.settingsOrder, [.classic, .radar, .clean, .pixel])
        XCTAssertEqual(AppDesignStyle.settingsOrder.map(\.title), ["Классический", "Радар", "Минимализм", "Пиксель"])
    }

    func testPostsNotificationWhenAppearanceChanges() {
        let harness = makeHarness()
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)
        let expectation = expectation(description: "Appearance notification")
        let observer = harness.notificationCenter.addObserver(
            forName: .appAppearanceDidChange,
            object: store,
            queue: .main
        ) { _ in
            expectation.fulfill()
        }

        store.designStyle = .radar

        wait(for: [expectation], timeout: 1)
        harness.notificationCenter.removeObserver(observer)
    }

    func testCleanDarkAppearanceUsesDarkSurfacesAndLightSurfaceText() {
        let appearance = AppAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .dark,
            traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )

        XCTAssertEqual(appearance.resolvedInterfaceStyle, .dark)
        XCTAssertTrue(appearance.card.backgroundColor.isEqual(UIColor(named: "themeCleanCardDark")))
        XCTAssertTrue(appearance.surfaceTextColor.isEqual(UIColor(named: "themeWhite")))
    }

    private func makeHarness(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (defaults: UserDefaults, notificationCenter: NotificationCenter) {
        let suiteName = "AppAppearanceStoreTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite", file: file, line: line)
            return (.standard, NotificationCenter())
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, NotificationCenter())
    }
}

final class AppFontRegistrationTests: XCTestCase {
    func testBundledFontFamiliesAreRegistered() {
        let expectedFamilies = [
            AppFontFamily.inter.rawValue,
            AppFontFamily.jetBrainsMono.rawValue,
            AppFontFamily.rubikPixels.rawValue,
            AppFontFamily.manrope.rawValue
        ]

        for family in expectedFamilies {
            XCTAssertFalse(
                UIFont.fontNames(forFamilyName: family).isEmpty,
                "Expected \(family) to be registered from UIAppFonts"
            )
        }
    }
}
