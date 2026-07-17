import UIKit

private final class AIThemeCardTransformCarrierView: UIView {
    override class var layerClass: AnyClass {
        CATransformLayer.self
    }
}

private final class AIThemeGradientBorderView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()

    var colors: [UIColor] = [] {
        didSet {
            gradientLayer.colors = colors.map(\.cgColor)
        }
    }

    var lineWidth: CGFloat = 1.6 {
        didSet { setNeedsLayout() }
    }

    var cornerRadius: CGFloat = 0 {
        didSet { setNeedsLayout() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.mask = borderMaskLayer
        layer.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        let innerBounds = bounds.insetBy(dx: lineWidth, dy: lineWidth)
        let path = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        path.append(
            UIBezierPath(
                roundedRect: innerBounds,
                cornerRadius: max(cornerRadius - lineWidth, 0)
            )
        )
        borderMaskLayer.frame = bounds
        borderMaskLayer.fillColor = UIColor.black.cgColor
        borderMaskLayer.fillRule = .evenOdd
        borderMaskLayer.path = path.cgPath
    }
}

final class ExpandedAIThemeCardView: UIView, UITextViewDelegate {
    private enum AccessibilityID {
        static let root = "expandedAIThemeCardView"
        static let front = "expandedAIThemeCardFrontView"
        static let back = "expandedAIThemeCardBackView"
        static let closeButton = "expandedAIThemeCardCloseButton"
        static let playButton = "expandedAIThemeCardPlayButton"
        static let backButton = "expandedAIThemeCardBackButton"
        static let promptEditor = "aiThemePromptEditor"
        static let questionCountSelector = "aiThemeQuestionCountSelector"
        static let difficultySelector = "aiThemeDifficultySelector"
        static let submitButton = "aiThemeSubmitButton"
        static let keyboardDoneButton = "aiThemeKeyboardDoneButton"
        static let progressStatus = "aiThemeProgressStatus"
    }

    private enum Layout {
        static let edgeInset: CGFloat = 20
        static let controlInset: CGFloat = 16
        static let iconButtonSize: CGFloat = 44
        static let controlReservation: CGFloat = 56
        static let titleSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 18
        static let selectorSpacing: CGFloat = 8
        static let selectorButtonHeight: CGFloat = 44
        static let promptMinimumHeight: CGFloat = 210
        static let promptTextInset: CGFloat = 12
        static let submitMinimumHeight: CGFloat = 54
        static let submitContentSpacing: CGFloat = 10
        static let scrollBottomInset: CGFloat = 76
    }

    private enum Typography {
        static let titleSize: CGFloat = 30
        static let subtitleSize: CGFloat = 16
        static let promptSize: CGFloat = 17
        static let sectionTitleSize: CGFloat = 16
        static let optionSize: CGFloat = 15
        static let submitSize: CGFloat = 19
        static let progressSize: CGFloat = 15
    }

    private enum Animation {
        static let flipDuration: TimeInterval = 0.28
        static let reducedMotionDuration: TimeInterval = 0.18
        static let perspectiveDistance: CGFloat = 760
    }

    private enum Outline {
        static let gradientLineWidth: CGFloat = 1.6
        static let gradientPink = UIColor(
            red: 255 / 255,
            green: 79 / 255,
            blue: 216 / 255,
            alpha: 1
        )
        static let gradientBlue = UIColor(
            red: 54 / 255,
            green: 163 / 255,
            blue: 255 / 255,
            alpha: 1
        )
        static let radarGlowOpacity: Float = 0.22
        static let radarGlowRadius: CGFloat = 10
    }

    private static let supportedQuestionCounts = AIQuizGenerationConfiguration.supportedQuestionCounts
    private static let supportedDifficulties = AIQuizDifficulty.allCases

    var onClose: (() -> Void)?
    var onFlip: (() -> Void)?
    var onBack: (() -> Void)?
    var onPromptChanged: ((String) -> Void)?
    var onQuestionCountChanged: ((Int) -> Void)?
    var onDifficultyChanged: ((AIQuizDifficulty) -> Void)?
    var onSubmit: (() -> Void)?
    var onAccessibilityEscape: (() -> Void)?
    var reduceMotionProvider: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    var frontFocusView: UIView { promptTextView }
    var backFocusView: UIView { backTitleLabel }
    var transitionSourceView: UIView { self }

    private(set) var face: HomeThemeCardFace = .front

    private let perspectiveStageView = UIView()
    private let shadowProxyView = UIView()
    private let rotatingCardView = AIThemeCardTransformCarrierView()
    private let frontPlaneView = UIView()
    private let backPlaneView = UIView()
    private let frontSurfaceView = UIView()
    private let backSurfaceView = UIView()
    private let frontFaceView = UIView()
    private let backFaceView = UIView()
    private let frontOutlineView = AIThemeGradientBorderView()
    private let backOutlineView = AIThemeGradientBorderView()
    private let flipInteractionButton = UIButton(type: .custom)

    private let frontScrollView = UIScrollView()
    private let frontContentStack = UIStackView()
    private let frontHeaderStack = UIStackView()
    private let frontHeaderTextStack = UIStackView()
    private let frontHeaderControlSpacer = UIView()
    private let frontTitleLabel = UILabel()
    private let frontSubtitleLabel = UILabel()
    private let promptContainerView = UIView()
    private let promptTextView = UITextView()
    private let promptPlaceholderLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let playButton = UIButton(type: .system)

    private let backScrollView = UIScrollView()
    private let backContentStack = UIStackView()
    private let backHeaderStack = UIStackView()
    private let backHeaderControlSpacer = UIView()
    private let backTitleLabel = UILabel()
    private let backButton = UIButton(type: .system)
    private let questionCountLabel = UILabel()
    private let questionCountStack = UIStackView()
    private let difficultyLabel = UILabel()
    private let difficultyStack = UIStackView()
    private let submitButton = UIButton(type: .system)
    private let submitContentStack = UIStackView()
    private let submitActivityIndicator = UIActivityIndicatorView(style: .medium)
    private let submitTitleLabel = UILabel()
    private let progressLabel = UILabel()
    private var questionCountButtons: [UIButton] = []
    private var difficultyButtons: [UIButton] = []
    private var lastRenderedGenerationPhase: HomeAIGenerationPhase?

