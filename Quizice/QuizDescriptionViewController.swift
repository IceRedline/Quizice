//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

final class QuizDescriptionViewController: UIViewController, QuizDescriptionViewControllerProtocol {
    
    @IBOutlet weak var themeNameLabel: UILabel!
    @IBOutlet weak var themeDescriptionLabel: UILabel!
    @IBOutlet weak var numberOfQuestionsPickerView: UIPickerView!
    
    var presenter: QuizDescriptionPresenterProtocol?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter?.configurePickerView(numberOfQuestionsPickerView)
        presenter?.viewDidLoad()
        
        numberOfQuestionsPickerView.setValue(UIColor.white, forKey: "textColor")
    }
    
    func updateLabels(themeName: String, themeDescription: String) {
        themeNameLabel.text = themeName
        themeDescriptionLabel.text = themeDescription
    }
    
    func configurePresenter(_ presenter: QuizDescriptionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    @IBAction private func startButtonTapped() {
        presenter?.saveNumberOfQuestions(chosenRow: numberOfQuestionsPickerView.selectedRow(inComponent: 0))
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizQuestionID")
        self.present(vc, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        dismiss(animated: true)
    }
}


