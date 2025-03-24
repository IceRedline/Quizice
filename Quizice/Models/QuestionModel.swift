//
//  QuestionModel.swift
//  Quizice
//
//  Created by Артем Табенский on 23.03.2025.
//

import Foundation

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

    var explanation: String? {
        quizQuestion.explanation
    }
}
