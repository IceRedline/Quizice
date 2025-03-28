//
//  QuizResultPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

protocol QuizResultPresenterProtocol {
    var view: QuizResultViewControllerProtocol? { get set }
    var correctAnswers: Int { get set }
    var totalQuestions: Int { get set }
    
    func viewDidLoad()
}
