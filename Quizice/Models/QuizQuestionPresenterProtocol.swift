//
//  QuizQuestionPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit

protocol QuizQuestionPresenterProtocol {
    var view: QuizQuestionViewControllerProtocol? { get set }
    var correctAnswers: Int { get set }
    var questionsTotalCount: Int { get set }
    var currentProgress: Float { get set }
    
    func viewDidLoad()
    func loadQuestion()
    func checkQuestionNumberAndProceed()
    func checkAnswerButtonTitle(selectedAnswer: UIButton) -> Bool
    func checkAnswer(_ sender: UIButton)
    func updateQuizState(isCorrect: Bool)
    func resetGameProgress()
}
