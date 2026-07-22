import XCTest
@testable import Quizice

@MainActor
final class AnalyticsServiceTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        suiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testEventNamesAndParametersUseStablePrivacySafeValues() {
        let screen = AnalyticsEvent.screenView(screen: .quizQuestion, theme: .catalog(id: "music"))
        XCTAssertEqual(screen.name, "screen_view")
        XCTAssertEqual(screen.parameters["screen"] as? String, "quiz_question")
        XCTAssertEqual(screen.parameters["theme_source"] as? String, "catalog")
        XCTAssertEqual(screen.parameters["theme_id"] as? String, "music")

        let answer = AnalyticsEvent.quizAnswered(
            theme: .catalog(id: "music"),
            questionIndex: 2,
            totalQuestions: 5,
            outcome: .incorrect
        )
        XCTAssertEqual(answer.name, "quiz_answered")
        XCTAssertEqual(answer.parameters["question_index"] as? Int, 2)
        XCTAssertEqual(answer.parameters["total_questions"] as? Int, 5)
        XCTAssertEqual(answer.parameters["outcome"] as? String, "incorrect")

        let completed = AnalyticsEvent.quizCompleted(theme: .catalog(id: "music"), correctAnswers: 4, totalQuestions: 5)
        XCTAssertEqual(completed.parameters["score_percent"] as? Int, 80)
    }

    func testThemeCardFlipUsesVisibleFaceAndPrivacySafeThemeContext() {
        let flippedToBack = AnalyticsEvent.themeCardFlipped(
            theme: .catalog(id: "music"),
            visibleFace: .back
        )
        XCTAssertEqual(flippedToBack.name, "theme_card_flipped")
        XCTAssertEqual(flippedToBack.parameters["visible_face"] as? String, "back")
        XCTAssertEqual(flippedToBack.parameters["theme_source"] as? String, "catalog")
        XCTAssertEqual(flippedToBack.parameters["theme_id"] as? String, "music")

        let flippedToFront = AnalyticsEvent.themeCardFlipped(
            theme: .catalog(id: "culture"),
            visibleFace: .front
        )
        XCTAssertEqual(flippedToFront.parameters["visible_face"] as? String, "front")
        XCTAssertEqual(flippedToFront.parameters["theme_source"] as? String, "catalog")
        XCTAssertEqual(flippedToFront.parameters["theme_id"] as? String, "culture")

        let aiFlip = AnalyticsEvent.themeCardFlipped(theme: .ai, visibleFace: .back)
        XCTAssertEqual(aiFlip.parameters["theme_source"] as? String, "ai")
        XCTAssertNil(aiFlip.parameters["theme_id"])
        XCTAssertNil(aiFlip.parameters["theme_name"])
        XCTAssertNil(aiFlip.parameters["description"])
    }

    func testAIEventsNeverExposePromptOrGeneratedThemeIdentifier() {
        let selected = AnalyticsEvent.themeSelected(theme: .ai, method: .ai)
        XCTAssertEqual(selected.parameters["theme_source"] as? String, "ai")
        XCTAssertNil(selected.parameters["theme_id"])

        let started = AnalyticsEvent.aiGenerationStarted(
            locale: "ru_RU",
            promptLength: 42,
            questionCount: 10,
            difficulty: .hard
        )
        XCTAssertEqual(started.name, "ai_generation_started")
        XCTAssertEqual(started.parameters["locale"] as? String, "ru_RU")
        XCTAssertEqual(started.parameters["prompt_length"] as? Int, 42)
        XCTAssertEqual(started.parameters["question_count"] as? Int, 10)
        XCTAssertEqual(started.parameters["difficulty"] as? String, "hard")
        XCTAssertNil(started.parameters["prompt"])
        XCTAssertFalse(started.parameters.values.contains { ($0 as? String) == "private prompt" })
    }

    func testSettingsAndStatisticsParametersAreNormalized() {
        let setting = AnalyticsEvent.settingChanged(setting: .language, oldValue: "system", newValue: "ru")
        XCTAssertEqual(setting.name, "setting_changed")
        XCTAssertEqual(setting.parameters["setting"] as? String, "language")
        XCTAssertEqual(setting.parameters["old_value"] as? String, "system")
        XCTAssertEqual(setting.parameters["new_value"] as? String, "ru")

        let statistics = AnalyticsEvent.statisticsViewed(attemptsCount: -1, totalQuestions: -5, accuracyPercent: 150)
        XCTAssertEqual(statistics.parameters["attempts_count"] as? Int, 0)
        XCTAssertEqual(statistics.parameters["total_questions"] as? Int, 0)
        XCTAssertEqual(statistics.parameters["accuracy_percent"] as? Int, 100)
    }

    func testBackendLatencyEventUsesOnlyNormalizedOperationalValues() {
        let event = AnalyticsEvent.backendRequestCompleted(
            BackendRequestMetric(
                operation: .statisticsSync,
                result: .contractError,
                durationMilliseconds: 125,
                statusCode: 422,
                responseBytes: 512
            )
        )

        XCTAssertEqual(event.name, "backend_request_completed")
        XCTAssertEqual(event.parameters["operation"] as? String, "statistics_sync")
        XCTAssertEqual(event.parameters["result"] as? String, "contract_error")
        XCTAssertEqual(event.parameters["duration_ms"] as? Int, 125)
        XCTAssertEqual(event.parameters["response_bytes"] as? Int, 512)
        XCTAssertEqual(event.parameters["status_class"] as? String, "4xx")
        XCTAssertNil(event.parameters["url"])
        XCTAssertNil(event.parameters["request_id"])
    }

    func testEventTaxonomyUsesTheDocumentedNames() {
        let progress = AnalyticsQuizProgress(theme: .catalog(id: "music"), answeredQuestions: 2, totalQuestions: 5, correctAnswers: 1)
        let events: [AnalyticsEvent] = [
            .screenView(screen: .home),
            .themeSelected(theme: .catalog(id: "music"), method: .manual),
            .themeCardFlipped(theme: .catalog(id: "music"), visibleFace: .back),
            .quizSetupCancelled(theme: .catalog(id: "music")),
            .quizStarted(theme: .catalog(id: "music"), questionCount: 5),
            .quizAnswered(theme: .catalog(id: "music"), questionIndex: 1, totalQuestions: 5, outcome: .correct),
            .quizExitRequested(progress),
            .quizExitCancelled(progress),
            .quizAbandoned(progress),
            .quizCompleted(theme: .catalog(id: "music"), correctAnswers: 4, totalQuestions: 5),
            .quizResultAction(theme: .catalog(id: "music"), action: .replay),
            .statisticsViewed(attemptsCount: 1, totalQuestions: 5, accuracyPercent: 80),
            .aiGenerationStarted(locale: "en", promptLength: 10, questionCount: 5, difficulty: .medium),
            .aiGenerationSucceeded(locale: "en", questionCount: 5, difficulty: .medium, durationMilliseconds: 100),
            .aiGenerationFailed(locale: "en", errorCode: "network", durationMilliseconds: 100),
            .aiGenerationCancelled(locale: "en", durationMilliseconds: 100),
            .backendRequestCompleted(
                BackendRequestMetric(
                    operation: .themes,
                    result: .success,
                    durationMilliseconds: 100,
                    statusCode: 200,
                    responseBytes: 100
                )
            ),
            .settingChanged(setting: .language, oldValue: "system", newValue: "en"),
            .settingsAction(.feedback)
        ]

        XCTAssertEqual(events.map(\.name), [
            "screen_view", "theme_selected", "theme_card_flipped", "quiz_setup_cancelled",
            "quiz_started", "quiz_answered", "quiz_exit_requested", "quiz_exit_cancelled",
            "quiz_abandoned", "quiz_completed", "quiz_result_action", "statistics_viewed",
            "ai_generation_started", "ai_generation_succeeded", "ai_generation_failed",
            "ai_generation_cancelled", "backend_request_completed", "setting_changed",
            "settings_action"
        ])
    }

    func testAPIKeyValidationRejectsMissingAndPlaceholderValues() {
        XCTAssertNil(AppMetricaAnalyticsTracker.validAPIKey(from: nil))
        XCTAssertNil(AppMetricaAnalyticsTracker.validAPIKey(from: ""))
        XCTAssertNil(AppMetricaAnalyticsTracker.validAPIKey(from: "  YOUR_APPMETRICA_API_KEY "))
        XCTAssertNil(AppMetricaAnalyticsTracker.validAPIKey(from: "$(APPMETRICA_API_KEY)"))
        XCTAssertEqual(AppMetricaAnalyticsTracker.validAPIKey(from: " valid-key "), "valid-key")
    }

    func testActivationSkipsTestsPreviewsAndSmokeHost() {
        XCTAssertTrue(AppMetricaAnalyticsTracker.shouldSkipActivation(environment: [:], isXCTestRuntime: true))
        XCTAssertTrue(AppMetricaAnalyticsTracker.shouldSkipActivation(
            environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"],
            isXCTestRuntime: false
        ))
        XCTAssertTrue(AppMetricaAnalyticsTracker.shouldSkipActivation(
            environment: ["QUIZICE_XCTEST_SMOKE_HOST": "1"],
            isXCTestRuntime: false
        ))
        XCTAssertFalse(AppMetricaAnalyticsTracker.shouldSkipActivation(environment: [:], isXCTestRuntime: false))
    }

    func testPresenterTracksCorrectAnswerAndCompletesOnlyOnce() throws {
        let analytics = AnalyticsTrackerSpy()
        let session = makeSession(themeID: "culture")
        let view = AnalyticsQuestionViewSpy()
        let presenter = QuizQuestionPresenter(
            session: session,
            statisticsStore: makeStatisticsStore(),
            analytics: analytics
        )
        presenter.view = view
        presenter.loadQuestions()
        presenter.loadQuestion()

        let question = try XCTUnwrap(view.loadedQuestion)
        let correct = try XCTUnwrap(question.answers.first { $0.title == "A" })
        presenter.checkAnswer(optionID: correct.id)
        presenter.timeExpired()
        presenter.checkQuestionNumberAndProceed()
        presenter.checkQuestionNumberAndProceed()

        XCTAssertEqual(analytics.events.map(\.name).filter { $0 == "quiz_answered" }.count, 1)
        XCTAssertEqual(analytics.events.map(\.name).filter { $0 == "quiz_completed" }.count, 1)
        XCTAssertEqual(analytics.events.first?.parameters["outcome"] as? String, "correct")
    }

    func testPresenterTracksTimeoutAsAnAnswer() {
        let analytics = AnalyticsTrackerSpy()
        let presenter = QuizQuestionPresenter(
            session: makeSession(themeID: "timer"),
            statisticsStore: makeStatisticsStore(),
            analytics: analytics
        )
        let view = AnalyticsQuestionViewSpy()
        presenter.view = view
        presenter.loadQuestions()
        presenter.loadQuestion()

        presenter.timeExpired()

        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events[0].name, "quiz_answered")
        XCTAssertEqual(analytics.events[0].parameters["outcome"] as? String, "timeout")
    }

    func testPresenterTracksWrongAnswerWithoutExposingAnswerText() throws {
        let analytics = AnalyticsTrackerSpy()
        let view = AnalyticsQuestionViewSpy()
        let presenter = QuizQuestionPresenter(
            session: makeSession(themeID: "politics"),
            statisticsStore: makeStatisticsStore(),
            analytics: analytics
        )
        presenter.view = view
        presenter.loadQuestions()
        presenter.loadQuestion()

        let question = try XCTUnwrap(view.loadedQuestion)
        let wrong = try XCTUnwrap(question.answers.first { $0.title != "A" })
        presenter.checkAnswer(optionID: wrong.id)

        XCTAssertEqual(analytics.events.count, 1)
        XCTAssertEqual(analytics.events[0].parameters["outcome"] as? String, "incorrect")
        XCTAssertNil(analytics.events[0].parameters["answer"])
        XCTAssertFalse(analytics.events[0].parameters.values.contains { ($0 as? String) == wrong.title })
    }

    private func makeSession(themeID: String) -> AnalyticsTestSession {
        let question = QuizQuestion(
            question: "Question text must not reach analytics",
            answers: ["A", "B", "C", "D"],
            correctAnswer: "A"
        )
        let theme = QuizTheme(
            id: themeID,
            theme: "Private localized theme name",
            themeDescription: "Private localized description",
            questions: [question]
        )
        let session = AnalyticsTestSession()
        session.chosenTheme = ThemeModel(quizTheme: theme)
        session.questionsCount = 1
        return session
    }

    private func makeStatisticsStore() -> StatisticsStore {
        let suiteName = "AnalyticsServiceTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return StatisticsStore(userDefaults: defaults, key: "attempts")
    }
}

private final class AnalyticsTrackerSpy: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {}
}

private final class AnalyticsTestSession: QuizSessionManaging {
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount = 1
    var startup1st = false

    func loadTheme(themeID: String) -> Bool { false }
}

private final class AnalyticsQuestionViewSpy: QuizQuestionViewControllerProtocol {
    var presenter: QuizQuestionPresenterProtocol?
    private(set) var loadedQuestion: QuizQuestionViewModel?

    func updateProgress(_ progress: Float) {}
    func showTimeExpired() {}
    func loadQuestionToView(_ viewModel: QuizQuestionViewModel) { loadedQuestion = viewModel }
    func showQuestionUnavailable(themeName: String?, message: String) {}
    func correctAnswerTapped(isTrue: Bool) {}
    func showResults(_ result: QuizResultState) {}
}
