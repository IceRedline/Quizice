protocol ThemeRepository: AnyObject {
    var themes: [QuizTheme]? { get }
    func loadData(forceReload: Bool)
    func fetchQuizThemes() -> [QuizTheme]
}
