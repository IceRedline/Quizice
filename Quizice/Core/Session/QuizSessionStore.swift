import Foundation

// QuizSessionStore holds transient quiz selection state shared across the
// Home flow, coordinator replay tasks, and quiz presenters. Reads and writes
// can arrive from the coordinator's async tasks and from UIKit callbacks, so
// every access is guarded by an NSLock. The lock guarantees atomic reads and
// writes of the backing storage even if a future caller ends up on a
// background thread; the previous main-queue precondition was too strict and
// crashed on legitimate concurrent callers.
final class QuizSessionStore: QuizSessionManaging {
    static let shared = QuizSessionStore()

    private let themes: () -> [QuizTheme]?

    private let lock = NSLock()
    private var _chosenTheme: ThemeModel?
    private var _questionsCount = 5
    private var _startup1st = true

    var chosenTheme: ThemeModel? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _chosenTheme
        }
        set {
            lock.lock()
            _chosenTheme = newValue
            lock.unlock()
        }
    }

    var questionsCount: Int {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _questionsCount
        }
        set {
            lock.lock()
            _questionsCount = newValue
            lock.unlock()
        }
    }

    var startup1st: Bool {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _startup1st
        }
        set {
            lock.lock()
            _startup1st = newValue
            lock.unlock()
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
        guard let theme = themes()?.first(where: predicate) else {
            AppLog.content.error("Failed to resolve selected theme")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(
                AnalyticsOperationalIssue.themeResolution,
                context: .themeResolution
            )
            return false
        }
        lock.lock()
        _chosenTheme = ThemeModel(quizTheme: theme)
        lock.unlock()
        return true
    }
}
