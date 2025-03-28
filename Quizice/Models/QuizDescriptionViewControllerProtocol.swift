//
//  QuizDescriptionViewControllerProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import UIKit

protocol QuizDescriptionViewControllerProtocol {
    var presenter: QuizDescriptionPresenterProtocol? { get set }
    
    func configurePresenter(_ presenter: QuizDescriptionPresenterProtocol)
    func updateLabels(themeName: String, themeDescription: String)
}
