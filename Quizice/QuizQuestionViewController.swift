//
//  QuizQuestionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

class QuizQuestionViewController: UIViewController, QuizQuestionViewControllerProtocol {
    
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
    private let quizFactory = QuizFactory.shared
    
    var presenter: QuizQuestionPresenterProtocol?
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePresenter(QuizQuestionPresenter())
        
        presenter?.viewDidLoad()
    }
    
    // MARK: - Timer methods
    
    private func startTimer() {
        timer?.invalidate() // Убедитесь, что предыдущий таймер сброшен
        remainingTime = totalTime
        timeStarted()
        
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
    
    private func timeStarted() {
        timerBar.progress = 1.0 // Начальное значение прогрессбара
        timerBar.tintColor = .systemBlue
    }
    
    private func timeExpired() {
        colorButtons()
        notificationFeedback.notificationOccurred(.error)
        quizFactory.updateQuizState(isCorrect: false)
        nextButton.isEnabled = true
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Methods
    
    private func configurePresenter(_ presenter: QuizQuestionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    private func colorButtons() {
        questionButtons?.forEach() { button in
            button.isEnabled = false
            if quizFactory.checkAnswer(selectedAnswer: button) {
                button.setTitleColor(.white, for: .disabled)
                animationsEngine.animateBackgroundColor(button, color: UIColor.correctAnswerButton.cgColor, duration: animationsDuration)
            } else {
                animationsEngine.animateBackgroundColor(button, color: UIColor.wrongAnswerButton.cgColor, duration: animationsDuration)
            }
        }
    }
    
    func resetButtons() {
        questionButtons = [answer1, answer2, answer3, answer4]
        questionButtons?.forEach() { button in
            button.backgroundColor = .defaultButton
            button.setTitleColor(.gray, for: .disabled)
            button.isEnabled = true
        }
    }
    
    func loadQuestionToView(themeName: String, question: String, questionNumberText: String, currentAnswers: [String]) {
        resetButtons()
        
        timerBar.progress = Float(quizFactory.currentProgress)
        
        self.themeName.text = themeName
        self.question.text = question
        
        for i in 0...3 {
            questionButtons?[i].setTitle(currentAnswers[i], for: .normal)
        }
        
        questionNumber.text = questionNumberText
        nextButton.isEnabled = false
        startTimer()
    }
    
    func correctAnswerTapped(isTrue: Bool) {
        switch isTrue {
            case true:
                notificationFeedback.notificationOccurred(.success)
                animationsEngine.animateTintColor(timerBar, color: .correctAnswerBar, duration: animationsDuration)
            case false:
                notificationFeedback.notificationOccurred(.error)
                animationsEngine.animateTintColor(timerBar, color: .wrongAnswerBar, duration: animationsDuration)
        }
    }
    
    func showResults() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "QuizResultID")
        self.present(vc, animated: true)
    }
    
    // MARK: - IBAction Methods
    
    @IBAction func answerChosen(_ sender: UIButton) {
        presenter?.checkAnswer(sender)
        
        colorButtons()
    
        nextButton.isEnabled = true
        
        stopTimer()
    }
    
    @IBAction func nextButtonTapped() {
        presenter?.checkQuestionNumberAndProceed()
    }
    
    @IBAction func backButtonTapped() {
        dismiss(animated: true)
        presenter?.resetGame()
    }
    
}

