//
//  QuizResultViewControllerProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

protocol QuizResultViewControllerProtocol {
    var presenter: QuizResultPresenterProtocol? { get set }
    
    func updateResultLabels(resultText: String, descriptionText: String)
}
