//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

final class QuizDescriptionViewController: UIViewController {
    
    @IBOutlet weak var themeNameLabel: UILabel!
    @IBOutlet weak var themeDescriptionLabel: UILabel!
    @IBOutlet weak var numberOfQuestionsPickerView: UIPickerView!
    
    private let numberOfQuestionsOptions: [Int] = [5, 10, 15]
    
    var themeName: String = "Default name"
    var themeDescription: String = "Default description"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        numberOfQuestionsPickerView.setValue(UIColor.white, forKey: "textColor")
        
        numberOfQuestionsPickerView.delegate = self
        numberOfQuestionsPickerView.dataSource = self
        themeNameLabel.text = themeName
        themeDescriptionLabel.text = themeDescription
    }
    
    @IBAction private func startButtonTapped() {
        QuizFactory.shared.questionsCount = numberOfQuestionsOptions[numberOfQuestionsPickerView.selectedRow(inComponent: 0)]
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizQuestionID")
        self.present(vc, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        dismiss(animated: true)
    }
}

extension QuizDescriptionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        numberOfQuestionsOptions.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        String(numberOfQuestionsOptions[row])
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        QuizFactory.shared.questionsCount = numberOfQuestionsOptions[row]
    }
    
}
