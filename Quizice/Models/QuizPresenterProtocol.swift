//
//  QuizPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import Foundation

protocol QuizPresenterProtocol {
    var view: QuizViewControllerProtocol? { get set }
    
    func configureDescriptionPresenter(viewController: QuizDescriptionViewController)
}
