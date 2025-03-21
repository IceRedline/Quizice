//
//  QuizViewController.swift
//  My First App
//
//  Created by Артем Табенский on 01.10.2024.
//

import UIKit

class QuizViewController: UIViewController {
    
    private let animationsEngine = Animations()
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    private func showVC() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizDescriptionID")
        self.present(vc, animated: true)
    }
    
    @IBAction private func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }
    
    @IBAction private func themeButtonTouchedUpInside(_ sender: UIButton) {
        QuizFactory.shared.loadTheme(sender.tag)
        showVC()
    }
    
    @IBAction private func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }
    
    @IBAction private func progressButtonTapped() {
        let alert = UIAlertController(
            title: "Ой!",
            message: "Этой страницы пока нету",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "Navigation")
        self.present(vc, animated: true)
    }
    
}
