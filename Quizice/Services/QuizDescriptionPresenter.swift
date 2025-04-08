//
//  QuizDescriptionPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import UIKit

final class QuizDescriptionPresenter: NSObject, QuizDescriptionPresenterProtocol {
    
    private let numberOfQuestionsOptions: [Int] = [5, 10, 15]
    
    var view: QuizDescriptionViewControllerProtocol?
    
    var themeName: String = "Default name"
    var themeDescription: String = "Default description"
    
    func viewDidLoad() {
        getLabelsText()
    }
    
    func configurePickerView(_ pickerView: UIPickerView) {
        pickerView.delegate = self
        pickerView.dataSource = self
    }
    
    func getLabelsText() {
        view?.updateLabels(themeName: themeName, themeDescription: themeDescription)
    }
    
    func saveNumberOfQuestions(chosenRow: Int) {
        QuizFactory.shared.questionsCount = numberOfQuestionsOptions[chosenRow]
    }
}

extension QuizDescriptionPresenter: UIPickerViewDelegate, UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        numberOfQuestionsOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        String(numberOfQuestionsOptions[row])
    }
}
