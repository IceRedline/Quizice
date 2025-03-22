//
//  QuizQuestionPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit

protocol QuizQuestionPresenterProtocol {
    var view: QuizQuestionViewControllerProtocol? { get set }
    
    func viewDidLoad()
    func loadQuestion()
    func checkQuestionNumberAndProceed()
    func checkAnswer(_ sender: UIButton)
    func resetGame()
}
