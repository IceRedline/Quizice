import Foundation
import SwiftData

@Model
private final class StoredQuizQuestion {
    var question: String
    var answers: [String]
    var correctAnswer: String

    init(question: String, answers: [String], correctAnswer: String) {
        self.question = question
        self.answers = answers
        self.correctAnswer = correctAnswer
    }

    convenience init(model: QuizQuestion) {
        self.init(
            question: model.question,
            answers: model.answers,
            correctAnswer: model.correctAnswer
        )
    }

    func makeDomainModel() -> QuizQuestion {
        QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer
        )
    }
}

@Model
private final class StoredQuizTheme {
    @Attribute(.unique) var id: String
    var theme: String
    var themeDescription: String
    var sourceRawValue: String?
    @Relationship(deleteRule: .cascade) var questions: [StoredQuizQuestion]

    init(
        id: String,
        theme: String,
        themeDescription: String,
        sourceRawValue: String?,
        questions: [StoredQuizQuestion]
    ) {
        self.id = id
        self.theme = theme
        self.themeDescription = themeDescription
        self.sourceRawValue = sourceRawValue
        self.questions = questions
    }

    convenience init(model: QuizTheme) {
        self.init(
            id: model.id,
            theme: model.theme,
            themeDescription: model.themeDescription,
            sourceRawValue: model.source.rawValue,
            questions: model.questions.map(StoredQuizQuestion.init(model:))
        )
    }

    func makeDomainModel() -> QuizTheme {
        QuizTheme(
            id: id,
            theme: theme,
            themeDescription: themeDescription,
            questions: questions.map { $0.makeDomainModel() },
            source: QuizThemeSource(rawValue: sourceRawValue ?? "") ?? .catalog
        )
    }
}

final class SwiftDataThemeStore {
    static var schema: Schema {
        Schema([StoredQuizTheme.self, StoredQuizQuestion.self])
    }

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchThemes() -> [QuizTheme] {
        let descriptor = FetchDescriptor<StoredQuizTheme>(sortBy: [SortDescriptor(\.theme)])
        do {
            return try context.fetch(descriptor).map { $0.makeDomainModel() }
        } catch {
            AppLog.persistence.error("Failed to fetch themes: \(String(describing: error), privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .persistentStore)
            return []
        }
    }

    func replaceThemes(with themes: [QuizTheme]) {
        clearThemes()
        for theme in themes {
            context.insert(StoredQuizTheme(model: theme))
        }
        do {
            try context.save()
        } catch {
            AppLog.persistence.error("Failed to save themes: \(String(describing: error), privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .persistentStore)
        }
    }

    func clearThemes() {
        do {
            let themes = try context.fetch(FetchDescriptor<StoredQuizTheme>())
            for theme in themes {
                context.delete(theme)
            }
            try context.save()
            AppLog.persistence.debug("SwiftData cleared")
        } catch {
            AppLog.persistence.error("Database clearing error: \(String(describing: error), privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .persistentStore)
        }
    }
}
