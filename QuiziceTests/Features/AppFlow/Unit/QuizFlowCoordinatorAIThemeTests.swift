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

    func testInlineAIThemeSuccessUpdatesSessionAndRoutesToDescriptionExactlyOnce() async throws {
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
        tenQuestionButton.sendActions(for: .touchUpInside)

        controls.submitButton.sendActions(for: .touchUpInside)
        try await waitUntil { service.generatedConfigurations.count == 1 }
        XCTAssertEqual(service.generatedConfigurations.first?.theme, "История космоса")
        XCTAssertEqual(service.generatedConfigurations.first?.questionCount, 10)

        let generatedTheme = makeGeneratedAITheme(questionCount: 10)
        service.resolveNext(with: .success(generatedTheme))

        try await waitUntil { harness.router.showDescriptionCallCount == 1 }
        XCTAssertEqual(harness.router.showDescriptionCallCount, 1)
        XCTAssertEqual(harness.session.chosenTheme?.themeID, generatedTheme.stableID)
        XCTAssertTrue(harness.session.chosenTheme?.isAIGenerated == true)
        XCTAssertEqual(harness.session.questionsCount, 10)
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

        await Task.yield()
        XCTAssertEqual(harness.router.showDescriptionCallCount, 1)
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
        XCTAssertEqual(harness.router.showDescriptionCallCount, 0)
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
        XCTAssertEqual(harness.router.showDescriptionCallCount, 0)
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
        XCTAssertEqual(harness.router.showDescriptionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)

        service.resolveNext(
            with: .success(makeGeneratedAITheme(questionCount: 5, id: "stale_ai_theme"))
        )
        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.analytics.aiGenerationCancelledCount, 1)
        XCTAssertEqual(harness.router.showDescriptionCallCount, 0)
        XCTAssertNil(harness.session.chosenTheme)
        XCTAssertNil(
            descendant(
                in: harness.viewController.view,
                accessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
    }
}
