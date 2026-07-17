import UIKit

private final class ThemeCardTransformCarrierView: UIView {
    override class var layerClass: AnyClass {
        CATransformLayer.self
    }
}

final class ExpandedThemeCardView: UIView, UIGestureRecognizerDelegate {
    private enum AccessibilityID {
        static let root = "expandedThemeCardView"
        static let parallaxCarrier = "expandedThemeCardParallaxCarrier"
        static let frontPlane = "expandedThemeCardFrontPlane"
        static let backPlane = "expandedThemeCardBackPlane"
        static let rotatingCarrier = "expandedThemeCardRotatingCarrier"
        static let shadowProxy = "expandedThemeCardShadowProxy"
        static let frontArtworkDepth = "expandedThemeCardFrontArtworkDepth"
        static let frontTitleDepth = "expandedThemeCardFrontTitleDepth"
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
        static let parallaxReturnDuration: TimeInterval = 0.32
        static let parallaxReturnDamping: CGFloat = 0.86
        static let parallaxTransitionSettleDuration: TimeInterval = 0.18
    }

    private static let supportedQuestionCounts = QuizQuestionCountPolicy.supportedCounts

    var onClose: (() -> Void)?
    var onFlip: (() -> Void)?
    var onBack: (() -> Void)?
    var onQuestionCountChanged: ((Int) -> Void)?
    var onStart: (() -> Void)?
    var onAccessibilityEscape: (() -> Void)?
    var reduceMotionProvider: () -> Bool = { UIAccessibility.isReduceMotionEnabled }
    var deviceParallaxEnabledProvider: () -> Bool = { true }
    var deviceMotionProvider: HomeThemeCardMotionProviding = CoreMotionHomeThemeCardMotionProvider() {
        didSet {
            oldValue.stop()
            isDeviceMotionActive = false
            updateDeviceParallaxAvailability()
        }
    }

    var frontFocusView: UIView { frontTitleLabel }
    var backFocusView: UIView { backTitleLabel }
    var transitionSourceView: UIView { self }
    var isParallaxSettling: Bool { parallaxReturnAnimator != nil }

    private(set) var selectedQuestionCount: Int?
    private(set) var face: HomeThemeCardFace = .front

    private let perspectiveStageView = UIView()
    private let parallaxPoseProbeView = UIView()
    private let shadowProxyView = UIView()
    private let rotatingCardView = ThemeCardTransformCarrierView()
    private let frontPlaneView = UIView()
    private let backPlaneView = UIView()
    private let frontSurfaceView = UIView()
    private let backSurfaceView = UIView()
    private let frontFaceView = UIView()
    private let backFaceView = UIView()
    private let flipInteractionButton = UIButton(type: .custom)

    private let frontSurfaceButton = UIButton(type: .custom)
    private let frontArtworkDepthView = UIView()
    private let frontImageView = UIImageView()
    private let frontTitleDepthView = UIView()
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
    private lazy var cardParallaxPanGestureRecognizer = UIPanGestureRecognizer(
        target: self,
        action: #selector(cardParallaxPanned(_:))
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
    private let deviceParallaxStyle = HomeThemeCardDeviceParallaxStyle.standard
    private var parallaxPresentationPhase: HomeThemeCardParallaxPresentationPhase = .inactive
    private var isApplicationActive = true
    private var isDeviceMotionActive = false
    private var isTouchParallaxActive = false
    private var touchParallaxStartInput = HomeThemeCardParallaxInput.zero
    private var renderedParallaxInput = HomeThemeCardParallaxInput.zero
    private var parallaxReturnAnimator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
        configureActions()
        configureParallaxObservers()
        normalizeFaces(showing: .front)
    }

    deinit {
        deviceMotionProvider.stop()
        parallaxReturnAnimator?.stopAnimation(true)
        NotificationCenter.default.removeObserver(self)
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
        shadowProxyView.layer.shadowPath = shadowPath
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            cancelTouchParallaxAndReset()
        }
        updateDeviceParallaxAvailability()
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
        frontTitleLabel.transform = .identity
        frontArtworkDepthView.transform = .identity
        frontTitleDepthView.transform = .identity
        perspectiveStageView.layer.transform = CATransform3DIdentity
        parallaxPoseProbeView.transform = .identity
        layer.sublayerTransform = CATransform3DIdentity
        renderedParallaxInput = .zero
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

