import Dispatch

// QuizSessionStore holds transient quiz selection state shared across the
// Home flow, coordinator replay tasks, and quiz presenters. Every legitimate
// caller runs on the main queue: navigation, UIKit lifecycle, and the
// coordinator's `Task { @MainActor ... }` replay blocks. The precondition
// checks below make that contract explicit so a future contributor cannot
// accidentally introduce a background-thread caller and start racing with
// the UI.
final class QuizSessionStore: QuizSessionManaging {
    static let shared = QuizSessionStore()

    private let themes: () -> [QuizTheme]?

    private var _chosenTheme: ThemeModel?
    private var _questionsCount = 5
    private var _startup1st = true

    var chosenTheme: ThemeModel? {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _chosenTheme
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            _chosenTheme = newValue
        }
    }

    var questionsCount: Int {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _questionsCount
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            _questionsCount = newValue
        }
    }

    var startup1st: Bool {
        get {
            dispatchPrecondition(condition: .onQueue(.main))
            return _startup1st
        }
        set {
            dispatchPrecondition(condition: .onQueue(.main))
            _startup1st = newValue
        }
    }

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
        dispatchPrecondition(condition: .onQueue(.main))
        guard let theme = themes()?.first(where: predicate) else {
            AppLog.content.error("Failed to resolve selected theme")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(
                AnalyticsOperationalIssue.themeResolution,
                context: .themeResolution
            )
            return false
        }
        _chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}
