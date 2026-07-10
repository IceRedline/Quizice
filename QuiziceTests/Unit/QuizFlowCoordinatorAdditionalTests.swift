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
    }

    func testGeneratedAIThemeUpdatesSessionAndShowsDescriptionAfterSheetDismissal() {
        let harness = makeHarness()
        harness.coordinator.start()
        let generatedTheme = SnapshotSupport.makeTheme(
            id: "ai-generated",
            name: "Generated theme",
            questions: (1...5).map { index in
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
        XCTAssertEqual(harness.session.questionsCount, 5)
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
