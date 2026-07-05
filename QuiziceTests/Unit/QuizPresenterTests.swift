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
