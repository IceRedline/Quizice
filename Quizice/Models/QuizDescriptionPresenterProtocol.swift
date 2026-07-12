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
    var analyticsTheme: AnalyticsTheme { get }
    var themeName: String { get set }
    var themeDescription: String { get set }
    var selectedQuestionCount: Int { get }
    var selectedQuestionCountRow: Int? { get }
    var isQuestionCountSelectionEnabled: Bool { get }
    
    func viewDidLoad()
    var numberOfQuestionsOptionCount: Int { get }
    func numberOfQuestionsTitle(at row: Int) -> String?
    func saveNumberOfQuestions(chosenRow: Int)
}

extension QuizDescriptionPresenterProtocol {
    var themeID: String? { nil }
    var analyticsTheme: AnalyticsTheme { .unknown }
    var selectedQuestionCount: Int { 0 }
    var selectedQuestionCountRow: Int? { nil }
    var isQuestionCountSelectionEnabled: Bool { true }
}
