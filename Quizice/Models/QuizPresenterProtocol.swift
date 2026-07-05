//
//  QuizPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import Foundation

struct QuizDescriptionContent: Equatable {
    let themeName: String
    let themeDescription: String
}

protocol QuizPresenterProtocol {
    var view: QuizViewControllerProtocol? { get set }
    
    func descriptionContent() -> QuizDescriptionContent
}
