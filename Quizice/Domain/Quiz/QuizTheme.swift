import Foundation

struct AIQuizGenerationConfiguration: Equatable {
    static let supportedQuestionCounts = [5, 10, 15]
    static let maximumThemeLength = 120

    let theme: String
    let questionCount: Int
    let difficulty: AIQuizDifficulty
    let locale: Locale
}

enum QuizThemeSource: String, Codable {
    case catalog
    case ai
}

class QuizTheme {
    var id: String
    var theme: String
    var themeDescription: String
    var sourceRawValue: String?
    var questions: [QuizQuestion]
    var aiGenerationConfiguration: AIQuizGenerationConfiguration?
    
    init(
        id: String,
        theme: String,
        themeDescription: String,
        questions: [QuizQuestion],
        source: QuizThemeSource = .catalog,
        aiGenerationConfiguration: AIQuizGenerationConfiguration? = nil
    ) {
        self.id = id
        self.theme = theme
        self.themeDescription = themeDescription
        self.sourceRawValue = source.rawValue
        self.questions = questions
        self.aiGenerationConfiguration = aiGenerationConfiguration
    }

    var source: QuizThemeSource {
        QuizThemeSource(rawValue: sourceRawValue ?? "") ?? .catalog
    }
}

struct QuizThemeDTO: Decodable {
    let id: String
    let theme: String
    let themeDescription: String
    let questions: [QuizQuestionDTO]

    func makeModel() -> QuizTheme {
        QuizTheme(
            id: id,
            theme: theme,
            themeDescription: themeDescription,
            questions: questions.map { $0.makeModel() }
        )
    }
}
