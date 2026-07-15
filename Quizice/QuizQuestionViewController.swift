import UIKit
import AVKit
#if DEBUG
import SwiftUI
#endif

final class QuizQuestionViewController: BaseQuizViewController, QuizQuestionViewControllerProtocol, QuizCardSlideTransitionSource, QuizCardSlideTransitionDestination {
    private enum Content {
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
        static let closeButton = "questionCloseButton"
        static let scrollView = "questionScrollView"
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
        static let questionSurroundingMinimumSpacing: CGFloat = 24
        static let questionHorizontalInset: CGFloat = 22
        static let answersHorizontalInset: CGFloat = 18
        static let answerMinimumHeight: CGFloat = 52
        static let answerContentHorizontalInset: CGFloat = 12
        static let answerContentVerticalInset: CGFloat = 6
        static let questionTargetMaximumHeight: CGFloat = 144
        static let answersBottomInset: CGFloat = 20
        static let actionTopSpacing: CGFloat = 22
        static let cardBottomInset: CGFloat = 18
        static let actionButtonWidth: CGFloat = 238
        static let primaryActionButtonHeight: CGFloat = 54
        static let bottomMaximumInset: CGFloat = 22
        static let answersStackSpacing: CGFloat = 14
        static let closeButtonSize: CGFloat = 44
        static let closeButtonTrailingInset: CGFloat = 20
        static let maximumContentWidth: CGFloat = 430
    }
    
    private enum Typography {
        static let themeFontSize: CGFloat = 24
        static let questionNumberFontSize: CGFloat = 18
        static let questionFontSize: CGFloat = 26
        static let answerButtonFontSize: CGFloat = 18
        static let actionButtonFontSize: CGFloat = 20
        static let themeMinimumScaleFactor: CGFloat = 0.70
        static let questionMinimumScaleFactor: CGFloat = 0.72
        static let answerMinimumScaleFactor: CGFloat = 0.72
        static let fontSearchIterations = 10
        static let maximumFontLayoutPasses = 3
        static let fontSizeComparisonTolerance: CGFloat = 0.1
        static let unlimitedNumberOfLines = 0
        static let answerButtonNumberOfLines = 0
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
        static let questionNumberTransitionDuration: TimeInterval = 0.18
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
    private var scrollView: UIScrollView!
    private var timerContainerView: UIView!
    private var timerBar: UIProgressView!
    private var questionTopSpacingGuide: UILayoutGuide!
    private var questionBottomSpacingGuide: UILayoutGuide!
    private var answersStackView: UIStackView!
    private var answer1Button: UIButton!
    private var answer2Button: UIButton!
    private var answer3Button: UIButton!
    private var answer4Button: UIButton!
    private var answerHeightConstraints: [NSLayoutConstraint] = []
    private var nextButton: UIButton!
    private var closeButton: UIButton!
    
    private let hapticFeedback = UINotificationFeedbackGenerator()
    private let animationsEngine = Animations()
    private var soundOfCorrectAnswerPlayer: AVAudioPlayer!
    private var soundOfIncorrectAnswerPlayer: AVAudioPlayer!
    weak var router: QuizRouting?
    private var currentAnswerOptions: [QuizAnswerOption] = []
    var analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared
    private var hasLoadedQuestion = false
    private var isQuestionTransitionInProgress = false
    private var isFittingContentFonts = false
    private weak var outgoingQuestionCardSnapshot: UIView?
    
    var presenter: QuizQuestionPresenterProtocol?

    var cardSlideTransitionSourceView: UIView { questionCardView }
    var cardSlideTransitionDestinationView: UIView { questionCardView }
    var cardSlideTransitionHorizontalInset: CGFloat { Layout.cardHorizontalInset }
    var cardSlideTransitionDestinationCompanionViews: [UIView] {
        let views: [UIView?] = [themeNameLabel, questionNumberLabel]
        return views.compactMap { $0 }
    }
    
    private var answerButtons: [UIButton] {
        [answer1Button, answer2Button, answer3Button, answer4Button]
    }

