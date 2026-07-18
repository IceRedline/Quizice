import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorAIThemeTests: QuizFlowCoordinatorTestCase {
    func testInlineAIThemeSubmitIsSingleFlight() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let harness = try makeInlineAIHarness(service: service)
        defer { harness.dispose() }
        let controls = try revealInlineAIBack(
            in: harness.viewController,
            prompt: "  Космос  \n"
        )

        controls.submitButton.sendActions(for: .touchUpInside)
        controls.submitButton.sendActions(for: .touchUpInside)

        try await waitUntil { service.generatedConfigurations.count == 1 }
        XCTAssertEqual(service.generatedConfigurations.map(\.theme), ["Космос"])
        XCTAssertEqual(service.generatedConfigurations.map(\.questionCount), [5])
        XCTAssertFalse(controls.submitButton.isEnabled)

        try closeInlineAICard(in: harness.viewController)
        try await waitUntil { harness.analytics.aiGenerationCancelledCount == 1 }
        service.resolveNext(with: .failure(CancellationError()))
    }

    func testInlineAIThemeSuccessUpdatesSessionAndRoutesToQuestionExactlyOnce() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let harness = try makeInlineAIHarness(service: service)
        defer { harness.dispose() }
        let controls = try revealInlineAIBack(
            in: harness.viewController,
            prompt: "  История космоса  "
        )
        let countSelector = try XCTUnwrap(
            descendant(
                in: controls.card,
                accessibilityIdentifier: "aiThemeQuestionCountSelector"
            )
        )
        let tenQuestionButton = try XCTUnwrap(
            countSelector.allDescendants.compactMap { $0 as? UIButton }.first {
                $0.title(for: .normal) == "10"
            }
        )
        let collectionView = try XCTUnwrap(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        var routeSnapshot: InlineAIRouteSnapshot?
        harness.router.onShowQuestion = {
            [weak self,
             weak viewController = harness.viewController,
             weak expandedCard = controls.card,
             weak collectionView] in
            guard let self, let viewController, let expandedCard, let collectionView else { return }
            routeSnapshot = InlineAIRouteSnapshot(
                cardWasAttached: expandedCard.isDescendant(of: viewController.view),
                backdropWasAttached: self.descendant(
                    in: viewController.view,
                    accessibilityIdentifier: "homeExpandedThemeCardBackdrop"
                ) != nil,
                cardWasInteractive: expandedCard.isUserInteractionEnabled,
                collectionWasInteractive: collectionView.isUserInteractionEnabled,
                sourceWasCard: viewController.cardSlideTransitionSourceView === expandedCard,
                isLaunchPending: viewController.isQuizLaunchPending,
                hasLaunchStarted: viewController.hasQuizLaunchStarted
            )
        }
        tenQuestionButton.sendActions(for: .touchUpInside)

        controls.submitButton.sendActions(for: .touchUpInside)
        try await waitUntil { service.generatedConfigurations.count == 1 }
        XCTAssertEqual(service.generatedConfigurations.first?.theme, "История космоса")
        XCTAssertEqual(service.generatedConfigurations.first?.questionCount, 10)

        let generatedTheme = makeGeneratedAITheme(questionCount: 10)
        service.resolveNext(with: .success(generatedTheme))

        try await waitUntil { harness.router.showQuestionCallCount == 1 }
        XCTAssertEqual(harness.router.showQuestionCallCount, 1)
        XCTAssertEqual(harness.analytics.quizStartedCount, 1)
        XCTAssertEqual(harness.session.chosenTheme?.themeID, generatedTheme.stableID)
        XCTAssertTrue(harness.session.chosenTheme?.isAIGenerated == true)
        XCTAssertEqual(
            harness.session.chosenTheme?.aiGenerationConfiguration,
            service.generatedConfigurations.first
        )
        XCTAssertEqual(harness.session.questionsCount, 10)
        XCTAssertEqual(controls.card.accessibilityIdentifier, "homeExpandedAIThemeCard")
        let snapshot = try XCTUnwrap(routeSnapshot)
        XCTAssertTrue(snapshot.cardWasAttached)
        XCTAssertTrue(snapshot.backdropWasAttached)
        XCTAssertFalse(snapshot.cardWasInteractive)
        XCTAssertFalse(snapshot.collectionWasInteractive)
        XCTAssertTrue(snapshot.sourceWasCard)
        XCTAssertTrue(snapshot.isLaunchPending)
        XCTAssertTrue(snapshot.hasLaunchStarted)

        await Task.yield()
        XCTAssertEqual(harness.router.showQuestionCallCount, 1)
        XCTAssertEqual(harness.analytics.quizStartedCount, 1)

        harness.viewController.quizFlowWillReturnToThemes()

        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertNil(harness.viewController.quizTransitionSourceView)
        XCTAssertFalse(harness.viewController.isQuizLaunchPending)
        XCTAssertFalse(harness.viewController.hasQuizLaunchStarted)
    }

    func testInlineAIThemeFailurePreservesDraftAndOffersRetryAndEdit() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let harness = try makeInlineAIHarness(service: service)
        defer { harness.dispose() }
        let prompt = "Мифы Древней Греции"
        let controls = try revealInlineAIBack(
            in: harness.viewController,
            prompt: prompt
        )

        controls.submitButton.sendActions(for: .touchUpInside)
        try await waitUntil { service.generatedConfigurations.count == 1 }
        service.resolveNext(
            with: .failure(YandexAIQuizThemeServiceError.network(.timedOut))
        )

        try await waitUntil {
            harness.viewController.presentedViewController?.modalPresentationStyle == .overFullScreen
        }
        let alert = try XCTUnwrap(harness.viewController.presentedViewController)
        alert.view.layoutIfNeeded()
        XCTAssertEqual(controls.promptEditor.text, prompt)
        XCTAssertTrue(controls.submitButton.isEnabled)
        XCTAssertTrue(alert.isModalInPresentation)
        XCTAssertTrue(alert.view.accessibilityViewIsModal)
        XCTAssertEqual(harness.router.showQuestionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)
    }

    func testReturningToThemesDismissesPresentedInlineAIAlert() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let harness = try makeInlineAIHarness(service: service)
        defer { harness.dispose() }
        let controls = try revealInlineAIBack(
            in: harness.viewController,
            prompt: "Архитектура"
        )

        controls.submitButton.sendActions(for: .touchUpInside)
        try await waitUntil { service.generatedConfigurations.count == 1 }
        service.resolveNext(
            with: .failure(YandexAIQuizThemeServiceError.network(.timedOut))
        )
        try await waitUntil {
            harness.viewController.presentedViewController?.modalPresentationStyle == .overFullScreen
        }

        harness.viewController.quizFlowWillReturnToThemes()

        try await waitUntil { harness.viewController.presentedViewController == nil }
        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        let collectionView = try XCTUnwrap(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertEqual(harness.router.showQuestionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)
    }

    func testClosingInlineAIThemeCancelsOnceAndIgnoresStaleSuccess() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let harness = try makeInlineAIHarness(service: service)
        defer { harness.dispose() }
        let controls = try revealInlineAIBack(
            in: harness.viewController,
            prompt: "Архитектура"
        )

        controls.submitButton.sendActions(for: .touchUpInside)
        try await waitUntil { service.generatedConfigurations.count == 1 }

        try closeInlineAICard(in: harness.viewController)
        try await waitUntil { harness.analytics.aiGenerationCancelledCount == 1 }
        XCTAssertEqual(harness.analytics.aiGenerationCancelledCount, 1)
        XCTAssertEqual(harness.router.showQuestionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)

        service.resolveNext(
            with: .success(makeGeneratedAITheme(questionCount: 5, id: "stale_ai_theme"))
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.analytics.aiGenerationCancelledCount, 1)
        XCTAssertEqual(harness.router.showQuestionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)
        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
    }

    func testReplayRegeneratesAIQuizWithOriginalConfigurationAndIsSingleFlight() async throws {
        let service = ControllableRoutingAIQuizThemeService()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        let configuration = AIQuizGenerationConfiguration(
            theme: "История космоса",
            questionCount: 10,
            difficulty: .hard,
            locale: Locale(identifier: "ru_RU")
        )
        let originalTheme = makeGeneratedAITheme(questionCount: 10, id: "original-ai-theme")
        originalTheme.aiGenerationConfiguration = configuration
        session.chosenTheme = ThemeModel(quizTheme: originalTheme)
        session.questionsCount = configuration.questionCount
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: []),
            session: session,
            aiQuizThemeService: service
        )
        coordinator.start()
        navigationController.topViewControllerOverride = navigationController
        coordinator.showResult(QuizResultState(correctAnswers: 7, totalQuestions: 10))
        let resultViewController = try XCTUnwrap(
            navigationController.presentedControllers.last as? QuizResultViewController
        )
        resultViewController.loadViewIfNeeded()

        coordinator.replayQuiz()
        coordinator.replayQuiz()

        try await waitUntil { service.generatedConfigurations.count == 1 }
        XCTAssertEqual(service.generatedConfigurations, [configuration])
        XCTAssertEqual(session.chosenTheme?.themeID, "original-ai-theme")
        let replayButton = try XCTUnwrap(
            resultViewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayButton"
            ) as? UIButton
        )
        let activityIndicator = try XCTUnwrap(
            resultViewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayActivityIndicator"
            ) as? UIActivityIndicatorView
        )
        let progressLabel = try XCTUnwrap(
            resultViewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayProgressStatus"
            ) as? UILabel
        )
        XCTAssertFalse(replayButton.isEnabled)
        XCTAssertTrue(activityIndicator.isAnimating)
        XCTAssertEqual(progressLabel.text, AIQuizGenerationPhase.analyzing.title)

        let regeneratedTheme = makeGeneratedAITheme(questionCount: 10, id: "regenerated-ai-theme")
        service.resolveNext(with: .success(regeneratedTheme))

        try await waitUntil { session.chosenTheme?.themeID == "regenerated-ai-theme" }
        XCTAssertEqual(session.questionsCount, 10)
        XCTAssertEqual(session.chosenTheme?.aiGenerationConfiguration, configuration)
        XCTAssertTrue(navigationController.presentedControllers.last is QuizQuestionViewController)
        XCTAssertEqual(navigationController.dismissAnimationFlags.last, false)
        XCTAssertTrue(replayButton.isEnabled)
        XCTAssertFalse(activityIndicator.isAnimating)
        XCTAssertTrue(progressLabel.isHidden)
    }
}

private struct InlineAIRouteSnapshot {
    let cardWasAttached: Bool
    let backdropWasAttached: Bool
    let cardWasInteractive: Bool
    let collectionWasInteractive: Bool
    let sourceWasCard: Bool
    let isLaunchPending: Bool
    let hasLaunchStarted: Bool
}
