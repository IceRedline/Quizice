//
//  QuizQuestionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit
import AVKit

final class QuizQuestionViewController: UIViewController, QuizQuestionViewControllerProtocol {
    
    // MARK: - Programmatic UI Properties
    
    private var themeNameLabel: UILabel!
    private var questionNumberLabel: UILabel!
    private var questionLabel: UILabel!
    private var timerBar: UIProgressView!
    private var answer1Button: UIButton!
    private var answer2Button: UIButton!
    private var answer3Button: UIButton!
    private var answer4Button: UIButton!
    private var nextButton: UIButton!
    
    // MARK: - Properties
    
    private var questionButtons: Array<UIButton>?
    private let hapticFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private let animationsDuration: Double = 0.15
    private var soundOfCorrectAnswerPlayer: AVAudioPlayer!
    private var soundOfIncorrectAnswerPlayer: AVAudioPlayer!
    
    var presenter: QuizQuestionPresenterProtocol?
    
    // MARK: - viewDidLoad
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }
    
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
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        themeNameLabel = makeLabel(font: .systemFont(ofSize: 24, weight: .semibold))
        questionNumberLabel = makeLabel(font: .systemFont(ofSize: 18, weight: .medium))
        questionLabel = makeLabel(font: .systemFont(ofSize: 26, weight: .bold))
        questionLabel.numberOfLines = 0
        
        timerBar = UIProgressView(progressViewStyle: .default)
        timerBar.translatesAutoresizingMaskIntoConstraints = false
        timerBar.progressTintColor = .systemBlue
        timerBar.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        
        answer1Button = makeAnswerButton()
        answer2Button = makeAnswerButton()
        answer3Button = makeAnswerButton()
        answer4Button = makeAnswerButton()
        [answer1Button, answer2Button, answer3Button, answer4Button].forEach { button in
            button.addTarget(self, action: #selector(answerChosen(_:)), for: .touchUpInside)
        }
        
        nextButton = makeActionButton(title: "Далее")
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        
        let backButton = makeActionButton(title: "Назад")
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        let answersStackView = UIStackView(arrangedSubviews: [answer1Button, answer2Button, answer3Button, answer4Button])
        answersStackView.axis = .vertical
        answersStackView.spacing = 14
        answersStackView.distribution = .fillEqually
        answersStackView.translatesAutoresizingMaskIntoConstraints = false
        
        [themeNameLabel, questionNumberLabel, timerBar, questionLabel, answersStackView, nextButton, backButton].forEach(rootView.addSubview)
        
        NSLayoutConstraint.activate([
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 28),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            
            questionNumberLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: 12),
            questionNumberLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            questionNumberLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            
            timerBar.topAnchor.constraint(equalTo: questionNumberLabel.bottomAnchor, constant: 18),
            timerBar.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 32),
            timerBar.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -32),
            
            questionLabel.topAnchor.constraint(equalTo: timerBar.bottomAnchor, constant: 36),
            questionLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            questionLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -28),
            
            answersStackView.topAnchor.constraint(greaterThanOrEqualTo: questionLabel.bottomAnchor, constant: 32),
            answersStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            answersStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            answersStackView.heightAnchor.constraint(equalToConstant: 256),
            
            nextButton.topAnchor.constraint(equalTo: answersStackView.bottomAnchor, constant: 24),
            nextButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 220),
            nextButton.heightAnchor.constraint(equalToConstant: 50),
            
            backButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 12),
            backButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 220),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -24)
        ])
    }
    
    private func makeLabel(font: UIFont) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = font
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makeAnswerButton() -> UIButton {
        let button = UIButton(type: .system)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.gray, for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .defaultButton
        button.layer.cornerRadius = 16
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func makeActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func colorAndDisableButtons() {
        questionButtons?.forEach() { button in
            button.isEnabled = false
            guard let presenter else { return }
            if presenter.checkAnswerButtonTitle(selectedAnswer: button) {
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
        
        timerBar.progress = presenter?.currentProgress ?? 0
        
        self.themeNameLabel.text = themeName
        self.questionLabel.text = questionText
        
        let buttons = questionButtons ?? []
        for (index, button) in buttons.enumerated() {
            let answerTitle = currentAnswers.indices.contains(index) ? currentAnswers[index] : "Недоступно"
            button.setTitle(answerTitle, for: .normal)
            button.isEnabled = currentAnswers.indices.contains(index)
        }
        
        questionNumberLabel.text = questionNumberText
        nextButton.isEnabled = false
        presenter?.startTimer()
    }
    
    func showQuestionUnavailable(themeName: String?, message: String) {
        questionButtons = [answer1Button, answer2Button, answer3Button, answer4Button]
        themeNameLabel.text = themeName ?? "Викторина"
        questionNumberLabel.text = "Вопросы недоступны"
        questionLabel.text = message
        timerBar.progress = 0
        timerBar.tintColor = .systemBlue
        questionButtons?.forEach { button in
            button.setTitle("—", for: .normal)
            button.backgroundColor = .defaultButton
            button.setTitleColor(.gray, for: .disabled)
            button.isEnabled = false
        }
        nextButton.isEnabled = false
    }
    
    func correctAnswerTapped(isTrue: Bool) {
        switch isTrue {
        case true:
            soundOfCorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.success)
            animationsEngine.animateTintColor(timerBar, color: .correctAnswerBar, duration: animationsDuration)
        case false:
            soundOfIncorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.error)
            animationsEngine.animateTintColor(timerBar, color: .wrongAnswerBar, duration: animationsDuration)
        }
    }
    
    func showResults() {
        let viewController = QuizResultViewController()
        viewController.modalPresentationStyle = .fullScreen
        presenter?.configureResultPresenter(viewController: viewController)
        present(viewController, animated: true)
    }
    
    private func resetSoundPlayers() {
        soundOfCorrectAnswerPlayer?.stop()
        soundOfCorrectAnswerPlayer?.currentTime = 0
        soundOfIncorrectAnswerPlayer?.stop()
        soundOfIncorrectAnswerPlayer?.currentTime = 0
    }
    
    // MARK: - IBAction Methods
    
    @IBAction func answerChosen(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        
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

