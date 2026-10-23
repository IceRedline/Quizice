import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeSettingsVisualStateTests: HomeScreenVisualStateTestCase {
    func testHomeHelpButtonSitsBelowSettingsAndReopensOnboarding() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeSettingsButton"
            ) as? UIButton
        )
        let helpButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeOnboardingHelpButton"
            ) as? UIButton
        )
        let helpSurface = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeOnboardingHelpVisualSurface"
            )
        )

        XCTAssertEqual(helpButton.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(helpSurface.bounds.size, CGSize(width: 36, height: 36))
        XCTAssertEqual(helpButton.center.x, settingsButton.center.x, accuracy: 0.5)
        XCTAssertGreaterThan(helpButton.frame.minY, settingsButton.frame.maxY)
        XCTAssertGreaterThanOrEqual(settingsButton.frame.minY, 0)
        XCTAssertGreaterThanOrEqual(helpButton.frame.minY, 0)
        XCTAssertEqual(helpButton.accessibilityLabel, L10n.Onboarding.helpAccessibilityLabel)
        XCTAssertEqual(helpButton.accessibilityHint, L10n.Onboarding.helpAccessibilityHint)
        XCTAssertNotNil(helpButton.image(for: .normal))

        helpButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showOnboardingCallCount, 1)
        XCTAssertEqual(router.showSettingsCallCount, 0)
    }

    func testHomeStartsAtTopAfterReservingSpaceForHelpButton() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура"),
            makeTheme(name: "Политика и бизнес")
        ]
        let viewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        let motivationLabel = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeMotivationLabel"
            )
        )

        XCTAssertGreaterThan(collectionView.adjustedContentInset.top, 0)
        XCTAssertEqual(
            collectionView.contentOffset.y,
            -collectionView.adjustedContentInset.top,
            accuracy: 0.5
        )
        XCTAssertGreaterThanOrEqual(motivationLabel.frame.minY, 0)
        XCTAssertEqual(motivationLabel.alpha, 1, accuracy: 0.001)
    }

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

@MainActor
final class SettingsAccountModelTests: XCTestCase {
    func testConfirmedDeletionRoutesOutOfSettings() {
        var deletionCompletionCount = 0
        let view = QuizSettingsView(
            onAccountDeleted: { deletionCompletionCount += 1 },
            personalizedRepeatsAvailable: { false }
        )

        view.presentAccountOutcome(.deleted)

        XCTAssertEqual(deletionCompletionCount, 1)
    }

    func testUnconfirmedDeletionKeepsSettingsAvailableForRetry() {
        var deletionCompletionCount = 0
        let view = QuizSettingsView(
            onAccountDeleted: { deletionCompletionCount += 1 },
            personalizedRepeatsAvailable: { false }
        )
        let outcomes: [SettingsAccountModel.Outcome] = [
            .deletionFailed, .cleanupRequired, .sessionExpired, .unavailable,
            .creationFailed, .created
        ]

        for outcome in outcomes {
            view.presentAccountOutcome(outcome)
            XCTAssertEqual(deletionCompletionCount, 0, "Unexpected navigation for \(outcome)")
        }
    }

    func testUnavailableAccountDoesNotReportDeletionSuccess() async {
        let model = SettingsAccountModel(manager: nil)

        let result = await model.deleteAccount()

        XCTAssertEqual(result, .unavailable)
        XCTAssertFalse(model.canDelete)
        XCTAssertFalse(model.canCreate)
        XCTAssertFalse(model.isBusy)
    }

    func testDeletionWaitsForConfirmationAndBlocksDuplicateOperations() async {
        let manager = SettingsAccountManagerStub()
        let started = expectation(description: "Deletion request started")
        manager.deletionStarted = { started.fulfill() }
        manager.suspendsDeletion = true
        let model = SettingsAccountModel(manager: manager)

        let request = Task { await model.deleteAccount() }
        await fulfillment(of: [started], timeout: 1)

        XCTAssertEqual(model.operation, .deleting)
        let duplicate = await model.deleteAccount()
        let creation = await model.createAccount()
        XCTAssertNil(duplicate)
        XCTAssertNil(creation)
        XCTAssertEqual(manager.deletionCount, 1)
        XCTAssertEqual(manager.creationCount, 0)

        manager.finishDeletion()
        let result = await request.value

        XCTAssertEqual(result, .deleted)
        XCTAssertFalse(model.isBusy)
        XCTAssertFalse(model.canDelete)
        XCTAssertTrue(model.canCreate)
    }

