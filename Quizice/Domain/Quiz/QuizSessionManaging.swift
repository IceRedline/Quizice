protocol QuizSessionManaging: AnyObject {
    var chosenTheme: ThemeModel? { get set }
    var questionsCount: Int { get set }
    var startup1st: Bool { get set }

    @discardableResult
    func loadTheme(themeID: String) -> Bool
}
