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

enum RandomQuizSelection {
    static let themeID = "random-selection"
    static let questionCount = 5

    static func makeTheme(
        from themes: [QuizTheme],
        excluding previousQuestions: [QuizQuestion] = [],
        title: String,
        description: String,
        randomizing: ([QuizQuestion]) -> [QuizQuestion]
    ) -> QuizTheme? {
        let usableQuestions = themes
            .flatMap(\.questions)
            .filter { question in
                QuizQuestionCountPolicy.isUsable(QuestionModel(quizQuestion: question))
            }
        let usableQuestionIDs = Set(usableQuestions.map(ObjectIdentifier.init))
        var seenQuestionIDs = Set<ObjectIdentifier>()
        let randomizedQuestions = randomizing(usableQuestions).filter { question in
            let identifier = ObjectIdentifier(question)
            return usableQuestionIDs.contains(identifier) && seenQuestionIDs.insert(identifier).inserted
        }

        let previousSignatures = Set(previousQuestions.map(QuestionSignature.init))
        let unseenQuestions = randomizedQuestions.filter {
            !previousSignatures.contains(QuestionSignature(question: $0))
        }
        let repeatedQuestions = randomizedQuestions.filter {
            previousSignatures.contains(QuestionSignature(question: $0))
        }
        let selectedQuestions = Array((unseenQuestions + repeatedQuestions).prefix(questionCount))
        guard selectedQuestions.count == questionCount else { return nil }

        return QuizTheme(
            id: themeID,
            theme: title,
            themeDescription: description,
            questions: selectedQuestions
        )
    }

    private struct QuestionSignature: Hashable {
        let question: String
        let answers: [String]
        let correctAnswer: String

        init(question: QuizQuestion) {
            self.question = question.question
            answers = question.answers
            correctAnswer = question.correctAnswer
        }
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
