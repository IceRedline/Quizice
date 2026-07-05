import XCTest
@testable import Quizice

@MainActor
final class QuizQuestionPresenterTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        suiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testLoadQuestionsClampsRequestedCountToUsableQuestionCount() {
        let session = QuestionPresenterSession()
        session.questionsCount = 99
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "tech",
            name: "Tech",
            questions: [
                makeQuestion("One?", correctAnswer: "A"),
                makeQuestion("Two?", correctAnswer: "B")
            ]
        ))
        let presenter = QuizQuestionPresenter(session: session, statisticsStore: makeStatisticsHarness().store)

        presenter.loadQuestions()

        XCTAssertEqual(presenter.questionsTotalCount, 2)
        XCTAssertEqual(presenter.chosenThemeQuestionsArray.count, 2)
    }

    func testLoadQuestionBuildsViewModelAndStableAnswerFeedback() throws {
        let session = QuestionPresenterSession()
        session.questionsCount = 1
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "music",
            name: "Music",
            questions: [makeQuestion("Which answer is correct?", correctAnswer: "C")]
        ))
        let view = QuestionPresenterViewSpy()
        let presenter = QuizQuestionPresenter(session: session, statisticsStore: makeStatisticsHarness().store)
        presenter.view = view

        presenter.loadQuestions()
        presenter.loadQuestion()

        let viewModel = try XCTUnwrap(view.loadedViewModels.first)
        let correctOption = try XCTUnwrap(viewModel.answers.first { $0.title == "C" })
        let wrongOption = try XCTUnwrap(viewModel.answers.first { $0.title != "C" })

        XCTAssertEqual(viewModel.themeName, "Music")
        XCTAssertEqual(viewModel.questionText, "Which answer is correct?")
        XCTAssertEqual(viewModel.questionNumberText, L10n.Question.number(1))
        XCTAssertEqual(viewModel.answers.count, 4)
        XCTAssertEqual(presenter.answerFeedback(for: correctOption.id), .correct)
        XCTAssertEqual(presenter.answerFeedback(for: wrongOption.id), .wrong)
    }

    func testCorrectAnswerRecordsSingleCompletedAttemptAndEmitsResult() throws {
        let harness = makeStatisticsHarness()
        let session = QuestionPresenterSession()
        session.questionsCount = 1
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "culture",
            name: "Culture",
            questions: [makeQuestion("Question?", correctAnswer: "D")]
        ))
        let view = QuestionPresenterViewSpy()
        let presenter = QuizQuestionPresenter(session: session, statisticsStore: harness.store)
        presenter.view = view

        presenter.loadQuestions()
        presenter.loadQuestion()
        let loadedQuestion = try XCTUnwrap(view.loadedViewModels.first)
        let correctOption = try XCTUnwrap(loadedQuestion.answers.first { $0.title == "D" })

        presenter.checkAnswer(optionID: correctOption.id)
        presenter.checkQuestionNumberAndProceed()
        presenter.checkQuestionNumberAndProceed()

        XCTAssertEqual(view.answerStateUpdates, [true])
        XCTAssertEqual(view.results, [
            QuizResultState(correctAnswers: 1, totalQuestions: 1),
            QuizResultState(correctAnswers: 1, totalQuestions: 1)
        ])
        XCTAssertEqual(harness.store.loadSummary().playedQuizzes, 1)
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 1)
    }

    func testWrongAnswerAndTimeExpiredProgressToResultWithoutCorrectCredit() throws {
        let harness = makeStatisticsHarness()
        let session = QuestionPresenterSession()
        session.questionsCount = 1
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "politics",
            name: "Politics",
            questions: [makeQuestion("Question?", correctAnswer: "A")]
        ))
        let view = QuestionPresenterViewSpy()
        let presenter = QuizQuestionPresenter(session: session, statisticsStore: harness.store)
        presenter.view = view

        presenter.loadQuestions()
        presenter.loadQuestion()
        let loadedQuestion = try XCTUnwrap(view.loadedViewModels.first)
        let wrongOption = try XCTUnwrap(loadedQuestion.answers.first { $0.title != "A" })

        presenter.checkAnswer(optionID: wrongOption.id)
        presenter.checkQuestionNumberAndProceed()

        XCTAssertEqual(view.answerStateUpdates, [false])
        XCTAssertEqual(view.results, [QuizResultState(correctAnswers: 0, totalQuestions: 1)])
        XCTAssertEqual(harness.store.loadSummary().playedQuizzes, 1)
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 0)
    }

    func testResetGameProgressClearsTransientState() {
        let presenter = QuizQuestionPresenter(
            session: QuestionPresenterSession(),
            statisticsStore: makeStatisticsHarness().store
        )
        presenter.chosenThemeQuestionsArray = [QuestionModel(quizQuestion: makeQuestion("Question?", correctAnswer: "A"))]
        presenter.currentQuestionIndex = 3
        presenter.correctAnswers = 2
        presenter.currentProgress = 0.8

        presenter.resetGameProgress()

        XCTAssertTrue(presenter.chosenThemeQuestionsArray.isEmpty)
        XCTAssertNil(presenter.currentQuestion)
        XCTAssertEqual(presenter.questionsTotalCount, 0)
        XCTAssertEqual(presenter.currentQuestionIndex, 0)
        XCTAssertEqual(presenter.correctAnswers, 0)
        XCTAssertEqual(presenter.currentProgress, 0.2)
    }

    private func makeQuestion(_ text: String, correctAnswer: String) -> QuizQuestion {
        QuizQuestion(question: text, answers: ["A", "B", "C", "D"], correctAnswer: correctAnswer)
    }

    private func makeStatisticsHarness() -> (store: StatisticsStore, defaults: UserDefaults) {
        let suiteName = "QuizQuestionPresenterTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (StatisticsStore(userDefaults: defaults, key: "attempts"), defaults)
    }
}

private final class QuestionPresenterSession: QuizSessionManaging {
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

private final class QuestionPresenterViewSpy: QuizQuestionViewControllerProtocol {
    var presenter: QuizQuestionPresenterProtocol?
    private(set) var progressUpdates: [Float] = []
    private(set) var loadedViewModels: [QuizQuestionViewModel] = []
    private(set) var unavailableMessages: [(String?, String)] = []
    private(set) var answerStateUpdates: [Bool] = []
    private(set) var results: [QuizResultState] = []
    private(set) var timeExpiredCallCount = 0

    func updateProgress(_ progress: Float) {
        progressUpdates.append(progress)
    }

    func showTimeExpired() {
        timeExpiredCallCount += 1
    }

    func loadQuestionToView(_ viewModel: QuizQuestionViewModel) {
        loadedViewModels.append(viewModel)
    }

    func showQuestionUnavailable(themeName: String?, message: String) {
        unavailableMessages.append((themeName, message))
    }

    func correctAnswerTapped(isTrue: Bool) {
        answerStateUpdates.append(isTrue)
    }

    func showResults(_ result: QuizResultState) {
        results.append(result)
    }
}
