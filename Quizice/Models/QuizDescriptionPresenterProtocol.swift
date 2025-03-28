//
//  QuizDescriptionPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import UIKit

protocol QuizDescriptionPresenterProtocol {
    var view: QuizDescriptionViewControllerProtocol? { get set }
    var themeName: String { get set }
    var themeDescription: String { get set }
    
    func viewDidLoad()
    func configurePickerView(_ pickerView: UIPickerView)
    func saveNumberOfQuestions(chosenRow: Int)
}
