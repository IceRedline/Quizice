import Foundation

enum QuizPreparationError: Error, Equatable {
    case unavailable
}

enum QuizCatalogOrigin: String, Equatable {
    case bundled
    case backend
}

enum CrossThemeQuestionSelectionMode: String, CaseIterable, Equatable {
    case random
    case randomBalanced = "random_balanced"
}

protocol ThemeRepository: AnyObject {
    var themes: [QuizTheme]? { get }
    var catalogOrigin: QuizCatalogOrigin { get }
    func loadData(forceReload: Bool)
    func fetchQuizThemes() -> [QuizTheme]
    @discardableResult
    func refreshBackendCatalog(locale: String) async -> Bool
    func prepareQuiz(themeID: String, questionCount: Int, locale: String) async throws -> QuizTheme
    func prepareRandomQuiz(
        selectionMode: CrossThemeQuestionSelectionMode,
        localFallback: QuizTheme,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme
}

extension ThemeRepository {
    var catalogOrigin: QuizCatalogOrigin { .bundled }

    @discardableResult
    func refreshBackendCatalog(locale: String) async -> Bool { false }

    func prepareQuiz(
        themeID: String,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        let catalog = themes ?? fetchQuizThemes()
        guard
            QuizQuestionCountPolicy.supportedCounts.contains(questionCount),
            let theme = catalog.first(where: { $0.stableID == themeID })
        else {
            throw QuizPreparationError.unavailable
        }

        let questions = theme.questions.filter {
            QuizQuestionCountPolicy.isUsable(QuestionModel(quizQuestion: $0))
        }
        guard questions.count >= questionCount else {
            throw QuizPreparationError.unavailable
        }

        return QuizTheme(
            id: theme.id,
            theme: theme.theme,
            themeDescription: theme.themeDescription,
            questions: Array(questions.shuffled().prefix(questionCount)),
            sfSymbolName: theme.sfSymbolName,
            source: theme.source,
            questionOrigin: theme.questionOrigin
        )
    }

    func prepareRandomQuiz(
        selectionMode: CrossThemeQuestionSelectionMode,
        localFallback: QuizTheme,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        localFallback
    }
}
