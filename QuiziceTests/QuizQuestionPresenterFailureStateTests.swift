import XCTest
@testable import Quizice

final class QuizQuestionPresenterFailureStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetQuizFactory()
    }

    override func tearDown() {
        resetQuizFactory()
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
        QuizFactory.shared.themes = [theme]
        QuizFactory.shared.chosenTheme = ThemeModel(quizTheme: theme)

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
        QuizFactory.shared.themes = [theme]
        QuizFactory.shared.chosenTheme = ThemeModel(quizTheme: theme)
        QuizFactory.shared.questionsCount = 1

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
        let presenter = QuizQuestionPresenter()
        let view = QuizQuestionViewControllerSpy()
        presenter.view = view
        view.presenter = presenter
        return (presenter, view)
    }

    private func makeTheme(name: String, questions: [QuizQuestion]) -> QuizTheme {
        QuizTheme(theme: name, themeDescription: "Synthetic test theme", questions: questions)
    }

    private func makeQuestion(
        question: String,
        answers: [String],
        correctAnswer: String
    ) -> QuizQuestion {
        QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer,
            explanation: "Synthetic explanation"
        )
    }

    private func resetQuizFactory() {
        QuizFactory.shared.themes = nil
        QuizFactory.shared.chosenTheme = nil
        QuizFactory.shared.questionsCount = 5
    }
}

private final class QuizQuestionViewControllerSpy: QuizQuestionViewControllerProtocol {
    var presenter: QuizQuestionPresenterProtocol?

    private(set) var progressUpdates: [Float] = []
    private(set) var timeExpiredCallCount = 0
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

    func loadQuestionToView(
        themeName: String,
        questionText: String,
        questionNumberText: String,
        currentAnswers: [String]
    ) {
        loadedQuestions.append(
            LoadedQuestion(
                themeName: themeName,
                questionText: questionText,
                questionNumberText: questionNumberText,
                currentAnswers: currentAnswers
            )
        )
    }

    func showQuestionUnavailable(themeName: String?, message: String) {
        unavailableCalls.append(UnavailableQuestion(themeName: themeName, message: message))
    }

    func correctAnswerTapped(isTrue: Bool) {
        answerStateUpdates.append(isTrue)
    }

    func showResults() {
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
