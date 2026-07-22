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
        XCTAssertNil(settingsButton.menu)
        let debugGesture = try XCTUnwrap(
            settingsButton.gestureRecognizers?.compactMap { $0 as? UILongPressGestureRecognizer }.first
        )
        XCTAssertEqual(debugGesture.minimumPressDuration, 0.5, accuracy: 0.001)
#endif

        settingsButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showSettingsCallCount, 1)
    }

    func testHomeSettingsDebugSheetContainsExistingSettingsAndBackgroundPresets() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

#if DEBUG
        XCTAssertNil(settingsButton.menu)
        let viewModel = viewController.makeDebugMenuViewModel()
        XCTAssertFalse(viewModel.isInterfaceHidden)
        XCTAssertFalse(viewModel.usesLocalhostBackend)
        XCTAssertFalse(viewModel.usesLocalContentOnly)
        XCTAssertFalse(viewModel.usesDirectAI)
        XCTAssertTrue(viewModel.showsBackgroundStyles)
        XCTAssertEqual(viewModel.backgroundStyle, .slate5x5)
        XCTAssertEqual(DebugMenuView.AccessibilityID.pulse, "debugMenuPulse")
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "appBackgroundView"))

        viewModel.selectBackgroundStyle(.slate4x4)

        XCTAssertEqual(AppAppearanceStore.shared.backgroundStyle, .slate4x4)
        XCTAssertEqual(viewModel.backgroundStyle, .slate4x4)

        viewController.presentDebugMenu()
        drainAnimations()
        let sheet = try XCTUnwrap(
            viewController.presentedViewController as? UIHostingController<DebugMenuView>
        )
        XCTAssertEqual(sheet.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(sheet.overrideUserInterfaceStyle, .dark)
        XCTAssertEqual(sheet.sheetPresentationController?.detents.count, 2)
        XCTAssertEqual(sheet.sheetPresentationController?.selectedDetentIdentifier, .large)
        XCTAssertEqual(sheet.rootView.viewModel.backgroundStyle, .slate4x4)
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
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))

        let viewModel = viewController.makeDebugMenuViewModel()
        viewModel.toggleLocalhostBackend()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey))
        XCTAssertTrue(viewModel.usesLocalhostBackend)
        XCTAssertFalse(viewModel.usesLocalContentOnly)
        XCTAssertNil(settingsButton.menu)
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

        let viewModel = viewController.makeDebugMenuViewModel()
        viewModel.toggleLocalContentOnly()

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey))
        XCTAssertFalse(viewModel.usesLocalhostBackend)
        XCTAssertTrue(viewModel.usesLocalContentOnly)
        XCTAssertNil(settingsButton.menu)
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
        XCTAssertTrue(viewController.makeDebugMenuViewModel().usesDirectAI)
        XCTAssertNil(settingsButton.menu)
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
        XCTAssertFalse(viewController.makeDebugMenuViewModel().usesDirectAI)
        XCTAssertNil(settingsButton.menu)
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
        let viewModel = viewController.makeDebugMenuViewModel()

        viewModel.toggleInterfaceVisibility()

        XCTAssertTrue(headerStackView.isHidden)
        XCTAssertTrue(screenStackView.isHidden)
        XCTAssertTrue(viewModel.isInterfaceHidden)
        XCTAssertFalse(settingsButton.isHidden)
        XCTAssertTrue(settingsButton.isEnabled)
        settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.showSettingsCallCount, 1)

        viewModel.toggleInterfaceVisibility()

        XCTAssertFalse(headerStackView.isHidden)
        XCTAssertFalse(screenStackView.isHidden)
        XCTAssertFalse(viewModel.isInterfaceHidden)
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
        XCTAssertNil(settingsButton.menu)
        XCTAssertFalse(viewController.makeDebugMenuViewModel().showsBackgroundStyles)
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
