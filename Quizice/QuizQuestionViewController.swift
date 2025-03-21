//
//  QuizQuestionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

class QuizQuestionViewController: UIViewController {
    
    // MARK: - IBOutlet Properties

    @IBOutlet weak var themeName: UILabel!
    @IBOutlet weak var questionNumber: UILabel!
    @IBOutlet weak var question: UILabel!
    @IBOutlet weak var timerBar: UIProgressView!
    @IBOutlet weak var answer1: UIButton!
    @IBOutlet weak var answer2: UIButton!
    @IBOutlet weak var answer3: UIButton!
    @IBOutlet weak var answer4: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    // MARK: - Properties
    
    var questionButtons: Array<UIButton>?
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private let animationsDuration: Double = 0.15
    private var timer: Timer?
    private var remainingTime: TimeInterval = 40.0
    private let totalTime: TimeInterval = 40.0
    private let QF = QuizFactory.shared
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadQuestion()
    }
    
    // MARK: - Timer methods
    
    private func startTimer() {
        timer?.invalidate() // Убедитесь, что предыдущий таймер сброшен
        remainingTime = totalTime
        timerBar.progress = 1.0 // Начальное значение прогрессбара
        timerBar.tintColor = .systemBlue
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.remainingTime -= 0.1
            self.timerBar.progress = Float(self.remainingTime / self.totalTime)
            
            if self.remainingTime <= 0 {
                self.timer?.invalidate()
                self.timer = nil
                self.timeExpired()
            }
        }
    }
    
    private func timeExpired() {
        colorButtons()
        notificationFeedback.notificationOccurred(.error)
        QF.updateQuizState(isCorrect: false)
        nextButton.isEnabled = true
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Methods
    
    private func colorButtons() {
        questionButtons?.forEach() { button in
            button.isEnabled = false
            if QF.checkAnswer(selectedAnswer: button) {
                button.setTitleColor(.white, for: .disabled)
                animationsEngine.animateBackgroundColor(button, color: UIColor.correctAnswerButton.cgColor, duration: animationsDuration)
            } else {
                animationsEngine.animateBackgroundColor(button, color: UIColor.wrongAnswerButton.cgColor, duration: animationsDuration)
            }
        }
    }
    
    private func loadQuestion() {
        questionButtons = [answer1, answer2, answer3, answer4]
        questionButtons?.forEach() { button in
            button.backgroundColor = .defaultButton
            button.setTitleColor(.gray, for: .disabled)
            button.isEnabled = true
        }
        
        question.textColor = .white
        timerBar.progress = Float(QF.currentProgress)
        
        themeName.text = QF.chosenTheme.name
        QF.currentQuestion = QF.chosenThemeQuestionsArray[0]
        question.text = QF.currentQuestion
        var currentAnswers = QF.chosenTheme.questionsAndAnswers[QF.currentQuestion]!.shuffled()
        
        while !currentAnswers.isEmpty {
            questionButtons?.forEach() { button in
                button.setTitle(currentAnswers[0], for: .normal)
                currentAnswers.remove(at: 0)
            }
        }
        
        questionNumber.text = "Вопрос №\(QF.questionCount + 1)"
        nextButton.isEnabled = false
        startTimer()
    }
    
    private func showResultsController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizResultID")
        self.present(vc, animated: true)
    }
    
    // MARK: - IBAction Methods
    
    @IBAction func answerChosen(_ sender: UIButton) {
        let isCorrect = QF.checkAnswer(selectedAnswer: sender)
        
        colorButtons()
        
        if isCorrect {
            notificationFeedback.notificationOccurred(.success)
            animationsEngine.animateTintColor(timerBar, color: .correctAnswerBar, duration: animationsDuration)
        } else {
            notificationFeedback.notificationOccurred(.error)
            animationsEngine.animateTintColor(timerBar, color: .wrongAnswerBar, duration: animationsDuration)
        }
        
        QF.updateQuizState(isCorrect: isCorrect)
        nextButton.isEnabled = true
        
        stopTimer()
    }
    
    @IBAction func nextButtonTapped() {
        if QF.questionCount == QF.questionsToComplete {
            showResultsController()
            QF.chosenThemeQuestionsArray.remove(at: 0)
        } else {
            QF.chosenThemeQuestionsArray.remove(at: 0)
            loadQuestion()
        }
    }
    
    @IBAction func backButtonTapped() {
        dismiss(animated: true)
        QF.resetProgress()
    }
    
}
