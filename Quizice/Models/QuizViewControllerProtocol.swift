//
//  QuizViewControllerProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import Foundation

protocol QuizViewControllerProtocol {
    var presenter: QuizPresenterProtocol? { get set }
    
    func configurePresenter(_ presenter: QuizPresenterProtocol)
}
