//
//  QuizResultPresenterProtocol.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

final class QuizResultPresenter: QuizResultPresenterProtocol {
    var view: QuizResultViewControllerProtocol?
    
    var correctAnswers: Int = 0
    var totalQuestions: Int = 0
    
    func viewDidLoad() {
        getResultText()
    }
    
    func getResultText() {
        let normalizedCorrectAnswers = max(correctAnswers, 0)
        let normalizedTotalQuestions = max(totalQuestions, 0)
        let resultText = "Твой результат:\n \(normalizedCorrectAnswers)/\(normalizedTotalQuestions)"
        var descriptionText = "no description"
        
        guard normalizedTotalQuestions > 0 else {
            descriptionText = "В этой попытке не было доступных вопросов. Попробуй выбрать другую тему."
            view?.updateResultLabels(resultText: resultText, descriptionText: descriptionText)
            return
        }
        
        let resultPercentage = Float(normalizedCorrectAnswers) / Float(normalizedTotalQuestions)
        switch resultPercentage {
        case 0...0.15:
            descriptionText = "Тебе точно стоит попробовать ещё раз!"
        case 0.15...0.3:
            descriptionText = "Ты знаешь, могло быть и хуже! Не сильно... Но могло!"
        case 0.3...0.5:
            descriptionText = "Да ладно, я знаю что ты не старался)"
        case 0.5...0.75:
            descriptionText = "Нормально, сойдёт для сельской местности"
        case 0.75..<1:
            descriptionText = "Ещё чуть-чуть и был бы как сам создатель квиза, молодец!"
        case 1:
            descriptionText = "Легенда, гений, соло легчайше для величайшего!"
        default:
            descriptionText = "Что-то пошло не так! Я не смог понять, сколько ответов правильные("
        }
        
        view?.updateResultLabels(resultText: resultText, descriptionText: descriptionText)
    }
}

