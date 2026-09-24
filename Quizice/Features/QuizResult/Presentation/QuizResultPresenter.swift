import Foundation

final class QuizResultPresenter: QuizResultPresenterProtocol {
    private let session: QuizSessionManaging
    private let descriptionText: String

    weak var view: QuizResultViewControllerProtocol?
    
    var correctAnswers: Int = 0
    var totalQuestions: Int = 0
    private(set) var resultAnnouncement: String = ""
    var themeID: String? {
        session.chosenTheme?.themeID
    }
    var analyticsTheme: AnalyticsTheme {
        session.chosenTheme?.analyticsTheme ?? .unknown
    }
    
    init(
        result: QuizResultState = QuizResultState(correctAnswers: 0, totalQuestions: 0),
        session: QuizSessionManaging,
        messages: ResultMessageProviding = ResultMessagesRepository.shared,
        locale: String = AppLocalizationStore.shared.resolvedLanguageCode
    ) {
        self.session = session
        self.correctAnswers = result.correctAnswers
        self.totalQuestions = result.totalQuestions
        let category = ResultMessageCategory.resolve(
            correctAnswers: result.correctAnswers, totalQuestions: result.totalQuestions
        )
        descriptionText = messages.message(for: category, locale: locale) ?? Self.fallback(for: category)
    }
    
    func viewDidLoad() {
        getResultText()
    }
    
    func getResultText() {
        let normalizedCorrectAnswers = max(correctAnswers, 0)
        let normalizedTotalQuestions = max(totalQuestions, 0)
        let isPerfectScore = normalizedTotalQuestions > 0
            && normalizedCorrectAnswers == normalizedTotalQuestions
        let resultText = L10n.Result.text(correctAnswers: normalizedCorrectAnswers, totalQuestions: normalizedTotalQuestions)
        resultAnnouncement = L10n.Result.announcement(
            correctAnswers: normalizedCorrectAnswers,
            totalQuestions: normalizedTotalQuestions
        )
        view?.updateResultLabels(resultText: resultText, descriptionText: descriptionText)
        view?.setPerfectScoreEffectVisible(isPerfectScore)
    }

    private static func fallback(for category: ResultMessageCategory) -> String {
        switch category {
        case .veryLowScore: L10n.Result.veryLowScoreDescription
        case .lowScore: L10n.Result.lowScoreDescription
        case .mediumLowScore: L10n.Result.mediumLowScoreDescription
        case .mediumScore: L10n.Result.mediumScoreDescription
        case .highScore: L10n.Result.strongResultDescription
        case .perfectScore: L10n.Result.perfectScoreDescription
        case .noQuestions: L10n.Result.noQuestionsDescription
        case .invalidScore: L10n.Result.invalidScoreDescription
        }
    }
}
