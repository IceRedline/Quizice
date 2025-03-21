//
//  QuizResultViewController.swift
//  My First App
//
//  Created by Артем Табенский on 07.10.2024.
//

import UIKit

class QuizResultViewController: UIViewController {

    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var resultDescription: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        resultLabel.text = "Твой результат:\n \(QuizFactory.shared.correctAnswers)/\(QuizFactory.shared.questionCount)"
        switch QuizFactory.shared.correctAnswers {
        case 0:
            resultDescription.text = "Эм..."
        case 1:
            resultDescription.text = "Ну, хотя бы в один попал..."
        case 2:
            resultDescription.text = "Да ладно, я знаю что ты не старался)"
        case 3:
            resultDescription.text = "Нормально, сойдёт для сельской местности"
        case 4:
            resultDescription.text = "Ещё чуть-чуть и был бы как Айс!"
        case 5:
            resultDescription.text = "Легенда, гений, соло легчайше для величайшего!"
        default:
            resultDescription.text = "Что-то пошло не так! Я не смог понять, сколько ответов правильные("
        }
    }
    
    @IBAction func backButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizID")
        self.present(vc, animated: true)
    }
    
}
