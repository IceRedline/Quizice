//
//  QuizQuestionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

class QuizQuestionViewController: UIViewController, QuizQuestionViewControllerProtocol {
    
    // MARK: - IBOutlet Properties
    
    @IBOutlet weak var themeNameLabel: UILabel!
    @IBOutlet weak var questionNumberLabel: UILabel!
    @IBOutlet weak var questionLabel: UILabel!
    @IBOutlet weak var timerBar: UIProgressView!
    @IBOutlet weak var answer1Button: UIButton!
    @IBOutlet weak var answer2Button: UIButton!
    @IBOutlet weak var answer3Button: UIButton!
    @IBOutlet weak var answer4Button: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    
    // MARK: - Properties
    
    private var questionButtons: Array<UIButton>?
    private let notificationFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private let animationsDuration: Double = 0.15
    
    var presenter: QuizQuestionPresenterProtocol?
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configurePresenter(QuizQuestionPresenter())
        presenter?.viewDidLoad()
    }
    
    // MARK: - Timer methods
    
    func updateProgress(_ progress: Float) {
        timerBar.progress = progress
    }
    
    func showTimeExpired() {
        colorAndDisableButtons()
        notificationFeedback.notificationOccurred(.error)
        nextButton.isEnabled = true
    }
    
    // MARK: - Methods
    
    private func configurePresenter(_ presenter: QuizQuestionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    private func colorAndDisableButtons() {
        questionButtons?.forEach() { button in
            button.isEnabled = false
            if presenter!.checkAnswerButtonTitle(selectedAnswer: button) {
                button.setTitleColor(.white, for: .disabled)
                animationsEngine.animateBackgroundColor(button, color: UIColor.correctAnswerButton.cgColor, duration: animationsDuration)
            } else {
                animationsEngine.animateBackgroundColor(button, color: UIColor.wrongAnswerButton.cgColor, duration: animationsDuration)
            }
        }
    }
    
    func resetAllColore() {
        questionButtons = [answer1Button, answer2Button, answer3Button, answer4Button]
        questionButtons?.forEach() { button in
            button.backgroundColor = .defaultButton
            button.setTitleColor(.gray, for: .disabled)
            button.isEnabled = true
        }
        timerBar.tintColor = .systemBlue
    }
    
    func loadQuestionToView(themeName: String, question: String, questionNumberText: String, currentAnswers: [String]) {
        resetAllColore()
        
        timerBar.progress = Float(presenter!.currentProgress)
        
        self.themeNameLabel.text = themeName
        self.questionLabel.text = question
        
        for i in 0...3 {
            questionButtons?[i].setTitle(currentAnswers[i], for: .normal)
        }
        
        questionNumberLabel.text = questionNumberText
        nextButton.isEnabled = false
        presenter?.startTimer()
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
        if let vc = storyboard.instantiateViewController(withIdentifier: "QuizResultID") as? QuizResultViewController {
            vc.correctAnswers = presenter!.correctAnswers
            vc.totalQuestions = presenter!.questionsTotalCount
            self.present(vc, animated: true)
        }
    }
    
    // MARK: - IBAction Methods
    
    @IBAction func answerChosen(_ sender: UIButton) {
        colorAndDisableButtons()
        presenter?.checkAnswer(sender)
        nextButton.isEnabled = true
        presenter?.stopTimer()
    }
    
    @IBAction func nextButtonTapped() {
        presenter?.checkQuestionNumberAndProceed()
    }
    
    @IBAction func backButtonTapped() {
        dismiss(animated: true)
        presenter?.resetGameProgress()
    }
}

