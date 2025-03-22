//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

class QuizDescriptionViewController: UIViewController {
    
    @IBOutlet weak var themeNameLabel: UILabel!
    @IBOutlet weak var themeDescriptionLabel: UILabel!
    
    var themeName: String = "Default name"
    var themeDescription: String = "Default description"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        themeNameLabel.text = themeName
        themeDescriptionLabel.text = themeDescription
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
