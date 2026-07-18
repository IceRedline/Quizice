import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorNavigationTests: QuizFlowCoordinatorTestCase {
    func testCloseQuestionReturnsToHome() {
        let harness = makeHarness()
        harness.coordinator.start()

        harness.coordinator.closeQuestion()

        XCTAssertEqual(harness.navigationController.popToRootCallCount, 1)
        XCTAssertEqual(harness.navigationController.popToRootAnimationFlags, [false])
        XCTAssertEqual(harness.navigationController.dismissCallCount, 1)
        XCTAssertEqual(harness.navigationController.dismissAnimationFlags, [true])
    }

    func testImmediateQuestionReturnExplicitlyRestoresLuckyHomeInteraction() async throws {
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
        try await waitUntil(timeout: 1.5) {
            navigationController.presentedControllers.count == 1
        }
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

    func testModalRoutesPresentQuestionResultAndSettings() {
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
    }

    func testResultRouteUsesTheCoordinatorSession() throws {
        let harness = makeHarness()
        harness.session.chosenTheme = ThemeModel(
            quizTheme: SnapshotSupport.makeTheme(id: "injected-session", name: "Injected")
        )
        QuizFactory.shared.chosenTheme = ThemeModel(
            quizTheme: SnapshotSupport.makeTheme(id: "global-session", name: "Global")
        )
        harness.coordinator.start()
        harness.navigationController.topViewControllerOverride = harness.navigationController

        harness.coordinator.showResult(QuizResultState(correctAnswers: 1, totalQuestions: 1))

        let resultViewController = try XCTUnwrap(
            harness.navigationController.presentedControllers.last as? QuizResultViewController
        )
        XCTAssertEqual(resultViewController.presenter?.themeID, "injected-session")
    }
}
