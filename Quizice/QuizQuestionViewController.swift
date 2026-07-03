import UIKit
import AVKit
#if DEBUG
import SwiftUI
#endif

final class QuizQuestionViewController: UIViewController, QuizQuestionViewControllerProtocol {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
        static let correctSoundName = "Quizice Correct"
        static let incorrectSoundName = "Quizice Incorrect"
        static let soundExtension = "m4a"
        static let disabledAnswerPlaceholder = "—"
    }
    
    private enum AccessibilityID {
        static let rootView = "questionRootView"
        static let themeLabel = "questionThemeLabel"
        static let questionNumberLabel = "questionNumberLabel"
        static let questionCardView = "questionCardView"
        static let questionTextLabel = "questionTextLabel"
        static let timerContainerView = "questionTimerContainerView"
        static let timerProgressView = "questionTimerProgressView"
        static let answersStackView = "questionAnswersStackView"
        static let answerButtonPrefix = "questionAnswerButton"
        static let nextButton = "questionNextButton"
        static let backButton = "questionBackButton"
    }
    
    private enum Layout {
        static let topInset: CGFloat = 24
        static let rootHorizontalInset: CGFloat = 24
        static let questionNumberTopSpacing: CGFloat = 10
        static let cardTopSpacing: CGFloat = 18
        static let cardHorizontalInset: CGFloat = 20
        static let timerTopInset: CGFloat = 22
        static let timerHorizontalInset: CGFloat = 22
        static let timerContainerHeight: CGFloat = 14
        static let timerBarHorizontalInset: CGFloat = 4
        static let timerBarHeight: CGFloat = 8
        static let questionTopSpacing: CGFloat = 24
        static let questionHorizontalInset: CGFloat = 22
        static let answersTopMinimumSpacing: CGFloat = 28
        static let answersHorizontalInset: CGFloat = 18
        static let answersHeight: CGFloat = 248
        static let answersBottomInset: CGFloat = 20
        static let actionTopSpacing: CGFloat = 22
        static let actionButtonWidth: CGFloat = 238
        static let primaryActionButtonHeight: CGFloat = 54
        static let secondaryActionButtonHeight: CGFloat = 50
        static let actionButtonSpacing: CGFloat = 12
        static let bottomMaximumInset: CGFloat = 22
        static let answersStackSpacing: CGFloat = 14
    }
    
    private enum Typography {
        static let themeFontSize: CGFloat = 24
        static let questionNumberFontSize: CGFloat = 18
        static let questionFontSize: CGFloat = 26
        static let answerButtonFontSize: CGFloat = 18
        static let actionButtonFontSize: CGFloat = 20
        static let unlimitedNumberOfLines = 0
        static let answerButtonNumberOfLines = 2
    }
    
    private enum Appearance {
        static let cardBackgroundAlpha: CGFloat = 0.26
        static let cardCornerRadius: CGFloat = 28
        static let cardBorderWidth: CGFloat = 1
        static let cardBorderAlpha: CGFloat = 0.18
        static let cardShadowOpacity: Float = 0.22
        static let cardShadowRadius: CGFloat = 16
        static let cardShadowOffset = CGSize(width: 0, height: 10)
        
        static let timerContainerBackgroundAlpha: CGFloat = 0.14
        static let timerContainerCornerRadius: CGFloat = 8
        static let timerTrackAlpha: CGFloat = 0.25
        static let timerBarCornerRadius: CGFloat = 4
        static let timerActiveColor = UIColor.defaultButton
        static let timerCorrectColor = UIColor.correctAnswerBar
        static let timerWrongColor = UIColor.wrongAnswerBar
        
        static let answerDisabledTitleColor = UIColor.gray
        static let answerCornerRadius: CGFloat = 18
        static let answerBorderWidth: CGFloat = 1
        static let answerBorderAlpha: CGFloat = 0.2
        
        static let disabledButtonTitleAlpha: CGFloat = 0.45
        static let primaryButtonBackgroundAlpha: CGFloat = 0.22
        static let secondaryButtonBackgroundAlpha: CGFloat = 0.12
        static let primaryButtonCornerRadius: CGFloat = 22
        static let secondaryButtonCornerRadius: CGFloat = 20
        static let actionButtonBorderWidth: CGFloat = 1
        static let primaryButtonBorderAlpha: CGFloat = 0.5
        static let secondaryButtonBorderAlpha: CGFloat = 0.34
        static let primaryButtonShadowOpacity: Float = 0.2
        static let secondaryButtonShadowOpacity: Float = 0
        static let actionButtonShadowRadius: CGFloat = 10
        static let actionButtonShadowOffset = CGSize(width: 0, height: 6)
    }
    
    private enum AnimationTiming {
        static let answerFeedbackDuration: Double = 0.15
        static let nextButtonEnableDuration: TimeInterval = 1
    }
    
    private enum ActionButtonStyle {
        case primary
        case secondary
        
        var backgroundAlpha: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonBackgroundAlpha
            case .secondary:
                return Appearance.secondaryButtonBackgroundAlpha
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonCornerRadius
            case .secondary:
                return Appearance.secondaryButtonCornerRadius
            }
        }
        
        var borderAlpha: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonBorderAlpha
            case .secondary:
                return Appearance.secondaryButtonBorderAlpha
            }
        }
        
        var shadowOpacity: Float {
            switch self {
            case .primary:
                return Appearance.primaryButtonShadowOpacity
            case .secondary:
                return Appearance.secondaryButtonShadowOpacity
            }
        }
    }
    
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
    
    private let hapticFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private var soundOfCorrectAnswerPlayer: AVAudioPlayer!
    private var soundOfIncorrectAnswerPlayer: AVAudioPlayer!
    
    var presenter: QuizQuestionPresenterProtocol?
    
    private var answerButtons: [UIButton] {
        [answer1Button, answer2Button, answer3Button, answer4Button]
    }
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: Content.backgroundImageName) ?? UIImage())
        rootView.accessibilityIdentifier = AccessibilityID.rootView
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadAnswerSounds()
        configurePresenter(QuizQuestionPresenter())
        presenter?.viewDidLoad()
        hapticFeedback.prepare()
    }
    
    func updateProgress(_ progress: Float) {
        timerBar.progress = progress
    }
    
    func showTimeExpired() {
        colorAndDisableButtons()
        animateTimerBarColor(Appearance.timerWrongColor)
        hapticFeedback.notificationOccurred(.error)
        nextButton.isEnabled = true
    }
    
    private func configurePresenter(_ presenter: QuizQuestionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureHeaderLabels()
        configureQuestionCard()
        configureQuestionContent()
        configureTimerViews()
        configureAnswerButtons()
        configureAnswersStackView()
        configureActionButtons()
        addSubviews(to: rootView)
        activateLayoutConstraints(in: rootView)
    }
    
    private func configureHeaderLabels() {
        themeNameLabel = makeLabel(font: .systemFont(ofSize: Typography.themeFontSize, weight: .semibold))
        themeNameLabel.accessibilityIdentifier = AccessibilityID.themeLabel
        
        questionNumberLabel = makeLabel(font: .systemFont(ofSize: Typography.questionNumberFontSize, weight: .medium))
        questionNumberLabel.accessibilityIdentifier = AccessibilityID.questionNumberLabel
    }
    
    private func configureQuestionCard() {
        questionCardView = UIView()
        questionCardView.accessibilityIdentifier = AccessibilityID.questionCardView
        questionCardView.backgroundColor = UIColor.black.withAlphaComponent(Appearance.cardBackgroundAlpha)
        questionCardView.layer.cornerRadius = Appearance.cardCornerRadius
        questionCardView.layer.borderWidth = Appearance.cardBorderWidth
        questionCardView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.cardBorderAlpha).cgColor
        questionCardView.layer.shadowColor = UIColor.black.cgColor
        questionCardView.layer.shadowOpacity = Appearance.cardShadowOpacity
        questionCardView.layer.shadowRadius = Appearance.cardShadowRadius
        questionCardView.layer.shadowOffset = Appearance.cardShadowOffset
        questionCardView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureQuestionContent() {
        questionLabel = makeLabel(font: .systemFont(ofSize: Typography.questionFontSize, weight: .bold))
        questionLabel.accessibilityIdentifier = AccessibilityID.questionTextLabel
        questionLabel.adjustsFontSizeToFitWidth = true
        questionLabel.numberOfLines = Typography.unlimitedNumberOfLines
    }
    
    private func configureTimerViews() {
        timerContainerView = UIView()
        timerContainerView.accessibilityIdentifier = AccessibilityID.timerContainerView
        timerContainerView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.timerContainerBackgroundAlpha)
        timerContainerView.layer.cornerRadius = Appearance.timerContainerCornerRadius
        timerContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        timerBar = UIProgressView(progressViewStyle: .default)
        timerBar.accessibilityIdentifier = AccessibilityID.timerProgressView
        timerBar.translatesAutoresizingMaskIntoConstraints = false
        setTimerBarColor(Appearance.timerActiveColor)
        timerBar.trackTintColor = UIColor.white.withAlphaComponent(Appearance.timerTrackAlpha)
        timerBar.layer.cornerRadius = Appearance.timerBarCornerRadius
        timerBar.clipsToBounds = true
    }
    
    private func configureAnswerButtons() {
        answer1Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 1))
        answer2Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 2))
        answer3Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 3))
        answer4Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 4))
        
        answerButtons.forEach { button in
            button.addTarget(self, action: #selector(answerChosen(_:)), for: .touchUpInside)
        }
    }
    
    private func configureAnswersStackView() {
        answersStackView = UIStackView(arrangedSubviews: answerButtons)
        answersStackView.accessibilityIdentifier = AccessibilityID.answersStackView
        answersStackView.axis = .vertical
        answersStackView.spacing = Layout.answersStackSpacing
        answersStackView.distribution = .fillEqually
        answersStackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureActionButtons() {
        nextButton = makeActionButton(title: L10n.Common.next, accessibilityIdentifier: AccessibilityID.nextButton, style: .primary)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)
        
        backButton = makeActionButton(title: L10n.Common.back, accessibilityIdentifier: AccessibilityID.backButton, style: .secondary)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    private func addSubviews(to rootView: UIView) {
        [themeNameLabel, questionNumberLabel, questionCardView, nextButton, backButton].forEach(rootView.addSubview)
        [timerContainerView, questionLabel, answersStackView].forEach(questionCardView.addSubview)
        timerContainerView.addSubview(timerBar)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.topInset),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.rootHorizontalInset),
            
            questionNumberLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: Layout.questionNumberTopSpacing),
            questionNumberLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset),
            questionNumberLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.rootHorizontalInset),
            
            questionCardView.topAnchor.constraint(equalTo: questionNumberLabel.bottomAnchor, constant: Layout.cardTopSpacing),
            questionCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.cardHorizontalInset),
            questionCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.cardHorizontalInset),
            
            timerContainerView.topAnchor.constraint(equalTo: questionCardView.topAnchor, constant: Layout.timerTopInset),
            timerContainerView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.timerHorizontalInset),
            timerContainerView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.timerHorizontalInset),
            timerContainerView.heightAnchor.constraint(equalToConstant: Layout.timerContainerHeight),
            
            timerBar.centerYAnchor.constraint(equalTo: timerContainerView.centerYAnchor),
            timerBar.leadingAnchor.constraint(equalTo: timerContainerView.leadingAnchor, constant: Layout.timerBarHorizontalInset),
            timerBar.trailingAnchor.constraint(equalTo: timerContainerView.trailingAnchor, constant: -Layout.timerBarHorizontalInset),
            timerBar.heightAnchor.constraint(equalToConstant: Layout.timerBarHeight),
            
            questionLabel.topAnchor.constraint(equalTo: timerContainerView.bottomAnchor, constant: Layout.questionTopSpacing),
            questionLabel.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.questionHorizontalInset),
            questionLabel.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.questionHorizontalInset),
            
            answersStackView.topAnchor.constraint(greaterThanOrEqualTo: questionLabel.bottomAnchor, constant: Layout.answersTopMinimumSpacing),
            answersStackView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.answersHorizontalInset),
            answersStackView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.answersHorizontalInset),
            answersStackView.heightAnchor.constraint(equalToConstant: Layout.answersHeight),
            answersStackView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor, constant: -Layout.answersBottomInset),
            
            nextButton.topAnchor.constraint(equalTo: questionCardView.bottomAnchor, constant: Layout.actionTopSpacing),
            nextButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: Layout.actionButtonWidth),
            nextButton.heightAnchor.constraint(equalToConstant: Layout.primaryActionButtonHeight),
            
            backButton.topAnchor.constraint(equalTo: nextButton.bottomAnchor, constant: Layout.actionButtonSpacing),
            backButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: Layout.actionButtonWidth),
            backButton.heightAnchor.constraint(equalToConstant: Layout.secondaryActionButtonHeight),
            backButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.bottomMaximumInset)
        ])
    }
    
    private func loadAnswerSounds() {
        if
            let correctSoundURL = Bundle.main.url(forResource: Content.correctSoundName, withExtension: Content.soundExtension),
            let incorrectSoundURL = Bundle.main.url(forResource: Content.incorrectSoundName, withExtension: Content.soundExtension) {
            soundOfCorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: correctSoundURL)
            soundOfIncorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: incorrectSoundURL)
        } else {
            print(L10n.Question.audioLoadFailure)
        }
    }
    
    private func answerButtonAccessibilityIdentifier(index: Int) -> String {
        "\(AccessibilityID.answerButtonPrefix)\(index)"
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
        button.setTitleColor(Appearance.answerDisabledTitleColor, for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: Typography.answerButtonFontSize, weight: .semibold)
        button.titleLabel?.numberOfLines = Typography.answerButtonNumberOfLines
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .defaultButton
        button.layer.cornerRadius = Appearance.answerCornerRadius
        button.layer.borderWidth = Appearance.answerBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.answerBorderAlpha).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func makeActionButton(title: String, accessibilityIdentifier: String, style: ActionButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(Appearance.disabledButtonTitleAlpha), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: Typography.actionButtonFontSize, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(style.backgroundAlpha)
        button.layer.cornerRadius = style.cornerRadius
        button.layer.borderWidth = Appearance.actionButtonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(style.borderAlpha).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = style.shadowOpacity
        button.layer.shadowRadius = Appearance.actionButtonShadowRadius
        button.layer.shadowOffset = Appearance.actionButtonShadowOffset
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func colorAndDisableButtons() {
        answerButtons.forEach { button in
            button.isEnabled = false
            guard let presenter else { return }
            if presenter.checkAnswerButtonTitle(selectedAnswer: button) {
                button.setTitleColor(.white, for: .disabled)
                button.backgroundColor = .correctAnswerButton
                animationsEngine.animateBackgroundColor(button, color: UIColor.correctAnswerButton.cgColor, duration: AnimationTiming.answerFeedbackDuration)
            } else {
                button.backgroundColor = .wrongAnswerButton
                animationsEngine.animateBackgroundColor(button, color: UIColor.wrongAnswerButton.cgColor, duration: AnimationTiming.answerFeedbackDuration)
            }
        }
    }
    
    func resetAllColors() {
        answerButtons.forEach { button in
            button.backgroundColor = .defaultButton
            button.setTitleColor(Appearance.answerDisabledTitleColor, for: .disabled)
            button.isEnabled = true
        }
        setTimerBarColor(Appearance.timerActiveColor)
    }
    
    func loadQuestionToView(themeName: String, questionText: String, questionNumberText: String, currentAnswers: [String]) {
        resetAllColors()
        
        timerBar.progress = presenter?.currentProgress ?? .zero
        themeNameLabel.text = themeName
        questionLabel.text = questionText
        applyAnswers(currentAnswers)
        questionNumberLabel.text = questionNumberText
        nextButton.isEnabled = false
        presenter?.startTimer()
    }
    
    private func applyAnswers(_ currentAnswers: [String]) {
        for (index, button) in answerButtons.enumerated() {
            let hasAnswer = currentAnswers.indices.contains(index)
            button.setTitle(hasAnswer ? currentAnswers[index] : L10n.Question.unavailableAnswer, for: .normal)
            button.isEnabled = hasAnswer
        }
    }
    
    func showQuestionUnavailable(themeName: String?, message: String) {
        themeNameLabel.text = themeName ?? L10n.Question.fallbackTheme
        questionNumberLabel.text = L10n.Question.unavailableNumber
        questionLabel.text = message
        timerBar.progress = .zero
        setTimerBarColor(Appearance.timerActiveColor)
        answerButtons.forEach { button in
            button.setTitle(Content.disabledAnswerPlaceholder, for: .normal)
            button.backgroundColor = .defaultButton
            button.setTitleColor(Appearance.answerDisabledTitleColor, for: .disabled)
            button.isEnabled = false
        }
        nextButton.isEnabled = false
    }
    
    func correctAnswerTapped(isTrue: Bool) {
        if isTrue {
            soundOfCorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.success)
            animateTimerBarColor(Appearance.timerCorrectColor)
        } else {
            soundOfIncorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.error)
            animateTimerBarColor(Appearance.timerWrongColor)
        }
    }

    private func setTimerBarColor(_ color: UIColor) {
        timerBar.progressTintColor = color
        timerBar.tintColor = color
    }

    private func animateTimerBarColor(_ color: UIColor) {
        UIView.transition(
            with: timerBar,
            duration: AnimationTiming.answerFeedbackDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                self.setTimerBarColor(color)
            }
        )
    }
    
    func showResults() {
        let viewController = QuizResultViewController()
        viewController.modalPresentationStyle = .fullScreen
        presenter?.configureResultPresenter(viewController: viewController)
        present(viewController, animated: true)
    }
    
    private func resetSoundPlayers() {
        soundOfCorrectAnswerPlayer?.stop()
        soundOfCorrectAnswerPlayer?.currentTime = .zero
        soundOfIncorrectAnswerPlayer?.stop()
        soundOfIncorrectAnswerPlayer?.currentTime = .zero
    }
    
    @IBAction func answerChosen(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        
        hapticFeedback.prepare()
        resetSoundPlayers()
        colorAndDisableButtons()
        presenter?.checkAnswer(sender)
        presenter?.stopTimer()
        UIView.animate(withDuration: AnimationTiming.nextButtonEnableDuration) {
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

#if DEBUG
#Preview("Question") {
    let viewController = QuizQuestionViewController()
    viewController.loadViewIfNeeded()
    viewController.loadQuestionToView(
        themeName: "История и культура",
        questionText: "Какой город был столицей Российской империи большую часть XVIII века?",
        questionNumberText: "Вопрос №3",
        currentAnswers: ["Москва", "Санкт-Петербург", "Казань", "Новгород"]
    )
    viewController.updateProgress(0.62)
    return viewController
}
#endif
