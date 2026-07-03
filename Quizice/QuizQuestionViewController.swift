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
    private var questionCardView: UIView!
    private var timerContainerView: UIView!
    private var timerBar: UIProgressView!
    private var answersStackView: UIStackView!
    private var answer1Button: UIButton!
    private var answer2Button: UIButton!
    private var answer3Button: UIButton!
    private var answer4Button: UIButton!
    private var nextButton: UIButton!
    private var backButton: UIButton!
    
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
        rootView.accessibilityIdentifier = "questionRootView"
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
        themeNameLabel.accessibilityIdentifier = "questionThemeLabel"
        
        questionNumberLabel = makeLabel(font: .systemFont(ofSize: 18, weight: .medium))
        questionNumberLabel.accessibilityIdentifier = "questionNumberLabel"
        
        questionCardView = UIView()
        questionCardView.accessibilityIdentifier = "questionCardView"
        questionCardView.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        questionCardView.layer.cornerRadius = 28
        questionCardView.layer.borderWidth = 1
        questionCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        questionCardView.layer.shadowColor = UIColor.black.cgColor
        questionCardView.layer.shadowOpacity = 0.22
        questionCardView.layer.shadowRadius = 16
        questionCardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        questionCardView.translatesAutoresizingMaskIntoConstraints = false
        
        questionLabel = makeLabel(font: .systemFont(ofSize: 26, weight: .bold))
        questionLabel.accessibilityIdentifier = "questionTextLabel"
        questionLabel.numberOfLines = 0
        
        timerContainerView = UIView()
        timerContainerView.accessibilityIdentifier = "questionTimerContainerView"
        timerContainerView.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        timerContainerView.layer.cornerRadius = 8
        timerContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        timerBar = UIProgressView(progressViewStyle: .default)
        timerBar.accessibilityIdentifier = "questionTimerProgressView"
        timerBar.translatesAutoresizingMaskIntoConstraints = false
        timerBar.progressTintColor = .systemBlue
        timerBar.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        timerBar.layer.cornerRadius = 4
        timerBar.clipsToBounds = true
        
        answer1Button = makeAnswerButton(accessibilityIdentifier: "questionAnswerButton1")
        answer2Button = makeAnswerButton(accessibilityIdentifier: "questionAnswerButton2")
        answer3Button = makeAnswerButton(accessibilityIdentifier: "questionAnswerButton3")
        answer4Button = makeAnswerButton(accessibilityIdentifier: "questionAnswerButton4")
        [answer1Button, answer2Button, answer3Button, answer4Button].forEach { button in
            button.addTarget(self, action: #selector(answerChosen(_:)), for: .touchUpInside)
        }
        questionButtons = [answer1Button, answer2Button, answer3Button, answer4Button]
        
        answersStackView = UIStackView(arrangedSubviews: [answer1Button, answer2Button, answer3Button, answer4Button])
        answersStackView.accessibilityIdentifier = "questionAnswersStackView"
        answersStackView.axis = .vertical
        answersStackView.spacing = 14
        answersStackView.distribution = .fillEqually
        answersStackView.translatesAutoresizingMaskIntoConstraints = false
        
        nextButton = makeActionButton(title: "Далее", accessibilityIdentifier: "questionNextButton", isPrimary: true)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        
        backButton = makeActionButton(title: "Назад", accessibilityIdentifier: "questionBackButton", isPrimary: false)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        [themeNameLabel, questionNumberLabel, questionCardView, nextButton, backButton].forEach(rootView.addSubview)
        [timerContainerView, questionLabel, answersStackView].forEach(questionCardView.addSubview)
        timerContainerView.addSubview(timerBar)
        
        NSLayoutConstraint.activate([
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 24),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            
            questionNumberLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: 10),
            questionNumberLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            questionNumberLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            
            questionCardView.topAnchor.constraint(equalTo: questionNumberLabel.bottomAnchor, constant: 18),
            questionCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            questionCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            
            timerContainerView.topAnchor.constraint(equalTo: questionCardView.topAnchor, constant: 22),
            timerContainerView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: 22),
            timerContainerView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -22),
            timerContainerView.heightAnchor.constraint(equalToConstant: 14),
            
            timerBar.centerYAnchor.constraint(equalTo: timerContainerView.centerYAnchor),
            timerBar.leadingAnchor.constraint(equalTo: timerContainerView.leadingAnchor, constant: 4),
            timerBar.trailingAnchor.constraint(equalTo: timerContainerView.trailingAnchor, constant: -4),
            timerBar.heightAnchor.constraint(equalToConstant: 8),
            
            questionLabel.topAnchor.constraint(equalTo: timerContainerView.bottomAnchor, constant: 24),
            questionLabel.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: 22),
            questionLabel.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -22),
            
            answersStackView.topAnchor.constraint(greaterThanOrEqualTo: questionLabel.bottomAnchor, constant: 28),
            answersStackView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: 18),
            answersStackView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -18),
            answersStackView.heightAnchor.constraint(equalToConstant: 248),
            answersStackView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor, constant: -20),
            
            nextButton.topAnchor.constraint(equalTo: questionCardView.bottomAnchor, constant: 22),
            nextButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: 238),
            nextButton.heightAnchor.constraint(equalToConstant: 54),
            
            backButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: 12),
            backButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 238),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -22)
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
    
    private func makeAnswerButton(accessibilityIdentifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.gray, for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.titleLabel?.numberOfLines = 2
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .defaultButton
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.2).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func makeActionButton(title: String, accessibilityIdentifier: String, isPrimary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = isPrimary ? UIColor.white.withAlphaComponent(0.22) : UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = isPrimary ? 22 : 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(isPrimary ? 0.5 : 0.34).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = isPrimary ? 0.2 : 0
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func colorAndDisableButtons() {
        questionButtons?.forEach() { button in
            button.isEnabled = false
            guard let presenter else { return }
            if presenter.checkAnswerButtonTitle(selectedAnswer: button) {
                button.setTitleColor(.white, for: .disabled)
                button.backgroundColor = .correctAnswerButton
                animationsEngine.animateBackgroundColor(button, color: UIColor.correctAnswerButton.cgColor, duration: animationsDuration)
            } else {
                button.backgroundColor = .wrongAnswerButton
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

