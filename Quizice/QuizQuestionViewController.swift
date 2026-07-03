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
        static let answerFeedbackBorderWidth: CGFloat = 4
        static let radarDimmedAnswerAlpha: CGFloat = 0.34
        
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
        static let answerFeedbackOptions: UIView.AnimationOptions = [.curveEaseInOut, .allowUserInteraction]
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

    private enum AnswerFeedbackState {
        case normal
        case correct
        case wrong
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
    private let appearanceStore = AppAppearanceStore.shared
    private var appearanceObserver: NSObjectProtocol?
    
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
        applyAppearance()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        installAppearanceObserver()
        installAppearanceTraitObserver()
        loadAnswerSounds()
        configurePresenter(QuizQuestionPresenter())
        presenter?.viewDidLoad()
        hapticFeedback.prepare()
    }

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
    }

    func updateProgress(_ progress: Float) {
        timerBar.progress = progress
    }
    
    func showTimeExpired() {
        let appearance = currentAppearance()
        colorAndDisableButtons()
        animateTimerBarColor(timerFeedbackColor(isCorrect: false, appearance: appearance))
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
        let typography = currentAppearance().typography
        themeNameLabel = makeLabel(font: typography.font(size: Typography.themeFontSize, weight: .semibold))
        themeNameLabel.accessibilityIdentifier = AccessibilityID.themeLabel
        
        questionNumberLabel = makeLabel(font: typography.font(size: Typography.questionNumberFontSize, weight: .medium))
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
        questionLabel = makeLabel(font: currentAppearance().typography.font(size: Typography.questionFontSize, weight: .bold))
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
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.answerButtonFontSize, weight: .semibold)
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
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.actionButtonFontSize, weight: .semibold)
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
        let appearance = currentAppearance()
        answerButtons.forEach { button in
            button.isEnabled = false
            guard let presenter else { return }
            if presenter.checkAnswerButtonTitle(selectedAnswer: button) {
                applyAnswerFeedback(.correct, to: button, appearance: appearance, animated: true)
            } else {
                applyAnswerFeedback(.wrong, to: button, appearance: appearance, animated: true)
            }
        }
    }
    
    func resetAllColors() {
        let appearance = currentAppearance()
        answerButtons.forEach { button in
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = true
        }
        setTimerBarColor(appearance.accentColor)
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
        let appearance = currentAppearance()
        setTimerBarColor(appearance.accentColor)
        answerButtons.forEach { button in
            button.setTitle(Content.disabledAnswerPlaceholder, for: .normal)
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = false
        }
        nextButton.isEnabled = false
    }
    
    func correctAnswerTapped(isTrue: Bool) {
        let appearance = currentAppearance()
        if isTrue {
            soundOfCorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.success)
            animateTimerBarColor(timerFeedbackColor(isCorrect: true, appearance: appearance))
        } else {
            soundOfIncorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.error)
            animateTimerBarColor(timerFeedbackColor(isCorrect: false, appearance: appearance))
        }
    }

    private func applyAnswerFeedback(
        _ state: AnswerFeedbackState,
        to button: UIButton,
        appearance: AppAppearance,
        animated: Bool = false
    ) {
        let changes = answerFeedbackChanges(for: state, appearance: appearance)
        button.setTitleColor(changes.normalTitleColor, for: .normal)
        button.setTitleColor(changes.disabledTitleColor, for: .disabled)

        let animations = {
            button.alpha = changes.alpha
            button.backgroundColor = changes.backgroundColor
            button.layer.borderWidth = changes.borderWidth
            button.layer.borderColor = changes.borderColor.cgColor
        }

        if animated {
            UIView.animate(
                withDuration: AnimationTiming.answerFeedbackDuration,
                delay: 0,
                options: AnimationTiming.answerFeedbackOptions,
                animations: animations
            )
        } else {
            animations()
        }

        if animated, changes.shouldAnimateLegacyBackground {
            animationsEngine.animateBackgroundColor(
                button,
                color: changes.backgroundColor.cgColor,
                duration: AnimationTiming.answerFeedbackDuration
            )
        }
    }

    private struct AnswerFeedbackChanges {
        let alpha: CGFloat
        let backgroundColor: UIColor
        let borderWidth: CGFloat
        let borderColor: UIColor
        let normalTitleColor: UIColor
        let disabledTitleColor: UIColor
        let shouldAnimateLegacyBackground: Bool
    }

    private func answerFeedbackChanges(for state: AnswerFeedbackState, appearance: AppAppearance) -> AnswerFeedbackChanges {
        var alpha: CGFloat = 1
        var backgroundColor = appearance.answerDefaultColor
        var borderWidth = appearance.row.borderWidth
        var borderColor = appearance.row.borderColor
        let normalTitleColor = appearance.surfaceTextColor
        var disabledTitleColor = appearance.disabledTextColor
        var shouldAnimateLegacyBackground = false

        switch (appearance.designStyle, state) {
        case (_, .normal):
            break

        case (.clean, .correct):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.correctAnswerColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.clean, .wrong):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.wrongAnswerColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.radar, .correct):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.accentColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.radar, .wrong):
            borderColor = appearance.disabledTextColor
            disabledTitleColor = appearance.disabledTextColor
            alpha = Appearance.radarDimmedAnswerAlpha

        case (_, .correct):
            backgroundColor = appearance.correctAnswerColor
            disabledTitleColor = appearance.surfaceTextColor
            shouldAnimateLegacyBackground = true

        case (_, .wrong):
            backgroundColor = appearance.wrongAnswerColor
            shouldAnimateLegacyBackground = true
        }

        return AnswerFeedbackChanges(
            alpha: alpha,
            backgroundColor: backgroundColor,
            borderWidth: borderWidth,
            borderColor: borderColor,
            normalTitleColor: normalTitleColor,
            disabledTitleColor: disabledTitleColor,
            shouldAnimateLegacyBackground: shouldAnimateLegacyBackground
        )
    }

    private func timerFeedbackColor(isCorrect: Bool, appearance: AppAppearance) -> UIColor {
        switch appearance.designStyle {
        case .radar:
            return isCorrect ? appearance.accentColor : appearance.disabledTextColor
        default:
            return isCorrect ? appearance.correctAnswerColor : appearance.wrongAnswerColor
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

    private func installAppearanceObserver() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .appAppearanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAppearance()
        }
    }

    private func installAppearanceTraitObserver() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (viewController: QuizQuestionViewController, _: UITraitCollection) in
            viewController.applyAppearance()
        }
    }

    private func currentAppearance() -> AppAppearance {
        appearanceStore.appearance(compatibleWith: traitCollection)
    }

    private func applyAppearance() {
        guard isViewLoaded else { return }
        let appearance = currentAppearance()
        appearance.applyBackground(to: view)
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        themeNameLabel?.textColor = appearance.screenTextColor
        themeNameLabel?.font = appearance.typography.font(size: Typography.themeFontSize, weight: .semibold)
        questionNumberLabel?.textColor = appearance.secondaryScreenTextColor
        questionNumberLabel?.font = appearance.typography.font(size: Typography.questionNumberFontSize, weight: .medium)

        questionCardView?.applySurfaceStyle(appearance.card)
        questionLabel?.textColor = appearance.surfaceTextColor
        questionLabel?.font = appearance.typography.font(size: Typography.questionFontSize, weight: .bold)

        timerContainerView?.backgroundColor = appearance.progressTrackColor
        timerContainerView?.layer.cornerRadius = min(appearance.card.cornerRadius, Appearance.timerContainerCornerRadius)
        timerBar?.trackTintColor = appearance.progressTrackColor
        setTimerBarColor(appearance.accentColor)

        answerButtons.forEach { button in
            button.titleLabel?.font = appearance.typography.font(size: Typography.answerButtonFontSize, weight: .semibold)
            button.layer.cornerRadius = min(appearance.row.cornerRadius, Appearance.answerCornerRadius)
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
        }

        nextButton?.applyActionAppearance(appearance.primaryButton, appearance: appearance, textColor: actionTextColor(isPrimary: true, appearance: appearance))
        nextButton?.titleLabel?.font = appearance.typography.font(size: Typography.actionButtonFontSize, weight: .semibold)
        backButton?.applyActionAppearance(appearance.secondaryButton, appearance: appearance, textColor: actionTextColor(isPrimary: false, appearance: appearance))
        backButton?.titleLabel?.font = appearance.typography.font(size: Typography.actionButtonFontSize, weight: .semibold)
    }

    private func actionTextColor(isPrimary: Bool, appearance: AppAppearance) -> UIColor {
        if isPrimary && appearance.designStyle == .clean {
            return appearance.resolvedInterfaceStyle == .dark ? appearance.screenTextColor : .black
        }
        if isPrimary && appearance.designStyle == .pixel {
            return .black
        }
        return appearance.screenTextColor
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
