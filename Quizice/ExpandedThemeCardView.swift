import UIKit

final class ExpandedThemeCardView: UIView, UIGestureRecognizerDelegate {
    private enum AccessibilityID {
        static let root = "expandedThemeCardView"
        static let frontPlane = "expandedThemeCardFrontPlane"
        static let backPlane = "expandedThemeCardBackPlane"
        static let rotatingCarrier = "expandedThemeCardRotatingCarrier"
        static let flipInteractionOverlay = "expandedThemeCardFlipInteractionOverlay"
        static let front = "expandedThemeCardFrontView"
        static let frontSurfaceButton = "expandedThemeCardFrontSurfaceButton"
        static let frontImage = "expandedThemeCardFrontImageView"
        static let closeButton = "expandedThemeCardCloseButton"
        static let infoButton = "expandedThemeCardInfoButton"
        static let back = "expandedThemeCardBackView"
        static let backSurfaceButton = "expandedThemeCardBackSurfaceButton"
        static let themeNameLabel = "descriptionThemeNameLabel"
        static let descriptionLabel = "descriptionTextLabel"
        static let questionCountLabel = "descriptionPickerCaptionLabel"
        static let questionCountControl = "descriptionQuestionCountPicker"
        static let startButton = "descriptionStartButton"
        static let backButton = "descriptionBackButton"
        static let unavailableLabel = "expandedThemeCardUnavailableLabel"
    }

    private enum Layout {
        static let edgeInset: CGFloat = 20
        static let controlInset: CGFloat = 16
        static let iconButtonSize: CGFloat = 44
        static let frontImageTopInset: CGFloat = 28
        static let frontImageHorizontalInset: CGFloat = 24
        static let frontImageToTitleSpacing: CGFloat = 12
        static let frontTitleBottomInset: CGFloat = 18
        static let frontTitleToInfoSpacing: CGFloat = 12
        static let backHeaderSpacing: CGFloat = 12
        static let backContentSpacing: CGFloat = 14
        static let controlsSpacing: CGFloat = 10
        static let segmentedControlHeight: CGFloat = 44
        static let startButtonMinimumHeight: CGFloat = 54
        static let classicFrontArtworkSize = CGSize(width: 118, height: 118)
        static let cleanFrontArtworkPointSize: CGFloat = 132
        static let radarFrontArtworkPointSize: CGFloat = 176
        static let frontArtworkCenterYOffset: CGFloat = -28
    }

    private enum Typography {
        static let frontTitleSize: CGFloat = 28
        static let backTitleSize: CGFloat = 30
        static let descriptionSize: CGFloat = 18
        static let captionSize: CGFloat = 16
        static let unavailableSize: CGFloat = 15
        static let buttonSize: CGFloat = 19
        static let segmentSize: CGFloat = 16
    }

    private enum Animation {
        static let flipDuration: TimeInterval = 0.28
        static let reducedMotionDuration: TimeInterval = 0.18
        static let perspectiveDistance: CGFloat = 760
    }

    private static let supportedQuestionCounts = QuizQuestionCountPolicy.supportedCounts

    var onClose: (() -> Void)?
    var onFlip: (() -> Void)?
    var onBack: (() -> Void)?
    var onQuestionCountChanged: ((Int) -> Void)?
    var onStart: (() -> Void)?
    var onAccessibilityEscape: (() -> Void)?
    var reduceMotionProvider: () -> Bool = { UIAccessibility.isReduceMotionEnabled }

    var frontFocusView: UIView { frontTitleLabel }
    var backFocusView: UIView { backTitleLabel }
    var transitionSourceView: UIView { self }

    private(set) var selectedQuestionCount: Int?
    private(set) var face: HomeThemeCardFace = .front

    private let perspectiveStageView = UIView()
    private let rotatingCardView = UIView()
    private let frontPlaneView = UIView()
    private let backPlaneView = UIView()
    private let frontSurfaceView = UIView()
    private let backSurfaceView = UIView()
    private let frontFaceView = UIView()
    private let backFaceView = UIView()
    private let flipInteractionButton = UIButton(type: .custom)

    private let frontSurfaceButton = UIButton(type: .custom)
    private let frontImageView = UIImageView()
    private let frontTitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let infoButton = UIButton(type: .system)

