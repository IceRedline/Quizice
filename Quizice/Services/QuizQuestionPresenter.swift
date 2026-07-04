//
//  QuizQuestionPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit

final class QuizQuestionPresenter: QuizQuestionPresenterProtocol {
    private let quizFactory = QuizFactory.shared
    private let statisticsStore = StatisticsStore()
    
    weak var view: QuizQuestionViewControllerProtocol?
    
    private var timer: Timer?
    private var remainingTime: TimeInterval = 20
    private let totalTime: TimeInterval = 20
    
    var chosenThemeQuestionsArray: [QuestionModel] = []
    var currentQuestion: QuestionModel?
    var questionsTotalCount: Int?
    var currentQuestionIndex: Int = 0
    var correctAnswers: Int = 0
    var currentProgress: Float = 0.2
    private var hasRecordedCompletedAttempt = false
    
    func viewDidLoad() {
        resetGameProgress()
        loadQuestions()
        loadQuestion()
    }
    
    // MARK: - Timer methods
    
    func startTimer() {
        guard hasActiveQuestion else {
            stopTimer()
            view?.updateProgress(0)
            return
        }
        
        stopTimer()
        remainingTime = totalTime
        view?.updateProgress(1.0)
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingTime -= 0.05
            let progress = Float(self.remainingTime / self.totalTime)
            self.view?.updateProgress(progress)
            
            if self.remainingTime <= 0 {
                self.stopTimer()
                self.timeExpired()
            }
        }
    }
    
    private func timeExpired() {
        view?.showTimeExpired()
        updateQuizState(isCorrect: false)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Methods
    
    func loadQuestions() {
        guard let chosenTheme = quizFactory.chosenTheme else {
            chosenThemeQuestionsArray = []
            questionsTotalCount = 0
            return
        }
        
        let usableQuestions = chosenTheme.questionsAndAnswers.filter { question in
            !question.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            question.answers.count >= 4 &&
            !question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        guard !usableQuestions.isEmpty else {
            chosenThemeQuestionsArray = []
            questionsTotalCount = 0
            return
        }
        
        let requestedCount = quizFactory.questionsCount > 0 ? quizFactory.questionsCount : usableQuestions.count
        let clampedCount = min(requestedCount, usableQuestions.count)
        questionsTotalCount = max(clampedCount, 1)
        chosenThemeQuestionsArray = Array(usableQuestions.shuffled().prefix(questionsTotalCount ?? usableQuestions.count))
        print("загружены вопросы: \(chosenThemeQuestionsArray.count)")
    }
    
    func loadQuestion() {
        guard hasActiveQuestion else {
            currentQuestion = nil
            stopTimer()
            view?.updateProgress(0)
            view?.showQuestionUnavailable(themeName: quizFactory.chosenTheme?.themeName, message: L10n.Question.unavailableMessage)
            return
        }
        
        let question = chosenThemeQuestionsArray[currentQuestionIndex]
        currentQuestion = question
        
        let themeName = quizFactory.chosenTheme?.themeName ?? L10n.Question.fallbackTheme
        let currentAnswers = Array(question.answers.shuffled().prefix(4))
        let questionNumberText = L10n.Question.number(currentQuestionIndex + 1)
        
        view?.loadQuestionToView(themeName: themeName, questionText: question.questionText, questionNumberText: questionNumberText, currentAnswers: currentAnswers)
    }
    
    func updateQuizState(isCorrect: Bool) {
        guard hasActiveQuestion else { return }
        
        if isCorrect {
            correctAnswers += 1
        }
        
        currentQuestionIndex += 1
        if let questionsTotalCount, questionsTotalCount > 0 {
            currentProgress = Float(currentQuestionIndex + 1) / Float(questionsTotalCount)
        }
    }
    
    func checkAnswerButtonTitle(selectedAnswer: UIButton) -> Bool {
        guard hasActiveQuestion else { return false }
        
        let correctAnswer = chosenThemeQuestionsArray[currentQuestionIndex].correctAnswer
        return selectedAnswer.currentTitle == correctAnswer
    }
    
    func checkAnswer(_ sender: UIButton) {
        guard hasActiveQuestion else { return }
        
        let isCorrect = checkAnswerButtonTitle(selectedAnswer: sender)
        view?.correctAnswerTapped(isTrue: isCorrect)
        updateQuizState(isCorrect: isCorrect)
    }
    
    func checkQuestionNumberAndProceed() {
        stopTimer()
        
        guard let questionsTotalCount, questionsTotalCount > 0 else {
            loadQuestion()
            return
        }
        
        if currentQuestionIndex >= questionsTotalCount {
            recordCompletedAttemptIfNeeded(totalQuestions: questionsTotalCount)
            view?.showResults()
        } else {
            loadQuestion()
        }
    }
    
    func configureResultPresenter(viewController: QuizResultViewController) {
        viewController.configurePresenter(QuizResultPresenter())
        viewController.presenter?.correctAnswers = correctAnswers
        viewController.presenter?.totalQuestions = max(questionsTotalCount ?? 0, 0)
    }
    
    func resetGameProgress() {
        stopTimer()
        chosenThemeQuestionsArray = []
        currentQuestion = nil
        questionsTotalCount = 0
        currentQuestionIndex = 0
        correctAnswers = 0
        currentProgress = 0.2
        hasRecordedCompletedAttempt = false
    }
    
    private func recordCompletedAttemptIfNeeded(totalQuestions: Int) {
        guard hasRecordedCompletedAttempt == false, totalQuestions > 0 else { return }
        hasRecordedCompletedAttempt = true
        statisticsStore.recordAttempt(correctAnswers: correctAnswers, totalQuestions: totalQuestions)
    }
    
    private var hasActiveQuestion: Bool {
        guard let questionsTotalCount, questionsTotalCount > 0 else { return false }
        return !chosenThemeQuestionsArray.isEmpty &&
        currentQuestionIndex >= 0 &&
        currentQuestionIndex < questionsTotalCount &&
        currentQuestionIndex < chosenThemeQuestionsArray.count &&
        chosenThemeQuestionsArray[currentQuestionIndex].answers.count >= 4
    }
}
