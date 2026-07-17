import Foundation

struct QuizAnswerOption: Equatable, Identifiable {
    let id: String
    let title: String
}

enum QuizAnswerFeedback: Equatable {
    case normal
    case correct
    case wrong
}

struct QuizQuestionViewModel: Equatable {
    let themeName: String
    let questionText: String
    let questionNumberText: String
    let answers: [QuizAnswerOption]
}

struct QuizResultState: Equatable {
    let correctAnswers: Int
    let totalQuestions: Int
}

struct QuestionModel {
    let quizQuestion: QuizQuestion

    var questionText: String {
        quizQuestion.question
    }

    var answers: [String] {
        quizQuestion.answers
    }

    var correctAnswer: String {
        quizQuestion.correctAnswer
    }
}
