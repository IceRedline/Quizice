import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeSettingsVisualStateTests: HomeScreenVisualStateTestCase {
    func testHomeSettingsButtonPresentsSettingsScreen() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton)

        XCTAssertNotNil(settingsButton.image(for: .normal))
#if DEBUG
        XCTAssertFalse(settingsButton.showsMenuAsPrimaryAction)
        XCTAssertNotNil(settingsButton.menu)
#endif

        settingsButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showSettingsCallCount, 1)
    }

    func testHomeSettingsDebugMenuContainsBackgroundPresets() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

#if DEBUG
        let menu = try XCTUnwrap(settingsButton.menu)
        let interfaceAction = try XCTUnwrap(menu.children.first as? UIAction)
        let localhostAction = try XCTUnwrap(menu.children.dropFirst().first as? UIAction)
        let localContentOnlyAction = try XCTUnwrap(menu.children.dropFirst(2).first as? UIAction)
        let directAIAction = try XCTUnwrap(menu.children.dropFirst(3).first as? UIAction)
        let backgroundMenu = try XCTUnwrap(menu.children.last as? UIMenu)
        let backgroundActions = backgroundMenu.children.compactMap { $0 as? UIAction }

        XCTAssertEqual(interfaceAction.title, "Hide UI")
        XCTAssertEqual(localhostAction.title, L10n.Settings.localhostBackend)
        XCTAssertEqual(localhostAction.subtitle, L10n.Settings.localhostBackendSubtitle)
        XCTAssertEqual(localhostAction.state, .off)
        XCTAssertEqual(localContentOnlyAction.title, L10n.Settings.localContentOnly)
        XCTAssertEqual(localContentOnlyAction.subtitle, L10n.Settings.localContentOnlySubtitle)
        XCTAssertEqual(localContentOnlyAction.state, .off)
        XCTAssertEqual(directAIAction.title, L10n.Settings.directAI)
        XCTAssertEqual(directAIAction.subtitle, L10n.Settings.directAISubtitle)
        XCTAssertEqual(directAIAction.state, .off)
        XCTAssertEqual(backgroundMenu.title, L10n.Home.backgroundStyleSwitcher)
        XCTAssertEqual(backgroundActions.count, AppBackgroundStyle.allCases.count)
        XCTAssertEqual(backgroundActions.map(\.title), AppBackgroundStyle.allCases.map(\.title))
        XCTAssertEqual(AppAppearanceStore.shared.backgroundStyle, .slate5x5)
        XCTAssertEqual(backgroundActions.filter { $0.state == .on }.map(\.title), [AppBackgroundStyle.slate5x5.title])
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "appBackgroundView"))

        XCTAssertNotNil(backgroundActions.first { $0.title == AppBackgroundStyle.slate4x4.title })
        viewController.selectBackgroundStyle(.slate4x4)

        XCTAssertEqual(AppAppearanceStore.shared.backgroundStyle, .slate4x4)
        let updatedBackgroundMenu = try XCTUnwrap(settingsButton.menu?.children.last as? UIMenu)
        let updatedBackgroundActions = updatedBackgroundMenu.children.compactMap { $0 as? UIAction }
        XCTAssertEqual(
            updatedBackgroundActions.filter { $0.state == .on }.map(\.title),
            [AppBackgroundStyle.slate4x4.title]
        )
#else
        XCTAssertNil(settingsButton.menu)
#endif
    }

    func testHomeSettingsDebugMenuTogglesLocalhostBackend() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        UserDefaults.standard.set(true, forKey: DebugBackendSettings.useLocalContentOnlyKey)

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )
        let localhostAction = try XCTUnwrap(settingsButton.menu?.children.dropFirst().first as? UIAction)

        XCTAssertEqual(localhostAction.state, .off)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))

        viewController.toggleDebugLocalhostBackend()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey))
        let updatedAction = try XCTUnwrap(settingsButton.menu?.children.dropFirst().first as? UIAction)
        XCTAssertEqual(updatedAction.state, .on)
