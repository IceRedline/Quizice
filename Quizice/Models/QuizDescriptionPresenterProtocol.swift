//
//  QuizDescriptionPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

protocol QuizDescriptionPresenterProtocol {
    var view: QuizDescriptionViewControllerProtocol? { get set }
    var themeID: String? { get }
    var themeName: String { get set }
    var themeDescription: String { get set }
    
    func viewDidLoad()
    var numberOfQuestionsOptionCount: Int { get }
    func numberOfQuestionsTitle(at row: Int) -> String?
    func saveNumberOfQuestions(chosenRow: Int)
}

extension QuizDescriptionPresenterProtocol {
    var themeID: String? { nil }
}
