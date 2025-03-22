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
    
    private let quizFactory = QuizFactory.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        themeName.text = quizFactory.chosenTheme.name
        themeDescription.text = quizFactory.chosenTheme.description
    }
    
    @IBAction private func startButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizQuestionID")
        self.present(vc, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        dismiss(animated: true)
    }
}
