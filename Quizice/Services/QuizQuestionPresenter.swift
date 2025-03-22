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
    
    private var timer: Timer?
    private var remainingTime: TimeInterval = 20
    private let totalTime: TimeInterval = 20
    
    var chosenThemeQuestionsArray: [String] = []
    var currentQuestion: String = ""
    var questionsTotalCount: Int = 0
    var currentQuestionIndex: Int = 0
    var correctAnswers: Int = 0
    var currentProgress: Float = 0.2
    
    func viewDidLoad() {
        resetGameProgress()
        loadQuestions()
        loadQuestion()
    }
    
    // MARK: - Timer methods
    
    func startTimer() {
        stopTimer()
        remainingTime = totalTime
        view?.updateProgress(1.0)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingTime -= 0.1
            let progress = Float(self.remainingTime / self.totalTime)
            self.view?.updateProgress(progress)
            
            if self.remainingTime <= 0 {
                self.stopTimer()
                self.timeExpired()
            }
        }
    }
    
    private func timeExpired() {
        updateQuizState(isCorrect: false)
        view?.showTimeExpired()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Methods
    
    func loadQuestions() {
        chosenThemeQuestionsArray = Array(quizFactory.chosenTheme.questionsAndAnswers.keys).shuffled()
        questionsTotalCount = chosenThemeQuestionsArray.count
        currentQuestion = chosenThemeQuestionsArray[0]
    }
    
    func loadQuestion() {
        
        currentQuestion = chosenThemeQuestionsArray[currentQuestionIndex]
        
        let themeName = quizFactory.chosenTheme.name
        let question = currentQuestion
        let questionNumberText = "Вопрос №\(currentQuestionIndex + 1)"
        let currentAnswers = quizFactory.chosenTheme.questionsAndAnswers[currentQuestion]!.shuffled()
        
        view?.loadQuestionToView(themeName: themeName, question: question, questionNumberText: questionNumberText, currentAnswers: currentAnswers)
    }
    
    func updateQuizState(isCorrect: Bool) {
        if isCorrect {
            correctAnswers += 1
        }
        currentProgress += 0.2
        currentQuestionIndex += 1
    }
    
    func checkAnswerButtonTitle(selectedAnswer: UIButton) -> Bool {
        let correctAnswer = quizFactory.chosenTheme.questionsAndAnswers[currentQuestion]?.first
        return selectedAnswer.currentTitle == correctAnswer
    }
    
    func checkAnswer(_ sender: UIButton) {
        let isCorrect = checkAnswerButtonTitle(selectedAnswer: sender)
        view?.correctAnswerTapped(isTrue: isCorrect)
        updateQuizState(isCorrect: isCorrect)
    }
    
    func checkQuestionNumberAndProceed() {
        if currentQuestionIndex == questionsTotalCount {
            view?.showResults()
        } else {
            loadQuestion()
        }
    }
    
    func resetGameProgress() {
        questionsTotalCount = 0
        currentQuestionIndex = 0
        correctAnswers = 0
        currentProgress = 0.2
    }
}
