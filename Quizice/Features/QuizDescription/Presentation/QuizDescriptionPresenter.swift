import Foundation

final class QuizDescriptionPresenter: QuizDescriptionPresenterProtocol {
    private let session: QuizSessionManaging

    weak var view: QuizDescriptionViewControllerProtocol?

    var themeName: String = L10n.Description.defaultThemeName
    var themeDescription: String = L10n.Description.defaultThemeDescription
    var themeID: String? {
        session.chosenTheme?.themeID
    }
    var analyticsTheme: AnalyticsTheme {
        session.chosenTheme?.analyticsTheme ?? .unknown
    }
    var selectedQuestionCount: Int { session.questionsCount }
    var selectedQuestionCountRow: Int? {
        numberOfQuestionsOptions.firstIndex(of: selectedQuestionCount)
    }
    var isQuestionCountSelectionEnabled: Bool {
        !(session.chosenTheme?.isAIGenerated ?? false)
    }
    
    init(session: QuizSessionManaging = QuizSessionStore.shared, content: QuizDescriptionContent? = nil) {
        self.session = session
        if let content {
            self.themeName = content.themeName
            self.themeDescription = content.themeDescription
        }
    }
    
    func viewDidLoad() {
        getLabelsText()
    }
    
    var numberOfQuestionsOptionCount: Int {
        numberOfQuestionsOptions.count
    }

    func numberOfQuestionsTitle(at row: Int) -> String? {
        let options = numberOfQuestionsOptions
        guard options.indices.contains(row) else { return nil }
        return String(options[row])
    }
    
    func getLabelsText() {
        view?.updateLabels(themeName: themeName, themeDescription: themeDescription)
    }
    
    func saveNumberOfQuestions(chosenRow: Int) {
        let options = numberOfQuestionsOptions
        guard options.indices.contains(chosenRow) else { return }
        session.questionsCount = options[chosenRow]
    }

    private var numberOfQuestionsOptions: [Int] {
        guard let chosenTheme = session.chosenTheme else {
            return QuizQuestionCountPolicy.supportedCounts
        }

        return QuizQuestionCountPolicy.availableCounts(for: chosenTheme.questionsAndAnswers)
    }
}
