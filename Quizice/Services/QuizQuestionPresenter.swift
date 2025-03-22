//
//  QuizQuestionPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit

class QuizQuestionPresenter: QuizQuestionPresenterProtocol {
    
    private let quizFactory = QuizFactory.shared
    
    var view: QuizQuestionViewControllerProtocol?
    
    func viewDidLoad() {
        loadQuestion()
    }
    
    func loadQuestion() {
        quizFactory.currentQuestion = quizFactory.chosenThemeQuestionsArray[quizFactory.currentQuestionIndex]
        
        let themeName = quizFactory.chosenTheme.name
        let question = quizFactory.currentQuestion
        let questionNumberText = "Вопрос №\(quizFactory.questionsTotalCount + 1)"
        let currentAnswers = quizFactory.chosenTheme.questionsAndAnswers[quizFactory.currentQuestion]!.shuffled()
        
        view?.loadQuestionToView(themeName: themeName, question: question, questionNumberText: questionNumberText, currentAnswers: currentAnswers)
    }
    
    func checkQuestionNumberAndProceed() {
        if quizFactory.currentQuestionIndex == quizFactory.questionsTotalCount {
            view?.showResults()
        } else {
            loadQuestion()
        }
    }
    
    func checkAnswer(_ sender: UIButton) {
        let isCorrect = quizFactory.checkAnswer(selectedAnswer: sender)
        view?.correctAnswerTapped(isTrue: isCorrect)
        quizFactory.updateQuizState(isCorrect: isCorrect)
    }
    
    func resetGame() {
        quizFactory.resetProgress()
    }
}
