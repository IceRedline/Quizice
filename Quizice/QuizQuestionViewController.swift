//
//  QuizQuestionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit
import AVKit

final class QuizQuestionViewController: UIViewController, QuizQuestionViewControllerProtocol {
    
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
    private let hapticFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private let animationsDuration: Double = 0.15
    private var soundOfCorrectAnswerPlayer: AVAudioPlayer!
    private var soundOfIncorrectAnswerPlayer: AVAudioPlayer!
    
    var presenter: QuizQuestionPresenterProtocol?
    
    // MARK: - viewDidLoad
    
    override func viewDidLoad() {
        super.viewDidLoad()
        questionLabel.adjustsFontSizeToFitWidth = true
        
        if
            let correctSoundURL = Bundle.main.url(forResource: "Quizice Correct", withExtension: "m4a"),
            let incorrectSoundURL = Bundle.main.url(forResource: "Quizice Incorrect", withExtension: "m4a") {
            soundOfCorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: correctSoundURL)
            soundOfIncorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: incorrectSoundURL)
        } else {
            print("Аудиофайлы не были загружены")
        }
        
        configurePresenter(QuizQuestionPresenter())
        presenter?.viewDidLoad()
        
        hapticFeedback.prepare()
    }
    
    // MARK: - Timer methods
    
    func updateProgress(_ progress: Float) {
        timerBar.progress = progress
    }
    
    func showTimeExpired() {
        colorAndDisableButtons()
        hapticFeedback.notificationOccurred(.error)
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
    
    func resetAllColors() {
        questionButtons = [answer1Button, answer2Button, answer3Button, answer4Button]
        questionButtons?.forEach() { button in
            button.backgroundColor = .defaultButton
            button.setTitleColor(.gray, for: .disabled)
            button.isEnabled = true
        }
        timerBar.tintColor = .systemBlue
    }
    
    func loadQuestionToView(themeName: String, questionText: String, questionNumberText: String, currentAnswers: [String]) {
        resetAllColors()
        
        timerBar.progress = Float(presenter!.currentProgress)
        
        self.themeNameLabel.text = themeName
        self.questionLabel.text = questionText
        
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
            soundOfCorrectAnswerPlayer.play()
            hapticFeedback.notificationOccurred(.success)
            animationsEngine.animateTintColor(timerBar, color: .correctAnswerBar, duration: animationsDuration)
        case false:
            soundOfIncorrectAnswerPlayer.play()
            hapticFeedback.notificationOccurred(.error)
            animationsEngine.animateTintColor(timerBar, color: .wrongAnswerBar, duration: animationsDuration)
        }
    }
    
    func showResults() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QuizResultID") as? QuizResultViewController {
            presenter?.configureResultPresenter(viewController: vc)
            self.present(vc, animated: true)
        }
    }
    
    private func resetSoundPlayers() {
        soundOfCorrectAnswerPlayer?.stop()
        soundOfCorrectAnswerPlayer?.currentTime = 0
        soundOfIncorrectAnswerPlayer?.stop()
        soundOfIncorrectAnswerPlayer?.currentTime = 0
    }
    
    // MARK: - IBAction Methods
    
    @IBAction func answerChosen(_ sender: UIButton) {
        hapticFeedback.prepare()
        resetSoundPlayers()
        colorAndDisableButtons()
        presenter?.checkAnswer(sender)
        presenter?.stopTimer()
        UIView.animate(withDuration: 1) {
            self.nextButton.isEnabled = true
        }
    }
    
    @IBAction func nextButtonTapped() {
        presenter?.checkQuestionNumberAndProceed()
    }
    
    @IBAction func backButtonTapped() {
        dismiss(animated: true)
        presenter?.resetGameProgress()
    }
}

