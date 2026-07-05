import XCTest
@testable import Quizice

final class QuizQuestionPresenterFailureStateTests: XCTestCase {
    private var session: QuizSessionSpy!

    override func setUp() {
        super.setUp()
        session = QuizSessionSpy()
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    func testNilChosenThemeShowsUnavailableQuestionState() {
        let (presenter, view) = makePresenter()

        presenter.loadQuestions()
        presenter.loadQuestion()

        assertUnavailableState(
            view,
            expectedThemeName: nil,
            file: #filePath,
            line: #line
        )
    }

    func testChosenThemeWithNoQuestionsShowsUnavailableQuestionState() {
        let theme = makeTheme(name: "Empty Theme", questions: [])
        session.themes = [theme]
        session.chosenTheme = ThemeModel(quizTheme: theme)

        let (presenter, view) = makePresenter()

        presenter.loadQuestions()
        presenter.loadQuestion()

        assertUnavailableState(
            view,
            expectedThemeName: "Empty Theme",
            file: #filePath,
            line: #line
        )
    }

    func testQuestionWithEmptyTextShowsUnavailableQuestionState() {
        assertMalformedQuestionShowsUnavailable(
            makeQuestion(question: "   ", answers: ["A", "B", "C", "D"], correctAnswer: "A")
        )
    }

    func testQuestionWithFewerThanFourAnswersShowsUnavailableQuestionState() {
        assertMalformedQuestionShowsUnavailable(
            makeQuestion(question: "Question?", answers: ["A", "B", "C"], correctAnswer: "A")
        )
    }

    func testQuestionWithEmptyCorrectAnswerShowsUnavailableQuestionState() {
        assertMalformedQuestionShowsUnavailable(
            makeQuestion(question: "Question?", answers: ["A", "B", "C", "D"], correctAnswer: "   ")
        )
    }

    private func assertMalformedQuestionShowsUnavailable(
        _ question: QuizQuestion,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let theme = makeTheme(name: "Malformed Theme", questions: [question])
        session.themes = [theme]
        session.chosenTheme = ThemeModel(quizTheme: theme)
        session.questionsCount = 1

        let (presenter, view) = makePresenter()

        presenter.loadQuestions()
        presenter.loadQuestion()

        assertUnavailableState(
            view,
            expectedThemeName: "Malformed Theme",
            file: file,
            line: line
        )
    }

    private func assertUnavailableState(
        _ view: QuizQuestionViewControllerSpy,
        expectedThemeName: String?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(view.unavailableCalls.count, 1, file: file, line: line)
        XCTAssertEqual(view.unavailableCalls.first?.themeName, expectedThemeName, file: file, line: line)
        XCTAssertFalse(view.unavailableCalls.first?.message.isEmpty ?? true, file: file, line: line)
        XCTAssertEqual(view.progressUpdates, [0], file: file, line: line)

        XCTAssertTrue(view.loadedQuestions.isEmpty, file: file, line: line)
        XCTAssertEqual(view.resultsCallCount, 0, file: file, line: line)
        XCTAssertEqual(view.answerStateUpdates.count, 0, file: file, line: line)
        XCTAssertEqual(view.timeExpiredCallCount, 0, file: file, line: line)
    }

    private func makePresenter() -> (QuizQuestionPresenter, QuizQuestionViewControllerSpy) {
        let presenter = QuizQuestionPresenter(session: session)
        let view = QuizQuestionViewControllerSpy()
        presenter.view = view
        view.presenter = presenter
        return (presenter, view)
    }

    private func makeTheme(name: String, questions: [QuizQuestion]) -> QuizTheme {
        QuizTheme(id: name.lowercased().replacingOccurrences(of: " ", with: "_"), theme: name, themeDescription: "Synthetic test theme", questions: questions)
    }

    private func makeQuestion(
        question: String,
        answers: [String],
        correctAnswer: String
    ) -> QuizQuestion {
        QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer
        )
    }

    func testQuestionWithDuplicatedCorrectAnswerShowsUnavailableQuestionState() {
        assertMalformedQuestionShowsUnavailable(
            makeQuestion(question: "Question?", answers: ["A", "A", "B", "C"], correctAnswer: "A")
        )
    }

    func testAnswerSelectionUsesOptionID() throws {
        let question = makeQuestion(question: "Question?", answers: ["A", "B", "C", "D"], correctAnswer: "C")
        let theme = makeTheme(name: "Valid Theme", questions: [question])
        session.themes = [theme]
        session.chosenTheme = ThemeModel(quizTheme: theme)
        session.questionsCount = 1

        let (presenter, view) = makePresenter()
        presenter.loadQuestions()
        presenter.loadQuestion()

        let loadedQuestion = try XCTUnwrap(view.loadedViewModels.first)
        let correctOption = try XCTUnwrap(loadedQuestion.answers.first { $0.title == "C" })
        let wrongOption = try XCTUnwrap(loadedQuestion.answers.first { $0.title != "C" })

        XCTAssertEqual(presenter.answerFeedback(for: correctOption.id), .correct)
        XCTAssertEqual(presenter.answerFeedback(for: wrongOption.id), .wrong)

        presenter.checkAnswer(optionID: correctOption.id)

        XCTAssertEqual(view.answerStateUpdates, [true])
    }
}

private final class QuizQuestionViewControllerSpy: QuizQuestionViewControllerProtocol {
    var presenter: QuizQuestionPresenterProtocol?

    private(set) var progressUpdates: [Float] = []
    private(set) var timeExpiredCallCount = 0
    private(set) var loadedViewModels: [QuizQuestionViewModel] = []
    private(set) var loadedQuestions: [LoadedQuestion] = []
    private(set) var unavailableCalls: [UnavailableQuestion] = []
    private(set) var answerStateUpdates: [Bool] = []
    private(set) var resultsCallCount = 0

    func updateProgress(_ progress: Float) {
        progressUpdates.append(progress)
    }

    func showTimeExpired() {
        timeExpiredCallCount += 1
    }

    func loadQuestionToView(_ viewModel: QuizQuestionViewModel) {
        loadedViewModels.append(viewModel)
        loadedQuestions.append(
            LoadedQuestion(
                themeName: viewModel.themeName,
                questionText: viewModel.questionText,
                questionNumberText: viewModel.questionNumberText,
                currentAnswers: viewModel.answers.map(\.title)
            )
        )
    }

    func showQuestionUnavailable(themeName: String?, message: String) {
        unavailableCalls.append(UnavailableQuestion(themeName: themeName, message: message))
    }

    func correctAnswerTapped(isTrue: Bool) {
        answerStateUpdates.append(isTrue)
    }

    func showResults(_ result: QuizResultState) {
        resultsCallCount += 1
    }

    struct LoadedQuestion: Equatable {
        let themeName: String
        let questionText: String
        let questionNumberText: String
        let currentAnswers: [String]
    }

    struct UnavailableQuestion: Equatable {
        let themeName: String?
        let message: String
    }
}

private final class QuizSessionSpy: QuizSessionManaging {
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount: Int = 5
    var startup1st: Bool = false

    func loadTheme(themeID: String) -> Bool {
        guard let theme = themes?.first(where: { $0.stableID == themeID }) else { return false }
        chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}
