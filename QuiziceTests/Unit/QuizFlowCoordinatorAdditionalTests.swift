import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorAdditionalTests: XCTestCase {
    override func tearDown() {
        resetSharedQuizFactoryForTests()
        super.tearDown()
    }

    func testStartInstallsHomeControllerAsNavigationRoot() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: []),
            session: session
        )

        coordinator.start()

        XCTAssertTrue(window.rootViewController === navigationController)
        XCTAssertTrue(navigationController.viewControllers.first is QuizViewController)
        XCTAssertTrue(navigationController.isNavigationBarHidden)
    }

    func testLaunchOverlayPresenterInstallsAndRemovesFakeLaunchAboveRoot() throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = rootViewController
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .radar)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(in: window, appearance: appearance, holdDuration: 60)

        let overlayWindow = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )
        XCTAssertFalse(overlayWindow.isKeyWindow)
        XCTAssertEqual(overlayWindow.windowLevel.rawValue, window.windowLevel.rawValue + 1)
        let hostingController = try XCTUnwrap(
            overlayWindow.rootViewController as? UIHostingController<FakeLaunchScreenView>
        )
        XCTAssertEqual(hostingController.rootView.appearance.designStyle, .radar)
        assertColor(overlayWindow.backgroundColor, equals: .black)
        assertColor(hostingController.view.backgroundColor, equals: .black)
        XCTAssertTrue(rootViewController.view.accessibilityElementsHidden)
        XCTAssertEqual(rootViewController.children.count, 1)

        presenter.dismiss(animated: false)

        XCTAssertTrue(overlayWindow.isHidden)
        XCTAssertNil(overlayWindow.rootViewController)
        XCTAssertFalse(rootViewController.view.accessibilityElementsHidden)
        XCTAssertEqual(rootViewController.children.count, 1)
    }

    func testLaunchOverlayPresenterAutomaticallyRevealsHomeAndRestoresAccessibility() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.isHidden = false
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .radar)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(
            in: window,
            appearance: appearance,
            holdDuration: 0,
            motion: FakeLaunchMotion(logoZoomScale: 42, logoZoomDuration: 0.05)
        )

        let overlayWindow = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )
        let dismissalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                overlayWindow.isHidden && overlayWindow.rootViewController == nil
            },
            object: nil
        )

        await fulfillment(of: [dismissalExpectation], timeout: 2)

        XCTAssertFalse(rootViewController.view.accessibilityElementsHidden)
    }

    func testFakeLaunchUsesCrossfadeCompletionWhenAnimationsAreDisabled() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let completionExpectation = expectation(description: "Fake launch completes without zoom")
        var completionStyle: FakeLaunchCompletionStyle?
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let appearance = makeLaunchAppearance(designStyle: .classic)
        let rootView = FakeLaunchScreenView(
            appearance: appearance,
            holdDuration: 0,
            motion: FakeLaunchMotion(logoZoomScale: 42, logoZoomDuration: 0.01)
        ) { style in
            completionStyle = style
            completionExpectation.fulfill()
        }
        let viewController = UIHostingController(rootView: rootView)
        window.rootViewController = viewController
        window.isHidden = false
        defer {
            UIView.setAnimationsEnabled(animationsWereEnabled)
            window.isHidden = true
            window.rootViewController = nil
        }

        await fulfillment(of: [completionExpectation], timeout: 1)

        XCTAssertEqual(completionStyle, .crossfade)
    }

    func testStaleLaunchFadeDoesNotRemoveAReplacementOverlay() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .classic)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(in: window, appearance: appearance, holdDuration: 60)
        let firstOverlay = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )

        presenter.dismiss()
        presenter.dismiss(animated: false)
        presenter.present(in: window, appearance: appearance, holdDuration: 60)

        let replacementOverlay = try XCTUnwrap(
            windowScene.windows.first {
                $0 !== firstOverlay
                    && $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
                    && !$0.isHidden
            }
        )
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(replacementOverlay.isHidden)
        XCTAssertNotNil(replacementOverlay.rootViewController)
        XCTAssertTrue(rootViewController.view.accessibilityElementsHidden)
    }

    func testFakeLaunchVisualStyleMatchesSelectedDesignAndColorScheme() throws {
        let classicAppearance = makeLaunchAppearance(designStyle: .classic)
        let classicStyle = FakeLaunchVisualStyle(appearance: classicAppearance)
        XCTAssertEqual(classicStyle.markStyle, .classicImage)
        XCTAssertTrue(classicStyle.revealsAppBackground)
        XCTAssertNil(classicStyle.foregroundColor)
        assertColor(classicStyle.backgroundColor, equals: UIColor(hex: 0x111620))

        let radarAppearance = makeLaunchAppearance(designStyle: .radar)
        let radarStyle = FakeLaunchVisualStyle(appearance: radarAppearance)
        XCTAssertEqual(radarStyle.markStyle, .radarText)
        XCTAssertFalse(radarStyle.revealsAppBackground)
        assertColor(radarStyle.backgroundColor, equals: .black)
        assertColor(
            try XCTUnwrap(radarStyle.foregroundColor),
            equals: radarAppearance.accentColor
        )

        let cleanLightAppearance = makeLaunchAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .light
        )
        let cleanLightStyle = FakeLaunchVisualStyle(appearance: cleanLightAppearance)
        XCTAssertEqual(cleanLightStyle.markStyle, .cleanText)
        XCTAssertFalse(cleanLightStyle.revealsAppBackground)
        assertColor(cleanLightStyle.backgroundColor, equals: .white)
        assertColor(try XCTUnwrap(cleanLightStyle.foregroundColor), equals: .black)

        let cleanDarkAppearance = makeLaunchAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .dark
        )
        let cleanDarkStyle = FakeLaunchVisualStyle(appearance: cleanDarkAppearance)
        XCTAssertEqual(cleanDarkStyle.markStyle, .cleanText)
        XCTAssertFalse(cleanDarkStyle.revealsAppBackground)
        assertColor(cleanDarkStyle.backgroundColor, equals: .black)
        assertColor(try XCTUnwrap(cleanDarkStyle.foregroundColor), equals: .white)
    }

    func testLaunchStoryboardMatchesFakeLaunchBaseGeometryAndColor() throws {
        let viewController = try XCTUnwrap(
            UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        )
        let logoImageView = try XCTUnwrap(
            viewController.view.subviews.compactMap { $0 as? UIImageView }.first
        )
        let backgroundColor = try XCTUnwrap(viewController.view.backgroundColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        XCTAssertTrue(backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 17.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(green, 22.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(blue, 32.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(alpha, 1, accuracy: 0.000_001)

        let pixelTolerance = 1 / UIScreen.main.scale
        for size in [
            CGSize(width: 320, height: 568),
            CGSize(width: 393, height: 852),
            CGSize(width: 600, height: 1_000)
        ] {
            viewController.view.frame = CGRect(origin: .zero, size: size)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            XCTAssertEqual(logoImageView.frame.midX, size.width / 2, accuracy: 0.01)
            XCTAssertEqual(logoImageView.frame.midY, size.height / 2, accuracy: 0.01)
            let expectedWidth = min(size.width * 0.7, 360)
            let expectedHeight = expectedWidth * 399 / 742
            XCTAssertEqual(logoImageView.frame.width, expectedWidth, accuracy: pixelTolerance)
            XCTAssertEqual(logoImageView.frame.height, expectedHeight, accuracy: pixelTolerance)
        }
    }

    func testDescriptionAndStatisticsRoutesPushExpectedControllers() {
        let harness = makeHarness()
        harness.coordinator.start()

        harness.coordinator.showDescription()
        harness.coordinator.showStatistics()

        XCTAssertTrue(harness.navigationController.viewControllers[1] is QuizDescriptionViewController)
        XCTAssertTrue(harness.navigationController.viewControllers[2] is StatisticsViewController)

        harness.coordinator.closeStatistics()
        XCTAssertEqual(harness.navigationController.popCallCount, 1)
    }

    func testCloseQuestionReturnsToHomeInsteadOfDescription() {
        let harness = makeHarness()
        harness.coordinator.start()

        harness.coordinator.closeQuestion()

        XCTAssertEqual(harness.navigationController.popToRootCallCount, 1)
        XCTAssertEqual(harness.navigationController.popToRootAnimationFlags, [false])
        XCTAssertEqual(harness.navigationController.dismissCallCount, 1)
        XCTAssertEqual(harness.navigationController.dismissAnimationFlags, [true])
    }

    func testImmediateQuestionReturnExplicitlyRestoresLuckyHomeInteraction() throws {
        let question = QuizQuestion(
            question: "Question?",
            answers: ["A", "B", "C", "D"],
            correctAnswer: "A"
        )
        let theme = SnapshotSupport.makeTheme(
            id: "music",
            name: "Music",
            questions: Array(repeating: question, count: 5)
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let repository = RoutingThemeRepository(themes: [theme])
        let session = RoutingSession()
        session.themes = [theme]
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: repository,
            session: session,
            aiQuizThemeService: MockAIQuizThemeService()
        )
        coordinator.start()
        navigationController.topViewControllerOverride = navigationController

        let home = try XCTUnwrap(navigationController.viewControllers.first as? QuizViewController)
        home.loadViewIfNeeded()
        home.view.frame = window.bounds
        home.view.layoutIfNeeded()
        let collectionView = try XCTUnwrap(
            descendant(in: home.view, accessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView
        )
        let luckyButton = try XCTUnwrap(
            descendant(in: home.view, accessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(navigationController.presentedControllers.count, 1)

        luckyButton.isHidden = true
        coordinator.returnToThemes()

        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertFalse(luckyButton.isHidden)

        let themeButton = try XCTUnwrap(
            descendant(in: home.view, accessibilityIdentifier: "music") as? UIButton
        )
        themeButton.sendActions(for: .touchUpInside)
        XCTAssertNotNil(
            descendant(in: home.view, accessibilityIdentifier: "homeExpandedThemeCard")
        )
    }

    func testReplayPreservesSelectionAndPresentsFreshQuestionController() throws {
        let harness = makeHarness()
        harness.coordinator.start()
        harness.navigationController.topViewControllerOverride = harness.navigationController
        let session = harness.session
        let selectedThemeID = session.chosenTheme?.themeID
        session.questionsCount = 10

        harness.coordinator.showQuestion()
        let firstQuestion = try XCTUnwrap(harness.navigationController.presentedControllers.last as? QuizQuestionViewController)

        harness.coordinator.replayQuiz()

        let replayedQuestion = try XCTUnwrap(harness.navigationController.presentedControllers.last as? QuizQuestionViewController)
        XCTAssertFalse(firstQuestion === replayedQuestion)
        XCTAssertEqual(session.chosenTheme?.themeID, selectedThemeID)
        XCTAssertEqual(session.questionsCount, 10)
        XCTAssertEqual(harness.navigationController.dismissAnimationFlags.last, false)
    }

    func testReturnToThemesReachesNavigationRoot() {
        let harness = makeHarness()
        harness.coordinator.start()

        harness.coordinator.returnToThemes()

        XCTAssertEqual(harness.navigationController.popToRootAnimationFlags, [false])
        XCTAssertEqual(harness.navigationController.dismissAnimationFlags, [true])
    }

    func testModalRoutesPresentQuestionResultSettingsAndAIThemeCreation() {
        let harness = makeHarness()
        harness.coordinator.start()
        harness.navigationController.topViewControllerOverride = harness.navigationController

        harness.coordinator.showQuestion()
        XCTAssertEqual(harness.navigationController.presentedControllers.count, 1)
        XCTAssertEqual(harness.navigationController.presentedControllers.last?.modalPresentationStyle, .custom)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags.last, true)
        let questionViewController = harness.navigationController.presentedControllers.last as? QuizQuestionViewController
        XCTAssertNotNil(questionViewController?.transitioningDelegate)

        harness.coordinator.showResult(QuizResultState(correctAnswers: 2, totalQuestions: 3))
        XCTAssertEqual(harness.navigationController.presentedControllers.count, 2)
        XCTAssertEqual(harness.navigationController.presentedControllers.last?.modalPresentationStyle, .custom)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags.last, true)
        let resultViewController = harness.navigationController.presentedControllers.last as? QuizResultViewController
        XCTAssertNotNil(resultViewController?.transitioningDelegate)

        harness.coordinator.showSettings()
        XCTAssertEqual(harness.navigationController.presentedControllers.count, 3)
        XCTAssertEqual(harness.navigationController.presentedControllers.last?.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags.last, true)

        harness.coordinator.showAIThemeCreation()
        XCTAssertEqual(harness.navigationController.presentedControllers.count, 4)
        XCTAssertEqual(harness.navigationController.presentedControllers.last?.modalPresentationStyle, .pageSheet)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags.last, true)
        XCTAssertEqual(
            harness.navigationController.presentedControllers.last?.overrideUserInterfaceStyle,
            AppAppearanceStore.shared.appearance(
                compatibleWith: harness.navigationController.traitCollection
            ).resolvedInterfaceStyle
        )
    }

    func testGeneratedAIThemeUpdatesSessionAndShowsDescriptionAfterSheetDismissal() {
        let harness = makeHarness()
        harness.coordinator.start()
        let generatedTheme = SnapshotSupport.makeTheme(
            id: "ai-generated",
            name: "Generated theme",
            questions: (1...10).map { index in
                QuizQuestion(
                    question: "Question \(index)?",
                    answers: ["A", "B", "C", "D"],
                    correctAnswer: "A"
                )
            }
        )
        let creationViewController = DeferredDismissViewControllerSpy()

        harness.coordinator.handleGeneratedAITheme(generatedTheme, dismissing: creationViewController)

        XCTAssertTrue(harness.session.chosenTheme?.quizTheme === generatedTheme)
        XCTAssertEqual(harness.session.questionsCount, 10)
        XCTAssertEqual(creationViewController.dismissAnimationFlags, [true])
        XCTAssertTrue(harness.navigationController.pushedControllers.isEmpty)

        creationViewController.completeDismissal()

        XCTAssertEqual(harness.navigationController.pushedControllers.count, 1)
        XCTAssertTrue(harness.navigationController.pushedControllers.last is QuizDescriptionViewController)
        XCTAssertEqual(harness.navigationController.pushAnimationFlags, [true])
    }

    private func makeHarness() -> (
        coordinator: QuizFlowCoordinator,
        navigationController: RoutingNavigationControllerSpy,
        session: RoutingSession
    ) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(id: "music", name: "Music"))
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: []),
            session: session,
            aiQuizThemeService: MockAIQuizThemeService()
        )
        return (coordinator, navigationController, session)
    }

    private func descendant(in rootView: UIView, accessibilityIdentifier: String) -> UIView? {
        if rootView.accessibilityIdentifier == accessibilityIdentifier {
            return rootView
        }
        for subview in rootView.subviews {
            if let match = descendant(
                in: subview,
                accessibilityIdentifier: accessibilityIdentifier
            ) {
                return match
            }
        }
        return nil
    }

    private func makeLaunchAppearance(
        designStyle: AppDesignStyle,
        cleanColorSchemePreference: CleanColorSchemePreference = .dark
    ) -> AppAppearance {
        AppAppearance(
            designStyle: designStyle,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: .slate5x5,
            traitCollection: UITraitCollection(
                userInterfaceStyle: cleanColorSchemePreference == .light ? .light : .dark
            )
        )
    }

    private func assertColor(
        _ actual: UIColor?,
        equals expected: UIColor,
        accuracy: CGFloat = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected a color", file: file, line: line)
            return
        }

        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        XCTAssertTrue(
            actual.getRed(
                &actualRed,
                green: &actualGreen,
                blue: &actualBlue,
                alpha: &actualAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertTrue(
            expected.getRed(
                &expectedRed,
                green: &expectedGreen,
                blue: &expectedBlue,
                alpha: &expectedAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed, expectedRed, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualGreen, expectedGreen, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBlue, expectedBlue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualAlpha, expectedAlpha, accuracy: accuracy, file: file, line: line)
    }
}

private final class RoutingNavigationControllerSpy: UINavigationController {
    private(set) var presentedControllers: [UIViewController] = []
    private(set) var presentedAnimationFlags: [Bool] = []
    private(set) var popCallCount = 0
    private(set) var popToRootCallCount = 0
    private(set) var popToRootAnimationFlags: [Bool] = []
    private(set) var dismissCallCount = 0
    private(set) var dismissAnimationFlags: [Bool] = []
    private(set) var pushedControllers: [UIViewController] = []
    private(set) var pushAnimationFlags: [Bool] = []
    var topViewControllerOverride: UIViewController?

    override var topViewController: UIViewController? {
        topViewControllerOverride ?? super.topViewController
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        presentedAnimationFlags.append(flag)
        completion?()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        popCallCount += 1
        return viewControllers.popLast()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushedControllers.append(viewController)
        pushAnimationFlags.append(animated)
        super.pushViewController(viewController, animated: animated)
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        popToRootCallCount += 1
        popToRootAnimationFlags.append(animated)
        return []
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        dismissAnimationFlags.append(flag)
        completion?()
    }
}

private final class DeferredDismissViewControllerSpy: UIViewController {
    private(set) var dismissAnimationFlags: [Bool] = []
    private var dismissalCompletion: (() -> Void)?

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissAnimationFlags.append(flag)
        dismissalCompletion = completion
    }

    func completeDismissal() {
        let completion = dismissalCompletion
        dismissalCompletion = nil
        completion?()
    }
}

private final class RoutingThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?

    init(themes: [QuizTheme]) {
        self.themes = themes
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }
}

private final class RoutingSession: QuizSessionManaging {
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount = 5
    var startup1st = false

    func loadTheme(themeID: String) -> Bool {
        guard let theme = themes?.first(where: { $0.stableID == themeID }) else {
            return false
        }
        chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}
