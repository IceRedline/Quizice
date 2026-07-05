//
//  QuestionData.swift
//  Quizice
//
//  Created by Артем Табенский on 22.03.2025.
//

import Foundation
import SwiftData

@Model
class QuizQuestion {
    var question: String
    var answers: [String]
    var correctAnswer: String
    
    init(question: String, answers: [String], correctAnswer: String) {
        self.question = question
        self.answers = answers
        self.correctAnswer = correctAnswer
    }
}

struct QuizQuestionDTO: Decodable {
    let question: String
    let answers: [String]
    let correctAnswer: String

    enum CodingKeys: String, CodingKey {
        case question
        case answers
        case correctAnswer
    }

    func makeModel() -> QuizQuestion {
        QuizQuestion(question: question, answers: answers, correctAnswer: correctAnswer)
    }
}
