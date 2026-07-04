//
//  QuizQuestionViewControllerProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import Foundation

protocol QuizQuestionViewControllerProtocol: AnyObject {
    var presenter: QuizQuestionPresenterProtocol? { get set }
    
    func updateProgress(_ progress: Float)
    func showTimeExpired()
    func loadQuestionToView(themeName: String, questionText: String, questionNumberText: String, currentAnswers: [String])
    func showQuestionUnavailable(themeName: String?, message: String)
    func correctAnswerTapped(isTrue: Bool)
    func showResults()
}
