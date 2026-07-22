import Foundation

class QuizQuestion {
    var question: String
    var answers: [String]
    var correctAnswer: String
    var explanation: String?
    
    init(
        question: String,
        answers: [String],
        correctAnswer: String,
        explanation: String? = nil
    ) {
        self.question = question
        self.answers = answers
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
}

struct QuizQuestionDTO: Decodable {
    let question: String
    let answers: [String]
    let correctAnswer: String
    let explanation: String?

    enum CodingKeys: String, CodingKey {
        case question
        case answers
        case correctAnswer
        case explanation
    }

    func makeModel() -> QuizQuestion {
        QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer,
            explanation: explanation
        )
    }
}
