//
//  QuestionData.swift
//  Quizice
//
//  Created by Артем Табенский on 22.03.2025.
//

import Foundation
import SwiftData

@Model
class QuizQuestion: Decodable {
    var question: String
    var answers: [String]
    var correctAnswer: String
    var explanation: String
    
    enum CodingKeys: String, CodingKey {
        case question
        case answers
        case correctAnswer
        case explanation
    }
    
    init(question: String, answers: [String], correctAnswer: String, explanation: String) {
        self.question = question
        self.answers = answers
        self.correctAnswer = correctAnswer
        self.explanation = explanation
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.question = try container.decode(String.self, forKey: .question)
        self.answers = try container.decode([String].self, forKey: .answers)
        self.correctAnswer = try container.decode(String.self, forKey: .correctAnswer)
        self.explanation = try container.decode(String.self, forKey: .explanation)
    }
}