    private var questionChromeViews: [UIView] {
        let views: [UIView?] = [themeNameLabel, questionNumberLabel, nextButton, closeButton]
        return views.compactMap { $0 }
    }
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .systemBackground
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
        if presenter == nil {
            configurePresenter(QuizQuestionPresenter(analytics: analytics))
        }
        applyAppearance()
        presenter?.viewDidLoad()
        installLocalizationObserver()

        hapticFeedback.prepare()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        fitContentFonts()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.track(.screenView(screen: .quizQuestion, theme: presenter?.analyticsProgress.theme ?? .unknown))
    }

    // MARK: - Timer methods

    func updateProgress(_ progress: Float) {
        timerBar.progress = progress
        timerBar.accessibilityValue = NumberFormatter.localizedString(
            from: NSNumber(value: max(0, min(progress, 1))),
            number: .percent
        )
    }
    
    func showTimeExpired() {
        let appearance = currentAppearance()
        colorAndDisableButtons()
        animateTimerBarColor(timerFeedbackColor(isCorrect: false, appearance: appearance))
        hapticFeedback.notificationOccurred(.error)
        nextButton.isEnabled = true
    }
    
    func configurePresenter(_ presenter: QuizQuestionPresenterProtocol) {
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
        themeNameLabel.numberOfLines = 1
        themeNameLabel.adjustsFontSizeToFitWidth = true
        themeNameLabel.minimumScaleFactor = Typography.themeMinimumScaleFactor
        themeNameLabel.allowsDefaultTighteningForTruncation = true
        themeNameLabel.baselineAdjustment = .alignCenters
        
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
        questionLabel.numberOfLines = Typography.unlimitedNumberOfLines
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    private func configureTimerViews() {
        timerContainerView = UIView()
        timerContainerView.accessibilityIdentifier = AccessibilityID.timerContainerView
        timerContainerView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.timerContainerBackgroundAlpha)
        timerContainerView.layer.cornerRadius = Appearance.timerContainerCornerRadius
        timerContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        timerBar = UIProgressView(progressViewStyle: .default)
        timerBar.accessibilityIdentifier = AccessibilityID.timerProgressView
        timerBar.accessibilityLabel = L10n.Question.timeRemaining
        timerBar.isAccessibilityElement = true
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
        answersStackView.distribution = .fill
        answersStackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureActionButtons() {
        nextButton = makeActionButton(title: L10n.Common.next, accessibilityIdentifier: AccessibilityID.nextButton, style: .primary)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        closeButton = UIButton(type: .system)
        closeButton.accessibilityIdentifier = AccessibilityID.closeButton
        closeButton.accessibilityLabel = L10n.Common.exit
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            ),
            for: .normal
        )
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.installPressFeedback()
    }
    
    private func addSubviews(to rootView: UIView) {
        scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = AccessibilityID.scrollView
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        [themeNameLabel, questionNumberLabel, closeButton, scrollView, nextButton].forEach(rootView.addSubview)
        scrollView.addSubview(questionCardView)
        [timerContainerView, questionLabel, answersStackView].forEach(questionCardView.addSubview)
        timerContainerView.addSubview(timerBar)
        questionTopSpacingGuide = UILayoutGuide()
        questionBottomSpacingGuide = UILayoutGuide()
        questionCardView.addLayoutGuide(questionTopSpacingGuide)
        questionCardView.addLayoutGuide(questionBottomSpacingGuide)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.topInset),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset + Layout.closeButtonSize),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -(Layout.rootHorizontalInset + Layout.closeButtonSize)),

            closeButton.centerYAnchor.constraint(equalTo: themeNameLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.closeButtonTrailingInset),
            closeButton.widthAnchor.constraint(equalToConstant: Layout.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Layout.closeButtonSize),
            
            questionNumberLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: Layout.questionNumberTopSpacing),
            questionNumberLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset),
            questionNumberLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.rootHorizontalInset),
            
            scrollView.topAnchor.constraint(equalTo: questionNumberLabel.bottomAnchor, constant: Layout.cardTopSpacing),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -Layout.actionTopSpacing),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            questionCardView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            questionCardView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            questionCardView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Layout.cardHorizontalInset),
            questionCardView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Layout.cardHorizontalInset),
            questionCardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            questionCardView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.cardBottomInset),
            
            timerContainerView.topAnchor.constraint(equalTo: questionCardView.topAnchor, constant: Layout.timerTopInset),
            timerContainerView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.timerHorizontalInset),
            timerContainerView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.timerHorizontalInset),
            timerContainerView.heightAnchor.constraint(equalToConstant: Layout.timerContainerHeight),
            
            timerBar.centerYAnchor.constraint(equalTo: timerContainerView.centerYAnchor),
            timerBar.leadingAnchor.constraint(equalTo: timerContainerView.leadingAnchor, constant: Layout.timerBarHorizontalInset),
            timerBar.trailingAnchor.constraint(equalTo: timerContainerView.trailingAnchor, constant: -Layout.timerBarHorizontalInset),
            timerBar.heightAnchor.constraint(equalToConstant: Layout.timerBarHeight),

            questionTopSpacingGuide.topAnchor.constraint(equalTo: timerBar.bottomAnchor),
            questionTopSpacingGuide.bottomAnchor.constraint(equalTo: questionLabel.topAnchor),
            questionTopSpacingGuide.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.questionSurroundingMinimumSpacing
            ),

            questionLabel.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.questionHorizontalInset),
            questionLabel.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.questionHorizontalInset),

            questionBottomSpacingGuide.topAnchor.constraint(equalTo: questionLabel.bottomAnchor),
            questionBottomSpacingGuide.bottomAnchor.constraint(equalTo: answersStackView.topAnchor),
            questionBottomSpacingGuide.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.questionSurroundingMinimumSpacing
            ),
            questionTopSpacingGuide.heightAnchor.constraint(equalTo: questionBottomSpacingGuide.heightAnchor),

            answersStackView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor, constant: Layout.answersHorizontalInset),
            answersStackView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor, constant: -Layout.answersHorizontalInset),
            answersStackView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor, constant: -Layout.answersBottomInset),
            
            nextButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: Layout.actionButtonWidth),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.primaryActionButtonHeight),
            nextButton.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.bottomMaximumInset)
        ])

        let cardWidthConstraint = questionCardView.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor,
            constant: -(Layout.cardHorizontalInset * 2)
        )
        cardWidthConstraint.priority = .defaultHigh
        cardWidthConstraint.isActive = true

        questionCardView.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor,
            constant: -Layout.cardBottomInset
        ).isActive = true

        answerHeightConstraints = answerButtons.map { button in
            let constraint = button.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.answerMinimumHeight)
            constraint.isActive = true
            return constraint
        }
    }
    
    private func loadAnswerSounds() {
        if
            let correctSoundURL = Bundle.main.url(forResource: Content.correctSoundName, withExtension: Content.soundExtension),
            let incorrectSoundURL = Bundle.main.url(forResource: Content.incorrectSoundName, withExtension: Content.soundExtension) {
            soundOfCorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: correctSoundURL)
            soundOfIncorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: incorrectSoundURL)
        } else {
            AppLog.audio.error("\(L10n.Question.audioLoadFailure, privacy: .public)")
        }
    }
    
    private func answerButtonAccessibilityIdentifier(index: Int) -> String {
        "\(AccessibilityID.answerButtonPrefix)\(index)"
    }
    
    private func makeLabel(font: UIFont) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = font
        label.adjustsFontForContentSizeCategory = true
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
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = Typography.answerButtonNumberOfLines
        button.titleLabel?.lineBreakMode = .byWordWrapping
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
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIColor.white.withAlphaComponent(style.backgroundAlpha)
        button.layer.cornerRadius = style.cornerRadius
        button.layer.borderWidth = Appearance.actionButtonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(style.borderAlpha).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = style.shadowOpacity
        button.layer.shadowRadius = Appearance.actionButtonShadowRadius
        button.layer.shadowOffset = Appearance.actionButtonShadowOffset
        button.translatesAutoresizingMaskIntoConstraints = false
        button.installPressFeedback()
        return button
    }
    
    private func colorAndDisableButtons() {
        let appearance = currentAppearance()
        for (index, button) in answerButtons.enumerated() {
            button.isEnabled = false
            guard
                let presenter,
                currentAnswerOptions.indices.contains(index)
            else { continue }
            switch presenter.answerFeedback(for: currentAnswerOptions[index].id) {
            case .correct:
                applyAnswerFeedback(.correct, to: button, appearance: appearance, animated: true)
            case .wrong:
                applyAnswerFeedback(.wrong, to: button, appearance: appearance, animated: true)
            case .normal:
                applyAnswerFeedback(.normal, to: button, appearance: appearance, animated: true)
            }
        }
    }
    
    func resetAllColors() {
        let appearance = currentAppearance()
        answerButtons.forEach { button in
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = true
        }
        setTimerBarColor(quizThemeAccentColor(for: appearance))
    }
    
    func loadQuestionToView(_ viewModel: QuizQuestionViewModel) {
        guard !isQuestionTransitionInProgress else { return }

        guard hasLoadedQuestion else {
            applyQuestion(viewModel, updatesQuestionNumber: true)
            hasLoadedQuestion = true
            presenter?.startTimer()
            return
        }

        guard shouldAnimateQuestionTransition else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        animateQuestionTransition(to: viewModel)
    }

    private var shouldAnimateQuestionTransition: Bool {
        questionCardView.window != nil && !UIAccessibility.isReduceMotionEnabled
    }

    private func applyQuestion(_ viewModel: QuizQuestionViewModel, updatesQuestionNumber: Bool) {
        resetQuestionScrollPosition()
        resetAllColors()
        
        timerBar.progress = presenter?.currentProgress ?? .zero
        themeNameLabel.text = viewModel.themeName
        questionLabel.text = viewModel.questionText
        applyAnswers(viewModel.answers)
        if updatesQuestionNumber {
            questionNumberLabel.text = viewModel.questionNumberText
        }
        nextButton.isEnabled = false
    }

    private func resetQuestionScrollPosition() {
        let topOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: false)
    }

    private func animateQuestionTransition(to viewModel: QuizQuestionViewModel) {
        guard let containerView = questionCardView.superview else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        containerView.layoutIfNeeded()
        guard let outgoingCardSnapshot = questionCardView.snapshotView(afterScreenUpdates: false) else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        isQuestionTransitionInProgress = true
        questionCardView.isUserInteractionEnabled = false
        nextButton.isEnabled = false

        outgoingCardSnapshot.frame = questionCardView.frame
        containerView.insertSubview(outgoingCardSnapshot, aboveSubview: questionCardView)
        outgoingQuestionCardSnapshot = outgoingCardSnapshot

        let horizontalOffset = QuizCardSlideTransition.horizontalOffset(
            in: containerView,
            horizontalInset: Layout.cardHorizontalInset
        )
        questionCardView.transform = CGAffineTransform(translationX: horizontalOffset, y: 0)
        applyQuestion(viewModel, updatesQuestionNumber: false)

        UIView.transition(
            with: questionNumberLabel,
            duration: AnimationTiming.questionNumberTransitionDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                self.questionNumberLabel.text = viewModel.questionNumberText
            }
        )

        UIView.animate(
            withDuration: QuizCardSlideTransition.questionAdvanceDuration,
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: {
                outgoingCardSnapshot.transform = CGAffineTransform(translationX: -horizontalOffset, y: 0)
                self.questionCardView.transform = .identity
            },
            completion: { _ in
                outgoingCardSnapshot.removeFromSuperview()
                self.outgoingQuestionCardSnapshot = nil
                self.questionCardView.transform = .identity
                self.completeQuestionTransition()
            }
        )
    }

    private func finishQuestionTransition(with viewModel: QuizQuestionViewModel, animatedQuestionNumber: Bool) {
        isQuestionTransitionInProgress = false
        questionCardView.isUserInteractionEnabled = true
        questionCardView.transform = .identity
        applyQuestion(viewModel, updatesQuestionNumber: !animatedQuestionNumber)
        if animatedQuestionNumber {
            UIView.transition(
                with: questionNumberLabel,
                duration: AnimationTiming.questionNumberTransitionDuration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: {
                    self.questionNumberLabel.text = viewModel.questionNumberText
                }
            )
        }
        presenter?.startTimer()
    }

    private func completeQuestionTransition() {
        isQuestionTransitionInProgress = false
        questionCardView.isUserInteractionEnabled = true
        presenter?.startTimer()
    }
    
    private func applyAnswers(_ currentAnswers: [QuizAnswerOption]) {
        currentAnswerOptions = currentAnswers
        for (index, button) in answerButtons.enumerated() {
            let hasAnswer = currentAnswers.indices.contains(index)
            button.setTitle(hasAnswer ? currentAnswers[index].title : L10n.Question.unavailableAnswer, for: .normal)
            button.isEnabled = hasAnswer
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        fitContentFonts()
    }
    
    func showQuestionUnavailable(themeName: String?, message: String) {
        hasLoadedQuestion = false
        isQuestionTransitionInProgress = false
        outgoingQuestionCardSnapshot?.removeFromSuperview()
        outgoingQuestionCardSnapshot = nil
        questionCardView.transform = .identity
        questionCardView.isUserInteractionEnabled = true
        themeNameLabel.text = themeName ?? L10n.Question.fallbackTheme
        questionNumberLabel.text = L10n.Question.unavailableNumber
        questionLabel.text = message
        currentAnswerOptions = []
        timerBar.progress = .zero
        let appearance = currentAppearance()
        setTimerBarColor(quizThemeAccentColor(for: appearance))
        answerButtons.forEach { button in
            button.setTitle(Content.disabledAnswerPlaceholder, for: .normal)
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = false
        }
        view.setNeedsLayout()
        view.layoutIfNeeded()
        fitContentFonts()
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

    override func applyAppearance() {
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
        setTimerBarColor(quizThemeAccentColor(for: appearance))

        answerButtons.forEach { button in
            button.titleLabel?.font = appearance.typography.font(size: Typography.answerButtonFontSize, weight: .semibold)
            button.layer.cornerRadius = min(appearance.row.cornerRadius, Appearance.answerCornerRadius)
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
        }
        fitContentFonts()

        nextButton?.applyActionAppearance(
            QuizThemeAccentStyle.primaryButtonStyle(themeID: presenter?.themeID, appearance: appearance),
            appearance: appearance,
            textColor: actionTextColor(isPrimary: true, appearance: appearance)
        )
        nextButton?.titleLabel?.font = appearance.typography.font(size: Typography.actionButtonFontSize, weight: .semibold)
        closeButton?.applyActionAppearance(
            appearance.iconButton,
            appearance: appearance,
            textColor: appearance.screenTextColor
        )
    }

    private func actionTextColor(isPrimary: Bool, appearance: AppAppearance) -> UIColor {
        if isPrimary && appearance.designStyle == .clean {
            return appearance.resolvedInterfaceStyle == .dark ? appearance.screenTextColor : .black
        }
        if !isPrimary && appearance.designStyle == .clean {
            return QuizThemeAccentStyle.secondaryButtonTextColor(themeID: presenter?.themeID, appearance: appearance)
        }
        return appearance.screenTextColor
    }

    private func quizThemeAccentColor(for appearance: AppAppearance) -> UIColor {
        QuizThemeAccentStyle.accentColor(themeID: presenter?.themeID, appearance: appearance)
    }

    private func fitContentFonts() {
        guard !isFittingContentFonts else { return }
        isFittingContentFonts = true
        defer { isFittingContentFonts = false }

        for pass in 0..<Typography.maximumFontLayoutPasses {
            questionCardView?.layoutIfNeeded()
            answersStackView?.layoutIfNeeded()

            let questionFontChanged = fitQuestionFont()
            let answerLayoutChanged = fitAnswerFonts()

            answerButtons.forEach {
                $0.setNeedsLayout()
                $0.layoutIfNeeded()
            }

            let requiresAnotherPass = pass == 0 || questionFontChanged || answerLayoutChanged
            guard requiresAnotherPass else { break }
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }

    @discardableResult
    private func fitQuestionFont() -> Bool {
        let baseFont = currentAppearance().typography.font(
            size: Typography.questionFontSize,
            weight: .bold,
            compatibleWith: view.traitCollection
        )
        let contentWidth = questionLabel.bounds.width
        guard contentWidth > .zero else { return false }

        let text = questionLabel.text ?? ""
        let fittedPointSize = fittedPointSize(
            for: text,
            baseFont: baseFont,
            minimumScaleFactor: Typography.questionMinimumScaleFactor,
            contentWidth: contentWidth,
            targetContentHeight: Layout.questionTargetMaximumHeight
        )
        questionLabel.preferredMaxLayoutWidth = contentWidth

        let fittedFont = baseFont.withSize(fittedPointSize)
        guard questionLabel.font.fontName != fittedFont.fontName
            || abs(questionLabel.font.pointSize - fittedFont.pointSize) > Typography.fontSizeComparisonTolerance
        else { return false }

        questionLabel.font = fittedFont
        questionLabel.invalidateIntrinsicContentSize()
        questionLabel.setNeedsLayout()
        return true
    }

    @discardableResult
    private func fitAnswerFonts() -> Bool {
        let baseFont = currentAppearance().typography.font(
            size: Typography.answerButtonFontSize,
            weight: .semibold,
            compatibleWith: view.traitCollection
        )
        let targetContentHeight = Layout.answerMinimumHeight - (Layout.answerContentVerticalInset * 2)
        var requiresLayout = false

        for (index, button) in answerButtons.enumerated() {
            guard let titleLabel = button.titleLabel else { continue }
            let text = button.title(for: .normal) ?? ""
            let contentWidth = button.bounds.width - (Layout.answerContentHorizontalInset * 2)

            guard !text.isEmpty, contentWidth > .zero else {
                if applyAnswerFont(baseFont, to: button) {
                    requiresLayout = true
                }
                if answerHeightConstraints.indices.contains(index),
                   abs(answerHeightConstraints[index].constant - Layout.answerMinimumHeight) > Typography.fontSizeComparisonTolerance {
                    answerHeightConstraints[index].constant = Layout.answerMinimumHeight
                    requiresLayout = true
                }
                continue
            }

            let fittedPointSize = fittedPointSize(
                for: text,
                baseFont: baseFont,
                minimumScaleFactor: Typography.answerMinimumScaleFactor,
                contentWidth: contentWidth,
                targetContentHeight: targetContentHeight
            )

            let fittedFont = baseFont.withSize(fittedPointSize)
            if applyAnswerFont(fittedFont, to: button) {
                requiresLayout = true
            }
            titleLabel.preferredMaxLayoutWidth = contentWidth

            let requiredHeight = max(
                Layout.answerMinimumHeight,
                textHeight(text, font: fittedFont, contentWidth: contentWidth)
                    + (Layout.answerContentVerticalInset * 2)
            )
            if answerHeightConstraints.indices.contains(index),
               abs(answerHeightConstraints[index].constant - requiredHeight) > Typography.fontSizeComparisonTolerance {
                answerHeightConstraints[index].constant = requiredHeight
                requiresLayout = true
            }
        }

        if requiresLayout {
            questionCardView?.setNeedsLayout()
            scrollView?.setNeedsLayout()
            view.setNeedsLayout()
        }
        return requiresLayout
    }

    private func fittedPointSize(
        for text: String,
        baseFont: UIFont,
        minimumScaleFactor: CGFloat,
        contentWidth: CGFloat,
        targetContentHeight: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return baseFont.pointSize }
        guard textHeight(text, font: baseFont, contentWidth: contentWidth) > targetContentHeight else {
            return baseFont.pointSize
        }

        let minimumPointSize = baseFont.pointSize * minimumScaleFactor
        let minimumFont = baseFont.withSize(minimumPointSize)
        guard textHeight(text, font: minimumFont, contentWidth: contentWidth) <= targetContentHeight else {
            return minimumPointSize
        }

        var lowerBound = minimumPointSize
        var upperBound = baseFont.pointSize
        for _ in 0..<Typography.fontSearchIterations {
            let candidate = (lowerBound + upperBound) / 2
            let candidateFont = baseFont.withSize(candidate)
            if textHeight(text, font: candidateFont, contentWidth: contentWidth) <= targetContentHeight {
                lowerBound = candidate
            } else {
                upperBound = candidate
            }
        }
        return lowerBound
    }

    private func textHeight(_ text: String, font: UIFont, contentWidth: CGFloat) -> CGFloat {
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height
        )
    }

    @discardableResult
    private func applyAnswerFont(_ font: UIFont, to button: UIButton) -> Bool {
        guard let titleLabel = button.titleLabel else { return false }
        if titleLabel.font.fontName != font.fontName
            || abs(titleLabel.font.pointSize - font.pointSize) > Typography.fontSizeComparisonTolerance {
            titleLabel.font = font
            titleLabel.invalidateIntrinsicContentSize()
            button.invalidateIntrinsicContentSize()
            button.setNeedsLayout()
            return true
        }
        return false
    }
    
    func showResults(_ result: QuizResultState) {
        fadeQuestionChromeForResultTransition()
        router?.showResult(result)
    }

    private func fadeQuestionChromeForResultTransition() {
        let changes = {
            self.questionChromeViews.forEach { $0.alpha = 0 }
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        UIView.animate(
            withDuration: QuizCardSlideTransition.presentationDuration,
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: changes
        )
    }
    
    private func resetSoundPlayers() {
        soundOfCorrectAnswerPlayer?.stop()
        soundOfCorrectAnswerPlayer?.currentTime = .zero
        soundOfIncorrectAnswerPlayer?.stop()
        soundOfIncorrectAnswerPlayer?.currentTime = .zero
    }
    
    @IBAction func answerChosen(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        guard
            let selectedIndex = answerButtons.firstIndex(where: { $0 === sender }),
            currentAnswerOptions.indices.contains(selectedIndex)
        else { return }
        
        hapticFeedback.prepare()
        resetSoundPlayers()
        colorAndDisableButtons()
        presenter?.checkAnswer(optionID: currentAnswerOptions[selectedIndex].id)
        presenter?.stopTimer()
        nextButton.isEnabled = true
    }
    
    @IBAction func nextButtonTapped() {
        guard !isQuestionTransitionInProgress else { return }
        presenter?.checkQuestionNumberAndProceed()
    }
    
    @objc private func closeButtonTapped() {
        guard presentedViewController == nil else { return }
        presenter?.pauseTimer()
        analytics.track(.quizExitRequested(presenter?.analyticsProgress ?? .empty))

        let alert = UIAlertController(
            title: L10n.Question.exitAlertTitle,
            message: L10n.Question.exitAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.no, style: .cancel) { [weak self] _ in
            self?.cancelExitConfirmation()
        })
        alert.addAction(UIAlertAction(title: L10n.Common.exit, style: .destructive) { [weak self] _ in
            self?.confirmExitAndReturnToThemes()
        })
        present(alert, animated: true)
    }

    func cancelExitConfirmation() {
        analytics.track(.quizExitCancelled(presenter?.analyticsProgress ?? .empty))
        presenter?.resumeTimer()
    }

    func confirmExitAndReturnToThemes() {
        analytics.track(.quizAbandoned(presenter?.analyticsProgress ?? .empty))
        presenter?.resetGameProgress()
        router?.closeQuestion()
    }

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        nextButton.setTitle(L10n.Common.next, for: .normal)
        closeButton.accessibilityLabel = L10n.Common.exit
        timerBar.accessibilityLabel = L10n.Question.timeRemaining
    }
}

private extension AnalyticsQuizProgress {
    static let empty = AnalyticsQuizProgress(
        theme: .unknown,
        answeredQuestions: 0,
        totalQuestions: 0,
        correctAnswers: 0
    )
}

#if DEBUG
#Preview("Question") {
    let viewController = QuizQuestionViewController()
    viewController.loadViewIfNeeded()
    viewController.loadQuestionToView(
        QuizQuestionViewModel(
            themeName: "История и культура",
            questionText: "Какой город был столицей Российской империи большую часть XVIII века?",
            questionNumberText: "Вопрос №3",
            answers: [
                QuizAnswerOption(id: "0", title: "Москва"),
                QuizAnswerOption(id: "1", title: "Санкт-Петербург"),
                QuizAnswerOption(id: "2", title: "Казань"),
                QuizAnswerOption(id: "3", title: "Новгород")
            ]
        )
    )
    viewController.updateProgress(0.62)
    return viewController
}
#endif