    private let backSurfaceButton = UIButton(type: .custom)
    private let backButton = UIButton(type: .system)
    private let backTitleLabel = UILabel()
    private let descriptionScrollView = UIScrollView()
    private let backDescriptionLabel = UILabel()
    private let questionCountLabel = UILabel()
    private let questionCountControl = UISegmentedControl(
        items: ExpandedThemeCardView.supportedQuestionCounts.map { String($0) }
    )
    private let unavailableLabel = UILabel()
    private let startButton = UIButton(type: .system)
    private let backControlsStack = UIStackView()
    private lazy var backTapGestureRecognizer = UITapGestureRecognizer(
        target: self,
        action: #selector(backTapped)
    )

    private var availableQuestionCounts: Set<Int> = []
    private var activeFaceAnimator: UIViewPropertyAnimator?
    private var faceAnimationStart: HomeThemeCardFace?
    private var faceAnimationEnd: HomeThemeCardFace?
    private var faceAnimationTarget: HomeThemeCardFace?
    private var faceAnimationCompletion: ((HomeThemeCardFace) -> Void)?
    private var cardCornerRadius: CGFloat = 0
    private var frontImageSizeConstraint: NSLayoutConstraint!
    private var configuredShadowStyle = AppShadowStyle.none
    private var isTransitionShadowHidden = false
    private var configuredSurfaceColor = UIColor.clear
    private var configuredBorderColor = UIColor.clear
    private var configuredBorderWidth: CGFloat = 0
    private var isTransitionSurfaceHidden = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
        configureActions()
        normalizeFaces(showing: .front)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cardCornerRadius
        ).cgPath
        rotatingCardView.layer.shadowPath = shadowPath
    }

    func configure(
        theme: QuizTheme,
        appearance: AppAppearance,
        availableQuestionCounts: [Int],
        selectedQuestionCount: Int?
    ) {
        cancelFaceAnimation()

        let themeID = theme.stableID
        let tintColor = ThemeVisualCatalog.tintColor(for: themeID)
        let borderColor = appearance.themeCardBorder(baseColor: tintColor)
        let supportedCounts = Set(Self.supportedQuestionCounts)
        self.availableQuestionCounts = Set(availableQuestionCounts).intersection(supportedCounts)

        frontImageView.image = frontArtworkImage(themeID: themeID, appearance: appearance)
        frontImageView.tintColor = borderColor
        frontImageView.transform = .identity
        frontImageSizeConstraint.constant = frontArtworkPointSize(for: appearance.designStyle)

        frontTitleLabel.text = theme.theme
        backTitleLabel.text = theme.theme
        backDescriptionLabel.text = theme.themeDescription.isEmpty
            ? L10n.Description.defaultThemeDescription
            : theme.themeDescription
        infoButton.accessibilityValue = theme.theme
        infoButton.accessibilityHint = nil

        applyAppearance(
            appearance,
            themeID: themeID,
            themeTintColor: tintColor,
            borderColor: borderColor
        )
        configureQuestionCounts(selectedQuestionCount: selectedQuestionCount)

        face = .front
        normalizeFaces(showing: .front)
    }

    func setFace(
        _ targetFace: HomeThemeCardFace,
        animated: Bool,
        completion: ((HomeThemeCardFace) -> Void)? = nil
    ) {
        if let animator = activeFaceAnimator,
           let startFace = faceAnimationStart,
           let endFace = faceAnimationEnd,
           targetFace == startFace || targetFace == endFace {
            faceAnimationTarget = targetFace
            faceAnimationCompletion = completion
            updateAccessibilityVisibility(for: targetFace)
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
        updateAccessibilityVisibility(for: targetFace)

        guard animated else {
            face = targetFace
            normalizeFaces(showing: targetFace)
            completion?(targetFace)
            return
        }

        if reduceMotionProvider() {
            animateCrossfade(to: targetFace, completion: completion)
        } else {
            animatePerspectiveFlip(to: targetFace, completion: completion)
        }
    }

    func setTransitionShadowHidden(_ isHidden: Bool) {
        isTransitionShadowHidden = isHidden
        let shadow = isHidden ? AppShadowStyle.none : configuredShadowStyle
        rotatingCardView.applyShadow(shadow)
    }

    func setTransitionSurfaceHidden(_ isHidden: Bool) {
        isTransitionSurfaceHidden = isHidden
        applyConfiguredSurfaceAppearance()
    }

    func setTransitionContentProgress(
        _ progress: CGFloat,
        sourceGeometry: HomeThemeCardContentGeometry
    ) {
        layoutIfNeeded()
        let visualState = HomeThemeCardTransitionVisualState(progress: progress)
        let remainingTranslation = 1 - visualState.progress
        let imageTranslation = sourceGeometry.imageTranslation(
            toAlignDestinationCenter: frontImageView.center,
            in: bounds.size
        )
        let titleTranslation = sourceGeometry.titleTranslation(
            toAlignDestinationCenter: frontTitleLabel.center,
            in: bounds.size
        )

        frontImageView.transform = CGAffineTransform(
            translationX: imageTranslation.x * remainingTranslation,
            y: imageTranslation.y * remainingTranslation
        )
        frontTitleLabel.transform = CGAffineTransform(
            translationX: titleTranslation.x * remainingTranslation,
            y: titleTranslation.y * remainingTranslation
        )
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

    private func configureViewHierarchy() {
        backgroundColor = .clear
        accessibilityIdentifier = AccessibilityID.root
        accessibilityViewIsModal = true
        isAccessibilityElement = false

        perspectiveStageView.translatesAutoresizingMaskIntoConstraints = false
        perspectiveStageView.clipsToBounds = false
        addSubview(perspectiveStageView)

        rotatingCardView.accessibilityIdentifier = AccessibilityID.rotatingCarrier
        rotatingCardView.translatesAutoresizingMaskIntoConstraints = false
        rotatingCardView.backgroundColor = .clear
        rotatingCardView.layer.masksToBounds = false
        perspectiveStageView.addSubview(rotatingCardView)

        let planes = [
            (frontPlaneView, frontSurfaceView, frontFaceView, AccessibilityID.frontPlane),
            (backPlaneView, backSurfaceView, backFaceView, AccessibilityID.backPlane)
        ]
        planes.forEach { plane in
            let (planeView, surfaceView, faceView, accessibilityIdentifier) = plane
            planeView.accessibilityIdentifier = accessibilityIdentifier
            planeView.translatesAutoresizingMaskIntoConstraints = false
            planeView.backgroundColor = .clear
            planeView.layer.isDoubleSided = false
            rotatingCardView.addSubview(planeView)

            surfaceView.translatesAutoresizingMaskIntoConstraints = false
            surfaceView.layer.masksToBounds = true
            planeView.addSubview(surfaceView)

            faceView.translatesAutoresizingMaskIntoConstraints = false
            surfaceView.addSubview(faceView)
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
                faceView.bottomAnchor.constraint(equalTo: surfaceView.bottomAnchor)
            ])
        }

        flipInteractionButton.accessibilityIdentifier = AccessibilityID.flipInteractionOverlay
        flipInteractionButton.isAccessibilityElement = false
        flipInteractionButton.isHidden = true
        flipInteractionButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(flipInteractionButton)

        NSLayoutConstraint.activate([
            perspectiveStageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            perspectiveStageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            perspectiveStageView.topAnchor.constraint(equalTo: topAnchor),
            perspectiveStageView.bottomAnchor.constraint(equalTo: bottomAnchor),

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

    private func configureFrontFace() {
        frontFaceView.accessibilityIdentifier = AccessibilityID.front

        frontSurfaceButton.accessibilityIdentifier = AccessibilityID.frontSurfaceButton
        frontSurfaceButton.isAccessibilityElement = false
        frontSurfaceButton.translatesAutoresizingMaskIntoConstraints = false

        frontImageView.accessibilityIdentifier = AccessibilityID.frontImage
        frontImageView.contentMode = .scaleAspectFit
        frontImageView.isAccessibilityElement = false
        frontImageView.isUserInteractionEnabled = false
        frontImageView.translatesAutoresizingMaskIntoConstraints = false

        frontTitleLabel.adjustsFontForContentSizeCategory = true
        frontTitleLabel.numberOfLines = 2
        frontTitleLabel.lineBreakMode = .byWordWrapping
        frontTitleLabel.textAlignment = .center
        frontTitleLabel.isAccessibilityElement = true
        frontTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        configureIconButton(
            closeButton,
            systemImageName: "xmark",
            accessibilityIdentifier: AccessibilityID.closeButton,
            accessibilityLabel: L10n.ThemeCard.closeAccessibilityLabel
        )
        configureIconButton(
            infoButton,
            systemImageName: "info",
            accessibilityIdentifier: AccessibilityID.infoButton,
            accessibilityLabel: L10n.ThemeCard.showDescriptionAccessibilityLabel
        )

        frontFaceView.addSubview(frontSurfaceButton)
        frontFaceView.addSubview(frontImageView)
        frontFaceView.addSubview(frontTitleLabel)
        frontFaceView.addSubview(closeButton)
        frontFaceView.addSubview(infoButton)
        frontImageSizeConstraint = frontImageView.widthAnchor.constraint(
            equalToConstant: Layout.cleanFrontArtworkPointSize
        )

        NSLayoutConstraint.activate([
            frontSurfaceButton.leadingAnchor.constraint(equalTo: frontFaceView.leadingAnchor),
            frontSurfaceButton.trailingAnchor.constraint(equalTo: frontFaceView.trailingAnchor),
            frontSurfaceButton.topAnchor.constraint(equalTo: frontFaceView.topAnchor),
            frontSurfaceButton.bottomAnchor.constraint(equalTo: frontFaceView.bottomAnchor),

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

            infoButton.trailingAnchor.constraint(
                equalTo: frontFaceView.trailingAnchor,
                constant: -Layout.controlInset
            ),
            infoButton.bottomAnchor.constraint(
                equalTo: frontFaceView.bottomAnchor,
                constant: -Layout.controlInset
            ),
            infoButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonSize),
            infoButton.heightAnchor.constraint(equalToConstant: Layout.iconButtonSize),

            frontTitleLabel.leadingAnchor.constraint(
                equalTo: frontFaceView.leadingAnchor,
                constant: Layout.frontImageHorizontalInset
            ),
            frontTitleLabel.trailingAnchor.constraint(
                lessThanOrEqualTo: infoButton.leadingAnchor,
                constant: -Layout.frontTitleToInfoSpacing
            ),
            frontTitleLabel.bottomAnchor.constraint(
                equalTo: frontFaceView.bottomAnchor,
                constant: -Layout.frontTitleBottomInset
            ),

            frontImageView.centerXAnchor.constraint(equalTo: frontFaceView.centerXAnchor),
            frontImageView.centerYAnchor.constraint(
                equalTo: frontFaceView.centerYAnchor,
                constant: Layout.frontArtworkCenterYOffset
            ),
            frontImageSizeConstraint,
            frontImageView.heightAnchor.constraint(equalTo: frontImageView.widthAnchor),
            frontImageView.topAnchor.constraint(
                greaterThanOrEqualTo: closeButton.bottomAnchor,
                constant: Layout.frontImageToTitleSpacing
            ),
            frontImageView.bottomAnchor.constraint(
                lessThanOrEqualTo: frontTitleLabel.topAnchor,
                constant: -Layout.frontImageToTitleSpacing
            )
        ])

        frontFaceView.accessibilityElements = [frontTitleLabel, infoButton, closeButton]
    }

    private func configureBackFace() {
        backFaceView.accessibilityIdentifier = AccessibilityID.back

        backSurfaceButton.accessibilityIdentifier = AccessibilityID.backSurfaceButton
        backSurfaceButton.isAccessibilityElement = false
        backSurfaceButton.translatesAutoresizingMaskIntoConstraints = false

        backTapGestureRecognizer.cancelsTouchesInView = false
        backTapGestureRecognizer.delegate = self
        backTapGestureRecognizer.require(toFail: descriptionScrollView.panGestureRecognizer)
        backFaceView.addGestureRecognizer(backTapGestureRecognizer)

        configureIconButton(
            backButton,
            systemImageName: "chevron.left",
            accessibilityIdentifier: AccessibilityID.backButton,
            accessibilityLabel: L10n.ThemeCard.showFrontAccessibilityLabel
        )

        backTitleLabel.accessibilityIdentifier = AccessibilityID.themeNameLabel
        backTitleLabel.adjustsFontForContentSizeCategory = true
        backTitleLabel.numberOfLines = 2
        backTitleLabel.lineBreakMode = .byWordWrapping
        backTitleLabel.isAccessibilityElement = true
        backTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        descriptionScrollView.accessibilityIdentifier = "descriptionScrollView"
        descriptionScrollView.alwaysBounceVertical = false
        descriptionScrollView.keyboardDismissMode = .onDrag
        descriptionScrollView.translatesAutoresizingMaskIntoConstraints = false

        backDescriptionLabel.accessibilityIdentifier = AccessibilityID.descriptionLabel
        backDescriptionLabel.adjustsFontForContentSizeCategory = true
        backDescriptionLabel.numberOfLines = 0
        backDescriptionLabel.lineBreakMode = .byWordWrapping
        backDescriptionLabel.isAccessibilityElement = true
        backDescriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        questionCountLabel.accessibilityIdentifier = AccessibilityID.questionCountLabel
        questionCountLabel.text = L10n.Description.questionCount
        questionCountLabel.adjustsFontForContentSizeCategory = true
        questionCountLabel.numberOfLines = 0

        questionCountControl.accessibilityIdentifier = AccessibilityID.questionCountControl
        questionCountControl.accessibilityLabel = L10n.Description.questionCount
        questionCountControl.translatesAutoresizingMaskIntoConstraints = false

        unavailableLabel.accessibilityIdentifier = AccessibilityID.unavailableLabel
        unavailableLabel.text = L10n.Question.unavailableMessage
        unavailableLabel.adjustsFontForContentSizeCategory = true
        unavailableLabel.numberOfLines = 0
        unavailableLabel.textAlignment = .center

        startButton.accessibilityIdentifier = AccessibilityID.startButton
        startButton.setTitle(L10n.Common.start, for: .normal)
        startButton.titleLabel?.adjustsFontForContentSizeCategory = true
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.installPressFeedback()

        backControlsStack.axis = .vertical
        backControlsStack.alignment = .fill
        backControlsStack.spacing = Layout.controlsSpacing
        backControlsStack.translatesAutoresizingMaskIntoConstraints = false
        [
            questionCountLabel,
            questionCountControl,
            unavailableLabel,
            startButton
        ].forEach(backControlsStack.addArrangedSubview)

        backFaceView.addSubview(backSurfaceButton)
        backFaceView.addSubview(backButton)
        backFaceView.addSubview(backTitleLabel)
        backFaceView.addSubview(descriptionScrollView)
        backFaceView.addSubview(backControlsStack)
        descriptionScrollView.addSubview(backDescriptionLabel)

        NSLayoutConstraint.activate([
            backSurfaceButton.leadingAnchor.constraint(equalTo: backFaceView.leadingAnchor),
            backSurfaceButton.trailingAnchor.constraint(equalTo: backFaceView.trailingAnchor),
            backSurfaceButton.topAnchor.constraint(equalTo: backFaceView.topAnchor),
            backSurfaceButton.bottomAnchor.constraint(equalTo: backFaceView.bottomAnchor),

            backButton.topAnchor.constraint(
                equalTo: backFaceView.topAnchor,
                constant: Layout.controlInset
            ),
            backButton.leadingAnchor.constraint(
                equalTo: backFaceView.leadingAnchor,
                constant: Layout.controlInset
            ),
            backButton.widthAnchor.constraint(equalToConstant: Layout.iconButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Layout.iconButtonSize),

            backTitleLabel.topAnchor.constraint(
                equalTo: backFaceView.topAnchor,
                constant: Layout.edgeInset
            ),
            backTitleLabel.leadingAnchor.constraint(
                equalTo: backButton.trailingAnchor,
                constant: Layout.backHeaderSpacing
            ),
            backTitleLabel.trailingAnchor.constraint(
                equalTo: backFaceView.trailingAnchor,
                constant: -Layout.edgeInset
            ),

            descriptionScrollView.topAnchor.constraint(
                greaterThanOrEqualTo: backButton.bottomAnchor,
                constant: Layout.backContentSpacing
            ),
            descriptionScrollView.topAnchor.constraint(
                greaterThanOrEqualTo: backTitleLabel.bottomAnchor,
                constant: Layout.backContentSpacing
            ),
            descriptionScrollView.leadingAnchor.constraint(
                equalTo: backFaceView.leadingAnchor,
                constant: Layout.edgeInset
            ),
            descriptionScrollView.trailingAnchor.constraint(
                equalTo: backFaceView.trailingAnchor,
                constant: -Layout.edgeInset
            ),
            descriptionScrollView.bottomAnchor.constraint(
                equalTo: backControlsStack.topAnchor,
                constant: -Layout.backContentSpacing
            ),

            backDescriptionLabel.topAnchor.constraint(
                equalTo: descriptionScrollView.contentLayoutGuide.topAnchor
            ),
            backDescriptionLabel.leadingAnchor.constraint(
                equalTo: descriptionScrollView.contentLayoutGuide.leadingAnchor
            ),
            backDescriptionLabel.trailingAnchor.constraint(
                equalTo: descriptionScrollView.contentLayoutGuide.trailingAnchor
            ),
            backDescriptionLabel.bottomAnchor.constraint(
                equalTo: descriptionScrollView.contentLayoutGuide.bottomAnchor
            ),
            backDescriptionLabel.widthAnchor.constraint(
                equalTo: descriptionScrollView.frameLayoutGuide.widthAnchor
            ),

            backControlsStack.leadingAnchor.constraint(
                equalTo: backFaceView.leadingAnchor,
                constant: Layout.edgeInset
            ),
            backControlsStack.trailingAnchor.constraint(
                equalTo: backFaceView.trailingAnchor,
                constant: -Layout.edgeInset
            ),
            backControlsStack.bottomAnchor.constraint(
                equalTo: backFaceView.bottomAnchor,
                constant: -Layout.edgeInset
            ),

            questionCountControl.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.segmentedControlHeight
            ),
            startButton.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.startButtonMinimumHeight
            )
        ])

        let preferredDescriptionTopConstraint = descriptionScrollView.topAnchor.constraint(
            equalTo: backTitleLabel.bottomAnchor,
            constant: Layout.backContentSpacing
        )
        preferredDescriptionTopConstraint.priority = .defaultHigh
        preferredDescriptionTopConstraint.isActive = true

        backFaceView.accessibilityElements = [
            backTitleLabel,
            backDescriptionLabel,
            questionCountLabel,
            questionCountControl,
            unavailableLabel,
            startButton,
            backButton
        ]
    }

    private func configureActions() {
        frontSurfaceButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        backSurfaceButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        infoButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        flipInteractionButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        questionCountControl.addTarget(
            self,
            action: #selector(questionCountChanged),
            for: .valueChanged
        )
        startButton.addTarget(self, action: #selector(startTapped), for: .touchUpInside)

        closeButton.installPressFeedback()
        infoButton.installPressFeedback()
        backButton.installPressFeedback()
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
    }

    private func applyAppearance(
        _ appearance: AppAppearance,
        themeID: String,
        themeTintColor: UIColor,
        borderColor: UIColor
    ) {
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle
        cardCornerRadius = appearance.themeCardCornerRadius

        configuredSurfaceColor = appearance.themeCardBackground(baseColor: themeTintColor)
        configuredBorderColor = borderColor
        configuredBorderWidth = appearance.themeCardBorderWidth
        applyConfiguredSurfaceAppearance()
        configuredShadowStyle = appearance.card.shadow
        let shadow = isTransitionShadowHidden ? AppShadowStyle.none : configuredShadowStyle
        rotatingCardView.applyShadow(shadow)

        frontTitleLabel.font = appearance.typography.font(
            size: Typography.frontTitleSize,
            weight: .bold
        )
        frontTitleLabel.textColor = appearance.themeCardTextColor(baseColor: themeTintColor)

        backTitleLabel.font = appearance.typography.font(
            size: Typography.backTitleSize,
            weight: .bold
        )
        backTitleLabel.textColor = appearance.surfaceTextColor
        backDescriptionLabel.font = appearance.typography.font(
            size: Typography.descriptionSize,
            weight: .regular
        )
        backDescriptionLabel.textColor = appearance.secondarySurfaceTextColor
        questionCountLabel.font = appearance.typography.font(
            size: Typography.captionSize,
            weight: .semibold
        )
        questionCountLabel.textColor = appearance.secondarySurfaceTextColor
        unavailableLabel.font = appearance.typography.font(
            size: Typography.unavailableSize,
            weight: .medium
        )
        unavailableLabel.textColor = appearance.destructiveColor

        [closeButton, infoButton, backButton].forEach { button in
            button.applyActionAppearance(
                appearance.iconButton,
                appearance: appearance,
                textColor: appearance.themeCardTextColor(baseColor: themeTintColor)
            )
        }

        let primaryButtonStyle = QuizThemeAccentStyle.primaryButtonStyle(
            themeID: themeID,
            appearance: appearance
        )
        startButton.titleLabel?.font = appearance.typography.font(
            size: Typography.buttonSize,
            weight: .semibold
        )
        startButton.applyActionAppearance(
            primaryButtonStyle,
            appearance: appearance,
            textColor: QuizThemeAccentStyle.primaryButtonTextColor(
                themeID: themeID,
                appearance: appearance
            )
        )

        questionCountControl.backgroundColor = appearance.row.backgroundColor
        questionCountControl.selectedSegmentTintColor = primaryButtonStyle.backgroundColor
        questionCountControl.layer.cornerRadius = appearance.row.cornerRadius
        questionCountControl.layer.borderWidth = appearance.row.borderWidth
        questionCountControl.layer.borderColor = appearance.row.borderColor.cgColor
        let segmentFont = appearance.typography.font(
            size: Typography.segmentSize,
            weight: .semibold
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: appearance.surfaceTextColor
            ],
            for: .normal
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: QuizThemeAccentStyle.primaryButtonTextColor(
                    themeID: themeID,
                    appearance: appearance
                )
            ],
            for: .selected
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: appearance.disabledTextColor
            ],
            for: .disabled
        )
    }

    private func applyConfiguredSurfaceAppearance() {
        let surfaceColor = isTransitionSurfaceHidden ? UIColor.clear : configuredSurfaceColor
        let borderColor = isTransitionSurfaceHidden ? UIColor.clear : configuredBorderColor
        let borderWidth = isTransitionSurfaceHidden ? CGFloat.zero : configuredBorderWidth

        [frontSurfaceView, backSurfaceView].forEach { surfaceView in
            surfaceView.backgroundColor = surfaceColor
            surfaceView.layer.cornerRadius = cardCornerRadius
            surfaceView.layer.cornerCurve = .continuous
            surfaceView.layer.borderWidth = borderWidth
            surfaceView.layer.borderColor = borderColor.cgColor
        }
        frontFaceView.backgroundColor = surfaceColor
        backFaceView.backgroundColor = surfaceColor
    }

    private func configureQuestionCounts(selectedQuestionCount: Int?) {
        for (index, count) in Self.supportedQuestionCounts.enumerated() {
            questionCountControl.setEnabled(
                availableQuestionCounts.contains(count),
                forSegmentAt: index
            )
        }

        let resolvedSelection = selectedQuestionCount.flatMap { selection in
            availableQuestionCounts.contains(selection) ? selection : nil
        }
            ?? Self.supportedQuestionCounts.first(where: availableQuestionCounts.contains)

        self.selectedQuestionCount = resolvedSelection
        if let resolvedSelection,
           let index = Self.supportedQuestionCounts.firstIndex(of: resolvedSelection) {
            questionCountControl.selectedSegmentIndex = index
        } else {
            questionCountControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }

        let isAvailable = resolvedSelection != nil
        unavailableLabel.isHidden = isAvailable
        unavailableLabel.accessibilityElementsHidden = isAvailable
        startButton.isEnabled = isAvailable
        startButton.accessibilityHint = isAvailable ? nil : L10n.Question.unavailableMessage
    }

    private func frontArtworkImage(themeID: String, appearance: AppAppearance) -> UIImage? {
        guard let image = ThemeVisualCatalog.logoImage(
            for: themeID,
            designStyle: appearance.designStyle
        ) else {
            return nil
        }

        switch appearance.designStyle {
        case .clean:
            let configuration = UIImage.SymbolConfiguration(
                pointSize: Layout.cleanFrontArtworkPointSize,
                weight: .regular
            )
            return image.applyingSymbolConfiguration(configuration) ?? image

        case .classic:
            let format = UIGraphicsImageRendererFormat()
            format.opaque = false
            format.scale = UIScreen.main.scale
            return UIGraphicsImageRenderer(
                size: Layout.classicFrontArtworkSize,
                format: format
            ).image { _ in
                image.draw(in: CGRect(origin: .zero, size: Layout.classicFrontArtworkSize))
            }

        case .radar:
            return image
        }
    }

    private func frontArtworkPointSize(for designStyle: AppDesignStyle) -> CGFloat {
        switch designStyle {
        case .classic:
            return Layout.classicFrontArtworkSize.width
        case .clean:
            return Layout.cleanFrontArtworkPointSize
        case .radar:
            return Layout.radarFrontArtworkPointSize
        }
    }

    private func animateCrossfade(
        to targetFace: HomeThemeCardFace,
        completion: ((HomeThemeCardFace) -> Void)?
    ) {
        beginFaceAnimation(
            to: targetFace,
            duration: Animation.reducedMotionDuration,
            curve: .easeInOut,
            reduceMotion: true,
            completion: completion
        )
    }

    private func animatePerspectiveFlip(
        to targetFace: HomeThemeCardFace,
        completion: ((HomeThemeCardFace) -> Void)?
    ) {
        beginFaceAnimation(
            to: targetFace,
            duration: Animation.flipDuration,
            curve: .linear,
            reduceMotion: false,
            completion: completion
        )
    }

    private func beginFaceAnimation(
        to targetFace: HomeThemeCardFace,
        duration: TimeInterval,
        curve: UIView.AnimationCurve,
        reduceMotion: Bool,
        completion: ((HomeThemeCardFace) -> Void)?
    ) {
        let startFace = face
        flipInteractionButton.isHidden = false
        prepareFaceAnimation(
            from: startFace,
            to: targetFace,
            reduceMotion: reduceMotion
        )

        let animator = UIViewPropertyAnimator(duration: duration, curve: curve) {
            self.applyFaceAnimationEndpoint(
                targetFace,
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

            UIAccessibility.post(
                notification: .layoutChanged,
                argument: completedFace == .front ? self.frontFocusView : self.backFocusView
            )
            requestedCompletion?(completedFace)
        }
        animator.startAnimation()
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
        layer.transform = CATransform3DIdentity
        flipInteractionButton.isHidden = true
        perspectiveStageView.layer.sublayerTransform = CATransform3DIdentity
        rotatingCardView.layer.transform = CATransform3DIdentity
        frontPlaneView.isHidden = !frontIsVisible
        frontPlaneView.alpha = 1
        frontPlaneView.layer.transform = CATransform3DIdentity
        backPlaneView.isHidden = frontIsVisible
        backPlaneView.alpha = 1
        backPlaneView.layer.transform = CATransform3DIdentity
        frontFaceView.isHidden = !frontIsVisible
        frontFaceView.alpha = 1
        frontFaceView.layer.transform = CATransform3DIdentity
        backFaceView.isHidden = frontIsVisible
        backFaceView.alpha = 1
        backFaceView.layer.transform = CATransform3DIdentity
        CATransaction.commit()
        updateAccessibilityVisibility(for: face)
    }

    private func prepareFaceAnimation(
        from startFace: HomeThemeCardFace,
        to targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        layer.transform = CATransform3DIdentity
        rotatingCardView.layer.transform = CATransform3DIdentity
        frontPlaneView.isHidden = false
        backPlaneView.isHidden = false
        frontFaceView.isHidden = false
        backFaceView.isHidden = false
        if reduceMotion {
            perspectiveStageView.layer.sublayerTransform = CATransform3DIdentity
            frontPlaneView.layer.transform = CATransform3DIdentity
            backPlaneView.layer.transform = CATransform3DIdentity
            frontPlaneView.alpha = startFace == .front ? 1 : 0
            backPlaneView.alpha = startFace == .back ? 1 : 0
        } else {
            var perspective = CATransform3DIdentity
            perspective.m34 = -1 / Animation.perspectiveDistance
            perspectiveStageView.layer.sublayerTransform = perspective
            frontPlaneView.alpha = 1
            backPlaneView.alpha = 1
            frontPlaneView.layer.transform = rotationY(startFace == .front ? 0 : .pi)
            backPlaneView.layer.transform = rotationY(startFace == .back ? 0 : .pi)
        }

        assert(startFace != targetFace)
    }

    private func applyFaceAnimationEndpoint(
        _ targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        if reduceMotion {
            rotatingCardView.layer.transform = CATransform3DIdentity
            frontPlaneView.alpha = targetFace == .front ? 1 : 0
            backPlaneView.alpha = targetFace == .back ? 1 : 0
        } else {
            rotatingCardView.layer.transform = rotationY(.pi)
        }
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

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === backTapGestureRecognizer else { return true }
        guard
            !descriptionScrollView.isTracking,
            !descriptionScrollView.isDragging,
            !descriptionScrollView.isDecelerating
        else { return false }

        var touchedView = touch.view
        while let currentView = touchedView, currentView !== backFaceView {
            if currentView is UIControl {
                return false
            }
            touchedView = currentView.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let includesBackTap = gestureRecognizer === backTapGestureRecognizer ||
            otherGestureRecognizer === backTapGestureRecognizer
        guard includesBackTap else { return false }

        return gestureRecognizer !== descriptionScrollView.panGestureRecognizer &&
            otherGestureRecognizer !== descriptionScrollView.panGestureRecognizer
    }

    @objc private func closeTapped() {
        onClose?()
    }

    @objc private func flipTapped() {
        onFlip?()
    }

    @objc private func backTapped() {
        onBack?()
    }

    @objc private func questionCountChanged() {
        let index = questionCountControl.selectedSegmentIndex
        guard Self.supportedQuestionCounts.indices.contains(index) else { return }
        let count = Self.supportedQuestionCounts[index]
        guard availableQuestionCounts.contains(count) else { return }
        selectedQuestionCount = count
        onQuestionCountChanged?(count)
    }

    @objc private func startTapped() {
        guard startButton.isEnabled, selectedQuestionCount != nil else { return }
        onStart?()
    }
}
