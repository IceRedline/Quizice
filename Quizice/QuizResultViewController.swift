//
//  QuizResultViewController.swift
//  My First App
//
//  Created by Артем Табенский on 07.10.2024.
//

import UIKit

final class QuizResultViewController: UIViewController {
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var resultDescription: UILabel!
    
    var correctAnswers: Int = 0
    var totalQuestions: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let resultPercentage: Float = Float(correctAnswers) / Float(totalQuestions)
        print(resultPercentage)
        
        resultLabel.text = "Твой результат:\n \(correctAnswers)/\(totalQuestions)"
        switch resultPercentage {
        case 0...0.15:
            resultDescription.text = "Эм..."
        case 0.15...0.3:
            resultDescription.text = "Ну, слабовато..."
        case 0.3...0.5:
            resultDescription.text = "Да ладно, я знаю что ты не старался)"
        case 0.5...0.75:
            resultDescription.text = "Нормально, сойдёт для сельской местности"
        case 0.75..<1:
            resultDescription.text = "Ещё чуть-чуть и был бы как Айс!"
        case 1:
            resultDescription.text = "Легенда, гений, соло легчайше для величайшего!"
        default:
            resultDescription.text = "Что-то пошло не так! Я не смог понять, сколько ответов правильные("
        }
    }
    
    @IBAction func backButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizViewController")
        self.present(vc, animated: true)
    }
}
