//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

class QuizDescriptionViewController: UIViewController {
    
    @IBOutlet weak var themeName: UILabel!
    @IBOutlet weak var themeDescription: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        themeName.text = QuizFactory.shared.chosenTheme.name
        themeDescription.text = QuizFactory.shared.chosenTheme.description
    }
    
    @IBAction private func startButtonTapped() {
        QuizFactory.shared.loadQuestions()
        
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizQuestionID")
        self.present(vc, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        dismiss(animated: true)
    }
}