    private var activeFaceAnimator: UIViewPropertyAnimator?
    private var faceAnimationStart: HomeThemeCardFace?
    private var faceAnimationEnd: HomeThemeCardFace?
    private var faceAnimationTarget: HomeThemeCardFace?
    private var faceAnimationCompletion: ((HomeThemeCardFace) -> Void)?
    private var configuredAppearance: AppAppearance?
    private var configuredSurfaceStyle: AppSurfaceStyle?
    private var configuredShadowStyle = AppShadowStyle.none
    private var cardCornerRadius: CGFloat = 0
    private var isTransitionShadowHidden = false
    private var isTransitionSurfaceHidden = false
    private var selectedQuestionCount = ExpandedAIThemeCardView.supportedQuestionCounts[0]
    private var selectedDifficulty = AIQuizDifficulty.medium
    private var canRevealConfiguration = false
    private var canSubmit = false
    private var isSubmitting = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureHierarchy()
        configureActions()
        configureKeyboardAccessory()
        configureKeyboardObservation()
        normalizeFaces(showing: .front)
    }

    deinit {
        activeFaceAnimator?.stopAnimation(true)
        NotificationCenter.default.removeObserver(self)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shadowProxyView.layer.cornerRadius = cardCornerRadius
        shadowProxyView.layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cardCornerRadius
        ).cgPath
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        guard previousTraitCollection?.preferredContentSizeCategory
            != traitCollection.preferredContentSizeCategory else { return }
        updateAdaptiveSelectorLayout()
    }

    func configure(state: HomeAIThemeCardState, appearance: AppAppearance) {
        configuredAppearance = appearance
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        if promptTextView.text != state.prompt {
            promptTextView.text = state.prompt
            promptTextView.invalidateIntrinsicContentSize()
        }
        updatePromptPlaceholderVisibility()

        selectedQuestionCount = state.selectedQuestionCount
        selectedDifficulty = state.selectedDifficulty
        isSubmitting = state.isSubmitting
        canRevealConfiguration = state.canRevealConfiguration
        canSubmit = state.canSubmit

        backTitleLabel.text = state.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if backTitleLabel.text?.isEmpty != false {
            backTitleLabel.text = L10n.AITheme.title
        }
        let generationPhaseChanged = lastRenderedGenerationPhase != state.generationPhase
        lastRenderedGenerationPhase = state.generationPhase
        progressLabel.text = state.generationPhase?.title
        progressLabel.isHidden = state.generationPhase == nil
        progressLabel.accessibilityElementsHidden = state.generationPhase == nil

        if generationPhaseChanged,
           let phase = state.generationPhase,
           UIAccessibility.isVoiceOverRunning {
            DispatchQueue.main.async { [weak self] in
                guard
                    let self,
                    self.window != nil,
                    self.lastRenderedGenerationPhase == phase
                else { return }
                UIAccessibility.post(notification: .announcement, argument: phase.title)
            }
        }

        applyAppearance(appearance)
        renderControls()
    }

    func setFace(
        _ targetFace: HomeThemeCardFace,
        animated: Bool,
        completion: ((HomeThemeCardFace) -> Void)? = nil
    ) {
        if targetFace == .back {
            resignPrompt()
        }

        if let animator = activeFaceAnimator,
           let startFace = faceAnimationStart,
           let endFace = faceAnimationEnd,
           targetFace == startFace || targetFace == endFace {
            faceAnimationTarget = targetFace
            faceAnimationCompletion = completion
            animator.isReversed = targetFace == startFace
            return
        }

        guard targetFace != face else {
            cancelFaceAnimation()
            normalizeFaces(showing: face)
            completion?(face)
            return
        }

        cancelFaceAnimation()
        guard animated else {
            face = targetFace
            normalizeFaces(showing: targetFace)
            completion?(targetFace)
            return
        }

        let reduceMotion = reduceMotionProvider()
        beginFaceAnimation(
            to: targetFace,
            duration: reduceMotion
                ? Animation.reducedMotionDuration
                : Animation.flipDuration,
            reduceMotion: reduceMotion,
            completion: completion
        )
    }

    func setTransitionShadowHidden(_ isHidden: Bool) {
        isTransitionShadowHidden = isHidden
        applyConfiguredShadow()
    }

    func setTransitionSurfaceHidden(_ isHidden: Bool) {
        isTransitionSurfaceHidden = isHidden
        applyConfiguredSurfaceAppearance()
    }

    @discardableResult
    func focusPrompt() -> Bool {
        guard !isSubmitting else { return false }
        return promptTextView.becomeFirstResponder()
    }

    @discardableResult
    func resignPrompt() -> Bool {
        promptTextView.resignFirstResponder()
    }

    override func accessibilityPerformEscape() -> Bool {
        if let onAccessibilityEscape {
            onAccessibilityEscape()
            return true
        }
        if face == .back, let onBack {
            onBack()
            return true
        }
        guard let onClose else { return false }
        onClose()
        return true
    }

    private func configureHierarchy() {
        backgroundColor = .clear
        accessibilityIdentifier = AccessibilityID.root
        accessibilityViewIsModal = true
        isAccessibilityElement = false
        clipsToBounds = false

        perspectiveStageView.translatesAutoresizingMaskIntoConstraints = false
        perspectiveStageView.clipsToBounds = false
        addSubview(perspectiveStageView)

        shadowProxyView.translatesAutoresizingMaskIntoConstraints = false
        shadowProxyView.backgroundColor = .clear
        shadowProxyView.layer.masksToBounds = false
        perspectiveStageView.addSubview(shadowProxyView)

        rotatingCardView.translatesAutoresizingMaskIntoConstraints = false
        rotatingCardView.backgroundColor = .clear
        rotatingCardView.layer.masksToBounds = false
        perspectiveStageView.addSubview(rotatingCardView)

        configurePlane(
            frontPlaneView,
            surfaceView: frontSurfaceView,
            faceView: frontFaceView,
            outlineView: frontOutlineView,
            accessibilityIdentifier: AccessibilityID.front
        )
        configurePlane(
            backPlaneView,
            surfaceView: backSurfaceView,
            faceView: backFaceView,
            outlineView: backOutlineView,
            accessibilityIdentifier: AccessibilityID.back
        )

        flipInteractionButton.isHidden = true
        flipInteractionButton.isAccessibilityElement = false
        flipInteractionButton.backgroundColor = .clear
        flipInteractionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(flipInteractionButton)

        NSLayoutConstraint.activate([
            perspectiveStageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            perspectiveStageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            perspectiveStageView.topAnchor.constraint(equalTo: topAnchor),
            perspectiveStageView.bottomAnchor.constraint(equalTo: bottomAnchor),

            shadowProxyView.leadingAnchor.constraint(equalTo: perspectiveStageView.leadingAnchor),
            shadowProxyView.trailingAnchor.constraint(equalTo: perspectiveStageView.trailingAnchor),
            shadowProxyView.topAnchor.constraint(equalTo: perspectiveStageView.topAnchor),
            shadowProxyView.bottomAnchor.constraint(equalTo: perspectiveStageView.bottomAnchor),

            rotatingCardView.leadingAnchor.constraint(equalTo: perspectiveStageView.leadingAnchor),
            rotatingCardView.trailingAnchor.constraint(equalTo: perspectiveStageView.trailingAnchor),
            rotatingCardView.topAnchor.constraint(equalTo: perspectiveStageView.topAnchor),
            rotatingCardView.bottomAnchor.constraint(equalTo: perspectiveStageView.bottomAnchor),

            flipInteractionButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            flipInteractionButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            flipInteractionButton.topAnchor.constraint(equalTo: topAnchor),
            flipInteractionButton.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        configureFrontFace()
        configureBackFace()
    }

    private func configurePlane(
        _ planeView: UIView,
        surfaceView: UIView,
        faceView: UIView,
        outlineView: UIView,
        accessibilityIdentifier: String
    ) {
        planeView.translatesAutoresizingMaskIntoConstraints = false
        planeView.backgroundColor = .clear
        planeView.layer.isDoubleSided = false
        rotatingCardView.addSubview(planeView)

        surfaceView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.layer.masksToBounds = true
        planeView.addSubview(surfaceView)

        faceView.accessibilityIdentifier = accessibilityIdentifier
        faceView.translatesAutoresizingMaskIntoConstraints = false
        faceView.backgroundColor = .clear
        surfaceView.addSubview(faceView)

        outlineView.translatesAutoresizingMaskIntoConstraints = false
        surfaceView.addSubview(outlineView)

        NSLayoutConstraint.activate([
            planeView.leadingAnchor.constraint(equalTo: rotatingCardView.leadingAnchor),
            planeView.trailingAnchor.constraint(equalTo: rotatingCardView.trailingAnchor),
            planeView.topAnchor.constraint(equalTo: rotatingCardView.topAnchor),
            planeView.bottomAnchor.constraint(equalTo: rotatingCardView.bottomAnchor),

            surfaceView.leadingAnchor.constraint(equalTo: planeView.leadingAnchor),
            surfaceView.trailingAnchor.constraint(equalTo: planeView.trailingAnchor),
            surfaceView.topAnchor.constraint(equalTo: planeView.topAnchor),
            surfaceView.bottomAnchor.constraint(equalTo: planeView.bottomAnchor),

            faceView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            faceView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            faceView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            faceView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor),

            outlineView.leadingAnchor.constraint(equalTo: surfaceView.leadingAnchor),
            outlineView.trailingAnchor.constraint(equalTo: surfaceView.trailingAnchor),
            outlineView.topAnchor.constraint(equalTo: surfaceView.topAnchor),
            outlineView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor)
        ])
    }

    private func configureFrontFace() {
        configureLabel(frontTitleLabel, numberOfLines: 2)
        frontTitleLabel.text = L10n.AITheme.title
        configureLabel(frontSubtitleLabel, numberOfLines: 0)
        frontSubtitleLabel.text = L10n.AITheme.subtitle

        frontHeaderTextStack.axis = .vertical
        frontHeaderTextStack.spacing = Layout.titleSpacing
        frontHeaderTextStack.addArrangedSubview(frontTitleLabel)
        frontHeaderTextStack.addArrangedSubview(frontSubtitleLabel)

        frontHeaderControlSpacer.translatesAutoresizingMaskIntoConstraints = false
        frontHeaderControlSpacer.widthAnchor.constraint(
            equalToConstant: Layout.controlReservation
        ).isActive = true
        frontHeaderStack.axis = .horizontal
        frontHeaderStack.alignment = .top
        frontHeaderStack.addArrangedSubview(frontHeaderTextStack)
        frontHeaderStack.addArrangedSubview(frontHeaderControlSpacer)

        promptContainerView.translatesAutoresizingMaskIntoConstraints = false
        promptContainerView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Layout.promptMinimumHeight
        ).isActive = true

        promptTextView.accessibilityIdentifier = AccessibilityID.promptEditor
        promptTextView.accessibilityLabel = L10n.AITheme.title
        promptTextView.accessibilityHint = L10n.AITheme.subtitle
        promptTextView.adjustsFontForContentSizeCategory = true
        promptTextView.backgroundColor = .clear
        // The card owns vertical scrolling. A second scroll owner in the editor
        // creates a dead nested-scroll region on compact devices.
        promptTextView.isScrollEnabled = false
        promptTextView.textContainerInset = UIEdgeInsets(
            top: Layout.promptTextInset,
            left: Layout.promptTextInset,
            bottom: Layout.promptTextInset,
            right: Layout.promptTextInset
        )
        promptTextView.delegate = self
        promptTextView.translatesAutoresizingMaskIntoConstraints = false

        promptPlaceholderLabel.text = L10n.AITheme.promptPlaceholder
        promptPlaceholderLabel.adjustsFontForContentSizeCategory = true
        promptPlaceholderLabel.numberOfLines = 0
        promptPlaceholderLabel.isAccessibilityElement = false
        promptPlaceholderLabel.isUserInteractionEnabled = false
        promptPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false

        promptContainerView.addSubview(promptTextView)
        promptContainerView.addSubview(promptPlaceholderLabel)
        NSLayoutConstraint.activate([
            promptTextView.leadingAnchor.constraint(equalTo: promptContainerView.leadingAnchor),
            promptTextView.trailingAnchor.constraint(equalTo: promptContainerView.trailingAnchor),
            promptTextView.topAnchor.constraint(equalTo: promptContainerView.topAnchor),
            promptTextView.bottomAnchor.constraint(equalTo: promptContainerView.bottomAnchor),

            promptPlaceholderLabel.leadingAnchor.constraint(
                equalTo: promptContainerView.leadingAnchor,
                constant: Layout.promptTextInset + 5
            ),
            promptPlaceholderLabel.trailingAnchor.constraint(
                equalTo: promptContainerView.trailingAnchor,
                constant: -(Layout.promptTextInset + 5)
            ),
            promptPlaceholderLabel.topAnchor.constraint(
                equalTo: promptContainerView.topAnchor,
                constant: Layout.promptTextInset + 8
            )
        ])

        frontContentStack.axis = .vertical
        frontContentStack.spacing = Layout.sectionSpacing
        frontContentStack.translatesAutoresizingMaskIntoConstraints = false
        frontContentStack.addArrangedSubview(frontHeaderStack)
        frontContentStack.addArrangedSubview(promptContainerView)

        configureScrollView(frontScrollView)
        frontScrollView.contentInset.bottom = Layout.scrollBottomInset
        frontScrollView.verticalScrollIndicatorInsets.bottom = Layout.scrollBottomInset
        frontScrollView.addSubview(frontContentStack)

        configureIconButton(
            closeButton,
            systemImageName: "xmark",
            accessibilityIdentifier: AccessibilityID.closeButton,
            accessibilityLabel: L10n.ThemeCard.closeAccessibilityLabel
        )
        configureIconButton(
            playButton,
            systemImageName: "play.fill",
            accessibilityIdentifier: AccessibilityID.playButton,
            accessibilityLabel: L10n.ThemeCard.showDescriptionAccessibilityLabel
        )

        frontFaceView.addSubview(frontScrollView)
        frontFaceView.addSubview(closeButton)
        frontFaceView.addSubview(playButton)
        NSLayoutConstraint.activate([
            frontScrollView.leadingAnchor.constraint(equalTo: frontFaceView.leadingAnchor),
            frontScrollView.trailingAnchor.constraint(equalTo: frontFaceView.trailingAnchor),
            frontScrollView.topAnchor.constraint(equalTo: frontFaceView.topAnchor),
            frontScrollView.bottomAnchor.constraint(equalTo: frontFaceView.bottomAnchor),

            frontContentStack.leadingAnchor.constraint(
                equalTo: frontScrollView.contentLayoutGuide.leadingAnchor,
                constant: Layout.edgeInset
            ),
            frontContentStack.trailingAnchor.constraint(
                equalTo: frontScrollView.contentLayoutGuide.trailingAnchor,
                constant: -Layout.edgeInset
            ),
            frontContentStack.topAnchor.constraint(
                equalTo: frontScrollView.contentLayoutGuide.topAnchor,
                constant: Layout.edgeInset
            ),
            frontContentStack.bottomAnchor.constraint(
                equalTo: frontScrollView.contentLayoutGuide.bottomAnchor,
                constant: -Layout.edgeInset
            ),
            frontContentStack.widthAnchor.constraint(
                equalTo: frontScrollView.frameLayoutGuide.widthAnchor,
                constant: -(Layout.edgeInset * 2)
            ),

            closeButton.topAnchor.constraint(
                equalTo: frontFaceView.topAnchor,
                constant: Layout.controlInset
            ),
            closeButton.trailingAnchor.constraint(
                equalTo: frontFaceView.trailingAnchor,
                constant: -Layout.controlInset
            ),
            closeButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Layout.iconButtonSize),

            playButton.trailingAnchor.constraint(
                equalTo: frontFaceView.trailingAnchor,
                constant: -Layout.controlInset
            ),
            playButton.bottomAnchor.constraint(
                equalTo: frontFaceView.bottomAnchor,
                constant: -Layout.controlInset
            ),
            playButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonSize),
            playButton.heightAnchor.constraint(equalToConstant: Layout.iconButtonSize)
        ])

        frontFaceView.accessibilityElements = [
            frontTitleLabel,
            frontSubtitleLabel,
            promptTextView,
            playButton,
            closeButton
        ]
    }

    private func configureBackFace() {
        configureLabel(backTitleLabel, numberOfLines: 0)
        configureLabel(questionCountLabel, numberOfLines: 0)
        questionCountLabel.text = L10n.AITheme.questionCount
        configureLabel(difficultyLabel, numberOfLines: 0)
        difficultyLabel.text = L10n.AITheme.difficulty

        backHeaderControlSpacer.translatesAutoresizingMaskIntoConstraints = false
        backHeaderControlSpacer.widthAnchor.constraint(
            equalToConstant: Layout.controlReservation
        ).isActive = true
        backHeaderStack.axis = .horizontal
        backHeaderStack.alignment = .top
        backHeaderStack.addArrangedSubview(backHeaderControlSpacer)
        backHeaderStack.addArrangedSubview(backTitleLabel)

        configureSelectorStack(questionCountStack)
        questionCountStack.accessibilityIdentifier = AccessibilityID.questionCountSelector
        questionCountButtons = Self.supportedQuestionCounts.enumerated().map { index, count in
            let button = makeOptionButton(
                title: String(count),
                accessibilityLabel: L10n.AITheme.questionCountAccessibility(count: count),
                tag: index,
                action: #selector(questionCountTapped(_:))
            )
            questionCountStack.addArrangedSubview(button)
            return button
        }

        configureSelectorStack(difficultyStack)
        difficultyStack.accessibilityIdentifier = AccessibilityID.difficultySelector
        difficultyButtons = Self.supportedDifficulties.enumerated().map { index, difficulty in
            let button = makeOptionButton(
                title: difficulty.title,
                accessibilityLabel: difficulty.title,
                tag: index,
                action: #selector(difficultyTapped(_:))
            )
            difficultyStack.addArrangedSubview(button)
            return button
        }
        updateAdaptiveSelectorLayout()

        submitButton.accessibilityIdentifier = AccessibilityID.submitButton
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Layout.submitMinimumHeight
        ).isActive = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.installPressFeedback()

        submitActivityIndicator.hidesWhenStopped = true
        submitActivityIndicator.isUserInteractionEnabled = false
        submitTitleLabel.adjustsFontForContentSizeCategory = true
        submitTitleLabel.numberOfLines = 1
        submitTitleLabel.minimumScaleFactor = 0.78
        submitTitleLabel.adjustsFontSizeToFitWidth = true
        submitTitleLabel.isUserInteractionEnabled = false
        submitContentStack.axis = .horizontal
        submitContentStack.alignment = .center
        submitContentStack.spacing = Layout.submitContentSpacing
        submitContentStack.isUserInteractionEnabled = false
        submitContentStack.translatesAutoresizingMaskIntoConstraints = false
        submitContentStack.addArrangedSubview(submitActivityIndicator)
        submitContentStack.addArrangedSubview(submitTitleLabel)
        submitButton.addSubview(submitContentStack)
        NSLayoutConstraint.activate([
            submitContentStack.centerXAnchor.constraint(equalTo: submitButton.centerXAnchor),
            submitContentStack.centerYAnchor.constraint(equalTo: submitButton.centerYAnchor),
            submitContentStack.leadingAnchor.constraint(
                greaterThanOrEqualTo: submitButton.leadingAnchor,
                constant: Layout.edgeInset
            ),
            submitContentStack.trailingAnchor.constraint(
                lessThanOrEqualTo: submitButton.trailingAnchor,
                constant: -Layout.edgeInset
            )
        ])

        progressLabel.accessibilityIdentifier = AccessibilityID.progressStatus
        progressLabel.accessibilityTraits.insert(.updatesFrequently)
        progressLabel.adjustsFontForContentSizeCategory = true
        progressLabel.numberOfLines = 0
        progressLabel.textAlignment = .center
        progressLabel.isHidden = true

        backContentStack.axis = .vertical
        backContentStack.spacing = Layout.sectionSpacing
        backContentStack.translatesAutoresizingMaskIntoConstraints = false
        [
            backHeaderStack,
            questionCountLabel,
            questionCountStack,
            difficultyLabel,
            difficultyStack,
            submitButton,
            progressLabel
        ].forEach(backContentStack.addArrangedSubview)
        backContentStack.setCustomSpacing(Layout.selectorSpacing, after: questionCountLabel)
        backContentStack.setCustomSpacing(Layout.selectorSpacing, after: difficultyLabel)

        configureScrollView(backScrollView)
        backScrollView.addSubview(backContentStack)

        configureIconButton(
            backButton,
            systemImageName: "chevron.left",
            accessibilityIdentifier: AccessibilityID.backButton,
            accessibilityLabel: L10n.ThemeCard.showFrontAccessibilityLabel
        )

        backFaceView.addSubview(backScrollView)
        backFaceView.addSubview(backButton)
        NSLayoutConstraint.activate([
            backScrollView.leadingAnchor.constraint(equalTo: backFaceView.leadingAnchor),
            backScrollView.trailingAnchor.constraint(equalTo: backFaceView.trailingAnchor),
            backScrollView.topAnchor.constraint(equalTo: backFaceView.topAnchor),
            backScrollView.bottomAnchor.constraint(equalTo: backFaceView.bottomAnchor),

            backContentStack.leadingAnchor.constraint(
                equalTo: backScrollView.contentLayoutGuide.leadingAnchor,
                constant: Layout.edgeInset
            ),
            backContentStack.trailingAnchor.constraint(
                equalTo: backScrollView.contentLayoutGuide.trailingAnchor,
                constant: -Layout.edgeInset
            ),
            backContentStack.topAnchor.constraint(
                equalTo: backScrollView.contentLayoutGuide.topAnchor,
                constant: Layout.edgeInset
            ),
            backContentStack.bottomAnchor.constraint(
                equalTo: backScrollView.contentLayoutGuide.bottomAnchor,
                constant: -Layout.edgeInset
            ),
            backContentStack.widthAnchor.constraint(
                equalTo: backScrollView.frameLayoutGuide.widthAnchor,
                constant: -(Layout.edgeInset * 2)
            ),

            backButton.topAnchor.constraint(
                equalTo: backFaceView.topAnchor,
                constant: Layout.controlInset
            ),
            backButton.leadingAnchor.constraint(
                equalTo: backFaceView.leadingAnchor,
                constant: Layout.controlInset
            ),
            backButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Layout.iconButtonSize)
        ])

        var backAccessibilityElements: [Any] = [backTitleLabel, questionCountLabel]
        backAccessibilityElements.append(contentsOf: questionCountButtons)
        backAccessibilityElements.append(difficultyLabel)
        backAccessibilityElements.append(contentsOf: difficultyButtons)
        backAccessibilityElements.append(contentsOf: [submitButton, progressLabel, backButton])
        backFaceView.accessibilityElements = backAccessibilityElements
    }

    private func configureScrollView(_ scrollView: UIScrollView) {
        scrollView.alwaysBounceVertical = false
        scrollView.keyboardDismissMode = .interactive
        scrollView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureLabel(_ label: UILabel, numberOfLines: Int) {
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = numberOfLines
        label.lineBreakMode = .byWordWrapping
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureSelectorStack(_ stackView: UIStackView) {
        stackView.axis = .horizontal
        stackView.alignment = .fill
        stackView.distribution = .fillEqually
        stackView.spacing = Layout.selectorSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Layout.selectorButtonHeight
        ).isActive = true
    }

    private func makeOptionButton(
        title: String,
        accessibilityLabel: String,
        tag: Int,
        action: Selector
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.tag = tag
        button.setTitle(title, for: .normal)
        button.accessibilityLabel = accessibilityLabel
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.72
        button.titleLabel?.numberOfLines = 1
        button.heightAnchor.constraint(
            greaterThanOrEqualToConstant: Layout.selectorButtonHeight
        ).isActive = true
        button.addTarget(self, action: action, for: .touchUpInside)
        button.installPressFeedback()
        return button
    }

    private func configureIconButton(
        _ button: UIButton,
        systemImageName: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String?
    ) {
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: systemImageName,
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
            ),
            for: .normal
        )
        button.translatesAutoresizingMaskIntoConstraints = false
        button.installPressFeedback()
    }

    private func configureActions() {
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        flipInteractionButton.addTarget(
            self,
            action: #selector(flipInteractionTapped),
            for: .touchUpInside
        )
    }

    private func configureKeyboardAccessory() {
        let toolbar = UIToolbar()
        let flexibleSpace = UIBarButtonItem(
            barButtonSystemItem: .flexibleSpace,
            target: nil,
            action: nil
        )
        let doneButton = UIBarButtonItem(
            title: L10n.Settings.done,
            style: .done,
            target: self,
            action: #selector(keyboardDoneTapped)
        )
        doneButton.accessibilityIdentifier = AccessibilityID.keyboardDoneButton
        toolbar.items = [flexibleSpace, doneButton]
        toolbar.sizeToFit()
        promptTextView.inputAccessoryView = toolbar
    }

    private func configureKeyboardObservation() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillChangeFrame(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification,
            object: nil
        )
    }

    private func updateAdaptiveSelectorLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory
            .isAccessibilityCategory
        difficultyStack.axis = usesAccessibilityLayout ? .vertical : .horizontal
        difficultyStack.distribution = usesAccessibilityLayout ? .fill : .fillEqually
        difficultyButtons.forEach { button in
            button.titleLabel?.numberOfLines = usesAccessibilityLayout ? 0 : 1
            button.titleLabel?.adjustsFontSizeToFitWidth = !usesAccessibilityLayout
            button.titleLabel?.textAlignment = .center
        }
    }

    private func updateKeyboardInsets(
        overlap: CGFloat,
        duration: TimeInterval,
        options: UIView.AnimationOptions
    ) {
        let bottomInset = max(
            Layout.scrollBottomInset,
            overlap > 0 ? overlap + Layout.promptTextInset : 0
        )
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [options, .beginFromCurrentState, .allowUserInteraction]
        ) {
            self.frontScrollView.contentInset.bottom = bottomInset
            self.frontScrollView.verticalScrollIndicatorInsets.bottom = bottomInset
            self.layoutIfNeeded()
            self.scrollPromptCaretIntoView()
        }
    }

    private func scrollPromptCaretIntoView() {
        guard
            face == .front,
            promptTextView.isFirstResponder,
            let selectedRange = promptTextView.selectedTextRange
        else { return }
        var caretRect = promptTextView.caretRect(for: selectedRange.end)
        caretRect = promptTextView.convert(caretRect, to: frontScrollView)
        caretRect = caretRect.insetBy(dx: -Layout.promptTextInset, dy: -Layout.promptTextInset)
        frontScrollView.scrollRectToVisible(caretRect, animated: false)
    }

    private func applyAppearance(_ appearance: AppAppearance) {
        configuredSurfaceStyle = appearance.card
        cardCornerRadius = appearance.card.cornerRadius
        configuredShadowStyle = appearance.designStyle == .radar
            ? AppShadowStyle(
                color: appearance.accentColor,
                opacity: Outline.radarGlowOpacity,
                radius: Outline.radarGlowRadius,
                offset: .zero
            )
            : appearance.card.shadow
        applyConfiguredSurfaceAppearance()
        applyConfiguredShadow()

        frontTitleLabel.font = appearance.typography.font(
            size: Typography.titleSize,
            weight: .bold
        )
        frontTitleLabel.textColor = appearance.surfaceTextColor
        frontSubtitleLabel.font = appearance.typography.font(
            size: Typography.subtitleSize,
            weight: .regular
        )
        frontSubtitleLabel.textColor = appearance.secondarySurfaceTextColor

        promptTextView.font = appearance.typography.font(
            size: Typography.promptSize,
            weight: .regular
        )
        promptTextView.textColor = appearance.surfaceTextColor
        promptTextView.tintColor = appearance.accentColor
        promptPlaceholderLabel.font = appearance.typography.font(
            size: Typography.promptSize,
            weight: .regular
        )
        promptPlaceholderLabel.textColor = appearance.secondarySurfaceTextColor
        promptContainerView.applySurfaceStyle(appearance.row)

        backTitleLabel.font = appearance.typography.font(
            size: Typography.titleSize,
            weight: .bold
        )
        backTitleLabel.textColor = appearance.surfaceTextColor
        [questionCountLabel, difficultyLabel].forEach { label in
            label.font = appearance.typography.font(
                size: Typography.sectionTitleSize,
                weight: .semibold
            )
            label.textColor = appearance.surfaceTextColor
        }
        submitTitleLabel.font = appearance.typography.font(
            size: Typography.submitSize,
            weight: .semibold
        )
        progressLabel.font = appearance.typography.font(
            size: Typography.progressSize,
            weight: .medium
        )
        progressLabel.textColor = appearance.secondarySurfaceTextColor

        [closeButton, playButton, backButton].forEach { button in
            button.applyActionAppearance(
                appearance.iconButton,
                appearance: appearance,
                textColor: appearance.surfaceTextColor
            )
        }
        submitButton.applyActionAppearance(
            appearance.primaryButton,
            appearance: appearance,
            textColor: appearance.accentForegroundColor
        )
        submitTitleLabel.textColor = appearance.accentForegroundColor
        submitActivityIndicator.color = appearance.accentForegroundColor

        let keyboardStyle = AIThemeKeyboardStyle(appearance: appearance)
        promptTextView.inputAccessoryView?.tintColor = keyboardStyle.doneButtonTintColor
        promptTextView.inputAccessoryView?.overrideUserInterfaceStyle = keyboardStyle.interfaceStyle
        switch keyboardStyle.interfaceStyle {
        case .dark:
            promptTextView.keyboardAppearance = .dark
        case .light:
            promptTextView.keyboardAppearance = .light
        default:
            promptTextView.keyboardAppearance = .default
        }
    }

    private func applyConfiguredSurfaceAppearance() {
        guard let style = configuredSurfaceStyle else { return }
        let isRadar = configuredAppearance?.designStyle == .radar
        let surfaceColor = isTransitionSurfaceHidden ? UIColor.clear : style.backgroundColor
        let solidBorderColor: UIColor
        let solidBorderWidth: CGFloat
        if isTransitionSurfaceHidden {
            solidBorderColor = .clear
            solidBorderWidth = 0
        } else if isRadar {
            solidBorderColor = configuredAppearance?.accentColor ?? style.borderColor
            solidBorderWidth = max(style.borderWidth, 1)
        } else {
            solidBorderColor = .clear
            solidBorderWidth = 0
        }

        [frontSurfaceView, backSurfaceView].forEach { surfaceView in
            surfaceView.backgroundColor = surfaceColor
            surfaceView.layer.cornerRadius = cardCornerRadius
            surfaceView.layer.cornerCurve = .continuous
            surfaceView.layer.borderColor = solidBorderColor.cgColor
            surfaceView.layer.borderWidth = solidBorderWidth
        }

        let usesGradient = !isRadar && !isTransitionSurfaceHidden
        [frontOutlineView, backOutlineView].forEach { outlineView in
            outlineView.colors = [Outline.gradientPink, Outline.gradientBlue]
            outlineView.lineWidth = Outline.gradientLineWidth
            outlineView.cornerRadius = cardCornerRadius
            outlineView.isHidden = !usesGradient
        }
        setNeedsLayout()
    }

    private func applyConfiguredShadow() {
        shadowProxyView.applyShadow(
            isTransitionShadowHidden ? .none : configuredShadowStyle
        )
    }

    private func renderControls() {
        guard let appearance = configuredAppearance else { return }

        promptTextView.isEditable = !isSubmitting
        promptTextView.alpha = isSubmitting ? 0.52 : 1
        playButton.isEnabled = canRevealConfiguration
        playButton.alpha = canRevealConfiguration ? 1 : 0.52
        playButton.accessibilityHint = canRevealConfiguration ? nil : L10n.AITheme.subtitle

        for (index, button) in questionCountButtons.enumerated() {
            guard Self.supportedQuestionCounts.indices.contains(index) else { continue }
            styleOptionButton(
                button,
                isSelected: Self.supportedQuestionCounts[index] == selectedQuestionCount,
                isEnabled: !isSubmitting,
                appearance: appearance
            )
        }
        for (index, button) in difficultyButtons.enumerated() {
            guard Self.supportedDifficulties.indices.contains(index) else { continue }
            styleOptionButton(
                button,
                isSelected: Self.supportedDifficulties[index] == selectedDifficulty,
                isEnabled: !isSubmitting,
                appearance: appearance
            )
        }

        submitButton.isEnabled = canSubmit
        submitButton.alpha = submitButton.isEnabled || isSubmitting ? 1 : 0.52
        submitTitleLabel.text = isSubmitting ? L10n.AITheme.generating : L10n.AITheme.submit
        submitButton.accessibilityLabel = submitTitleLabel.text
        if isSubmitting {
            submitActivityIndicator.startAnimating()
        } else {
            submitActivityIndicator.stopAnimating()
        }
    }

    private func styleOptionButton(
        _ button: UIButton,
        isSelected: Bool,
        isEnabled: Bool,
        appearance: AppAppearance
    ) {
        let style = isSelected ? appearance.primaryButton : appearance.row
        let textColor = isSelected
            ? appearance.accentForegroundColor
            : appearance.surfaceTextColor
        button.applyActionAppearance(style, appearance: appearance, textColor: textColor)
        button.titleLabel?.font = appearance.typography.font(
            size: Typography.optionSize,
            weight: .semibold
        )
        button.isEnabled = isEnabled
        button.alpha = isEnabled ? (isSelected ? 1 : 0.78) : 0.52
        if isSelected {
            button.accessibilityTraits.insert(.selected)
        } else {
            button.accessibilityTraits.remove(.selected)
        }
    }

    private func updatePromptPlaceholderVisibility() {
        promptPlaceholderLabel.isHidden = !promptTextView.text.isEmpty
    }

    func textViewDidChange(_ textView: UITextView) {
        guard textView === promptTextView else { return }
        textView.invalidateIntrinsicContentSize()
        setNeedsLayout()
        layoutIfNeeded()
        scrollPromptCaretIntoView()
        updatePromptPlaceholderVisibility()
        canRevealConfiguration = !textView.text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
        canSubmit = canRevealConfiguration && !isSubmitting
        renderControls()
        onPromptChanged?(textView.text)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard textView === promptTextView else { return }
        scrollPromptCaretIntoView()
    }

    private func beginFaceAnimation(
        to targetFace: HomeThemeCardFace,
        duration: TimeInterval,
        reduceMotion: Bool,
        completion: ((HomeThemeCardFace) -> Void)?
    ) {
        let startFace = face
        flipInteractionButton.isHidden = false
        prepareFaceAnimation(from: startFace, to: targetFace, reduceMotion: reduceMotion)

        let animator = UIViewPropertyAnimator(
            duration: duration,
            curve: reduceMotion ? .easeInOut : .linear
        ) {
            self.applyFaceAnimationEndpoint(
                from: startFace,
                to: targetFace,
                reduceMotion: reduceMotion
            )
        }
        activeFaceAnimator = animator
        faceAnimationStart = startFace
        faceAnimationEnd = targetFace
        faceAnimationTarget = targetFace
        faceAnimationCompletion = completion

        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator, self.activeFaceAnimator === animator else { return }
            let completedFace: HomeThemeCardFace
            switch position {
            case .start:
                completedFace = startFace
            case .end:
                completedFace = targetFace
            case .current:
                completedFace = self.faceAnimationTarget ?? targetFace
            @unknown default:
                completedFace = self.faceAnimationTarget ?? targetFace
            }

            let requestedFace = self.faceAnimationTarget ?? completedFace
            let requestedCompletion = self.faceAnimationCompletion
            self.clearFaceAnimationState()
            self.face = completedFace
            self.normalizeFaces(showing: completedFace)

            guard completedFace == requestedFace else {
                self.setFace(requestedFace, animated: true, completion: requestedCompletion)
                return
            }
            requestedCompletion?(completedFace)
        }
        animator.startAnimation()
    }

    private func prepareFaceAnimation(
        from startFace: HomeThemeCardFace,
        to targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        frontPlaneView.isHidden = false
        backPlaneView.isHidden = false
        frontFaceView.isHidden = false
        backFaceView.isHidden = false

        if reduceMotion {
            perspectiveStageView.layer.sublayerTransform = CATransform3DIdentity
            rotatingCardView.layer.transform = CATransform3DIdentity
            shadowProxyView.layer.transform = CATransform3DIdentity
            frontPlaneView.layer.transform = CATransform3DIdentity
            backPlaneView.layer.transform = CATransform3DIdentity
            frontPlaneView.alpha = startFace == .front ? 1 : 0
            backPlaneView.alpha = startFace == .back ? 1 : 0
        } else {
            guard let transition = HomeThemeCardFlipTransition(
                startFace: startFace,
                targetFace: targetFace
            ) else { return }
            var perspective = CATransform3DIdentity
            perspective.m34 = -1 / Animation.perspectiveDistance
            perspectiveStageView.layer.sublayerTransform = perspective
            frontPlaneView.alpha = 1
            backPlaneView.alpha = 1
            frontPlaneView.layer.transform = rotationY(
                HomeThemeCardFlipTransition.localAngle(for: .front)
            )
            backPlaneView.layer.transform = rotationY(
                HomeThemeCardFlipTransition.localAngle(for: .back)
            )
            let carrierAngle = transition.carrierAngle(progress: 0)
            rotatingCardView.layer.transform = rotationY(carrierAngle)
            shadowProxyView.layer.transform = rotationY(carrierAngle)
        }
    }

    private func applyFaceAnimationEndpoint(
        from startFace: HomeThemeCardFace,
        to targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        if reduceMotion {
            frontPlaneView.alpha = targetFace == .front ? 1 : 0
            backPlaneView.alpha = targetFace == .back ? 1 : 0
        } else if let transition = HomeThemeCardFlipTransition(
            startFace: startFace,
            targetFace: targetFace
        ) {
            let carrierAngle = transition.carrierAngle(progress: 1)
            rotatingCardView.layer.transform = rotationY(carrierAngle)
            shadowProxyView.layer.transform = rotationY(carrierAngle)
        }
    }

    private func cancelFaceAnimation() {
        activeFaceAnimator?.stopAnimation(true)
        clearFaceAnimationState()
        normalizeFaces(showing: face)
    }

    private func clearFaceAnimationState() {
        activeFaceAnimator = nil
        faceAnimationStart = nil
        faceAnimationEnd = nil
        faceAnimationTarget = nil
        faceAnimationCompletion = nil
    }

    private func normalizeFaces(showing face: HomeThemeCardFace) {
        let frontIsVisible = face == .front
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        flipInteractionButton.isHidden = true
        perspectiveStageView.layer.sublayerTransform = CATransform3DIdentity
        let carrierAngle = HomeThemeCardFlipTransition.carrierAngle(showing: face)
        rotatingCardView.layer.transform = rotationY(carrierAngle)
        shadowProxyView.layer.transform = rotationY(carrierAngle)
        frontPlaneView.isHidden = !frontIsVisible
        frontPlaneView.alpha = 1
        frontPlaneView.layer.transform = rotationY(
            HomeThemeCardFlipTransition.localAngle(for: .front)
        )
        backPlaneView.isHidden = frontIsVisible
        backPlaneView.alpha = 1
        backPlaneView.layer.transform = rotationY(
            HomeThemeCardFlipTransition.localAngle(for: .back)
        )
        frontFaceView.isHidden = !frontIsVisible
        backFaceView.isHidden = frontIsVisible
        CATransaction.commit()
        updateAccessibilityVisibility(for: face)
    }

    private func updateAccessibilityVisibility(for face: HomeThemeCardFace) {
        let frontIsVisible = face == .front
        frontFaceView.accessibilityElementsHidden = !frontIsVisible
        frontFaceView.isUserInteractionEnabled = frontIsVisible
        backFaceView.accessibilityElementsHidden = frontIsVisible
        backFaceView.isUserInteractionEnabled = !frontIsVisible
    }

    private func rotationY(_ angle: CGFloat) -> CATransform3D {
        CATransform3DMakeRotation(angle, 0, 1, 0)
    }

    @objc private func closeTapped() {
        resignPrompt()
        onClose?()
    }

    @objc private func flipTapped() {
        guard canRevealConfiguration else { return }
        resignPrompt()
        onFlip?()
    }

    @objc private func flipInteractionTapped() {
        onFlip?()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func questionCountTapped(_ sender: UIButton) {
        guard
            !isSubmitting,
            Self.supportedQuestionCounts.indices.contains(sender.tag)
        else { return }
        selectedQuestionCount = Self.supportedQuestionCounts[sender.tag]
        renderControls()
        onQuestionCountChanged?(selectedQuestionCount)
    }

    @objc private func difficultyTapped(_ sender: UIButton) {
        guard
            !isSubmitting,
            Self.supportedDifficulties.indices.contains(sender.tag)
        else { return }
        selectedDifficulty = Self.supportedDifficulties[sender.tag]
        renderControls()
        onDifficultyChanged?(selectedDifficulty)
    }

    @objc private func submitTapped() {
        guard submitButton.isEnabled, !isSubmitting else { return }
        onSubmit?()
    }

    @objc private func keyboardDoneTapped() {
        resignPrompt()
    }

    @objc private func keyboardWillChangeFrame(_ notification: Notification) {
        guard
            let window,
            let userInfo = notification.userInfo,
            let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
        else { return }

        let frameInWindow = window.convert(keyboardFrame, from: window.screen.coordinateSpace)
        let frameInCard = convert(frameInWindow, from: window)
        let overlap = bounds.intersection(frameInCard).height
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? TimeInterval ?? 0.25
        let curveRawValue = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey]
            as? UInt ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: curveRawValue << 16)
        updateKeyboardInsets(overlap: overlap, duration: duration, options: options)
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        let userInfo = notification.userInfo
        let duration = userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey]
            as? TimeInterval ?? 0.25
        let curveRawValue = userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey]
            as? UInt ?? UInt(UIView.AnimationCurve.easeInOut.rawValue)
        let options = UIView.AnimationOptions(rawValue: curveRawValue << 16)
        updateKeyboardInsets(overlap: 0, duration: duration, options: options)
    }
}
