import Foundation

typealias QuizFactory = ThemeCatalogRepository

extension ThemeCatalogRepository: QuizSessionManaging {
    var chosenTheme: ThemeModel? {
        get { QuizSessionStore.shared.chosenTheme }
        set { QuizSessionStore.shared.chosenTheme = newValue }
    }

    var questionsCount: Int {
        get { QuizSessionStore.shared.questionsCount }
        set { QuizSessionStore.shared.questionsCount = newValue }
    }

    var startup1st: Bool {
        get { QuizSessionStore.shared.startup1st }
        set { QuizSessionStore.shared.startup1st = newValue }
    }

    @discardableResult
    func loadTheme(themeID: String) -> Bool {
        QuizSessionStore.shared.loadTheme(themeID: themeID)
    }

    @discardableResult
    func loadTheme(themeName: String) -> Bool {
        QuizSessionStore.shared.loadTheme(themeName: themeName)
    }
}
