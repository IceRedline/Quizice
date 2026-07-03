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
        let resultText = L10n.Result.text(correctAnswers: normalizedCorrectAnswers, totalQuestions: normalizedTotalQuestions)
        var descriptionText = L10n.Result.fallbackDescription

        guard normalizedTotalQuestions > 0 else {
            descriptionText = L10n.Result.noQuestionsDescription
            view?.updateResultLabels(resultText: resultText, descriptionText: descriptionText)
            return
        }
        
        let resultPercentage = Float(normalizedCorrectAnswers) / Float(normalizedTotalQuestions)
        switch resultPercentage {
        case 0...0.15:
            descriptionText = L10n.Result.veryLowScoreDescription
        case 0.15...0.3:
            descriptionText = L10n.Result.lowScoreDescription
        case 0.3...0.5:
            descriptionText = L10n.Result.mediumLowScoreDescription
        case 0.5...0.75:
            descriptionText = L10n.Result.mediumScoreDescription
        case 0.75..<1:
            descriptionText = L10n.Result.highScoreDescription
        case 1:
            descriptionText = L10n.Result.perfectScoreDescription
        default:
            descriptionText = L10n.Result.invalidScoreDescription
        }
        
        view?.updateResultLabels(resultText: resultText, descriptionText: descriptionText)
    }
}