    func setParallaxPresentationPhase(_ phase: HomeThemeCardParallaxPresentationPhase) {
        guard parallaxPresentationPhase != phase else {
            updateDeviceParallaxAvailability()
            return
        }

        let previousPhase = parallaxPresentationPhase
        parallaxPresentationPhase = phase
        if previousPhase.preservesParallaxContinuity,
           !phase.preservesParallaxContinuity {
            if phase == .inactive {
                // Launch/removal must stop sampling before the router snapshots
                // the transition source; no return animation may outlive the card.
                cancelTouchParallaxAndReset()
            } else {
                settleParallaxForPresentationTransition()
            }
        }
        updateDeviceParallaxAvailability()
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

        if reduceMotionProvider() {
            animateCrossfade(to: targetFace, completion: completion)
        } else {
            animatePerspectiveFlip(to: targetFace, completion: completion)
        }
    }

    func setTransitionShadowHidden(_ isHidden: Bool) {
        isTransitionShadowHidden = isHidden
        let shadow = isHidden ? AppShadowStyle.none : configuredShadowStyle
        shadowProxyView.applyShadow(shadow)
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
        let parallaxState = HomeThemeCardExpansionParallaxState(progress: progress)
        let remainingTranslation = 1 - visualState.progress
        let imageTranslation = sourceGeometry.imageTranslation(
            toAlignDestinationCenter: frontArtworkDepthView.center,
            in: bounds.size
        )
        let titleTranslation = sourceGeometry.titleTranslation(
            toAlignDestinationCenter: frontTitleDepthView.center,
            in: bounds.size
        )
        let usesSpatialMotion = !reduceMotionProvider()
        let artworkScale = usesSpatialMotion ? parallaxState.artworkScale : 1
        let titleScale = usesSpatialMotion ? parallaxState.titleScale : 1

        frontArtworkDepthView.transform = CGAffineTransform(
            a: artworkScale,
            b: 0,
            c: 0,
            d: artworkScale,
            tx: imageTranslation.x * remainingTranslation,
            ty: imageTranslation.y * remainingTranslation
        )
        frontTitleDepthView.transform = CGAffineTransform(
            a: titleScale,
            b: 0,
            c: 0,
            d: titleScale,
            tx: titleTranslation.x * remainingTranslation,
            ty: titleTranslation.y * remainingTranslation
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
        perspectiveStageView.accessibilityIdentifier = AccessibilityID.parallaxCarrier
        addSubview(perspectiveStageView)

        // A clear one-point probe stores the normalized pose so an interrupted
        // spring can sample its presentation value without moving visible content.
        parallaxPoseProbeView.translatesAutoresizingMaskIntoConstraints = false
        parallaxPoseProbeView.backgroundColor = .clear
        parallaxPoseProbeView.isUserInteractionEnabled = false
        parallaxPoseProbeView.accessibilityElementsHidden = true
        addSubview(parallaxPoseProbeView)

        shadowProxyView.accessibilityIdentifier = AccessibilityID.shadowProxy
        shadowProxyView.translatesAutoresizingMaskIntoConstraints = false
        shadowProxyView.backgroundColor = .clear
        shadowProxyView.layer.masksToBounds = false
        perspectiveStageView.addSubview(shadowProxyView)

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
            // CATransformLayer preserves both sides in one 3D coordinate space.
            // The carrier performs the entire 180-degree turn while these planes
            // keep a fixed offset, so the visual motion never reverses at 90°.
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

            parallaxPoseProbeView.leadingAnchor.constraint(equalTo: leadingAnchor),
            parallaxPoseProbeView.topAnchor.constraint(equalTo: topAnchor),
            parallaxPoseProbeView.widthAnchor.constraint(equalToConstant: 1),
            parallaxPoseProbeView.heightAnchor.constraint(equalToConstant: 1),

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

    private func configureFrontFace() {
        frontFaceView.accessibilityIdentifier = AccessibilityID.front

        frontSurfaceButton.accessibilityIdentifier = AccessibilityID.frontSurfaceButton
        frontSurfaceButton.isAccessibilityElement = false
        frontSurfaceButton.translatesAutoresizingMaskIntoConstraints = false

        frontArtworkDepthView.accessibilityIdentifier = AccessibilityID.frontArtworkDepth
        frontArtworkDepthView.translatesAutoresizingMaskIntoConstraints = false
        frontArtworkDepthView.isUserInteractionEnabled = false

        frontImageView.accessibilityIdentifier = AccessibilityID.frontImage
        frontImageView.contentMode = .scaleAspectFit
        frontImageView.isAccessibilityElement = false
        frontImageView.isUserInteractionEnabled = false
        frontImageView.translatesAutoresizingMaskIntoConstraints = false

        frontTitleDepthView.accessibilityIdentifier = AccessibilityID.frontTitleDepth
        frontTitleDepthView.translatesAutoresizingMaskIntoConstraints = false
        frontTitleDepthView.isUserInteractionEnabled = false

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
            systemImageName: "play.fill",
            accessibilityIdentifier: AccessibilityID.infoButton,
            accessibilityLabel: L10n.ThemeCard.showDescriptionAccessibilityLabel
        )

        frontFaceView.addSubview(frontSurfaceButton)
        frontFaceView.addSubview(frontArtworkDepthView)
        frontArtworkDepthView.addSubview(frontImageView)
        frontFaceView.addSubview(frontTitleDepthView)
        frontTitleDepthView.addSubview(frontTitleLabel)
        frontFaceView.addSubview(closeButton)
        frontFaceView.addSubview(infoButton)
        frontImageSizeConstraint = frontArtworkDepthView.widthAnchor.constraint(
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

            frontTitleDepthView.leadingAnchor.constraint(
                equalTo: frontFaceView.leadingAnchor,
                constant: Layout.frontImageHorizontalInset
            ),
            frontTitleDepthView.trailingAnchor.constraint(
                lessThanOrEqualTo: infoButton.leadingAnchor,
                constant: -Layout.frontTitleToInfoSpacing
            ),
            frontTitleDepthView.bottomAnchor.constraint(
                equalTo: frontFaceView.bottomAnchor,
                constant: -Layout.frontTitleBottomInset
            ),

            frontTitleLabel.leadingAnchor.constraint(equalTo: frontTitleDepthView.leadingAnchor),
            frontTitleLabel.trailingAnchor.constraint(equalTo: frontTitleDepthView.trailingAnchor),
            frontTitleLabel.topAnchor.constraint(equalTo: frontTitleDepthView.topAnchor),
            frontTitleLabel.bottomAnchor.constraint(equalTo: frontTitleDepthView.bottomAnchor),

            frontArtworkDepthView.centerXAnchor.constraint(equalTo: frontFaceView.centerXAnchor),
            frontArtworkDepthView.centerYAnchor.constraint(
                equalTo: frontFaceView.centerYAnchor,
                constant: Layout.frontArtworkCenterYOffset
            ),
            frontImageSizeConstraint,
            frontArtworkDepthView.heightAnchor.constraint(equalTo: frontArtworkDepthView.widthAnchor),
            frontArtworkDepthView.topAnchor.constraint(
                greaterThanOrEqualTo: closeButton.bottomAnchor,
                constant: Layout.frontImageToTitleSpacing
            ),
            frontArtworkDepthView.bottomAnchor.constraint(
                lessThanOrEqualTo: frontTitleDepthView.topAnchor,
                constant: -Layout.frontImageToTitleSpacing
            ),

            frontImageView.leadingAnchor.constraint(equalTo: frontArtworkDepthView.leadingAnchor),
            frontImageView.trailingAnchor.constraint(equalTo: frontArtworkDepthView.trailingAnchor),
            frontImageView.topAnchor.constraint(equalTo: frontArtworkDepthView.topAnchor),
            frontImageView.bottomAnchor.constraint(equalTo: frontArtworkDepthView.bottomAnchor)
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
        descriptionScrollView.isDirectionalLockEnabled = true
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
        cardParallaxPanGestureRecognizer.name = "expandedThemeCardParallaxPan"
        cardParallaxPanGestureRecognizer.maximumNumberOfTouches = 1
        cardParallaxPanGestureRecognizer.cancelsTouchesInView = true
        cardParallaxPanGestureRecognizer.delaysTouchesBegan = false
        cardParallaxPanGestureRecognizer.delegate = self
        // The outer card owns one pan for both faces. On the back, it recognizes
        // alongside the description scroll view so the whole card remains a
        // continuous tilt surface without taking scrolling away from the user.
        addGestureRecognizer(cardParallaxPanGestureRecognizer)
        backTapGestureRecognizer.require(toFail: cardParallaxPanGestureRecognizer)

        frontSurfaceButton.addTarget(self, action: #selector(flipTapped), for: .touchUpInside)
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
        shadowProxyView.applyShadow(shadow)

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
            // The image view is square, but scaleAspectFit preserves the artwork's
            // intrinsic ratio. Re-rasterizing into a square visibly stretched the
            // non-square Classic assets during the source-to-card crossfade.
            return image

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
        updateDeviceParallaxAvailability()

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
        let carrierAngle = HomeThemeCardFlipTransition.carrierAngle(showing: face)
        shadowProxyView.layer.transform = rotationY(carrierAngle)
        rotatingCardView.layer.transform = rotationY(carrierAngle)
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
        frontFaceView.alpha = 1
        frontFaceView.layer.transform = CATransform3DIdentity
        backFaceView.isHidden = frontIsVisible
        backFaceView.alpha = 1
        backFaceView.layer.transform = CATransform3DIdentity
        CATransaction.commit()
        updateAccessibilityVisibility(for: face)
        updateDeviceParallaxAvailability()
    }

    private func prepareFaceAnimation(
        from startFace: HomeThemeCardFace,
        to targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        layer.transform = CATransform3DIdentity
        shadowProxyView.layer.transform = CATransform3DIdentity
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
            shadowProxyView.layer.transform = rotationY(carrierAngle)
            rotatingCardView.layer.transform = rotationY(carrierAngle)
        }

        assert(startFace != targetFace)
    }

    private func applyFaceAnimationEndpoint(
        from startFace: HomeThemeCardFace,
        to targetFace: HomeThemeCardFace,
        reduceMotion: Bool
    ) {
        if reduceMotion {
            shadowProxyView.layer.transform = CATransform3DIdentity
            rotatingCardView.layer.transform = CATransform3DIdentity
            frontPlaneView.alpha = targetFace == .front ? 1 : 0
            backPlaneView.alpha = targetFace == .back ? 1 : 0
        } else {
            guard let transition = HomeThemeCardFlipTransition(
                startFace: startFace,
                targetFace: targetFace
            ) else { return }
            let carrierAngle = transition.carrierAngle(progress: 1)
            shadowProxyView.layer.transform = rotationY(carrierAngle)
            rotatingCardView.layer.transform = rotationY(carrierAngle)
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

    private func configureParallaxObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    private var canUseTouchParallax: Bool {
        window != nil &&
            isApplicationActive &&
            !reduceMotionProvider() &&
            parallaxPresentationPhase.permitsTouchParallax(currentFace: face) &&
            activeFaceAnimator == nil
    }

    private func updateDeviceParallaxAvailability() {
        let shouldEnableTouch = canUseTouchParallax
        if cardParallaxPanGestureRecognizer.isEnabled != shouldEnableTouch {
            cardParallaxPanGestureRecognizer.isEnabled = shouldEnableTouch
        }

        let shouldStartDeviceMotion = window != nil &&
            isApplicationActive &&
            !reduceMotionProvider() &&
            deviceParallaxEnabledProvider() &&
            deviceMotionProvider.isAvailable &&
            !isTouchParallaxActive &&
            parallaxReturnAnimator == nil &&
            parallaxPresentationPhase.permitsDeviceMotion(currentFace: face)

        if shouldStartDeviceMotion, !isDeviceMotionActive {
            isDeviceMotionActive = true
            deviceMotionProvider.start { [weak self] input in
                guard let self else { return }
                if Thread.isMainThread {
                    self.receiveDeviceParallaxInput(input)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.receiveDeviceParallaxInput(input)
                    }
                }
            }
        } else if !shouldStartDeviceMotion, isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
            if !isTouchParallaxActive, parallaxReturnAnimator == nil {
                applyParallaxInput(.zero, disablesImplicitAnimations: true)
            }
        } else if !shouldStartDeviceMotion,
                  !isTouchParallaxActive,
                  parallaxReturnAnimator == nil,
                  !renderedParallaxInput.isNeutral {
            applyParallaxInput(.zero, disablesImplicitAnimations: true)
        }
    }

    private func receiveDeviceParallaxInput(_ input: HomeThemeCardParallaxInput) {
        guard
            isDeviceMotionActive,
            !isTouchParallaxActive,
            !reduceMotionProvider(),
            parallaxPresentationPhase.permitsDeviceMotion(currentFace: face)
        else { return }

        applyParallaxInput(input, disablesImplicitAnimations: true)
    }

    private func applyParallaxInput(
        _ input: HomeThemeCardParallaxInput,
        disablesImplicitAnimations: Bool
    ) {
        let renderState = HomeThemeCardParallaxRenderState(
            input: input,
            style: deviceParallaxStyle
        )

        let applyChanges = {
            if renderState.isNeutral {
                self.layer.sublayerTransform = CATransform3DIdentity
                self.perspectiveStageView.layer.transform = CATransform3DIdentity
                self.parallaxPoseProbeView.transform = .identity
            } else {
                var perspective = CATransform3DIdentity
                perspective.m34 = -1 / renderState.perspectiveDistance
                self.layer.sublayerTransform = perspective

                var cardTransform = CATransform3DIdentity
                cardTransform = CATransform3DRotate(
                    cardTransform,
                    renderState.rotationX,
                    1,
                    0,
                    0
                )
                cardTransform = CATransform3DRotate(
                    cardTransform,
                    renderState.rotationY,
                    0,
                    1,
                    0
                )
                self.perspectiveStageView.layer.transform = cardTransform
                self.parallaxPoseProbeView.transform = CGAffineTransform(
                    translationX: input.x,
                    y: input.y
                )
            }
        }

        if disablesImplicitAnimations {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyChanges()
            CATransaction.commit()
        } else {
            applyChanges()
        }
        renderedParallaxInput = input
    }

    private func beginTouchParallax() {
        guard canUseTouchParallax else { return }
        let liveInput = presentationParallaxInput()
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)

        if isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
        }
        touchParallaxStartInput = liveInput
        isTouchParallaxActive = true
    }