    func testDeletionFailureCanBeRetriedWithoutPretendingSuccess() async {
        let manager = SettingsAccountManagerStub()
        manager.deletionError = URLError(.notConnectedToInternet)
        let model = SettingsAccountModel(manager: manager)

        let failure = await model.deleteAccount()

        XCTAssertEqual(failure, .deletionFailed)
        XCTAssertTrue(model.canDelete)
        XCTAssertFalse(model.isBusy)
        manager.deletionError = nil

        let retry = await model.deleteAccount()

        XCTAssertEqual(retry, .deleted)
        XCTAssertEqual(manager.deletionCount, 2)
    }

    func testLocalCleanupFailureIsDistinctFromUnconfirmedServerDeletion() async {
        let manager = SettingsAccountManagerStub()
        manager.deletionError = AccountDeletionError.localCleanupFailed
        let model = SettingsAccountModel(manager: manager)

        let result = await model.deleteAccount()

        XCTAssertEqual(result, .cleanupRequired)
        XCTAssertTrue(model.canDelete)
        XCTAssertFalse(model.isBusy)
    }

    func testExpiredDeletionSessionDoesNotCreateAccount() async {
        let manager = SettingsAccountManagerStub()
        manager.deletionError = AccountDeletionError.sessionExpired
        let model = SettingsAccountModel(manager: manager)

        let result = await model.deleteAccount()

        XCTAssertEqual(result, .sessionExpired)
        XCTAssertEqual(manager.creationCount, 0)
        XCTAssertFalse(model.isBusy)
    }

    func testAccountCreationOnlyRunsExplicitlyAndSupportsRetry() async {
        let manager = SettingsAccountManagerStub()
        manager.accountDeletionAvailable = false
        manager.canCreateAccount = true
        manager.creationError = URLError(.timedOut)
        let model = SettingsAccountModel(manager: manager)
        model.refreshAvailability()

        XCTAssertEqual(manager.creationCount, 0)
        let failure = await model.createAccount()
        XCTAssertEqual(failure, .creationFailed)
        XCTAssertTrue(model.canCreate)
        XCTAssertFalse(model.isBusy)
        manager.creationError = nil

        let retry = await model.createAccount()

        XCTAssertEqual(retry, .created)
        XCTAssertTrue(model.canDelete)
        XCTAssertFalse(model.canCreate)
        XCTAssertEqual(manager.creationCount, 2)
    }

    func testAvailabilityIsRecheckedBeforeSendingDeletion() async {
        let manager = SettingsAccountManagerStub()
        let model = SettingsAccountModel(manager: manager)
        manager.accountDeletionAvailable = false

        let result = await model.deleteAccount()

        XCTAssertEqual(result, .unavailable)
        XCTAssertEqual(manager.deletionCount, 0)
        XCTAssertFalse(model.canDelete)
    }
}

@MainActor
private final class SettingsAccountManagerStub: AccountManaging {
    var accountDeletionAvailable = true
    var canCreateAccount = false
    var deletionCount = 0
    var creationCount = 0
    var deletionError: Error?
    var creationError: Error?
    var suspendsDeletion = false
    var deletionStarted: (() -> Void)?
    private var deletionContinuation: CheckedContinuation<Void, Never>?

    func deleteAccount() async throws {
        deletionCount += 1
        if suspendsDeletion {
            await withCheckedContinuation { continuation in
                deletionContinuation = continuation
                deletionStarted?()
            }
        }
        if let deletionError { throw deletionError }
        accountDeletionAvailable = false
        canCreateAccount = true
    }

    func finishDeletion() {
        deletionContinuation?.resume()
        deletionContinuation = nil
    }

    func createAccount() async throws {
        creationCount += 1
        if let creationError { throw creationError }
        accountDeletionAvailable = true
        canCreateAccount = false
    }
}
