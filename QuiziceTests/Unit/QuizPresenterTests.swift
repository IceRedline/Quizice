import XCTest
@testable import Quizice

@MainActor
final class QuizPresenterTests: XCTestCase {
    override func tearDown() {
        resetSharedQuizFactoryForTests()
        super.tearDown()
    }

    func testDescriptionContentUsesChosenTheme() {
        let session = QuizPresenterSession()
        let theme = SnapshotSupport.makeTheme(
            id: "music",
            name: "Music",
            description: "Music questions"
        )
        session.chosenTheme = ThemeModel(quizTheme: theme)
        let presenter = QuizPresenter(session: session)

        XCTAssertEqual(
            presenter.descriptionContent(),
            QuizDescriptionContent(themeName: "Music", themeDescription: "Music questions")
        )
    }

    func testDescriptionContentFallsBackWhenThemeIsMissing() {
        let presenter = QuizPresenter(session: QuizPresenterSession())

        XCTAssertEqual(
            presenter.descriptionContent(),
            QuizDescriptionContent(
                themeName: L10n.Description.defaultThemeName,
                themeDescription: L10n.Description.defaultThemeDescription
            )
        )
    }

    func testDescriptionPresenterExposesQuestionCountOptionsAndUpdatesSession() {
        let session = QuizPresenterSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "technology",
            name: "Tech",
            questions: makeQuestions(count: 15)
        ))
        let view = QuizDescriptionViewSpy()
        let presenter = QuizDescriptionPresenter(
            session: session,
            content: QuizDescriptionContent(themeName: "Tech", themeDescription: "Tech questions")
        )
        presenter.view = view

        presenter.viewDidLoad()
        presenter.saveNumberOfQuestions(chosenRow: 1)
        presenter.saveNumberOfQuestions(chosenRow: 99)

        XCTAssertEqual(view.updates, [.init(themeName: "Tech", themeDescription: "Tech questions")])
        XCTAssertEqual(presenter.numberOfQuestionsOptionCount, 3)
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 0), "5")
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 1), "10")
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 2), "15")
        XCTAssertNil(presenter.numberOfQuestionsTitle(at: -1))
        XCTAssertNil(presenter.numberOfQuestionsTitle(at: 3))
        XCTAssertEqual(session.questionsCount, 10)
    }

    func testDescriptionPresenterExposesOnlyFiveForThemeWithFiveUsableQuestions() {
        let session = QuizPresenterSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "ai-generated",
            name: "Generated",
            questions: makeQuestions(count: 5)
        ))
        session.questionsCount = 10
        let presenter = QuizDescriptionPresenter(session: session)

        XCTAssertEqual(presenter.numberOfQuestionsOptionCount, 1)
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 0), "5")
        XCTAssertNil(presenter.numberOfQuestionsTitle(at: 1))

        presenter.saveNumberOfQuestions(chosenRow: 0)

        XCTAssertEqual(session.questionsCount, 5)
    }

    func testAIGeneratedThemeLocksTheGeneratedQuestionCount() {
        let session = QuizPresenterSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "ai-generated",
            name: "Generated",
            questions: makeQuestions(count: 10)
        ))
        session.questionsCount = 10

        let presenter = QuizDescriptionPresenter(session: session)

        XCTAssertFalse(presenter.isQuestionCountSelectionEnabled)
        XCTAssertEqual(presenter.selectedQuestionCountRow, 1)
        XCTAssertEqual(presenter.selectedQuestionCount, 10)
    }

    func testCatalogThemeKeepsQuestionCountSelectionEnabled() {
        let session = QuizPresenterSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "technology",
            name: "Technology",
            questions: makeQuestions(count: 15)
        ))
        session.questionsCount = 5

        let presenter = QuizDescriptionPresenter(session: session)

        XCTAssertTrue(presenter.isQuestionCountSelectionEnabled)
        XCTAssertEqual(presenter.selectedQuestionCountRow, 0)
    }

    func testDescriptionPresenterCountsOnlyUsableQuestions() {
        let session = QuizPresenterSession()
        let unusableQuestion = QuizQuestion(
            question: "   ",
            answers: ["A", "B", "C", "D"],
            correctAnswer: "A"
        )
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "partially-invalid",
            name: "Partially invalid",
            questions: makeQuestions(count: 9) + [unusableQuestion]
        ))
        let presenter = QuizDescriptionPresenter(session: session)

        XCTAssertEqual(presenter.numberOfQuestionsOptionCount, 1)
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 0), "5")
        XCTAssertNil(presenter.numberOfQuestionsTitle(at: 1))
    }

    func testDescriptionPresenterHasNoOptionsWhenThemeHasFewerThanFiveUsableQuestions() {
        let session = QuizPresenterSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(
            id: "short",
            name: "Short",
            questions: makeQuestions(count: 4)
        ))
        session.questionsCount = 10
        let presenter = QuizDescriptionPresenter(session: session)

        XCTAssertEqual(presenter.numberOfQuestionsOptionCount, 0)
        XCTAssertNil(presenter.numberOfQuestionsTitle(at: 0))

        presenter.saveNumberOfQuestions(chosenRow: 0)

        XCTAssertEqual(session.questionsCount, 10)
    }

    func testDescriptionPresenterKeepsLegacyOptionsWhenThemeIsMissing() {
        let presenter = QuizDescriptionPresenter(session: QuizPresenterSession())

        XCTAssertEqual(presenter.numberOfQuestionsOptionCount, 3)
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 0), "5")
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 1), "10")
        XCTAssertEqual(presenter.numberOfQuestionsTitle(at: 2), "15")
    }

    private func makeQuestions(count: Int) -> [QuizQuestion] {
        (0..<count).map { index in
            QuizQuestion(
                question: "Question \(index)?",
                answers: ["A", "B", "C", "D"],
                correctAnswer: "A"
            )
        }
    }
}

private final class QuizPresenterSession: QuizSessionManaging {
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

private final class QuizDescriptionViewSpy: QuizDescriptionViewControllerProtocol {
    struct Update: Equatable {
        let themeName: String
        let themeDescription: String
    }

    var presenter: QuizDescriptionPresenterProtocol?
    private(set) var updates: [Update] = []

    func updateLabels(themeName: String, themeDescription: String) {
        updates.append(Update(themeName: themeName, themeDescription: themeDescription))
    }

    func configurePresenter(_ presenter: any QuizDescriptionPresenterProtocol) {
        self.presenter = presenter
    }
}