    private func finishTouchParallax(velocity: CGPoint) {
        guard isTouchParallaxActive else { return }
        isTouchParallaxActive = false

        let liveInput = presentationParallaxInput()
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)
        let normalizedVelocity = HomeThemeCardPanParallaxMapper.normalizedVelocity(
            velocity,
            in: bounds.size
        )
        let timing = UISpringTimingParameters(
            dampingRatio: Animation.parallaxReturnDamping,
            initialVelocity: CGVector(
                dx: relativeSpringVelocity(
                    normalizedVelocity.dx,
                    currentValue: liveInput.x
                ),
                dy: relativeSpringVelocity(
                    normalizedVelocity.dy,
                    currentValue: liveInput.y
                )
            )
        )
        let animator = UIViewPropertyAnimator(
            duration: Animation.parallaxReturnDuration,
            timingParameters: timing
        )
        parallaxReturnAnimator = animator
        animator.addAnimations { [weak self] in
            self?.applyParallaxInput(.zero, disablesImplicitAnimations: false)
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.parallaxReturnAnimator === animator else { return }
            self.parallaxReturnAnimator = nil
            self.applyParallaxInput(.zero, disablesImplicitAnimations: true)
            self.updateDeviceParallaxAvailability()
        }
        animator.startAnimation()
    }

    private func relativeSpringVelocity(
        _ velocity: CGFloat,
        currentValue: CGFloat
    ) -> CGFloat {
        let remainingDistance = -currentValue
        guard abs(remainingDistance) > 0.01 else { return 0 }
        return min(max(velocity / remainingDistance, -8), 8)
    }

    private func presentationParallaxInput() -> HomeThemeCardParallaxInput {
        guard let presentationTransform = parallaxPoseProbeView.layer.presentation()?.transform else {
            return renderedParallaxInput
        }

        return HomeThemeCardParallaxInput(
            x: presentationTransform.m41,
            y: presentationTransform.m42
        )
    }

    private func cancelTouchParallaxAndReset() {
        isTouchParallaxActive = false
        touchParallaxStartInput = .zero
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(.zero, disablesImplicitAnimations: true)
    }

    private func settleParallaxForPresentationTransition() {
        isTouchParallaxActive = false
        touchParallaxStartInput = .zero

        if isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
        }

        guard !reduceMotionProvider() else {
            cancelTouchParallaxAndReset()
            return
        }

        let liveInput = presentationParallaxInput()
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)

        guard !liveInput.isNeutral else {
            applyParallaxInput(.zero, disablesImplicitAnimations: true)
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: Animation.parallaxTransitionSettleDuration,
            curve: .easeOut
        )
        parallaxReturnAnimator = animator
        animator.addAnimations { [weak self] in
            self?.applyParallaxInput(.zero, disablesImplicitAnimations: false)
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.parallaxReturnAnimator === animator else { return }
            self.parallaxReturnAnimator = nil
            self.applyParallaxInput(.zero, disablesImplicitAnimations: true)
            self.updateDeviceParallaxAvailability()
        }
        animator.startAnimation()
    }

    @objc private func cardParallaxPanned(_ recognizer: UIPanGestureRecognizer) {
        handleFrontParallaxPan(
            state: recognizer.state,
            translation: recognizer.translation(in: self),
            velocity: recognizer.velocity(in: self)
        )
    }

    func handleFrontParallaxPan(
        state: UIGestureRecognizer.State,
        translation: CGPoint,
        velocity: CGPoint
    ) {
        switch state {
        case .began:
            beginTouchParallax()

        case .changed:
            if !isTouchParallaxActive {
                beginTouchParallax()
            }
            guard isTouchParallaxActive else { return }
            let input = HomeThemeCardPanParallaxMapper.input(
                translation: translation,
                in: bounds.size,
                startingAt: touchParallaxStartInput
            )
            applyParallaxInput(input, disablesImplicitAnimations: true)

        case .ended:
            guard isTouchParallaxActive else { return }
            let input = HomeThemeCardPanParallaxMapper.input(
                translation: translation,
                in: bounds.size,
                startingAt: touchParallaxStartInput
            )
            applyParallaxInput(input, disablesImplicitAnimations: true)
            finishTouchParallax(velocity: velocity)

        case .cancelled, .failed:
            finishTouchParallax(velocity: .zero)

        case .possible:
            break

        @unknown default:
            cancelTouchParallaxAndReset()
        }
    }

    @objc private func applicationWillResignActive() {
        isApplicationActive = false
        cancelTouchParallaxAndReset()
        updateDeviceParallaxAvailability()
    }

    @objc private func applicationDidBecomeActive() {
        isApplicationActive = true
        updateDeviceParallaxAvailability()
    }

    @objc private func reduceMotionStatusDidChange() {
        if reduceMotionProvider() {
            cancelTouchParallaxAndReset()
        }
        updateDeviceParallaxAvailability()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === cardParallaxPanGestureRecognizer else { return true }
        return canUseTouchParallax
    }

    func allowsParallaxPan(startingAt touchedView: UIView?) -> Bool {
        guard let touchedView else { return false }

        switch face {
        case .front:
            let touchesFront = touchedView === frontFaceView ||
                touchedView.isDescendant(of: frontFaceView)
            let touchesClose = touchedView === closeButton ||
                touchedView.isDescendant(of: closeButton)
            let touchesInfo = touchedView === infoButton ||
                touchedView.isDescendant(of: infoButton)
            return touchesFront && !touchesClose && !touchesInfo

        case .back:
            let touchesBack = touchedView === backFaceView ||
                touchedView.isDescendant(of: backFaceView)
            // A pan has its own movement threshold. Let it begin anywhere on
            // the back, including over controls: a stationary touch still
            // reaches the control, while an intentional drag cancels that
            // touch and drives the card tilt. Filtering UIControl descendants
            // left the whole central controls column as a dead parallax
            // zone, so the gesture appeared to work only near the edges.
            return touchesBack
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === cardParallaxPanGestureRecognizer {
            return allowsParallaxPan(startingAt: touch.view)
        }
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
        let isParallaxAndDescriptionPair =
            (gestureRecognizer === cardParallaxPanGestureRecognizer &&
                otherGestureRecognizer === descriptionScrollView.panGestureRecognizer) ||
            (gestureRecognizer === descriptionScrollView.panGestureRecognizer &&
                otherGestureRecognizer === cardParallaxPanGestureRecognizer)
        guard isParallaxAndDescriptionPair else { return false }
        return HomeThemeCardParallaxGesturePolicy
            .permitsSimultaneousDescriptionScroll(on: face)
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