#endif
    }

    func testHomeSettingsDebugMenuTogglesLocalContentOnlyAndDisablesLocalhost() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        UserDefaults.standard.set(true, forKey: DebugBackendSettings.useLocalhostKey)

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

        viewController.toggleDebugLocalContentOnly()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))
        let localhostAction = try XCTUnwrap(settingsButton.menu?.children.dropFirst().first as? UIAction)
        let localContentOnlyAction = try XCTUnwrap(settingsButton.menu?.children.dropFirst(2).first as? UIAction)
        XCTAssertEqual(localhostAction.state, .off)
        XCTAssertEqual(localContentOnlyAction.state, .on)
#endif
    }

    func testHomeSettingsDebugMenuTogglesDirectAI() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let viewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeSettingsButton"
            ) as? UIButton
        )

        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugAIRuntimeSettings.useDirectAIKey))
        viewController.toggleDebugDirectAI(prepareAPIKey: { true })

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DebugAIRuntimeSettings.useDirectAIKey))
        let directAIAction = try XCTUnwrap(
            settingsButton.menu?.children.dropFirst(3).first as? UIAction
        )
        XCTAssertEqual(directAIAction.state, .on)
#endif
    }

    func testHomeSettingsDebugMenuDoesNotEnableDirectAIWithoutAPIKey() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let viewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeSettingsButton"
            ) as? UIButton
        )

        viewController.toggleDebugDirectAI(prepareAPIKey: { false })

        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugAIRuntimeSettings.useDirectAIKey))
        let directAIAction = try XCTUnwrap(
            settingsButton.menu?.children.dropFirst(3).first as? UIAction
        )
        XCTAssertEqual(directAIAction.state, .off)
#endif
    }

    func testHomeSettingsDebugMenuHidesAndRestoresInterface() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )
        let headerStackView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView")
        )
        let screenStackView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeScreenStackView")
        )
        XCTAssertNotNil(settingsButton.menu?.children.first as? UIAction)

        viewController.toggleDebugInterfaceVisibility()

        XCTAssertTrue(headerStackView.isHidden)
        XCTAssertTrue(screenStackView.isHidden)
        XCTAssertFalse(settingsButton.isHidden)
        XCTAssertTrue(settingsButton.isEnabled)
        settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.showSettingsCallCount, 1)

        let showAction = try XCTUnwrap(settingsButton.menu?.children.first as? UIAction)
        XCTAssertEqual(showAction.title, "Show UI")
        viewController.toggleDebugInterfaceVisibility()

        XCTAssertFalse(headerStackView.isHidden)
        XCTAssertFalse(screenStackView.isHidden)
#endif
    }

    func testHomeHasNoSeparateDebugButtonsOrInactiveBackgroundMenu() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))

        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeBackgroundStyleButton"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeDebugInterfaceButton"))
#if DEBUG
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )
        XCTAssertTrue(settingsButton.menu?.children.compactMap { $0 as? UIMenu }.isEmpty == true)
#endif
    }

    func testRadarSettingsSurfaceStaysBehindGearArtwork() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton)
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))
        let imageView = try XCTUnwrap(settingsButton.imageView)
        let surfaceIndex = try XCTUnwrap(settingsButton.subviews.firstIndex(of: visualSurface))
        let imageIndex = try XCTUnwrap(settingsButton.subviews.firstIndex(of: imageView))

        XCTAssertLessThan(surfaceIndex, imageIndex)
        XCTAssertNotNil(settingsButton.image(for: .normal))
        XCTAssertEqual(settingsButton.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
    }

    func testClassicSettingsSurfaceIsCircular() throws {
        UserDefaults.standard.set(AppDesignStyle.classic.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))

        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
        XCTAssertEqual(visualSurface.layer.cornerRadius, visualSurface.bounds.height / 2, accuracy: 0.001)
        XCTAssertEqual(visualSurface.layer.cornerCurve, .circular)
    }

    func testCleanSettingsSurfaceIsCircular() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 375, height: 667))
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))

        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
        XCTAssertEqual(visualSurface.layer.cornerRadius, visualSurface.bounds.height / 2, accuracy: 0.001)
        XCTAssertEqual(visualSurface.layer.cornerCurve, .circular)
    }

}
