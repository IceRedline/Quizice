final class QuizSessionStore: QuizSessionManaging {
    static let shared = QuizSessionStore()

    private let themes: () -> [QuizTheme]?

    var chosenTheme: ThemeModel?
    var questionsCount = 5
    var startup1st = true

    init(themes: @escaping () -> [QuizTheme]? = { ThemeCatalogRepository.shared.themes }) {
        self.themes = themes
    }

    @discardableResult
    func loadTheme(themeID: String) -> Bool {
        resolveTheme { $0.stableID == themeID }
    }

    @discardableResult
    func loadTheme(themeName: String) -> Bool {
        resolveTheme { $0.theme == themeName || $0.stableID == themeName }
    }

    private func resolveTheme(where predicate: (QuizTheme) -> Bool) -> Bool {
        guard let theme = themes()?.first(where: predicate) else {
            AppLog.content.error("Failed to resolve selected theme")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(
                AnalyticsOperationalIssue.themeResolution,
                context: .themeResolution
            )
            return false
        }
        chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}
