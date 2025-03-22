//
//  QuizQuestionViewControllerProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import Foundation

protocol QuizQuestionViewControllerProtocol {
    var presenter: QuizQuestionPresenterProtocol? { get set }
    
    func loadQuestionToView(themeName: String, question: String, questionNumberText: String, currentAnswers: [String])
    func correctAnswerTapped(isTrue: Bool)
    func showResults()
}
