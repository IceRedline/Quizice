import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorCatalogReplayTests: QuizFlowCoordinatorTestCase {
    func testReplayQuizWithCatalogThemeDispatchesToRepository() async throws {
        let music = SnapshotSupport.makeTheme(id: "music", name: "Music")
        let repository = CountingReplayThemeRepository(themes: [music])
        let session = RoutingSession()
        session.chosenTheme = ThemeModel(quizTheme: music)
        session.questionsCount = 5
        let harness = makeCoordinator(themeRepository: repository, session: session)

        harness.coordinator.replayQuiz()

        try await waitUntil { repository.prepareQuizCallCount >= 1 }
        // Catalog replay path forwards through repository.prepareQuiz (not
        // prepareRandomQuiz and not the AI service). Concurrent replay taps
        // must be coalesced.
        XCTAssertEqual(repository.prepareRandomQuizCallCount, 0)
    }

    func testReplayQuizIgnoresDuplicateInvocationsWhileRunning() async throws {
        let music = SnapshotSupport.makeTheme(id: "music", name: "Music")
        let repository = CountingReplayThemeRepository(themes: [music])
        let session = RoutingSession()
        session.chosenTheme = ThemeModel(quizTheme: music)
        session.questionsCount = 5
        let harness = makeCoordinator(themeRepository: repository, session: session)

        harness.coordinator.replayQuiz()
        harness.coordinator.replayQuiz()
        harness.coordinator.replayQuiz()

        try await waitUntil { repository.prepareQuizCallCount >= 1 }
        // A second/third replayQuiz while the first is still preparing must
        // short-circuit — otherwise the coordinator would race on session
        // mutation and stack multiple backend requests.
        XCTAssertEqual(repository.prepareQuizCallCount, 1)
    }

    private func makeCoordinator(
        themeRepository: ThemeRepository,
        session: QuizSessionManaging
    ) -> (
        coordinator: QuizFlowCoordinator,
        navigationController: RoutingNavigationControllerSpy
    ) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: themeRepository,
            session: session,
            aiQuizThemeService: MockAIQuizThemeService()
        )
        return (coordinator, navigationController)
    }
}

@MainActor
final class CountingReplayThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?
    let catalogOrigin: QuizCatalogOrigin = .bundled
    private(set) var prepareQuizCallCount = 0
    private(set) var prepareRandomQuizCallCount = 0

    init(themes: [QuizTheme]) {
        self.themes = themes
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }

    func prepareQuiz(
        themeID: String,
        questionCount: Int,
        difficulty: AIQuizDifficulty,
        locale: String
    ) async throws -> QuizTheme {
        prepareQuizCallCount += 1
        try await Task.sleep(nanoseconds: 300_000_000)
        guard let theme = themes?.first(where: { $0.stableID == themeID }) else {
            throw QuizPreparationError.unavailable
        }
        return theme
    }

    func prepareRandomQuiz(
        selectionMode: CrossThemeQuestionSelectionMode,
        localFallback: QuizTheme,
        questionCount: Int,
        difficulty: AIQuizDifficulty,
        locale: String
    ) async throws -> QuizTheme {
        prepareRandomQuizCallCount += 1
        try await Task.sleep(nanoseconds: 300_000_000)
        return localFallback
    }
}
