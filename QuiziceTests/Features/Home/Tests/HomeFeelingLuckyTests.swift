import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeFeelingLuckyTests: HomeScreenVisualStateTestCase {
    func testFeelingLuckyStartsFiveQuestionsWithoutDescription() async throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        QuizFactory.shared.questionsCount = 15

        let viewController = QuizViewController(
            randomQuestionsProvider: { $0 },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await launchTask.value

        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyAnalyticsTracksRandomFiveQuestionStart() async throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let analytics = HomeAnalyticsTrackingSpy()
        let viewController = QuizViewController(
            analytics: analytics,
            randomQuestionsProvider: { $0 },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)
        analytics.reset()

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await launchTask.value

        let luckyEvents = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(luckyEvents.map(\.name), ["theme_selected", "quiz_started"])
        guard luckyEvents.count == 2 else { return }
        XCTAssertEqual(luckyEvents[0].parameters["selection_method"] as? String, "random")
        XCTAssertEqual(luckyEvents[0].parameters["theme_id"] as? String, "random-selection")
        XCTAssertEqual(luckyEvents[1].parameters["theme_id"] as? String, "random-selection")
        XCTAssertEqual(luckyEvents[1].parameters["question_count"] as? Int, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyForwardsSelectedBackendMode() async throws {
        let repository = FeelingLuckyThemeRepositorySpy(
            themes: [makeTheme(name: "Музыка", questionCount: 15)]
        )
        let viewController = QuizViewController(
            themeRepository: repository,
            randomQuestionsProvider: { $0 },
            randomQuestionSelectionModeProvider: { .randomBalanced },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeFeelingLuckyButton"
            ) as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await launchTask.value

        XCTAssertEqual(repository.requestedSelectionModes, [.randomBalanced])
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testBackendFeelingLuckyDoesNotRequireBundledQuestions() async throws {
        let remoteTheme = QuizTheme(
            id: "music",
            theme: "Музыка",
            themeDescription: "Описание",
            questions: [],
            questionOrigin: .backend
        )
        let repository = FeelingLuckyThemeRepositorySpy(
            themes: [remoteTheme],
            catalogOrigin: .backend
        )
        let viewController = QuizViewController(
            themeRepository: repository,
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeFeelingLuckyButton"
            ) as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        try await waitUntil {
            router.showQuestionCallCount == 1
        }

        XCTAssertEqual(repository.requestedSelectionModes.count, 1)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testBackendThemeOffersEverySupportedQuestionCountWithoutBundledQuestions() {
        let remoteTheme = QuizTheme(
            id: "music",
            theme: "Музыка",
            themeDescription: "Описание",
            questions: [],
            questionOrigin: .backend
        )
        let repository = FeelingLuckyThemeRepositorySpy(
            themes: [remoteTheme],
            catalogOrigin: .backend
        )
        let session = QuizSessionStore(themes: { repository.themes })
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session
        )
        let sourceButton = UIButton()

        viewController.themeButtonTouchedUpInside(sourceButton, themeID: remoteTheme.stableID)

        XCTAssertEqual(
            viewController.homeCardState.availableQuestionCounts,
            QuizQuestionCountPolicy.supportedCounts
        )
    }

    func testFeelingLuckySelectsFiveQuestionsFromTheCombinedPoolAndUsesRandomSelectionTitle() async throws {
        let music = makeTheme(name: "Музыка", questionCount: 3)
        let technology = makeTheme(name: "Технологии", questionCount: 4)
        QuizFactory.shared.themes = [music, technology]
        var offeredQuestions: [QuizQuestion] = []
        let viewController = QuizViewController(
            randomQuestionsProvider: { questions in
                offeredQuestions = questions
                return Array(questions.reversed())
            },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await launchTask.value

        XCTAssertEqual(offeredQuestions.count, 7)
        XCTAssertTrue(music.questions.allSatisfy { question in offeredQuestions.contains { $0 === question } })
        XCTAssertTrue(technology.questions.allSatisfy { question in offeredQuestions.contains { $0 === question } })
        let selectedTheme = try XCTUnwrap(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(selectedTheme.themeID, "random-selection")
        XCTAssertEqual(selectedTheme.themeName, L10n.Home.randomSelection)
        XCTAssertEqual(selectedTheme.questionsAndAnswers.count, 5)
        XCTAssertTrue(selectedTheme.quizTheme.questions.contains { selected in
            music.questions.contains { $0 === selected }
        })
        XCTAssertTrue(selectedTheme.quizTheme.questions.contains { selected in
            technology.questions.contains { $0 === selected }
        })
        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyShowsProgressUntilMinimumFeedbackDelayCompletes() async throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let delayStarted = expectation(description: "Minimum feedback delay started")
        let delay = FeelingLuckyFeedbackDelay(started: delayStarted)
        defer { delay.release() }
        let viewController = QuizViewController(
            randomQuestionsProvider: { $0 },
            feelingLuckyMinimumFeedbackDelay: { await delay.wait() }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView
        )
        let progressView = try XCTUnwrap(
            luckyButton.descendant(withAccessibilityIdentifier: "homeFeelingLuckyProgressView")
                as? UIActivityIndicatorView
        )

        luckyButton.sendActions(for: .touchUpInside)
        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await fulfillment(of: [delayStarted], timeout: 2)

        XCTAssertFalse(luckyButton.isEnabled)
        XCTAssertTrue(progressView.isAnimating)
        XCTAssertEqual(luckyButton.accessibilityLabel, L10n.Home.feelingLuckyLoading)
        XCTAssertFalse(collectionView.isUserInteractionEnabled)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        XCTAssertTrue(viewController.cardSlideTransitionSourceView === luckyButton)

        QuizFactory.shared.questionsCount = 10
        delay.release()
        await launchTask.value

        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertTrue(progressView.isAnimating)
        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
    }

    func testFeelingLuckyCancellationRestoresHomeAndIgnoresStaleDelayCompletion() async throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let delayStarted = expectation(description: "Minimum feedback delay started")
        let delay = FeelingLuckyFeedbackDelay(started: delayStarted)
        defer { delay.release() }
        let viewController = QuizViewController(
            randomQuestionsProvider: { $0 },
            feelingLuckyMinimumFeedbackDelay: { await delay.wait() }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        let progressView = try XCTUnwrap(
            luckyButton.descendant(withAccessibilityIdentifier: "homeFeelingLuckyProgressView")
                as? UIActivityIndicatorView
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView")
                as? UICollectionView
        )
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        let launchTask = try XCTUnwrap(viewController.feelingLuckyTask)
        await fulfillment(of: [delayStarted], timeout: 2)
        XCTAssertTrue(progressView.isAnimating)

        viewController.quizFlowWillReturnToThemes()

        XCTAssertTrue(luckyButton.isEnabled)
        XCTAssertFalse(progressView.isAnimating)
        XCTAssertEqual(luckyButton.accessibilityLabel, L10n.Home.feelingLucky)
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertTrue(settingsButton.isEnabled)
        XCTAssertEqual(router.showQuestionCallCount, 0)

        delay.release()
        await launchTask.value

        XCTAssertEqual(router.showQuestionCallCount, 0)
        XCTAssertTrue(luckyButton.isEnabled)
        XCTAssertFalse(progressView.isAnimating)
    }

    func testFeelingLuckyDoesNotLaunchWhenCombinedPoolHasFewerThanFiveUsableQuestions() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка", questionCount: 2),
            makeTheme(name: "Технологии", questionCount: 2)
        ]
        let viewController = QuizViewController(randomQuestionsProvider: { $0 })
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        let motivationLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel
        )
        XCTAssertEqual(motivationLabel.text, L10n.Question.unavailableMessage)
    }

}

private final class FeelingLuckyThemeRepositorySpy: ThemeRepository {
    var themes: [QuizTheme]?
    let catalogOrigin: QuizCatalogOrigin
    private(set) var requestedSelectionModes: [CrossThemeQuestionSelectionMode] = []

    init(
        themes: [QuizTheme],
        catalogOrigin: QuizCatalogOrigin = .bundled
    ) {
        self.themes = themes
        self.catalogOrigin = catalogOrigin
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }

    func prepareRandomQuiz(
        selectionMode: CrossThemeQuestionSelectionMode,
        localFallback: QuizTheme,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        requestedSelectionModes.append(selectionMode)
        return localFallback
    }
}

/// Keeps the feedback delay suspended until the test releases it. Main-actor
/// isolation also prevents the async-let child from racing with test assertions.
@MainActor
private final class FeelingLuckyFeedbackDelay {
    private let started: XCTestExpectation
    private var continuation: CheckedContinuation<Void, Never>?
    private var isReleased = false

    init(started: XCTestExpectation) { self.started = started }

    func wait() async {
        guard !isReleased else { return }
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started.fulfill()
        }
    }

    func release() {
        isReleased = true
        continuation?.resume()
        continuation = nil
    }
}
