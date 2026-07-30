import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorLocaleReplayTests: QuizFlowCoordinatorTestCase {
    func testAIReplayDropsResponseWhenLocaleChangedMidGeneration() async throws {
        // setUp installs .russian; craft an AI theme whose configuration says
        // English so that when the response arrives the coordinator will see
        // a locale mismatch and refuse to swap the session onto stale
        // (wrong-language) content.
        let service = ControllableRoutingAIQuizThemeService()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        let configuration = AIQuizGenerationConfiguration(
            theme: "Space history",
            questionCount: 10,
            difficulty: .medium,
            locale: Locale(identifier: "en_US")
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
        coordinator.showQuestion()
        _ = try XCTUnwrap(
            navigationController.presentedControllers.last as? QuizQuestionViewController
        )
        coordinator.showResult(QuizResultState(correctAnswers: 7, totalQuestions: 10))
        _ = try XCTUnwrap(
            navigationController.presentedControllers.last as? QuizResultViewController
        )

        coordinator.replayQuiz()

        try await waitUntil { service.generatedConfigurations.count == 1 }

        let regeneratedTheme = makeGeneratedAITheme(questionCount: 10, id: "regenerated-ai-theme")
        service.resolveNext(with: .success(regeneratedTheme))

        // Give the continuation time to hop back onto the main actor. If the
        // coordinator applied the response the session's themeID would move
        // to "regenerated-ai-theme"; the mismatch guard must keep the
        // original ID in place.
        try? await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertEqual(session.chosenTheme?.themeID, "original-ai-theme")
    }
}
