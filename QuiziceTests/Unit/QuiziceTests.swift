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
    func testDefaultsUseClassicDesignSystemCleanModeAndAnimatedBackground() {
        let harness = makeHarness()
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        XCTAssertEqual(store.designStyle, .classic)
        XCTAssertEqual(store.cleanColorSchemePreference, .system)
        XCTAssertEqual(store.backgroundStyle, .slate5x5)
    }

    func testPersistsDesignAndCleanMode() {
        let harness = makeHarness()
        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        store.designStyle = .radar
        store.cleanColorSchemePreference = .dark
        store.backgroundStyle = .slate4x4

        let reloadedStore = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)
        XCTAssertEqual(reloadedStore.designStyle, .radar)
        XCTAssertEqual(reloadedStore.cleanColorSchemePreference, .dark)
        XCTAssertEqual(reloadedStore.backgroundStyle, .slate4x4)
    }

    func testFallsBackFromInvalidStoredValues() {
        let harness = makeHarness()
        harness.defaults.set("invalid-design", forKey: AppAppearanceStore.Keys.designStyle)
        harness.defaults.set("invalid-theme", forKey: AppAppearanceStore.Keys.cleanColorScheme)
        harness.defaults.set("invalid-background", forKey: AppAppearanceStore.Keys.backgroundStyle)

        let store = AppAppearanceStore(userDefaults: harness.defaults, notificationCenter: harness.notificationCenter)

        XCTAssertEqual(store.designStyle, .classic)
        XCTAssertEqual(store.cleanColorSchemePreference, .system)
        XCTAssertEqual(store.backgroundStyle, .slate5x5)
    }

    func testSettingsDesignOrderAndTitles() {
        XCTAssertEqual(AppDesignStyle.settingsOrder, [.classic, .radar, .clean])
        XCTAssertEqual(
            AppDesignStyle.settingsOrder.map(\.title),
            [
                L10n.Settings.Design.classic,
                L10n.Settings.Design.radar,
                L10n.Settings.Design.clean
            ]
        )
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

final class QuizResultPresenterBoundaryTests: XCTestCase {
    func testResultDescriptionBoundariesUseHalfOpenRanges() {
        assertDescription(correctAnswers: 0, totalQuestions: 100, expected: L10n.Result.veryLowScoreDescription)
        assertDescription(correctAnswers: 15, totalQuestions: 100, expected: L10n.Result.lowScoreDescription)
        assertDescription(correctAnswers: 30, totalQuestions: 100, expected: L10n.Result.mediumLowScoreDescription)
        assertDescription(correctAnswers: 50, totalQuestions: 100, expected: L10n.Result.mediumScoreDescription)
        assertDescription(correctAnswers: 75, totalQuestions: 100, expected: L10n.Result.strongResultDescription)
        assertDescription(correctAnswers: 100, totalQuestions: 100, expected: L10n.Result.perfectScoreDescription)
    }

    func testZeroTotalQuestionsUsesNoQuestionsDescription() {
        assertDescription(correctAnswers: 0, totalQuestions: 0, expected: L10n.Result.noQuestionsDescription)
    }

    private func assertDescription(
        correctAnswers: Int,
        totalQuestions: Int,
        expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let presenter = QuizResultPresenter(
            result: QuizResultState(correctAnswers: correctAnswers, totalQuestions: totalQuestions)
        )
        let view = QuizResultViewSpy()
        presenter.view = view

        presenter.viewDidLoad()

        XCTAssertEqual(view.descriptionTexts.last, expected, file: file, line: line)
    }
}

final class QuizDescriptionPresenterTests: XCTestCase {
    func testOutOfBoundsQuestionCountSelectionDoesNotMutateSession() {
        let session = PresenterTestSession()
        session.questionsCount = 10
        let presenter = QuizDescriptionPresenter(session: session)

        presenter.saveNumberOfQuestions(chosenRow: 99)

        XCTAssertEqual(session.questionsCount, 10)
    }
}

@MainActor
final class QuizFlowCoordinatorTests: XCTestCase {
    func testReturnToThemesDismissesFlowAndKeepsExistingWindowRootController() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = NavigationControllerSpy()
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            session: PresenterTestSession()
        )
        coordinator.start()
        let rootBeforeReturn = window.rootViewController

        coordinator.returnToThemes()

        XCTAssertTrue(window.rootViewController === rootBeforeReturn)
        XCTAssertEqual(navigationController.dismissCallCount, 1)
        XCTAssertEqual(navigationController.popToRootCallCount, 1)
        XCTAssertEqual(navigationController.events, [.popToRoot(animated: false), .dismiss(animated: true)])
    }
}

private final class QuizResultViewSpy: QuizResultViewControllerProtocol {
    var presenter: QuizResultPresenterProtocol?
    private(set) var descriptionTexts: [String] = []

    func updateResultLabels(resultText: String, descriptionText: String) {
        descriptionTexts.append(descriptionText)
    }
}

private final class PresenterTestSession: QuizSessionManaging {
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount: Int = 5
    var startup1st: Bool = false

    func loadTheme(themeID: String) -> Bool {
        guard let theme = themes?.first(where: { $0.stableID == themeID }) else { return false }
        chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}

private final class NavigationControllerSpy: UINavigationController {
    enum Event: Equatable {
        case dismiss(animated: Bool)
        case popToRoot(animated: Bool)
    }

    private(set) var dismissCallCount = 0
    private(set) var popToRootCallCount = 0
    private(set) var events: [Event] = []

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        events.append(.dismiss(animated: flag))
        completion?()
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        popToRootCallCount += 1
        events.append(.popToRoot(animated: animated))
        return []
    }
}
