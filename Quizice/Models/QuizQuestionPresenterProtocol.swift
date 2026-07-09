//
//  QuizQuestionPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import Foundation

protocol QuizQuestionPresenterProtocol {
    var view: QuizQuestionViewControllerProtocol? { get set }
    var themeID: String? { get }
    var correctAnswers: Int { get set }
    var questionsTotalCount: Int? { get set }
    var currentProgress: Float { get set }
    
    func viewDidLoad()
    func startTimer()
    func stopTimer()
    func loadQuestion()
    func checkQuestionNumberAndProceed()
    func answerFeedback(for optionID: String) -> QuizAnswerFeedback
    func checkAnswer(optionID: String)
    func updateQuizState(isCorrect: Bool)
    func resetGameProgress()
}

extension QuizQuestionPresenterProtocol {
    var themeID: String? { nil }
}
