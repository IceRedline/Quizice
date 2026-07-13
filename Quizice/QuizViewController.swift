import UIKit

final class QuizViewController: BaseQuizViewController, QuizViewControllerProtocol, ThemeCollectionDelegate, QuizCardSlideTransitionSource, QuizHomeReturnHandling {
    private enum Content {
#if DEBUG
        static let backgroundStyleIconName = "circle.grid.3x3.fill"
        static let hideInterfaceIconName = "eye.slash"
        static let showInterfaceIconName = "eye"
#endif
        static let settingsIconName = "gear"
        static let themeCellReuseIdentifier = "themeCell"
    }

    private enum AccessibilityID {
        static let rootView = "homeRootView"
        static let motivationLabel = "homeMotivationLabel"
        static let motivationBlurredImageView = "homeMotivationBlurredImageView"
        static let headerStackView = "homeHeaderStackView"
        static let themesCollectionView = "homeThemesCollectionView"
        static let screenStackView = "homeScreenStackView"
        static let settingsButton = "homeSettingsButton"
        static let settingsVisualSurface = "homeSettingsVisualSurface"
        static let expandedCard = "homeExpandedThemeCard"
        static let expandedStatisticsCard = "homeExpandedStatisticsCard"
        static let expandedAIThemeCard = "homeExpandedAIThemeCard"
        static let expandedCardBackdrop = "homeExpandedThemeCardBackdrop"
        static let expandedCardBackdropDismissButton = "homeExpandedThemeCardBackdropDismissButton"
        static let expandedCardTransition = "homeExpandedThemeCardTransition"
        static let expandedStatisticsCardTransition = "homeExpandedStatisticsCardTransition"
        static let expandedAIThemeCardTransition = "homeExpandedAIThemeCardTransition"
        static let expandedCardSourceSnapshot = "homeExpandedThemeCardSourceSnapshot"
        static let expandedStatisticsCardSourceSnapshot = "homeExpandedStatisticsCardSourceSnapshot"
        static let expandedAIThemeCardSourceSnapshot = "homeExpandedAIThemeCardSourceSnapshot"
        static let aiThemeAlertRetryButton = "aiThemeAlertRetryButton"
        static let aiThemeAlertDismissButton = "aiThemeAlertDismissButton"
    }

    private enum Layout {
        static let headerStackSpacing: CGFloat = 0
        static let headerHorizontalInset: CGFloat = 24
        static let screenTopInset: CGFloat = 28
        static let screenBottomInset: CGFloat = 0
        static let screenStackSpacing: CGFloat = 0
        static let headerToCollectionSpacing: CGFloat = 22
        static let collectionItemSpacing: CGFloat = 16
        static let collectionHorizontalInset: CGFloat = 24
        static let collectionTopInset: CGFloat = 0
        static let collectionBottomInset: CGFloat = 0
        static let motivationFadeDistance: CGFloat = 72
        static let motivationBlurRampDistance: CGFloat = 18
        static let motivationBlurHoldDistance: CGFloat = 42
        static let motivationBlurRadius: CGFloat = 7
        static let motivationBlurPadding: CGFloat = 24
        static let settingsButtonTopInset: CGFloat = 8
        static let settingsButtonTrailingInset: CGFloat = 14
        static let settingsButtonSize: CGFloat = 44
        static let settingsButtonVisualSize: CGFloat = 36
        static let visibleCellRowSortingTolerance: CGFloat = 1
        static let scrollActivationTolerance: CGFloat = 1

        static var headerMargins: NSDirectionalEdgeInsets {
            NSDirectionalEdgeInsets(
                top: .zero,
                leading: headerHorizontalInset,
                bottom: .zero,
                trailing: headerHorizontalInset
            )
        }

        static var collectionSectionInsets: UIEdgeInsets {
            UIEdgeInsets(
                top: collectionTopInset,
                left: collectionHorizontalInset,
                bottom: collectionBottomInset,
                right: collectionHorizontalInset
            )
        }

        static var screenMargins: NSDirectionalEdgeInsets {
            NSDirectionalEdgeInsets(
                top: screenTopInset,
                leading: .zero,
                bottom: screenBottomInset,
                trailing: .zero
            )
        }
    }

    private enum Typography {
        static let motivationFontSize: CGFloat = 26
        static let actionButtonFontSize: CGFloat = 19
        static let settingsIconPointSize: CGFloat = 14
        static let unlimitedNumberOfLines = 0
    }

    private enum Appearance {
        static let hiddenAlpha: CGFloat = 0
        static let visibleAlpha: CGFloat = 1
        static let motivationBlurMaxAlpha: CGFloat = 0.82
        static let headerLayerZPosition: CGFloat = 0
        static let collectionLayerZPosition: CGFloat = 10
        static let controlsLayerZPosition: CGFloat = 20
        static let expandedCardBackdropLayerZPosition: CGFloat = 100
        static let expandedCardLayerZPosition: CGFloat = 110
        static let reducedTransparencyBackdropAlpha: CGFloat = 0.96

        static let primaryButtonBackgroundAlpha: CGFloat = 0.88
        static let primaryButtonCornerRadius: CGFloat = 22
        static let primaryButtonShadowOpacity: Float = 0.24
        static let primaryButtonShadowRadius: CGFloat = 14
        static let primaryButtonShadowOffset = CGSize(width: 0, height: 8)
        static let settingsButtonBackgroundAlpha: CGFloat = 0.14
        static let settingsButtonBorderAlpha: CGFloat = 0.22
        static let settingsButtonShadowOpacity: Float = 0.18
        static let settingsButtonShadowRadius: CGFloat = 12
        static let settingsButtonShadowOffset = CGSize(width: 0, height: 6)

    }

    private enum AnimationTiming {
        static let revealDuration: TimeInterval = 0.22
        static let cellFadeInStagger: TimeInterval = 0.04
        static let initialVisibleAlpha: CGFloat = 0.92
        static let cardExpansionDuration: TimeInterval = 0.32
        static let reducedMotionDuration: TimeInterval = 0.18
        static let cardExpansionDampingRatio: CGFloat = 1
    }

    private enum ExpandedCardLayout {
        static let horizontalInset: CGFloat = 20
        static let topInset: CGFloat = 72
        static let bottomInset: CGFloat = 20
        static let maximumWidth: CGFloat = 430
        static let minimumHeight: CGFloat = 430
        static let heightToWidthRatio: CGFloat = 1.48
        static let keyboardSpacing: CGFloat = 12
        static let keyboardMinimumTopInset: CGFloat = 8
    }

    private var motivationContainerView: UIView!
    private var motivationLabel: UILabel!
    private var motivationBlurredImageView: UIImageView!
    private var headerStackView: UIStackView!
    private var screenStackView: UIStackView!
    private var settingsButton: UIButton!
    private var settingsButtonVisualSurface: UIView!
#if DEBUG
    private var isDebugInterfaceHidden = false
#endif

    private var themesCollectionView: UICollectionView!

    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging
    private let statisticsStore: StatisticsStore
    private let aiQuizThemeService: AIQuizThemeServiceProtocol
    private let analytics: AnalyticsTracking
    private let themesCollectionService: ThemesCollectionService
    private let motivationPromptProvider: (String?) -> String
    private let randomThemeIDProvider: ([QuizTheme]) -> String?
    private let cardReduceMotionProvider: () -> Bool
    private let cardReduceTransparencyProvider: () -> Bool
    private let cardDeviceParallaxEnabledProvider: () -> Bool
    private let cardMotionProvider: HomeThemeCardMotionProviding
    private let aiNow: () -> Date
    private let aiRequestIDProvider: () -> UUID
    private let feelingLuckyMinimumFeedbackDelay: () async -> Void
    private let animationsEngine = Animations()
    private let motivationBlurContext = CIContext(options: nil)
    private var motivationBlurSnapshotSignature: String?
    private var homeCardState = HomeThemeCardState()
    private var homeAIThemeCardState = HomeAIThemeCardState()
    private var expandedThemeCardView: ExpandedThemeCardView?
    private var expandedStatisticsCardView: ExpandedStatisticsCardView?
    private var expandedAIThemeCardView: ExpandedAIThemeCardView?
    private var expandedCardBackdropView: UIView?
    private var expandedCardBackdropDismissButton: UIButton?
    private var expandedCardBlurView: UIVisualEffectView?
    private var expandedCardSnapshotView: UIView?
    private var expandedCardSourceContentView: UIView?
    private var expandedCardSourceContentGeometry: HomeThemeCardContentGeometry?
    private var expandedCardTransitionView: ThemeCardExpansionTransitionView?
    private var expandedCardInteractionButton: ThemeCardTransitionInteractionButton?
    private var expandedCardAnimator: UIViewPropertyAnimator?
    private var expandedAIKeyboardAnimator: UIViewPropertyAnimator?
    private var expandedTheme: QuizTheme?
    private var expandedStatisticsSummary: StatisticsSummary?
    private var aiSubmissionTask: Task<Void, Never>?
    private var aiProgressTask: Task<Void, Never>?
    private var aiAlertPresentationTask: Task<Void, Never>?
    private let aiAlertPresenter = QuizAlertPresenter()
    private var feelingLuckyTask: Task<Void, Never>?
    private var feelingLuckyRequestID: UUID?
    private weak var quizTransitionSourceView: UIView?
    private var isQuizLaunchPending = false
    private var hasQuizLaunchStarted = false
    private var closeAfterFlipToFront = false
    private var focusAIThemePromptAfterFlip = false
    private var expandedCardNeedsRefresh = false
    private var expandedCardScreenViewTracked = false
    private var expandedCardLastTrackedFace: HomeThemeCardFace?
    private var expandedAIKeyboardLift: CGFloat = 0
    weak var router: QuizRouting?
    var presenter: QuizPresenterProtocol?

    var cardSlideTransitionSourceView: UIView {
        quizTransitionSourceView
            ?? expandedThemeCardView?.transitionSourceView
            ?? expandedAIThemeCardView
            ?? themesCollectionView
    }

    var cardSlideTransitionHorizontalInset: CGFloat { ExpandedCardLayout.horizontalInset }

    private var expandedCardContentView: UIView? {
        if let expandedThemeCardView { return expandedThemeCardView }
        if let expandedStatisticsCardView { return expandedStatisticsCardView }
        return expandedAIThemeCardView
    }

    private var startupAnimatedViews: [UIView] {
        [motivationLabel, motivationBlurredImageView, themesCollectionView, settingsButton]
    }

    init(
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizSessionStore.shared,
        statisticsStore: StatisticsStore = StatisticsStore(),
        aiQuizThemeService: AIQuizThemeServiceProtocol = MockAIQuizThemeService(),
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        motivationPromptProvider: @escaping (String?) -> String = QuizViewController.randomMotivationPrompt,
        randomThemeIDProvider: @escaping ([QuizTheme]) -> String? = { $0.randomElement()?.stableID },
        cardReduceMotionProvider: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        cardReduceTransparencyProvider: @escaping () -> Bool = { UIAccessibility.isReduceTransparencyEnabled },
        cardDeviceParallaxEnabledProvider: @escaping () -> Bool = { true },
        cardMotionProvider: HomeThemeCardMotionProviding = CoreMotionHomeThemeCardMotionProvider(),
        aiNow: @escaping () -> Date = Date.init,
        aiRequestIDProvider: @escaping () -> UUID = UUID.init,
        feelingLuckyMinimumFeedbackDelay: @escaping () async -> Void = {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
    ) {
        self.themeRepository = themeRepository
        self.session = session
        self.statisticsStore = statisticsStore
        self.aiQuizThemeService = aiQuizThemeService
        self.analytics = analytics
        self.motivationPromptProvider = motivationPromptProvider
        self.randomThemeIDProvider = randomThemeIDProvider
        self.themesCollectionService = ThemesCollectionService(
            themeRepository: themeRepository,
            statisticsStore: statisticsStore
        )
        self.cardReduceMotionProvider = cardReduceMotionProvider
        self.cardReduceTransparencyProvider = cardReduceTransparencyProvider
        self.cardDeviceParallaxEnabledProvider = cardDeviceParallaxEnabledProvider
        self.cardMotionProvider = cardMotionProvider
        self.aiNow = aiNow
        self.aiRequestIDProvider = aiRequestIDProvider
        self.feelingLuckyMinimumFeedbackDelay = feelingLuckyMinimumFeedbackDelay
        super.init(nibName: nil, bundle: nil)
    }

    deinit {
        aiSubmissionTask?.cancel()
        aiProgressTask?.cancel()
        aiAlertPresentationTask?.cancel()
        feelingLuckyTask?.cancel()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
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

        if session.startup1st {
            themeRepository.loadData(forceReload: false)
        }

        if presenter == nil {
            configurePresenter(QuizPresenter(session: session))
        }

        configureThemesCollectionService()
        installLocalizationObserver()
        updateThemeAvailabilityMessage()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let settingsButtonVisualSurface {
            settingsButton.sendSubviewToBack(settingsButtonVisualSurface)
        }
        updateCollectionTopInset()
        updateCollectionScrollAvailability()
        expandedCardBackdropView?.frame = view.bounds
        expandedCardBackdropDismissButton?.frame = view.bounds
        if expandedCardAnimator == nil,
           homeCardState.phase == .expandedFront || homeCardState.phase == .expandedBack {
            expandedThemeCardView?.frame = expandedThemeCardFrame()
            expandedStatisticsCardView?.frame = expandedThemeCardFrame()
            expandedAIThemeCardView?.frame = expandedAIThemeCardFrame()
        }
        if !session.startup1st {
            updateMotivationHeaderVisibility(for: themesCollectionView)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restoreHomeAfterQuizIfNeeded()
        themesCollectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        restoreHomeAfterQuizIfNeeded()
        analytics.track(.screenView(screen: .home))

        if session.startup1st {
            animateStartupViews()
            session.startup1st = false
        }
    }

    func configurePresenter(_ presenter: any QuizPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }

    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureHeaderViews()
        configureSettingsButton()
        configureHeaderStack()
        configureThemesCollectionView()
        configureScreenStack()
        configureInitialStartupVisibilityIfNeeded()

        rootView.addSubview(headerStackView)
        rootView.addSubview(screenStackView)
        rootView.addSubview(settingsButton)
        applyLayerOrdering()
        activateLayoutConstraints(in: rootView)
    }

    private func configureThemesCollectionService() {
        themesCollectionView.backgroundColor = .clear
        themesCollectionService.delegate = self
        themesCollectionView.delegate = themesCollectionService
        themesCollectionView.dataSource = themesCollectionService
        themesCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Content.themeCellReuseIdentifier)
        themesCollectionView.register(
            ThemeCardCollectionViewCell.self,
            forCellWithReuseIdentifier: ThemeCardCollectionViewCell.reuseIdentifier
        )
        themesCollectionView.register(
            StatisticsCardCollectionViewCell.self,
            forCellWithReuseIdentifier: StatisticsCardCollectionViewCell.reuseIdentifier
        )
    }

    private func configureHeaderViews() {
        let typography = currentAppearance().typography
        motivationContainerView = UIView()
        motivationContainerView.translatesAutoresizingMaskIntoConstraints = false

        motivationLabel = makeLabel(text: motivationPromptProvider(nil), font: typography.font(size: Typography.motivationFontSize, weight: .bold))
        motivationLabel.numberOfLines = 2
        motivationLabel.accessibilityIdentifier = AccessibilityID.motivationLabel
        motivationLabel.adjustsFontForContentSizeCategory = true

        motivationBlurredImageView = UIImageView()
        motivationBlurredImageView.accessibilityIdentifier = AccessibilityID.motivationBlurredImageView
        motivationBlurredImageView.alpha = Appearance.hiddenAlpha
        motivationBlurredImageView.contentMode = .topLeft
        motivationBlurredImageView.isUserInteractionEnabled = false
        motivationBlurredImageView.translatesAutoresizingMaskIntoConstraints = false

        motivationContainerView.addSubview(motivationBlurredImageView)
        motivationContainerView.addSubview(motivationLabel)

        NSLayoutConstraint.activate([
            motivationLabel.leadingAnchor.constraint(equalTo: motivationContainerView.leadingAnchor),
            motivationLabel.trailingAnchor.constraint(equalTo: motivationContainerView.trailingAnchor),
            motivationLabel.topAnchor.constraint(equalTo: motivationContainerView.topAnchor),
            motivationLabel.bottomAnchor.constraint(equalTo: motivationContainerView.bottomAnchor),

            motivationBlurredImageView.leadingAnchor.constraint(equalTo: motivationContainerView.leadingAnchor, constant: -Layout.motivationBlurPadding),
            motivationBlurredImageView.trailingAnchor.constraint(equalTo: motivationContainerView.trailingAnchor, constant: Layout.motivationBlurPadding),
            motivationBlurredImageView.topAnchor.constraint(equalTo: motivationContainerView.topAnchor, constant: -Layout.motivationBlurPadding),
            motivationBlurredImageView.bottomAnchor.constraint(equalTo: motivationContainerView.bottomAnchor, constant: Layout.motivationBlurPadding)
        ])
    }

    private func configureSettingsButton() {
        settingsButton = UIButton(type: .system)
        settingsButtonVisualSurface = UIView()
        settingsButtonVisualSurface.accessibilityIdentifier = AccessibilityID.settingsVisualSurface
        settingsButtonVisualSurface.isUserInteractionEnabled = false
        settingsButtonVisualSurface.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.accessibilityIdentifier = AccessibilityID.settingsButton
        settingsButton.accessibilityLabel = L10n.Settings.title
        let settingsIcon = UIImage(
            systemName: Content.settingsIconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Typography.settingsIconPointSize, weight: .semibold)
        )
        settingsButton.setImage(settingsIcon, for: .normal)
        settingsButton.tintColor = .white
        settingsButton.insertSubview(settingsButtonVisualSurface, at: 0)
        NSLayoutConstraint.activate([
            settingsButtonVisualSurface.centerXAnchor.constraint(equalTo: settingsButton.centerXAnchor),
            settingsButtonVisualSurface.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            settingsButtonVisualSurface.widthAnchor.constraint(equalToConstant: Layout.settingsButtonVisualSize),
            settingsButtonVisualSurface.heightAnchor.constraint(equalToConstant: Layout.settingsButtonVisualSize)
        ])
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
#if DEBUG
        settingsButton.showsMenuAsPrimaryAction = false
        settingsButton.changesSelectionAsPrimaryAction = false
#endif
        settingsButton.installPressFeedback()
    }

    private func configureHeaderStack() {
        headerStackView = UIStackView(arrangedSubviews: [motivationContainerView])
        headerStackView.accessibilityIdentifier = AccessibilityID.headerStackView
        headerStackView.axis = .vertical
        headerStackView.alignment = .leading
        headerStackView.spacing = Layout.headerStackSpacing
        headerStackView.isLayoutMarginsRelativeArrangement = true
        headerStackView.directionalLayoutMargins = Layout.headerMargins
        headerStackView.isUserInteractionEnabled = false
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureThemesCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = Layout.collectionItemSpacing
        layout.minimumInteritemSpacing = Layout.collectionItemSpacing
        layout.sectionInset = Layout.collectionSectionInsets

        themesCollectionView = HomeThemesCollectionView(frame: .zero, collectionViewLayout: layout)
        themesCollectionView.accessibilityIdentifier = AccessibilityID.themesCollectionView
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        themesCollectionView.alwaysBounceVertical = false
        themesCollectionView.bounces = false
        themesCollectionView.canCancelContentTouches = true
        themesCollectionView.contentInsetAdjustmentBehavior = .never
        themesCollectionView.delaysContentTouches = true
        themesCollectionView.showsVerticalScrollIndicator = false
        themesCollectionView.isScrollEnabled = false
        themesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        themesCollectionView.setContentHuggingPriority(.defaultLow, for: .vertical)
        themesCollectionView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private func configureScreenStack() {
        screenStackView = UIStackView(arrangedSubviews: [themesCollectionView])
        screenStackView.accessibilityIdentifier = AccessibilityID.screenStackView
        screenStackView.axis = .vertical
        screenStackView.alignment = .fill
        screenStackView.spacing = Layout.screenStackSpacing
        screenStackView.isLayoutMarginsRelativeArrangement = false
        screenStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func applyLayerOrdering() {
        headerStackView.layer.zPosition = Appearance.headerLayerZPosition
        motivationContainerView.layer.zPosition = Appearance.headerLayerZPosition
        screenStackView.layer.zPosition = Appearance.collectionLayerZPosition
        themesCollectionView.layer.zPosition = Appearance.collectionLayerZPosition
        settingsButton.layer.zPosition = Appearance.controlsLayerZPosition
    }

    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            screenStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            screenStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            screenStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            screenStackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            headerStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.screenTopInset),
            headerStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            settingsButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.settingsButtonTopInset),
            settingsButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.settingsButtonTrailingInset),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),

            motivationContainerView.widthAnchor.constraint(equalTo: headerStackView.layoutMarginsGuide.widthAnchor)
        ])
    }

    private func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = font
        label.textAlignment = .left
        label.numberOfLines = Typography.unlimitedNumberOfLines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    override func applyAppearance() {
        guard isViewLoaded else { return }
        let appearance = currentAppearance()
        appearance.applyBackground(to: view)
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        motivationLabel?.textColor = appearance.screenTextColor
        motivationLabel?.font = appearance.typography.font(size: Typography.motivationFontSize, weight: .bold)
        motivationLabel?.textAlignment = .left
        headerStackView?.alignment = .leading
        headerStackView?.directionalLayoutMargins = Layout.headerMargins
        invalidateMotivationBlurredText()

        settingsButton?.backgroundColor = .clear
        settingsButton?.layer.borderWidth = 0
        settingsButton?.layer.shadowOpacity = 0
        settingsButton?.tintColor = appearance.screenTextColor
        settingsButtonVisualSurface?.applySurfaceStyle(appearance.iconButton)
        if appearance.designStyle == .classic || appearance.designStyle == .clean {
            settingsButtonVisualSurface?.layer.cornerRadius = Layout.settingsButtonVisualSize / 2
            settingsButtonVisualSurface?.layer.cornerCurve = .circular
        }
        settingsButton?.tintColor = appearance.screenTextColor

#if DEBUG
        updateSettingsDebugMenu(appearance: appearance)
#endif

        themesCollectionView?.backgroundColor = .clear
        themesCollectionView?.reloadData()
        refreshExpandedThemeCardAppearance()
    }

    private func configureInitialStartupVisibilityIfNeeded() {
        guard session.startup1st else { return }
        startupAnimatedViews.forEach { $0.alpha = AnimationTiming.initialVisibleAlpha }
    }

    private func updateCollectionScrollAvailability() {
        themesCollectionView.layoutIfNeeded()
        let contentHeight = themesCollectionView.collectionViewLayout.collectionViewContentSize.height
        let viewportHeight = max(
            themesCollectionView.bounds.height - themesCollectionView.adjustedContentInset.top - themesCollectionView.adjustedContentInset.bottom,
            .zero
        )
        let shouldScroll = contentHeight > viewportHeight + Layout.scrollActivationTolerance

        let isGridInteractive = homeCardState.phase == .grid && !isQuizLaunchPending
        themesCollectionView.isScrollEnabled = shouldScroll
        themesCollectionView.alwaysBounceVertical = shouldScroll
        themesCollectionView.bounces = shouldScroll
        if !isGridInteractive {
            themesCollectionView.isScrollEnabled = false
            themesCollectionView.alwaysBounceVertical = false
            themesCollectionView.bounces = false
        }
    }

    private func updateCollectionTopInset() {
        let oldTopInset = themesCollectionView.contentInset.top
        let topInset = headerStackView.bounds.height + Layout.screenTopInset + Layout.headerToCollectionSpacing
        refreshMotivationBlurredTextIfNeeded()
        guard abs(oldTopInset - topInset) > Layout.scrollActivationTolerance else { return }

        let contentOffsetFromTopInset = themesCollectionView.contentOffset.y + oldTopInset
        themesCollectionView.contentInset.top = topInset
        themesCollectionView.verticalScrollIndicatorInsets.top = topInset

        if !themesCollectionView.isDragging && !themesCollectionView.isDecelerating {
            themesCollectionView.contentOffset.y = contentOffsetFromTopInset - topInset
        }
    }

    private func updateMotivationHeaderVisibility(for scrollView: UIScrollView) {
        let scrolledDistance = max(scrollView.contentOffset.y + scrollView.adjustedContentInset.top, .zero)
        let progress = min(scrolledDistance / Layout.motivationFadeDistance, 1)
        let alpha = 1 - progress
        let blurInProgress = min(scrolledDistance / Layout.motivationBlurRampDistance, 1)
        let blurOutDistance = Layout.motivationFadeDistance - Layout.motivationBlurHoldDistance
        let blurOutProgress = max(min((scrolledDistance - Layout.motivationBlurHoldDistance) / blurOutDistance, 1), 0)

        motivationLabel.alpha = alpha
        motivationBlurredImageView.alpha = Appearance.motivationBlurMaxAlpha * blurInProgress * (1 - blurOutProgress)
    }

    private func invalidateMotivationBlurredText() {
        motivationBlurSnapshotSignature = nil
        motivationBlurredImageView?.image = nil
    }

    private func refreshMotivationBlurredTextIfNeeded() {
        guard motivationLabel.bounds.width > .zero, motivationLabel.bounds.height > .zero else { return }

        let signature = [
            motivationLabel.text ?? "",
            motivationLabel.font.fontName,
            "\(motivationLabel.font.pointSize)",
            String(describing: motivationLabel.textColor),
            "\(motivationLabel.bounds.size.width)",
            "\(motivationLabel.bounds.size.height)",
            "\(Layout.motivationBlurPadding)"
        ].joined(separator: "|")

        guard motivationBlurSnapshotSignature != signature else { return }
        motivationBlurSnapshotSignature = signature
        motivationBlurredImageView.image = makeBlurredMotivationTextImage()
    }

    private func makeBlurredMotivationTextImage() -> UIImage? {
        let padding = Layout.motivationBlurPadding
        let bounds = CGRect(
            origin: .zero,
            size: CGSize(
                width: motivationLabel.bounds.width + padding * 2,
                height: motivationLabel.bounds.height + padding * 2
            )
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        format.opaque = false

        let sourceImage = UIGraphicsImageRenderer(bounds: bounds, format: format).image { context in
            context.cgContext.translateBy(x: padding, y: padding)
            motivationLabel.layer.render(in: context.cgContext)
        }

        guard
            let inputImage = CIImage(image: sourceImage),
            let clampFilter = CIFilter(name: "CIAffineClamp"),
            let blurFilter = CIFilter(name: "CIGaussianBlur")
        else {
            return sourceImage
        }

        clampFilter.setValue(inputImage, forKey: kCIInputImageKey)
        clampFilter.setValue(CGAffineTransform.identity, forKey: kCIInputTransformKey)
        blurFilter.setValue(clampFilter.outputImage, forKey: kCIInputImageKey)
        blurFilter.setValue(Layout.motivationBlurRadius, forKey: kCIInputRadiusKey)

        guard
            let outputImage = blurFilter.outputImage?.cropped(to: inputImage.extent),
            let cgImage = motivationBlurContext.createCGImage(outputImage, from: inputImage.extent)
        else {
            return sourceImage
        }

        return UIImage(cgImage: cgImage, scale: sourceImage.scale, orientation: sourceImage.imageOrientation)
    }

    private func animateStartupViews() {
        let visibleCells = sortedVisibleThemeCells()
        prepareStartupAnimation(visibleCells: visibleCells)

        guard !UIAccessibility.isReduceMotionEnabled else {
            startupAnimatedViews.forEach { $0.alpha = Appearance.visibleAlpha }
            visibleCells.forEach { $0.alpha = Appearance.visibleAlpha }
            return
        }

        UIView.animate(
            withDuration: AnimationTiming.revealDuration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.startupAnimatedViews.forEach { $0.alpha = Appearance.visibleAlpha }
        }
        animateThemeCells(visibleCells)
    }

    private func sortedVisibleThemeCells() -> [UICollectionViewCell] {
        themesCollectionView.visibleCells.sorted { lhs, rhs in
            let verticalDistance = abs(lhs.frame.minY - rhs.frame.minY)
            if verticalDistance > Layout.visibleCellRowSortingTolerance {
                return lhs.frame.minY < rhs.frame.minY
            }
            return lhs.frame.minX < rhs.frame.minX
        }
    }

    private func prepareStartupAnimation(visibleCells: [UICollectionViewCell]) {
        visibleCells.forEach { cell in
            cell.alpha = AnimationTiming.initialVisibleAlpha
        }
    }

    private func animateThemeCells(_ visibleCells: [UICollectionViewCell]) {
        for (index, cell) in visibleCells.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * AnimationTiming.cellFadeInStagger) {
                UIView.animate(
                    withDuration: AnimationTiming.revealDuration,
                    delay: 0,
                    options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
                ) {
                    cell.alpha = Appearance.visibleAlpha
                }
            }
        }
    }

    func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }

    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String) {
        animationsEngine.animateUpFloat(sender)
        guard
            homeCardState.phase == .grid,
            !isQuizLaunchPending,
            session.loadTheme(themeID: themeID),
            let theme = themeRepository.themes?.first(where: { $0.stableID == themeID }),
            let chosenTheme = session.chosenTheme
        else {
            updateThemeAvailabilityMessage()
            return
        }

        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha

        let effect = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .present(
                themeID: themeID,
                availableQuestionCounts: QuizQuestionCountPolicy.availableCounts(
                    for: chosenTheme.questionsAndAnswers
                ),
                preferredQuestionCount: session.questionsCount
            )
        )
        guard let effect else { return }

        analytics.track(.themeSelected(theme: session.chosenTheme?.analyticsTheme ?? .unknown, method: .manual))
        handleHomeCardEffect(effect, theme: theme, sourceView: sender)
    }

    func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }

    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        startRandomTheme(sourceView: sender)
    }

    func quizFlowWillReturnToThemes() {
        restoreHomeAfterQuizIfNeeded(force: true)
    }

    func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        guard homeCardState.phase == .grid, !isQuizLaunchPending else { return }
        let effect = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .presentAI
        )
        guard let effect else { return }
        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha
        handleHomeCardEffect(effect, sourceView: sender)
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        guard homeCardState.phase == .grid, !isQuizLaunchPending else { return }
        let effect = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .presentStatistics
        )
        guard let effect else { return }
        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha
        handleHomeCardEffect(effect, sourceView: sender)
    }

    func themesCollectionDidScroll(_ scrollView: UIScrollView) {
        updateMotivationHeaderVisibility(for: scrollView)
    }

    private func updateThemeAvailabilityMessage() {
        let hasThemes = themeRepository.themes?.isEmpty == false
        if !hasThemes {
            motivationLabel.text = L10n.Home.unavailableThemes
            invalidateMotivationBlurredText()
        }
    }

    private func refreshMotivationPrompt() {
        guard themeRepository.themes?.isEmpty == false else { return }
        motivationLabel.text = motivationPromptProvider(motivationLabel.text)
        invalidateMotivationBlurredText()
    }

    private static func randomMotivationPrompt(excluding currentPrompt: String? = nil) -> String {
        let prompts = L10n.Home.motivationPrompts
        let availablePrompts = prompts.filter { $0 != currentPrompt }
        let prompt = (availablePrompts.isEmpty ? prompts : availablePrompts).randomElement() ?? ""
        return prompt.replacingOccurrences(of: "\\n", with: "\n")
    }

    private func startRandomTheme(sourceView: UIView) {
        guard
            homeCardState.phase == .grid,
            !isQuizLaunchPending,
            let router
        else { return }
        guard let themes = themeRepository.themes else {
            updateThemeAvailabilityMessage()
            return
        }

        let eligibleThemes = themes.filter { theme in
            QuizQuestionCountPolicy.availableCounts(
                for: ThemeModel(quizTheme: theme).questionsAndAnswers
            ).contains(QuizQuestionCountPolicy.supportedCounts[0])
        }
        guard
            let themeID = randomThemeIDProvider(eligibleThemes),
            eligibleThemes.contains(where: { $0.stableID == themeID }),
            session.loadTheme(themeID: themeID)
        else {
            motivationLabel.text = L10n.Question.unavailableMessage
            invalidateMotivationBlurredText()
            return
        }

        session.questionsCount = QuizQuestionCountPolicy.supportedCounts[0]
        analytics.track(.themeSelected(theme: session.chosenTheme?.analyticsTheme ?? .unknown, method: .random))
        quizTransitionSourceView = sourceView
        isQuizLaunchPending = true
        hasQuizLaunchStarted = false
        themesCollectionService.isFeelingLuckyLoading = true
        themesCollectionView.isUserInteractionEnabled = false
        settingsButton.isEnabled = false
        updateCollectionScrollAvailability()

        let requestID = UUID()
        feelingLuckyRequestID = requestID
        feelingLuckyTask?.cancel()
        let minimumFeedbackDelay = feelingLuckyMinimumFeedbackDelay
        feelingLuckyTask = Task { @MainActor [weak self, router] in
            await minimumFeedbackDelay()
            guard !Task.isCancelled, let self else { return }
            guard
                self.feelingLuckyRequestID == requestID,
                self.isQuizLaunchPending,
                self.session.chosenTheme?.themeID == themeID
            else {
                self.cancelFeelingLuckyLaunch()
                return
            }

            self.feelingLuckyTask = nil
            self.session.questionsCount = QuizQuestionCountPolicy.supportedCounts[0]
            self.analytics.track(
                .quizStarted(
                    theme: self.session.chosenTheme?.analyticsTheme ?? .unknown,
                    questionCount: self.session.questionsCount
                )
            )
            self.hasQuizLaunchStarted = true
            router.showQuestion()
        }
    }

    private func cancelFeelingLuckyLaunch() {
        let wasWaitingToLaunch = isQuizLaunchPending
            && !hasQuizLaunchStarted
            && feelingLuckyRequestID != nil
        feelingLuckyTask?.cancel()
        feelingLuckyTask = nil
        feelingLuckyRequestID = nil
        themesCollectionService.isFeelingLuckyLoading = false
        settingsButton?.isEnabled = true
        if wasWaitingToLaunch, isViewLoaded {
            isQuizLaunchPending = false
            quizTransitionSourceView = nil
            themesCollectionView.isUserInteractionEnabled = true
            updateCollectionScrollAvailability()
        }
    }

    private func handleHomeCardEffect(
        _ effect: HomeThemeCardEffect,
        theme: QuizTheme? = nil,
        sourceView: UIView? = nil
    ) {
        switch effect {
        case let .expand(themeID):
            guard
                let theme,
                theme.stableID == themeID,
                let sourceView
            else { return }
            expandThemeCard(theme: theme, from: sourceView)

        case .expandStatistics:
            guard let sourceView else { return }
            expandStatisticsCard(
                summary: statisticsStore.loadSummary(),
                from: sourceView
            )

        case .expandAI:
            guard let sourceView else { return }
            expandAIThemeCard(from: sourceView)

        case let .flip(face):
            if homeCardState.isAIThemePresented {
                flipExpandedAIThemeCard(to: face)
            } else {
                flipExpandedThemeCard(to: face)
            }

        case .collapse:
            collapseExpandedThemeCard()

        case .collapseStatistics:
            collapseExpandedStatisticsCard()

        case .collapseAI:
            collapseExpandedAIThemeCard()

        case .reverseExpansion:
            reverseExpandedCardTransition()

        case let .launch(themeID, questionCount):
            updateExpandedThemeCardParallaxPhase()
            launchQuiz(themeID: themeID, questionCount: questionCount)
        }
    }

    private func sendHomeCardAction(_ action: HomeThemeCardAction) {
        guard let effect = HomeThemeCardReducer.reduce(state: &homeCardState, action: action) else {
            return
        }
        handleHomeCardEffect(effect, theme: expandedTheme)
    }

    private func expandThemeCard(theme: QuizTheme, from sourceView: UIView) {
        guard expandedThemeCardView == nil, expandedCardBackdropView == nil else { return }

        expandedCardScreenViewTracked = false
        view.layoutIfNeeded()
        let sourceFrame = sourceView.convert(sourceView.bounds, to: view)
        let targetFrame = expandedThemeCardFrame()
        let appearance = currentAppearance()
        let reduceMotion = cardReduceMotionProvider()
        let snapshotView = sourceView.snapshotView(afterScreenUpdates: false) ?? makeSnapshotFallback(from: sourceView)
        snapshotView.frame = sourceFrame
        snapshotView.layer.cornerRadius = sourceView.layer.cornerRadius
        snapshotView.layer.cornerCurve = sourceView.layer.cornerCurve
        snapshotView.layer.masksToBounds = true
        snapshotView.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
        snapshotView.accessibilityIdentifier = "homeExpandedThemeCardReducedMotionSourceSnapshot"

        let sourceContent = makeThemeCardSourceContent(from: sourceView)
        let sourceContentView = sourceContent.view
        sourceContentView.accessibilityIdentifier = AccessibilityID.expandedCardSourceSnapshot

        expandedTheme = theme
        expandedCardLastTrackedFace = .front
        themesCollectionService.presentedThemeID = theme.stableID
        themesCollectionView.isUserInteractionEnabled = false
        updateCollectionScrollAvailability()
        setBackgroundAccessibilityHidden(true)

        let backdropView = makeExpandedCardBackdrop(appearance: appearance)
        backdropView.frame = view.bounds
        backdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropView.layer.zPosition = Appearance.expandedCardBackdropLayerZPosition
        view.addSubview(backdropView)
        expandedCardBackdropView = backdropView
        installExpandedCardBackdropDismissButton()

        let cardView = ExpandedThemeCardView(frame: targetFrame)
        cardView.reduceMotionProvider = cardReduceMotionProvider
        cardView.deviceParallaxEnabledProvider = cardDeviceParallaxEnabledProvider
        cardView.deviceMotionProvider = cardMotionProvider
        cardView.accessibilityIdentifier = AccessibilityID.expandedCard
        cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
        cardView.configure(
            theme: theme,
            appearance: appearance,
            availableQuestionCounts: homeCardState.availableQuestionCounts,
            selectedQuestionCount: homeCardState.selectedQuestionCount
        )
        cardView.setParallaxPresentationPhase(homeCardState.phase.parallaxPresentationPhase)
        wireExpandedThemeCardActions(cardView)
        cardView.layoutIfNeeded()
        expandedThemeCardView = cardView

        if reduceMotion {
            cardView.alpha = 0
            view.addSubview(cardView)
            view.addSubview(snapshotView)
            installExpandedCardInteractionButton(tracking: [cardView, snapshotView])
        } else {
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeExpandedCardTransitionView(
                frame: sourceFrame,
                targetFrame: targetFrame,
                theme: theme,
                appearance: appearance,
                initialCornerRadius: sourceView.layer.cornerRadius,
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 0),
                initialShadow: appearance.themeCardShadow
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            transitionView.install(
                destinationView: cardView,
                sourceContentView: sourceContentView,
                visualState: HomeThemeCardTransitionVisualState(progress: 0),
                destinationProgressHandler: { [weak cardView] progress in
                    cardView?.setTransitionContentProgress(
                        progress,
                        sourceGeometry: sourceContent.geometry
                    )
                }
            )
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        expandedCardSnapshotView = snapshotView
        expandedCardSourceContentView = sourceContentView
        expandedCardSourceContentGeometry = sourceContent.geometry

        if reduceMotion, expandedCardBlurView == nil {
            backdropView.alpha = 0
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView, weak backdropView] in
            guard let self else { return }
            if let blurView = self.expandedCardBlurView {
                blurView.effect = UIBlurEffect(style: .systemMaterial)
            } else {
                backdropView?.alpha = 1
            }

            if reduceMotion {
                snapshotView?.alpha = 0
                cardView?.alpha = 1
            } else {
                self.expandedCardTransitionView?.move(
                    to: targetFrame,
                    cornerRadius: appearance.themeCardCornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1),
                    shadow: appearance.card.shadow
                )
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .end,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func expandStatisticsCard(
        summary: StatisticsSummary,
        from sourceView: UIView
    ) {
        guard
            expandedThemeCardView == nil,
            expandedStatisticsCardView == nil,
            expandedCardBackdropView == nil
        else { return }

        expandedCardScreenViewTracked = false
        view.layoutIfNeeded()
        let sourceFrame = sourceView.convert(sourceView.bounds, to: view)
        let targetFrame = expandedThemeCardFrame()
        let appearance = currentAppearance()
        let reduceMotion = cardReduceMotionProvider()
        let snapshotView = sourceView.snapshotView(afterScreenUpdates: false)
            ?? makeSnapshotFallback(from: sourceView)
        snapshotView.frame = sourceFrame
        snapshotView.layer.cornerRadius = sourceView.layer.cornerRadius
        snapshotView.layer.cornerCurve = sourceView.layer.cornerCurve
        snapshotView.layer.masksToBounds = true
        snapshotView.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
        snapshotView.accessibilityIdentifier = "homeExpandedStatisticsCardReducedMotionSourceSnapshot"

        let sourceContentView = makeStatisticsCardSourceContent(from: sourceView)
        sourceContentView.accessibilityIdentifier = AccessibilityID.expandedStatisticsCardSourceSnapshot

        expandedStatisticsSummary = summary
        themesCollectionService.isStatisticsPresented = true
        themesCollectionView.isUserInteractionEnabled = false
        updateCollectionScrollAvailability()
        setBackgroundAccessibilityHidden(true)

        let backdropView = makeExpandedCardBackdrop(appearance: appearance)
        backdropView.frame = view.bounds
        backdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropView.layer.zPosition = Appearance.expandedCardBackdropLayerZPosition
        view.addSubview(backdropView)
        expandedCardBackdropView = backdropView
        installExpandedCardBackdropDismissButton()

        let cardView = ExpandedStatisticsCardView(frame: targetFrame)
        cardView.accessibilityIdentifier = AccessibilityID.expandedStatisticsCard
        cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
        cardView.configure(summary: summary, appearance: appearance)
        wireExpandedStatisticsCardActions(cardView)
        cardView.layoutIfNeeded()
        expandedStatisticsCardView = cardView

        if reduceMotion {
            cardView.alpha = 0
            view.addSubview(cardView)
            view.addSubview(snapshotView)
            installExpandedCardInteractionButton(tracking: [cardView, snapshotView])
        } else {
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeStatisticsCardTransitionView(
                frame: sourceFrame,
                targetFrame: targetFrame,
                surfaceColor: sourceView.backgroundColor ?? .clear,
                borderColor: transitionBorderColor(
                    for: sourceView,
                    fallback: appearance.row.borderColor
                ),
                borderWidth: sourceView.layer.borderWidth,
                initialCornerRadius: sourceView.layer.cornerRadius,
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 0),
                initialShadow: .none
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            transitionView.install(
                destinationView: cardView,
                sourceContentView: sourceContentView,
                visualState: HomeThemeCardTransitionVisualState(progress: 0)
            )
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        expandedCardSnapshotView = snapshotView
        expandedCardSourceContentView = sourceContentView
        expandedCardSourceContentGeometry = nil

        if reduceMotion, expandedCardBlurView == nil {
            backdropView.alpha = 0
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView, weak backdropView] in
            guard let self else { return }
            if let blurView = self.expandedCardBlurView {
                blurView.effect = UIBlurEffect(style: .systemMaterial)
            } else {
                backdropView?.alpha = 1
            }

            if reduceMotion {
                snapshotView?.alpha = 0
                cardView?.alpha = 1
            } else {
                self.expandedCardTransitionView?.move(
                    to: targetFrame,
                    cornerRadius: appearance.card.cornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1),
                    shadow: appearance.card.shadow,
                    surfaceColor: appearance.card.backgroundColor,
                    borderColor: appearance.card.borderColor,
                    borderWidth: appearance.card.borderWidth
                )
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .end,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func expandAIThemeCard(from sourceView: UIView) {
        guard
            expandedThemeCardView == nil,
            expandedStatisticsCardView == nil,
            expandedAIThemeCardView == nil,
            expandedCardBackdropView == nil
        else { return }

        homeAIThemeCardState = HomeAIThemeCardState()
        expandedCardScreenViewTracked = false
        expandedCardLastTrackedFace = .front
        view.layoutIfNeeded()
        let sourceFrame = sourceView.convert(sourceView.bounds, to: view)
        let targetFrame = expandedThemeCardFrame()
        let appearance = currentAppearance()
        let reduceMotion = cardReduceMotionProvider()
        let snapshotView = sourceView.snapshotView(afterScreenUpdates: false)
            ?? makeSnapshotFallback(from: sourceView)
        snapshotView.frame = sourceFrame
        snapshotView.layer.cornerRadius = sourceView.layer.cornerRadius
        snapshotView.layer.cornerCurve = sourceView.layer.cornerCurve
        snapshotView.layer.masksToBounds = true
        snapshotView.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
        snapshotView.accessibilityIdentifier = "homeExpandedAIThemeCardReducedMotionSourceSnapshot"

        let sourceContentView = makeAIThemeCardSourceContent(from: sourceView)
        sourceContentView.accessibilityIdentifier = AccessibilityID.expandedAIThemeCardSourceSnapshot

        themesCollectionService.isAIThemePresented = true
        themesCollectionView.isUserInteractionEnabled = false
        updateCollectionScrollAvailability()
        setBackgroundAccessibilityHidden(true)

        let backdropView = makeExpandedCardBackdrop(appearance: appearance)
        backdropView.frame = view.bounds
        backdropView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        backdropView.layer.zPosition = Appearance.expandedCardBackdropLayerZPosition
        view.addSubview(backdropView)
        expandedCardBackdropView = backdropView
        installExpandedCardBackdropDismissButton()

        let cardView = ExpandedAIThemeCardView(frame: targetFrame)
        cardView.reduceMotionProvider = cardReduceMotionProvider
        cardView.accessibilityIdentifier = AccessibilityID.expandedAIThemeCard
        cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
        cardView.configure(state: homeAIThemeCardState, appearance: appearance)
        wireExpandedAIThemeCardActions(cardView)
        cardView.layoutIfNeeded()
        expandedAIThemeCardView = cardView

        if reduceMotion {
            cardView.alpha = 0
            view.addSubview(cardView)
            view.addSubview(snapshotView)
            installExpandedCardInteractionButton(tracking: [cardView, snapshotView])
        } else {
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeAIThemeCardTransitionView(
                frame: sourceFrame,
                targetFrame: targetFrame,
                surfaceColor: sourceView.backgroundColor ?? appearance.card.backgroundColor,
                borderColor: transitionBorderColor(
                    for: sourceView,
                    fallback: appearance.card.borderColor
                ),
                borderWidth: sourceView.layer.borderWidth,
                initialCornerRadius: sourceView.layer.cornerRadius,
                collapsedCornerRadius: sourceView.layer.cornerRadius,
                expandedCornerRadius: appearance.card.cornerRadius,
                gradientReferenceWidth: max(sourceFrame.width, targetFrame.width),
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 0),
                initialShadow: .none
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            transitionView.install(
                destinationView: cardView,
                sourceContentView: sourceContentView,
                visualState: HomeThemeCardTransitionVisualState(progress: 0)
            )
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        expandedCardSnapshotView = snapshotView
        expandedCardSourceContentView = sourceContentView
        expandedCardSourceContentGeometry = nil

        if reduceMotion, expandedCardBlurView == nil {
            backdropView.alpha = 0
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView, weak backdropView] in
            guard let self else { return }
            if let blurView = self.expandedCardBlurView {
                blurView.effect = UIBlurEffect(style: .systemMaterial)
            } else {
                backdropView?.alpha = 1
            }

            if reduceMotion {
                snapshotView?.alpha = 0
                cardView?.alpha = 1
            } else {
                self.expandedCardTransitionView?.move(
                    to: targetFrame,
                    cornerRadius: appearance.card.cornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1),
                    shadow: appearance.card.shadow,
                    surfaceColor: appearance.card.backgroundColor,
                    borderColor: appearance.card.borderColor,
                    borderWidth: appearance.card.borderWidth
                )
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .end,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func wireExpandedThemeCardActions(_ cardView: ExpandedThemeCardView) {
        cardView.onClose = { [weak self] in
            self?.sendHomeCardAction(.closeRequested)
        }
        cardView.onFlip = { [weak self] in
            self?.handleExpandedThemeCardFlipTap()
        }
        cardView.onBack = { [weak self] in
            self?.handleExpandedThemeCardFlipTap()
        }
        cardView.onQuestionCountChanged = { [weak self] count in
            self?.sendHomeCardAction(.questionCountSelected(count))
        }
        cardView.onStart = { [weak self] in
            self?.sendHomeCardAction(.startRequested)
        }
        cardView.onAccessibilityEscape = { [weak self] in
            self?.handleExpandedCardAccessibilityEscape()
        }
    }

    private func wireExpandedStatisticsCardActions(_ cardView: ExpandedStatisticsCardView) {
        cardView.onClose = { [weak self] in
            self?.sendHomeCardAction(.closeRequested)
        }
        cardView.onAccessibilityEscape = { [weak self] in
            self?.sendHomeCardAction(.closeRequested)
        }
    }

    private func wireExpandedAIThemeCardActions(_ cardView: ExpandedAIThemeCardView) {
        cardView.onClose = { [weak self] in
            self?.requestExpandedCardClose()
        }
        cardView.onFlip = { [weak self] in
            self?.handleExpandedThemeCardFlipTap()
        }
        cardView.onBack = { [weak self] in
            guard let self else { return }
            if self.homeAIThemeCardState.isSubmitting {
                self.sendAIThemeCardAction(.cancelRequested)
            }
            self.focusAIThemePromptAfterFlip = true
            self.handleExpandedThemeCardFlipTap()
        }
        cardView.onPromptChanged = { [weak self] prompt in
            self?.sendAIThemeCardAction(.promptChanged(prompt))
        }
        cardView.onQuestionCountChanged = { [weak self] count in
            self?.sendAIThemeCardAction(.questionCountSelected(count))
        }
        cardView.onDifficultyChanged = { [weak self] difficulty in
            self?.sendAIThemeCardAction(.difficultySelected(difficulty))
        }
        cardView.onSubmit = { [weak self] in
            guard let self else { return }
            self.sendAIThemeCardAction(
                .submitRequested(
                    requestID: self.aiRequestIDProvider(),
                    locale: AppLocalizationStore.shared.resolvedLocale,
                    now: self.aiNow()
                )
            )
        }
        cardView.onAccessibilityEscape = { [weak self] in
            self?.handleExpandedCardAccessibilityEscape()
        }
        cardView.onKeyboardFrameChange = { [weak self, weak cardView] frame, duration, options in
            guard let self, let cardView else { return }
            self.updateExpandedAIThemeCardFrame(
                cardView,
                keyboardFrameInWindow: frame,
                duration: duration,
                options: options
            )
        }
    }

    private func sendAIThemeCardAction(_ action: HomeAIThemeCardAction) {
        let effect = HomeAIThemeCardReducer.reduce(
            state: &homeAIThemeCardState,
            action: action
        )
        refreshExpandedAIThemeCard()
        guard let effect else { return }
        handleAIThemeCardEffect(effect)
    }

    private func handleAIThemeCardEffect(_ effect: HomeAIThemeCardEffect) {
        switch effect {
        case let .flipAvailabilityChanged(isAllowed):
            _ = HomeThemeCardReducer.reduce(
                state: &homeCardState,
                action: .flipAvailabilityChanged(isAllowed)
            )

        case let .submit(submission):
            startAIThemeSubmission(submission)

        case let .cancelSubmission(submission):
            cancelAIThemeSubmission(submission)

        case .submissionCompleted:
            break

        case let .presentAlert(alert):
            presentAIThemeGenerationAlert(alert)

        case .focusPrompt:
            focusAIThemePrompt()
        }
    }

    private func refreshExpandedAIThemeCard() {
        guard let cardView = expandedAIThemeCardView else { return }
        let face = cardView.face
        cardView.configure(state: homeAIThemeCardState, appearance: currentAppearance())
        cardView.setFace(face, animated: false)
    }

    private func startAIThemeSubmission(_ submission: HomeAIThemeCardSubmission) {
        guard homeAIThemeCardState.activeSubmission?.id == submission.id else { return }

        aiSubmissionTask?.cancel()
        aiProgressTask?.cancel()
        analytics.track(
            .aiGenerationStarted(
                locale: submission.configuration.locale.identifier,
                promptLength: submission.configuration.theme.count,
                questionCount: submission.configuration.questionCount,
                difficulty: submission.configuration.difficulty
            )
        )
        AppLog.quiz.info(
            "AI quiz submission started: locale=\(submission.configuration.locale.identifier, privacy: .public) prompt_length=\(submission.configuration.theme.count, privacy: .public) questions=\(submission.configuration.questionCount, privacy: .public) difficulty=\(submission.configuration.difficulty.rawValue, privacy: .public)"
        )

        startAIThemeProgressUpdates(for: submission.id)
        let service = aiQuizThemeService
        aiSubmissionTask = Task { @MainActor [weak self] in
            do {
                let theme = try await service.generateQuizTheme(
                    configuration: submission.configuration
                )
                try Task.checkCancellation()
                self?.completeAIThemeSubmission(
                    theme: theme,
                    submission: submission
                )
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self?.failAIThemeSubmission(error: error, submission: submission)
            }
        }
    }

    private func startAIThemeProgressUpdates(for requestID: UUID) {
        aiProgressTask?.cancel()
        aiProgressTask = Task { @MainActor [weak self] in
            let updates: [(UInt64, HomeAIGenerationPhase)] = [
                (1_000_000_000, .sending),
                (1_500_000_000, .generating),
                (3_500_000_000, .almostReady)
            ]
            do {
                for (delay, phase) in updates {
                    try await Task.sleep(nanoseconds: delay)
                    try Task.checkCancellation()
                    guard
                        let self,
                        self.homeAIThemeCardState.activeSubmission?.id == requestID
                    else {
                        return
                    }
                    _ = HomeAIThemeCardReducer.reduce(
                        state: &self.homeAIThemeCardState,
                        action: .progressAdvanced(requestID: requestID, phase: phase)
                    )
                    self.refreshExpandedAIThemeCard()
                }
            } catch {
                return
            }
        }
    }

    private func completeAIThemeSubmission(
        theme: QuizTheme,
        submission: HomeAIThemeCardSubmission
    ) {
        guard
            homeAIThemeCardState.activeSubmission?.id == submission.id,
            let router
        else { return }
        guard case .submissionCompleted = HomeAIThemeCardReducer.reduce(
            state: &homeAIThemeCardState,
            action: .submissionSucceeded(requestID: submission.id)
        ) else { return }

        aiSubmissionTask = nil
        aiProgressTask?.cancel()
        aiProgressTask = nil
        refreshExpandedAIThemeCard()
        analytics.track(
            .aiGenerationSucceeded(
                locale: submission.configuration.locale.identifier,
                questionCount: theme.questions.count,
                difficulty: submission.configuration.difficulty,
                durationMilliseconds: aiSubmissionDurationMilliseconds(submission)
            )
        )
        AppLog.quiz.info(
            "AI quiz result accepted: questions=\(theme.questions.count, privacy: .public)"
        )

        session.chosenTheme = ThemeModel(quizTheme: theme)
        session.questionsCount = theme.questions.count
        analytics.track(.themeSelected(theme: .ai, method: .ai))

        UIView.performWithoutAnimation {
            removeExpandedThemeCardViews()
            _ = HomeThemeCardReducer.reduce(state: &homeCardState, action: .reset)
            restoreGridAfterExpandedCard(presentedCard: nil)
            view.layoutIfNeeded()
        }
        router.showDescription()
    }

    private func failAIThemeSubmission(
        error: Error,
        submission: HomeAIThemeCardSubmission
    ) {
        guard homeAIThemeCardState.activeSubmission?.id == submission.id else { return }
        let alert = AIQuizGenerationAlert(error: error)
        guard let effect = HomeAIThemeCardReducer.reduce(
            state: &homeAIThemeCardState,
            action: .submissionFailed(requestID: submission.id, alert: alert)
        ) else { return }

        aiSubmissionTask = nil
        aiProgressTask?.cancel()
        aiProgressTask = nil
        let errorCode = (error as? YandexAIQuizThemeServiceError)?.analyticsCode ?? "unexpected"
        analytics.track(
            .aiGenerationFailed(
                locale: submission.configuration.locale.identifier,
                errorCode: errorCode,
                durationMilliseconds: aiSubmissionDurationMilliseconds(submission)
            )
        )
        analytics.reportOperationalError(error, context: .aiGeneration(code: errorCode))
        refreshExpandedAIThemeCard()
        handleAIThemeCardEffect(effect)
    }

    private func cancelAIThemeSubmission(_ submission: HomeAIThemeCardSubmission) {
        aiSubmissionTask?.cancel()
        aiSubmissionTask = nil
        aiProgressTask?.cancel()
        aiProgressTask = nil
        analytics.track(
            .aiGenerationCancelled(
                locale: submission.configuration.locale.identifier,
                durationMilliseconds: aiSubmissionDurationMilliseconds(submission)
            )
        )
        refreshExpandedAIThemeCard()
    }

    private func aiSubmissionDurationMilliseconds(
        _ submission: HomeAIThemeCardSubmission
    ) -> Int {
        max(Int(aiNow().timeIntervalSince(submission.startedAt) * 1_000), 0)
    }

    private func presentAIThemeGenerationAlert(_ alert: AIQuizGenerationAlert) {
        guard homeAIThemeCardState.activeAlert == alert else { return }

        aiAlertPresentationTask?.cancel()
        aiAlertPresentationTask = nil
        if tryPresentAIThemeGenerationAlert(alert) { return }

        aiAlertPresentationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self, self.homeAIThemeCardState.activeAlert == alert else { return }
                do {
                    try await Task.sleep(nanoseconds: 50_000_000)
                } catch {
                    return
                }

                if self.tryPresentAIThemeGenerationAlert(alert) {
                    self.aiAlertPresentationTask = nil
                    return
                }
            }
        }
    }

    private func tryPresentAIThemeGenerationAlert(_ alert: AIQuizGenerationAlert) -> Bool {
        aiAlertPresenter.presentingViewController = self
        return aiAlertPresenter.present(
            makeAIThemeGenerationAlertOverlay(alert),
            appearance: currentAppearance(),
            reduceMotion: cardReduceMotionProvider()
        )
    }

    private func makeAIThemeGenerationAlertOverlay(_ alert: AIQuizGenerationAlert) -> QuizAlertOverlay {
        let dismissAction = QuizAlertAction(
            title: alert.canRetry || alert.shouldFocusPromptOnDismiss
                ? L10n.AITheme.editTheme
                : L10n.Settings.alertAction,
            emphasis: alert.canRetry ? .secondary : .primary,
            accessibilityIdentifier: AccessibilityID.aiThemeAlertDismissButton,
            action: { [weak self] in self?.dismissAIThemeGenerationAlert(alert) }
        )

        let primaryAction: QuizAlertAction
        let secondaryAction: QuizAlertAction?
        if alert.canRetry {
            primaryAction = QuizAlertAction(
                title: L10n.AITheme.retry,
                emphasis: .primary,
                accessibilityIdentifier: AccessibilityID.aiThemeAlertRetryButton,
                action: { [weak self] in self?.retryAIThemeGeneration(after: alert) }
            )
            secondaryAction = dismissAction
        } else {
            primaryAction = dismissAction
            secondaryAction = nil
        }

        return QuizAlertOverlay(
            title: alert.title,
            message: alert.message,
            systemImage: alert.kind.systemImage,
            iconColor: alert.kind.iconColor(in: currentAppearance()),
            primaryAction: primaryAction,
            secondaryAction: secondaryAction,
            onEscape: dismissAction.action
        )
    }

    private func retryAIThemeGeneration(after alert: AIQuizGenerationAlert) {
        guard homeAIThemeCardState.activeAlert == alert else { return }
        dismissAIThemeAlertPresentation { [weak self] in
            guard let self else { return }
            self.clearAIThemeGenerationAlert()
            self.sendAIThemeCardAction(
                .submitRequested(
                    requestID: self.aiRequestIDProvider(),
                    locale: AppLocalizationStore.shared.resolvedLocale,
                    now: self.aiNow()
                )
            )
        }
    }

    private func dismissAIThemeGenerationAlert(_ alert: AIQuizGenerationAlert) {
        guard homeAIThemeCardState.activeAlert == alert else { return }
        dismissAIThemeAlertPresentation { [weak self] in
            guard let self else { return }
            if alert.shouldFocusPromptOnDismiss {
                self.editAIThemeAfterAlert()
            } else {
                self.clearAIThemeGenerationAlert()
            }
        }
    }

    private func dismissAIThemeAlertPresentation(completion: @escaping () -> Void) {
        aiAlertPresentationTask?.cancel()
        aiAlertPresentationTask = nil
        aiAlertPresenter.dismiss(completion: completion)
    }

    private func clearAIThemeGenerationAlert() {
        _ = HomeAIThemeCardReducer.reduce(
            state: &homeAIThemeCardState,
            action: .alertDismissed
        )
        refreshExpandedAIThemeCard()
    }

    private func editAIThemeAfterAlert() {
        clearAIThemeGenerationAlert()
        focusAIThemePromptAfterFlip = true
        if homeCardState.phase == .expandedBack {
            sendHomeCardAction(.flipRequested)
        } else {
            focusAIThemePrompt()
        }
    }

    private func handleExpandedThemeCardFlipTap() {
        // A backdrop dismissal is a committed intent. Once an in-flight flip is
        // returning to the front for dismissal, further card taps must not cancel it.
        guard !closeAfterFlipToFront else { return }
        sendHomeCardAction(.flipRequested)
    }

    private func flipExpandedThemeCard(to face: HomeThemeCardFace) {
        updateExpandedThemeCardParallaxPhase()
        expandedThemeCardView?.setFace(face, animated: true) { [weak self] completedFace in
            guard let self else { return }
            let previousPhase = self.homeCardState.phase
            _ = HomeThemeCardReducer.reduce(
                state: &self.homeCardState,
                action: .flipCompleted(completedFace)
            )
            self.updateExpandedThemeCardParallaxPhase()
            let completedStableFlip: Bool
            switch (previousPhase, completedFace, self.homeCardState.phase) {
            case (.flippingToBack, .back, .expandedBack),
                 (.flippingToFront, .front, .expandedFront):
                completedStableFlip = true
            default:
                completedStableFlip = false
            }
            if completedStableFlip, self.expandedCardLastTrackedFace != completedFace {
                self.expandedCardLastTrackedFace = completedFace
                self.analytics.track(
                    .themeCardFlipped(
                        theme: self.session.chosenTheme?.analyticsTheme ?? .unknown,
                        visibleFace: completedFace == .front ? .front : .back
                    )
                )
            }
            if completedStableFlip,
               completedFace == .back,
               !self.expandedCardScreenViewTracked {
                self.expandedCardScreenViewTracked = true
                self.analytics.track(
                    .screenView(
                        screen: .quizDescription,
                        theme: self.session.chosenTheme?.analyticsTheme ?? .unknown
                    )
                )
            }
            if self.expandedCardNeedsRefresh {
                self.refreshExpandedThemeCardAppearance()
            }
            if self.closeAfterFlipToFront, completedFace == .front {
                self.closeAfterFlipToFront = false
                self.sendHomeCardAction(.closeRequested)
            }
        }
    }

    private func flipExpandedAIThemeCard(to face: HomeThemeCardFace) {
        expandedAIThemeCardView?.setFace(face, animated: true) { [weak self] completedFace in
            guard let self else { return }
            let previousPhase = self.homeCardState.phase
            _ = HomeThemeCardReducer.reduce(
                state: &self.homeCardState,
                action: .flipCompleted(completedFace)
            )

            let completedStableFlip: Bool
            switch (previousPhase, completedFace, self.homeCardState.phase) {
            case (.flippingToBack, .back, .expandedBack),
                 (.flippingToFront, .front, .expandedFront):
                completedStableFlip = true
            default:
                completedStableFlip = false
            }

            if completedStableFlip, self.expandedCardLastTrackedFace != completedFace {
                self.expandedCardLastTrackedFace = completedFace
                self.analytics.track(
                    .themeCardFlipped(
                        theme: .ai,
                        visibleFace: completedFace == .front ? .front : .back
                    )
                )
            }

            if self.closeAfterFlipToFront, completedFace == .front {
                self.closeAfterFlipToFront = false
                self.requestExpandedCardClose()
                return
            }

            if completedStableFlip,
               completedFace == .front,
               self.focusAIThemePromptAfterFlip {
                self.focusAIThemePromptAfterFlip = false
                self.focusAIThemePrompt()
            } else if completedStableFlip {
                UIAccessibility.post(
                    notification: .layoutChanged,
                    argument: completedFace == .front
                        ? self.expandedAIThemeCardView?.frontFocusView
                        : self.expandedAIThemeCardView?.backFocusView
                )
            }
            if self.expandedCardNeedsRefresh {
                self.refreshExpandedThemeCardAppearance()
            }
        }
    }

    private func focusAIThemePrompt(
        accessibilityNotification: UIAccessibility.Notification = .layoutChanged
    ) {
        guard let cardView = expandedAIThemeCardView else { return }
        if cardView.face == .front {
            _ = cardView.focusPrompt()
            UIAccessibility.post(
                notification: accessibilityNotification,
                argument: cardView.frontFocusView
            )
            return
        }
        focusAIThemePromptAfterFlip = true
        sendHomeCardAction(.flipRequested)
    }

    private func requestExpandedCardClose() {
        if homeCardState.isAIThemePresented,
           homeAIThemeCardState.isSubmitting {
            sendAIThemeCardAction(.cancelRequested)
        }
        sendHomeCardAction(.closeRequested)
    }

    private func handleExpandedCardAccessibilityEscape() {
        switch homeCardState.phase {
        case .expandedBack:
            if homeCardState.isAIThemePresented,
               homeAIThemeCardState.isSubmitting {
                requestExpandedCardClose()
                return
            }
            closeAfterFlipToFront = true
            sendHomeCardAction(.flipRequested)
        case .expandedFront:
            requestExpandedCardClose()
        case .grid, .expanding, .flippingToBack, .flippingToFront, .collapsing, .launching:
            break
        }
    }

    private func collapseExpandedThemeCard() {
        guard let cardView = expandedThemeCardView else {
            resetExpandedThemeCard()
            return
        }

        updateExpandedThemeCardParallaxPhase()

        let reduceMotion = cardReduceMotionProvider()
        let currentSourceButton = homeCardState.themeID.flatMap { sourceButton(themeID: $0) }
        let sourceFrame = currentSourceButton.map { $0.convert($0.bounds, to: view) }
        let targetFrame = cardView.convert(cardView.bounds, to: view)
        let appearance = currentAppearance()
        let snapshotView = expandedCardSnapshotView

        if let currentSourceButton {
            let refreshedSourceContent = makeThemeCardSourceContent(from: currentSourceButton)
            refreshedSourceContent.view.accessibilityIdentifier = AccessibilityID.expandedCardSourceSnapshot
            expandedCardSourceContentView?.removeFromSuperview()
            expandedCardSourceContentView = refreshedSourceContent.view
            expandedCardSourceContentGeometry = refreshedSourceContent.geometry
        }

        let sourceContentView = expandedCardSourceContentView
        let sourceContentGeometry = expandedCardSourceContentGeometry

        if reduceMotion {
            cardView.alpha = 1
            snapshotView?.isHidden = false
            snapshotView?.alpha = 0
            snapshotView?.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
            if let snapshotView, let sourceFrame {
                snapshotView.frame = sourceFrame
                view.addSubview(snapshotView)
            }
            installExpandedCardInteractionButton(
                tracking: [cardView] + [snapshotView].compactMap { $0 }
            )
        } else {
            sourceContentView?.isHidden = false
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeExpandedCardTransitionView(
                frame: targetFrame,
                targetFrame: targetFrame,
                theme: expandedTheme,
                appearance: appearance,
                initialCornerRadius: appearance.themeCardCornerRadius,
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 1),
                initialShadow: appearance.card.shadow
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            if let sourceContentView, let sourceContentGeometry {
                transitionView.install(
                    destinationView: cardView,
                    sourceContentView: sourceContentView,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1),
                    destinationProgressHandler: { [weak cardView] progress in
                        cardView?.setTransitionContentProgress(
                            progress,
                            sourceGeometry: sourceContentGeometry
                        )
                    }
                )
            }
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView] in
            guard let self else { return }
            self.expandedCardBlurView?.effect = nil
            if self.expandedCardBlurView == nil {
                self.expandedCardBackdropView?.alpha = 0
            }

            if reduceMotion {
                cardView?.alpha = 0
                snapshotView?.alpha = sourceFrame == nil ? 0 : 1
            } else if let sourceFrame {
                self.expandedCardTransitionView?.move(
                    to: sourceFrame,
                    cornerRadius: appearance.themeCardCornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 0),
                    shadow: appearance.themeCardShadow
                )
            } else {
                self.expandedCardTransitionView?.alpha = 0
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .start,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func collapseExpandedStatisticsCard() {
        guard let cardView = expandedStatisticsCardView else {
            resetExpandedThemeCard()
            return
        }

        let reduceMotion = cardReduceMotionProvider()
        let currentSourceButton = sourceStatisticsButton()
        let sourceFrame = currentSourceButton.map { $0.convert($0.bounds, to: view) }
        let targetFrame = cardView.convert(cardView.bounds, to: view)
        let appearance = currentAppearance()
        let snapshotView = expandedCardSnapshotView

        if let currentSourceButton {
            let refreshedSourceContent = makeStatisticsCardSourceContent(from: currentSourceButton)
            refreshedSourceContent.accessibilityIdentifier = AccessibilityID.expandedStatisticsCardSourceSnapshot
            expandedCardSourceContentView?.removeFromSuperview()
            expandedCardSourceContentView = refreshedSourceContent
        }

        let sourceContentView = expandedCardSourceContentView

        if reduceMotion {
            cardView.alpha = 1
            snapshotView?.isHidden = false
            snapshotView?.alpha = 0
            snapshotView?.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
            if let snapshotView, let sourceFrame {
                snapshotView.frame = sourceFrame
                view.addSubview(snapshotView)
            }
            installExpandedCardInteractionButton(
                tracking: [cardView] + [snapshotView].compactMap { $0 }
            )
        } else {
            sourceContentView?.isHidden = false
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeStatisticsCardTransitionView(
                frame: targetFrame,
                targetFrame: targetFrame,
                surfaceColor: appearance.card.backgroundColor,
                borderColor: appearance.card.borderColor,
                borderWidth: appearance.card.borderWidth,
                initialCornerRadius: appearance.card.cornerRadius,
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 1),
                initialShadow: appearance.card.shadow
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            if let sourceContentView {
                transitionView.install(
                    destinationView: cardView,
                    sourceContentView: sourceContentView,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1)
                )
            }
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView] in
            guard let self else { return }
            self.expandedCardBlurView?.effect = nil
            if self.expandedCardBlurView == nil {
                self.expandedCardBackdropView?.alpha = 0
            }

            if reduceMotion {
                cardView?.alpha = 0
                snapshotView?.alpha = sourceFrame == nil ? 0 : 1
            } else if let sourceFrame {
                self.expandedCardTransitionView?.move(
                    to: sourceFrame,
                    cornerRadius: currentSourceButton?.layer.cornerRadius ?? appearance.row.cornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 0),
                    shadow: .none,
                    surfaceColor: currentSourceButton?.backgroundColor ?? appearance.row.backgroundColor,
                    borderColor: transitionBorderColor(
                        for: currentSourceButton,
                        fallback: appearance.row.borderColor
                    ),
                    borderWidth: currentSourceButton?.layer.borderWidth ?? appearance.row.borderWidth
                )
            } else {
                self.expandedCardTransitionView?.alpha = 0
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .start,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func collapseExpandedAIThemeCard() {
        guard let cardView = expandedAIThemeCardView else {
            resetExpandedThemeCard()
            return
        }

        freezeExpandedAIKeyboardAnimation(on: cardView)
        _ = cardView.resignPrompt()
        let reduceMotion = cardReduceMotionProvider()
        let currentSourceButton = sourceAIThemeButton()
        let sourceFrame = currentSourceButton.map { $0.convert($0.bounds, to: view) }
        let targetFrame = cardView.convert(cardView.bounds, to: view)
        let appearance = currentAppearance()
        let snapshotView = expandedCardSnapshotView

        if let currentSourceButton {
            let refreshedSourceContent = makeAIThemeCardSourceContent(from: currentSourceButton)
            refreshedSourceContent.accessibilityIdentifier = AccessibilityID.expandedAIThemeCardSourceSnapshot
            expandedCardSourceContentView?.removeFromSuperview()
            expandedCardSourceContentView = refreshedSourceContent
        }

        let sourceContentView = expandedCardSourceContentView
        if reduceMotion {
            cardView.alpha = 1
            snapshotView?.isHidden = false
            snapshotView?.alpha = 0
            snapshotView?.layer.zPosition = Appearance.expandedCardLayerZPosition + 1
            if let snapshotView, let sourceFrame {
                snapshotView.frame = sourceFrame
                view.addSubview(snapshotView)
            }
            installExpandedCardInteractionButton(
                tracking: [cardView] + [snapshotView].compactMap { $0 }
            )
        } else {
            sourceContentView?.isHidden = false
            cardView.setTransitionShadowHidden(true)
            cardView.setTransitionSurfaceHidden(true)
            let transitionView = makeAIThemeCardTransitionView(
                frame: targetFrame,
                targetFrame: targetFrame,
                surfaceColor: appearance.card.backgroundColor,
                borderColor: appearance.card.borderColor,
                borderWidth: appearance.card.borderWidth,
                initialCornerRadius: appearance.card.cornerRadius,
                collapsedCornerRadius: currentSourceButton?.layer.cornerRadius
                    ?? appearance.row.cornerRadius,
                expandedCornerRadius: appearance.card.cornerRadius,
                gradientReferenceWidth: max(sourceFrame?.width ?? 0, targetFrame.width),
                initialVisualState: HomeThemeCardTransitionVisualState(progress: 1),
                initialShadow: appearance.card.shadow
            )
            transitionView.layer.zPosition = Appearance.expandedCardLayerZPosition
            view.addSubview(transitionView)
            if let sourceContentView {
                transitionView.install(
                    destinationView: cardView,
                    sourceContentView: sourceContentView,
                    visualState: HomeThemeCardTransitionVisualState(progress: 1)
                )
            }
            expandedCardTransitionView = transitionView
            installExpandedCardInteractionButton(tracking: [transitionView])
        }

        let animator: UIViewPropertyAnimator
        if reduceMotion {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.reducedMotionDuration,
                curve: .easeInOut
            )
        } else {
            animator = UIViewPropertyAnimator(
                duration: AnimationTiming.cardExpansionDuration,
                dampingRatio: AnimationTiming.cardExpansionDampingRatio
            )
        }

        animator.addAnimations { [weak self, weak snapshotView, weak cardView] in
            guard let self else { return }
            self.expandedCardBlurView?.effect = nil
            if self.expandedCardBlurView == nil {
                self.expandedCardBackdropView?.alpha = 0
            }

            if reduceMotion {
                cardView?.alpha = 0
                snapshotView?.alpha = sourceFrame == nil ? 0 : 1
            } else if let sourceFrame {
                self.expandedCardTransitionView?.move(
                    to: sourceFrame,
                    cornerRadius: currentSourceButton?.layer.cornerRadius ?? appearance.row.cornerRadius,
                    visualState: HomeThemeCardTransitionVisualState(progress: 0),
                    shadow: .none,
                    surfaceColor: currentSourceButton?.backgroundColor ?? appearance.row.backgroundColor,
                    borderColor: self.transitionBorderColor(
                        for: currentSourceButton,
                        fallback: appearance.row.borderColor
                    ),
                    borderWidth: currentSourceButton?.layer.borderWidth ?? appearance.row.borderWidth
                )
            } else {
                self.expandedCardTransitionView?.alpha = 0
            }
        }
        animator.addCompletion { [weak self, weak animator] position in
            guard let self, let animator else { return }
            self.completeExpandedCardAnimation(
                animator: animator,
                position: position,
                expandedPosition: .start,
                targetFrame: targetFrame
            )
        }

        expandedCardAnimator = animator
        animator.startAnimation()
    }

    private func reverseExpandedCardTransition() {
        guard
            let animator = expandedCardAnimator,
            animator.state == .active
        else { return }

        animator.isReversed.toggle()
    }

    private func installExpandedCardInteractionButton(tracking views: [UIView]) {
        expandedCardInteractionButton?.removeFromSuperview()

        let button = ThemeCardTransitionInteractionButton(frame: .zero)
        button.frame = view.bounds
        button.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        button.backgroundColor = .clear
        button.accessibilityIdentifier = "homeExpandedThemeCardTransitionSurfaceButton"
        button.isAccessibilityElement = false
        button.trackedViews = views
        button.onTap = { [weak self] in
            // The card surface always means "show the other side". During the
            // source-to-card morph the reducer intentionally ignores the request;
            // background taps are handled independently by the backdrop.
            self?.handleExpandedThemeCardFlipTap()
        }
        button.layer.zPosition = Appearance.expandedCardLayerZPosition + 2
        view.addSubview(button)
        expandedCardInteractionButton = button
    }

    private func completeExpandedCardAnimation(
        animator: UIViewPropertyAnimator,
        position: UIViewAnimatingPosition,
        expandedPosition: UIViewAnimatingPosition,
        targetFrame: CGRect
    ) {
        guard expandedCardAnimator === animator else { return }

        let gridPosition: UIViewAnimatingPosition = expandedPosition == .end ? .start : .end
        if position == expandedPosition, homeCardState.phase == .expanding {
            expandedCardAnimator = nil
            completeExpandedCardPresentation(targetFrame: targetFrame)
        } else if position == gridPosition, homeCardState.phase == .collapsing {
            expandedCardAnimator = nil
            completeExpandedCardCollapse()
        }
    }

    private func completeExpandedCardPresentation(targetFrame: CGRect) {
        let presentedCard = homeCardState.presentedCard
        completeExpandedCardTransition(targetFrame: targetFrame)
        expandedCardInteractionButton?.removeFromSuperview()
        expandedCardInteractionButton = nil
        expandedCardSnapshotView?.alpha = 0
        expandedCardSnapshotView?.isHidden = true
        expandedCardSourceContentView?.alpha = 0
        expandedCardSourceContentView?.isHidden = true
        _ = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .expansionCompleted
        )
        updateExpandedThemeCardParallaxPhase()
        if expandedCardNeedsRefresh {
            refreshExpandedThemeCardAppearance()
        }
        if presentedCard == .statistics, !expandedCardScreenViewTracked {
            expandedCardScreenViewTracked = true
            let summary = expandedStatisticsSummary ?? statisticsStore.loadSummary()
            analytics.track(.screenView(screen: .statistics))
            analytics.track(
                .statisticsViewed(
                    attemptsCount: summary.playedQuizzes,
                    totalQuestions: summary.totalQuestions,
                    accuracyPercent: summary.percentage
                )
            )
        } else if presentedCard == .ai, !expandedCardScreenViewTracked {
            expandedCardScreenViewTracked = true
            analytics.track(.screenView(screen: .aiThemeCreation, theme: .ai))
        }
        if presentedCard == .ai {
            DispatchQueue.main.async { [weak self] in
                self?.focusAIThemePrompt(accessibilityNotification: .screenChanged)
            }
        } else {
            UIAccessibility.post(
                notification: .screenChanged,
                argument: expandedThemeCardView?.frontFocusView
                    ?? expandedStatisticsCardView?.initialFocusView
            )
        }
    }

    private func completeExpandedCardCollapse() {
        let presentedCard = homeCardState.presentedCard
        if case .theme = presentedCard {
            analytics.track(
                .quizSetupCancelled(theme: session.chosenTheme?.analyticsTheme ?? .unknown)
            )
        }
        themesCollectionService.presentedThemeID = nil
        themesCollectionService.isStatisticsPresented = false
        themesCollectionService.isAIThemePresented = false
        themesCollectionView.layoutIfNeeded()
        removeExpandedThemeCardViews()
        _ = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .collapseCompleted
        )
        restoreGridAfterExpandedCard(presentedCard: presentedCard)
    }

    private func makeExpandedCardTransitionView(
        frame: CGRect,
        targetFrame: CGRect,
        theme: QuizTheme?,
        appearance: AppAppearance,
        initialCornerRadius: CGFloat,
        initialVisualState: HomeThemeCardTransitionVisualState,
        initialShadow: AppShadowStyle
    ) -> ThemeCardExpansionTransitionView {
        let themeID = theme?.stableID ?? homeCardState.themeID ?? ""
        let tintColor = ThemeVisualCatalog.tintColor(for: themeID)
        let transitionView = ThemeCardExpansionTransitionView(
            frame: frame,
            targetFrameInRoot: targetFrame,
            surfaceColor: appearance.themeCardBackground(baseColor: tintColor),
            borderColor: appearance.themeCardBorder(baseColor: tintColor),
            borderWidth: appearance.themeCardBorderWidth,
            cornerRadius: initialCornerRadius,
            visualState: initialVisualState,
            shadow: initialShadow
        )
        transitionView.accessibilityIdentifier = AccessibilityID.expandedCardTransition
        return transitionView
    }

    private func makeStatisticsCardTransitionView(
        frame: CGRect,
        targetFrame: CGRect,
        surfaceColor: UIColor,
        borderColor: UIColor,
        borderWidth: CGFloat,
        initialCornerRadius: CGFloat,
        initialVisualState: HomeThemeCardTransitionVisualState,
        initialShadow: AppShadowStyle
    ) -> ThemeCardExpansionTransitionView {
        let appearance = currentAppearance()
        let transitionView = ThemeCardExpansionTransitionView(
            frame: frame,
            targetFrameInRoot: targetFrame,
            surfaceColor: surfaceColor,
            borderColor: appearance.designStyle == .radar
                ? appearance.accentColor
                : borderColor,
            borderWidth: borderWidth,
            cornerRadius: initialCornerRadius,
            visualState: initialVisualState,
            shadow: initialShadow,
            usesIntensityLayer: false
        )
        transitionView.accessibilityIdentifier = AccessibilityID.expandedStatisticsCardTransition
        return transitionView
    }

    private func makeAIThemeCardTransitionView(
        frame: CGRect,
        targetFrame: CGRect,
        surfaceColor: UIColor,
        borderColor: UIColor,
        borderWidth: CGFloat,
        initialCornerRadius: CGFloat,
        collapsedCornerRadius: CGFloat,
        expandedCornerRadius: CGFloat,
        gradientReferenceWidth: CGFloat,
        initialVisualState: HomeThemeCardTransitionVisualState,
        initialShadow: AppShadowStyle
    ) -> ThemeCardExpansionTransitionView {
        let appearance = currentAppearance()
        let transitionView = ThemeCardExpansionTransitionView(
            frame: frame,
            targetFrameInRoot: targetFrame,
            surfaceColor: surfaceColor,
            borderColor: appearance.designStyle == .radar
                ? appearance.accentColor
                : borderColor,
            borderWidth: borderWidth,
            cornerRadius: initialCornerRadius,
            visualState: initialVisualState,
            shadow: initialShadow,
            usesIntensityLayer: false,
            gradientOutlineConfiguration: appearance.designStyle == .radar
                ? nil
                : ThemeCardTransitionGradientOutlineConfiguration(
                    colors: ExpandedAIThemeCardView.gradientOutlineColors,
                    lineWidth: ExpandedAIThemeCardView.gradientOutlineLineWidth,
                    collapsedCornerRadius: collapsedCornerRadius,
                    expandedCornerRadius: expandedCornerRadius,
                    referenceWidth: gradientReferenceWidth
                ),
            solidBorderColorOverride: appearance.designStyle == .radar
                ? appearance.accentColor
                : nil
        )
        transitionView.accessibilityIdentifier = AccessibilityID.expandedAIThemeCardTransition
        return transitionView
    }

    private func transitionBorderColor(for view: UIView?, fallback: UIColor) -> UIColor {
        guard let color = view?.layer.borderColor else { return fallback }
        return UIColor(cgColor: color)
    }

    private func completeExpandedCardTransition(targetFrame: CGRect) {
        guard
            let cardView = expandedCardContentView,
            expandedCardTransitionView != nil
        else {
            expandedCardContentView?.alpha = 1
            return
        }

        UIView.performWithoutAnimation {
            cardView.removeFromSuperview()
            cardView.frame = targetFrame
            cardView.alpha = 1
            cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
            expandedThemeCardView?.setTransitionSurfaceHidden(false)
            expandedThemeCardView?.setTransitionShadowHidden(false)
            expandedStatisticsCardView?.setTransitionSurfaceHidden(false)
            expandedStatisticsCardView?.setTransitionShadowHidden(false)
            expandedAIThemeCardView?.setTransitionSurfaceHidden(false)
            expandedAIThemeCardView?.setTransitionShadowHidden(false)
            view.addSubview(cardView)
            expandedCardTransitionView?.removeFromSuperview()
            expandedCardTransitionView = nil
        }
    }

    private func launchQuiz(themeID: String, questionCount: Int) {
        guard
            !isQuizLaunchPending,
            session.chosenTheme?.themeID == themeID,
            let cardView = expandedThemeCardView,
            let router
        else { return }

        session.questionsCount = questionCount
        analytics.track(
            .quizStarted(
                theme: session.chosenTheme?.analyticsTheme ?? .unknown,
                questionCount: questionCount
            )
        )
        quizTransitionSourceView = cardView.transitionSourceView
        isQuizLaunchPending = true
        hasQuizLaunchStarted = true
        cardView.isUserInteractionEnabled = false
        router.showQuestion()
    }

    private func makeExpandedCardBackdrop(appearance: AppAppearance) -> UIView {
        let backdropView: UIView
        if cardReduceTransparencyProvider() {
            let opaqueView = UIView()
            opaqueView.backgroundColor = appearance.backgroundColor.withAlphaComponent(
                Appearance.reducedTransparencyBackdropAlpha
            )
            opaqueView.alpha = 0
            backdropView = opaqueView
            expandedCardBlurView = nil
        } else {
            let blurView = UIVisualEffectView(effect: nil)
            backdropView = blurView
            expandedCardBlurView = blurView
        }

        backdropView.accessibilityIdentifier = AccessibilityID.expandedCardBackdrop
        backdropView.accessibilityElementsHidden = true
        backdropView.isUserInteractionEnabled = false
        let dismissButton = UIButton(type: .custom)
        dismissButton.accessibilityIdentifier = AccessibilityID.expandedCardBackdropDismissButton
        dismissButton.isAccessibilityElement = false
        dismissButton.backgroundColor = .clear
        dismissButton.addTarget(
            self,
            action: #selector(expandedCardBackdropTapped),
            for: .touchUpInside
        )
        expandedCardBackdropDismissButton = dismissButton
        return backdropView
    }

    private func installExpandedCardBackdropDismissButton() {
        guard let dismissButton = expandedCardBackdropDismissButton else { return }
        dismissButton.frame = view.bounds
        dismissButton.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        dismissButton.layer.zPosition = Appearance.expandedCardBackdropLayerZPosition + 1
        view.addSubview(dismissButton)
    }

    @objc private func expandedCardBackdropTapped() {
        switch homeCardState.phase {
        case .expanding, .expandedFront, .expandedBack:
            requestExpandedCardClose()

        case .flippingToBack:
            // Finish the user's dismissal through the sharp front face. Retargeting
            // the interruptible flip avoids waiting for a stale back completion.
            closeAfterFlipToFront = true
            sendHomeCardAction(.flipRequested)

        case .flippingToFront:
            closeAfterFlipToFront = true

        case .grid, .collapsing, .launching:
            break
        }
    }

    private func expandedThemeCardFrame() -> CGRect {
        let safeFrame = view.safeAreaLayoutGuide.layoutFrame
        let width = min(
            max(safeFrame.width - ExpandedCardLayout.horizontalInset * 2, 0),
            ExpandedCardLayout.maximumWidth
        )
        let top = safeFrame.minY + ExpandedCardLayout.topInset
        let maximumBottom = safeFrame.maxY - ExpandedCardLayout.bottomInset
        let availableHeight = max(maximumBottom - top, 0)
        let preferredHeight = max(
            width * ExpandedCardLayout.heightToWidthRatio,
            ExpandedCardLayout.minimumHeight
        )
        let height = min(preferredHeight, availableHeight)
        let centeredY = safeFrame.midY - height / 2
        let originY = max(top, min(centeredY, maximumBottom - height))

        return CGRect(
            x: safeFrame.midX - width / 2,
            y: originY,
            width: width,
            height: height
        ).integral
    }

    private func expandedAIThemeCardFrame() -> CGRect {
        expandedThemeCardFrame().offsetBy(dx: 0, dy: -expandedAIKeyboardLift)
    }

    private func updateExpandedAIThemeCardFrame(
        _ cardView: ExpandedAIThemeCardView,
        keyboardFrameInWindow: CGRect?,
        duration: TimeInterval,
        options: UIView.AnimationOptions
    ) {
        guard
            cardView === expandedAIThemeCardView,
            cardView.window != nil,
            homeCardState.phase != .collapsing
        else { return }

        freezeExpandedAIKeyboardAnimation(on: cardView)
        let baseFrame = expandedThemeCardFrame()
        let requestedLift: CGFloat
        if let keyboardFrameInWindow, let window = cardView.window {
            let keyboardFrame = view.convert(keyboardFrameInWindow, from: window)
            let desiredPromptBottom = keyboardFrame.minY - ExpandedCardLayout.keyboardSpacing
            requestedLift = max(
                baseFrame.minY + cardView.promptContainerMaxYAtRest - desiredPromptBottom,
                0
            )
        } else {
            requestedLift = 0
        }

        let safeTop = view.safeAreaLayoutGuide.layoutFrame.minY
            + ExpandedCardLayout.keyboardMinimumTopInset
        let maximumLift = max(baseFrame.minY - safeTop, 0)
        expandedAIKeyboardLift = min(requestedLift, maximumLift)
        let targetFrame = expandedAIThemeCardFrame()

        guard duration > 0 else {
            cardView.frame = targetFrame
            self.expandedCardInteractionButton?.frame = self.view.bounds
            return
        }

        let curveRawValue = Int(options.rawValue >> 16)
        let curve: UIView.AnimationCurve
        switch curveRawValue {
        case UIView.AnimationCurve.easeInOut.rawValue:
            curve = .easeInOut
        case UIView.AnimationCurve.easeIn.rawValue:
            curve = .easeIn
        case UIView.AnimationCurve.easeOut.rawValue:
            curve = .easeOut
        case UIView.AnimationCurve.linear.rawValue:
            curve = .linear
        default:
            // UIKit commonly reports the private keyboard curve value 7.
            // Keep the card synchronized with the keyboard using a supported
            // moving/morphing curve instead of constructing an unknown enum.
            curve = .easeInOut
        }
        let animator = UIViewPropertyAnimator(duration: duration, curve: curve)
        animator.addAnimations { [weak self, weak cardView] in
            guard let self, let cardView else { return }
            cardView.frame = targetFrame
            self.expandedCardInteractionButton?.frame = self.view.bounds
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.expandedAIKeyboardAnimator === animator else { return }
            self.expandedAIKeyboardAnimator = nil
        }
        expandedAIKeyboardAnimator = animator
        animator.startAnimation()
    }

    private func freezeExpandedAIKeyboardAnimation(
        on cardView: ExpandedAIThemeCardView,
        visibleFrameOverride: CGRect? = nil
    ) {
        guard let animator = expandedAIKeyboardAnimator else { return }

        let visibleFrame = visibleFrameOverride ?? cardView.layer.presentation()?.frame
        animator.stopAnimation(true)
        expandedAIKeyboardAnimator = nil
        cardView.layer.removeAllAnimations()

        guard let visibleFrame else { return }
        cardView.frame = visibleFrame
        expandedAIKeyboardLift = max(expandedThemeCardFrame().minY - visibleFrame.minY, 0)
    }

    private func makeSnapshotFallback(from sourceView: UIView) -> UIView {
        let fallbackView = UIView()
        fallbackView.backgroundColor = sourceView.backgroundColor
        fallbackView.layer.cornerRadius = sourceView.layer.cornerRadius
        fallbackView.layer.cornerCurve = sourceView.layer.cornerCurve
        fallbackView.layer.borderWidth = sourceView.layer.borderWidth
        fallbackView.layer.borderColor = sourceView.layer.borderColor
        return fallbackView
    }

    private func makeThemeCardSourceContent(
        from sourceView: UIView
    ) -> (view: UIView, geometry: HomeThemeCardContentGeometry) {
        var ancestor: UIView? = sourceView
        while let currentView = ancestor {
            if let cell = currentView as? ThemeCardCollectionViewCell {
                return cell.makeTransitionContent()
            }
            ancestor = currentView.superview
        }

        let containerView = UIView(frame: sourceView.bounds)
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = false
        containerView.accessibilityElementsHidden = true
        var imageCenter = CGPoint(x: sourceView.bounds.midX, y: sourceView.bounds.midY)
        var titleCenter = imageCenter

        sourceView.subviews.forEach { contentView in
            guard
                let identifier = contentView.accessibilityIdentifier,
                identifier.hasPrefix(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix) ||
                    identifier.hasPrefix(ThemesCollectionService.Content.themeTitleAccessibilityIDPrefix),
                let snapshotView = contentView.snapshotView(afterScreenUpdates: false)
            else { return }

            let contentFrame = contentView.convert(contentView.bounds, to: sourceView)
            snapshotView.frame = contentFrame
            containerView.addSubview(snapshotView)

            if identifier.hasPrefix(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix) {
                imageCenter = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            } else {
                titleCenter = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            }
        }
        return (
            view: containerView,
            geometry: HomeThemeCardContentGeometry(
                containerSize: sourceView.bounds.size,
                imageCenter: imageCenter,
                titleCenter: titleCenter
            )
        )
    }

    private func makeStatisticsCardSourceContent(from sourceView: UIView) -> UIView {
        var ancestor: UIView? = sourceView
        while let currentView = ancestor {
            if let cell = currentView as? StatisticsCardCollectionViewCell {
                return cell.makeTransitionContent()
            }
            ancestor = currentView.superview
        }

        let containerView = UIView(frame: sourceView.bounds)
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = false
        containerView.accessibilityElementsHidden = true
        if let contentView = sourceView.subviews.first(where: { $0 is UIStackView }),
           let snapshotView = contentView.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = contentView.convert(contentView.bounds, to: sourceView)
            containerView.addSubview(snapshotView)
        }
        return containerView
    }

    private func makeAIThemeCardSourceContent(from sourceView: UIView) -> UIView {
        let wasHidden = sourceView.isHidden
        let sourceControl = sourceView as? UIControl
        let wasEnabled = sourceControl?.isEnabled
        sourceView.isHidden = false
        sourceControl?.isEnabled = true
        sourceView.layoutIfNeeded()
        defer {
            sourceView.isHidden = wasHidden
            if let wasEnabled {
                sourceControl?.isEnabled = wasEnabled
            }
        }

        let containerView = UIView(frame: sourceView.bounds)
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = false
        containerView.accessibilityElementsHidden = true

        var didCopyContent = false
        if let button = sourceView as? UIButton,
           let titleLabel = button.titleLabel,
           let titleSnapshot = titleLabel.snapshotView(afterScreenUpdates: false) {
            titleSnapshot.frame = titleLabel.convert(titleLabel.bounds, to: sourceView)
            containerView.addSubview(titleSnapshot)
            didCopyContent = true
        }
        if let betaBadge = sourceView.subviews.first(where: {
            $0.accessibilityIdentifier == ThemesCollectionService.Content.aiThemeBetaBadgeAccessibilityID
        }), let badgeSnapshot = betaBadge.snapshotView(afterScreenUpdates: false) {
            badgeSnapshot.frame = betaBadge.convert(betaBadge.bounds, to: sourceView)
            containerView.addSubview(badgeSnapshot)
            didCopyContent = true
        }

        if !didCopyContent,
           let snapshotView = sourceView.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = sourceView.bounds
            containerView.addSubview(snapshotView)
        }
        return containerView
    }

    private func sourceButton(themeID: String) -> UIButton? {
        themesCollectionView.visibleCells
            .compactMap { $0 as? ThemeCardCollectionViewCell }
            .map(\.actionButton)
            .first(where: { $0.accessibilityIdentifier == themeID })
    }

    private func sourceButtonFrame(themeID: String) -> CGRect? {
        guard let button = sourceButton(themeID: themeID) else { return nil }
        return button.convert(button.bounds, to: view)
    }

    private func sourceStatisticsButton() -> UIButton? {
        themesCollectionView.visibleCells
            .compactMap { $0 as? StatisticsCardCollectionViewCell }
            .map(\.actionButton)
            .first
    }

    private func sourceAIThemeButton() -> UIButton? {
        themesCollectionView.visibleCells
            .lazy
            .flatMap { $0.contentView.subviews }
            .compactMap { $0 as? UIButton }
            .first(where: {
                $0.accessibilityIdentifier == ThemesCollectionService.Content.aiThemeAccessibilityID
            })
    }

    private func setBackgroundAccessibilityHidden(_ isHidden: Bool) {
        headerStackView.accessibilityElementsHidden = isHidden
        screenStackView.accessibilityElementsHidden = isHidden
        settingsButton.accessibilityElementsHidden = isHidden
    }

    private func refreshExpandedThemeCardAppearance() {
        switch homeCardState.phase {
        case .expanding, .flippingToBack, .flippingToFront:
            expandedCardNeedsRefresh = true
            return
        case .grid, .collapsing:
            return
        case .expandedFront, .expandedBack, .launching:
            break
        }

        if homeCardState.isStatisticsPresented,
           let cardView = expandedStatisticsCardView {
            expandedCardNeedsRefresh = false
            let summary = statisticsStore.loadSummary()
            expandedStatisticsSummary = summary
            cardView.configure(summary: summary, appearance: currentAppearance())
            if expandedCardBlurView == nil {
                expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                    Appearance.reducedTransparencyBackdropAlpha
                )
            }
            return
        }

        if homeCardState.isAIThemePresented,
           let cardView = expandedAIThemeCardView {
            expandedCardNeedsRefresh = false
            let face = cardView.face
            cardView.configure(state: homeAIThemeCardState, appearance: currentAppearance())
            cardView.setFace(face, animated: false)
            if expandedCardBlurView == nil {
                expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                    Appearance.reducedTransparencyBackdropAlpha
                )
            }
            return
        }

        guard
            let cardView = expandedThemeCardView,
            let themeID = homeCardState.themeID,
            let theme = themeRepository.themes?.first(where: { $0.stableID == themeID }) ?? expandedTheme
        else { return }

        expandedCardNeedsRefresh = false
        let face = cardView.face
        expandedTheme = theme
        cardView.configure(
            theme: theme,
            appearance: currentAppearance(),
            availableQuestionCounts: homeCardState.availableQuestionCounts,
            selectedQuestionCount: homeCardState.selectedQuestionCount
        )
        cardView.setFace(face, animated: false)
        updateExpandedThemeCardParallaxPhase()
        if expandedCardBlurView == nil {
            expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                Appearance.reducedTransparencyBackdropAlpha
            )
        }
    }

    private func resetExpandedThemeCard() {
        expandedCardAnimator?.stopAnimation(true)
        expandedCardAnimator = nil
        if let effect = HomeAIThemeCardReducer.reduce(
            state: &homeAIThemeCardState,
            action: .reset
        ) {
            handleAIThemeCardEffect(effect)
        }
        removeExpandedThemeCardViews()
        _ = HomeThemeCardReducer.reduce(state: &homeCardState, action: .reset)
        guard isViewLoaded else {
            quizTransitionSourceView = nil
            return
        }
        restoreGridAfterExpandedCard(presentedCard: nil)
    }

    private func restoreHomeAfterQuizIfNeeded(force: Bool = false) {
        guard force || (isQuizLaunchPending && hasQuizLaunchStarted) else { return }
        cancelFeelingLuckyLaunch()
        quizTransitionSourceView?.isHidden = false
        isQuizLaunchPending = false
        hasQuizLaunchStarted = false
        resetExpandedThemeCard()
    }

    private func removeExpandedThemeCardViews() {
        expandedAIKeyboardAnimator?.stopAnimation(true)
        expandedAIKeyboardAnimator = nil
        expandedThemeCardView?.setParallaxPresentationPhase(.inactive)
        expandedThemeCardView?.removeFromSuperview()
        expandedStatisticsCardView?.removeFromSuperview()
        expandedAIThemeCardView?.removeFromSuperview()
        expandedCardSnapshotView?.removeFromSuperview()
        expandedCardSourceContentView?.removeFromSuperview()
        expandedCardTransitionView?.removeFromSuperview()
        expandedCardInteractionButton?.removeFromSuperview()
        expandedCardBackdropDismissButton?.removeFromSuperview()
        expandedCardBackdropView?.removeFromSuperview()
        expandedThemeCardView = nil
        expandedStatisticsCardView = nil
        expandedAIThemeCardView = nil
        expandedCardSnapshotView = nil
        expandedCardSourceContentView = nil
        expandedCardSourceContentGeometry = nil
        expandedCardTransitionView = nil
        expandedCardInteractionButton = nil
        expandedCardBackdropDismissButton = nil
        expandedCardBackdropView = nil
        expandedCardBlurView = nil
        expandedTheme = nil
        expandedStatisticsSummary = nil
        aiSubmissionTask?.cancel()
        aiSubmissionTask = nil
        aiProgressTask?.cancel()
        aiProgressTask = nil
        homeAIThemeCardState = HomeAIThemeCardState()
        closeAfterFlipToFront = false
        focusAIThemePromptAfterFlip = false
        expandedCardNeedsRefresh = false
        expandedCardScreenViewTracked = false
        expandedCardLastTrackedFace = nil
        expandedAIKeyboardLift = 0
    }

    private func updateExpandedThemeCardParallaxPhase() {
        expandedThemeCardView?.setParallaxPresentationPhase(
            homeCardState.phase.parallaxPresentationPhase
        )
    }

    private func restoreGridAfterExpandedCard(presentedCard: HomePresentedCard?) {
        themesCollectionService.presentedThemeID = nil
        themesCollectionService.isStatisticsPresented = false
        themesCollectionService.isAIThemePresented = false
        themesCollectionView.isUserInteractionEnabled = true
        setBackgroundAccessibilityHidden(false)
        updateCollectionScrollAvailability()
        quizTransitionSourceView = nil

        guard let presentedCard else { return }
        themesCollectionView.layoutIfNeeded()
        let focusView: UIView?
        switch presentedCard {
        case let .theme(themeID):
            focusView = sourceButton(themeID: themeID)
        case .statistics:
            focusView = sourceStatisticsButton()
        case .ai:
            focusView = sourceAIThemeButton()
        }
        UIAccessibility.post(
            notification: .screenChanged,
            argument: focusView
        )
    }

#if DEBUG
    var expandedCardAnimatorForTesting: UIViewPropertyAnimator? {
        expandedCardAnimator
    }

    var expandedAIKeyboardAnimatorForTesting: UIViewPropertyAnimator? {
        expandedAIKeyboardAnimator
    }

    var expandedAIKeyboardAnimationCurveForTesting: UIView.AnimationCurve? {
        (expandedAIKeyboardAnimator?.timingParameters as? UICubicTimingParameters)?.animationCurve
    }

    var expandedCardTransitionInitialFrameForTesting: CGRect? {
        expandedCardTransitionView?.targetFrameInRoot
    }

    func updateExpandedAIThemeCardFrameForTesting(
        keyboardFrameInWindow: CGRect?,
        duration: TimeInterval,
        curveRawValue: UInt = UInt(UIView.AnimationCurve.easeInOut.rawValue)
    ) {
        guard let cardView = expandedAIThemeCardView else { return }
        updateExpandedAIThemeCardFrame(
            cardView,
            keyboardFrameInWindow: keyboardFrameInWindow,
            duration: duration,
            options: UIView.AnimationOptions(
                rawValue: curveRawValue << 16
            )
        )
    }

    func freezeExpandedAIKeyboardAnimationForTesting(visibleFrame: CGRect) {
        guard let cardView = expandedAIThemeCardView else { return }
        freezeExpandedAIKeyboardAnimation(
            on: cardView,
            visibleFrameOverride: visibleFrame
        )
    }

    private func updateSettingsDebugMenu(appearance: AppAppearance) {
        guard let settingsButton else { return }

        let interfaceAction = UIAction(
            title: isDebugInterfaceHidden ? "Show UI" : "Hide UI",
            image: UIImage(
                systemName: isDebugInterfaceHidden
                    ? Content.showInterfaceIconName
                    : Content.hideInterfaceIconName
            )
        ) { [weak self] _ in
            self?.toggleDebugInterfaceVisibility()
        }

        var menuElements: [UIMenuElement] = [interfaceAction]
        if appearance.designStyle == .classic {
            let backgroundMenu = UIMenu(
                title: L10n.Home.backgroundStyleSwitcher,
                image: UIImage(systemName: Content.backgroundStyleIconName),
                options: .displayInline,
                children: AppBackgroundStyle.allCases.map { [weak self] style in
                    UIAction(
                        title: style.title,
                        image: UIImage(systemName: style.systemImageName),
                        state: style == appearance.backgroundStyle ? .on : .off
                    ) { _ in
                        self?.selectBackgroundStyle(style)
                    }
                }
            )
            menuElements.append(backgroundMenu)
        }

        settingsButton.menu = UIMenu(children: menuElements)
    }

    func selectBackgroundStyle(_ style: AppBackgroundStyle) {
        let store = AppAppearanceStore.shared
        guard store.backgroundStyle != style else { return }

        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        store.backgroundStyle = style
        feedback.selectionChanged()
    }
#endif

    @objc private func settingsButtonTapped() {
        guard !isQuizLaunchPending else { return }
        router?.showSettings()
    }

#if DEBUG
    func toggleDebugInterfaceVisibility() {
        isDebugInterfaceHidden.toggle()

        headerStackView.isHidden = isDebugInterfaceHidden
        screenStackView.isHidden = isDebugInterfaceHidden
        updateSettingsDebugMenu(appearance: currentAppearance())
    }
#endif

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        refreshMotivationPrompt()
#if DEBUG
        updateSettingsDebugMenu(appearance: currentAppearance())
#endif
        settingsButton.accessibilityLabel = L10n.Settings.title
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        updateThemeAvailabilityMessage()
        themesCollectionView.reloadData()
        refreshExpandedThemeCardAppearance()
    }
}

private final class ThemeCardTransitionInteractionButton: UIButton {
    var trackedViews: [UIView] = [] {
        didSet {
            initialTrackedFrames = trackedViews.map { $0.layer.frame }
        }
    }
    var onTap: (() -> Void)?
    private var initialTrackedFrames: [CGRect] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(tapped), for: .touchUpInside)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        guard super.point(inside: point, with: event), superview != nil else { return false }

        return trackedViews.enumerated().contains { index, trackedView in
            guard let trackedSuperview = trackedView.superview else { return false }
            let candidateFrames: [CGRect]
            if let presentationFrame = trackedView.layer.presentation()?.frame {
                candidateFrames = [presentationFrame]
            } else {
                candidateFrames = [trackedView.layer.frame] +
                    (initialTrackedFrames.indices.contains(index) ? [initialTrackedFrames[index]] : [])
            }
            return candidateFrames.contains { candidateFrame in
                convert(candidateFrame, from: trackedSuperview).contains(point)
            }
        }
    }

    @objc private func tapped() {
        onTap?()
    }
}

private struct ThemeCardTransitionGradientOutlineConfiguration {
    let colors: [UIColor]
    let lineWidth: CGFloat
    let collapsedCornerRadius: CGFloat
    let expandedCornerRadius: CGFloat
    let referenceWidth: CGFloat
}

private final class ThemeCardTransitionGradientOutlineView: UIView {
    private enum AccessibilityID {
        static let collapsedRing = "homeExpandedAIThemeCardTransitionCollapsedGradientRing"
        static let expandedRing = "homeExpandedAIThemeCardTransitionExpandedGradientRing"
    }

    private let collapsedRingImageView = UIImageView()
    private let expandedRingImageView = UIImageView()

    init(configuration: ThemeCardTransitionGradientOutlineConfiguration) {
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isUserInteractionEnabled = false
        accessibilityElementsHidden = true
        accessibilityIdentifier = "homeExpandedAIThemeCardTransitionGradientOutline"

        configure(
            collapsedRingImageView,
            accessibilityIdentifier: AccessibilityID.collapsedRing,
            image: Self.makeResizableRingImage(
                colors: configuration.colors,
                lineWidth: configuration.lineWidth,
                cornerRadius: configuration.collapsedCornerRadius,
                referenceWidth: configuration.referenceWidth
            )
        )
        configure(
            expandedRingImageView,
            accessibilityIdentifier: AccessibilityID.expandedRing,
            image: Self.makeResizableRingImage(
                colors: configuration.colors,
                lineWidth: configuration.lineWidth,
                cornerRadius: configuration.expandedCornerRadius,
                referenceWidth: configuration.referenceWidth
            )
        )
        addSubview(collapsedRingImageView)
        addSubview(expandedRingImageView)
        apply(progress: 0)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutRingFrames()
    }

    func updateGeometry(frame: CGRect) {
        self.frame = frame
        layoutRingFrames()
    }

    private func layoutRingFrames() {
        collapsedRingImageView.frame = bounds
        expandedRingImageView.frame = bounds
    }

    func apply(progress: CGFloat) {
        let progress = min(max(progress, 0), 1)
        collapsedRingImageView.alpha = 1 - progress
        expandedRingImageView.alpha = progress
    }

    private func configure(
        _ imageView: UIImageView,
        accessibilityIdentifier: String,
        image: UIImage
    ) {
        imageView.backgroundColor = .clear
        imageView.isOpaque = false
        imageView.isUserInteractionEnabled = false
        imageView.accessibilityElementsHidden = true
        imageView.accessibilityIdentifier = accessibilityIdentifier
        imageView.contentMode = .scaleToFill
        imageView.image = image
    }

    private static func makeResizableRingImage(
        colors: [UIColor],
        lineWidth: CGFloat,
        cornerRadius: CGFloat,
        referenceWidth: CGFloat
    ) -> UIImage {
        let verticalCap = max(ceil(cornerRadius), ceil(lineWidth))
        let size = CGSize(
            width: max(ceil(referenceWidth), verticalCap * 2 + 1),
            height: verticalCap * 2 + 1
        )
        let format = UIGraphicsImageRendererFormat()
        format.opaque = false
        format.scale = UIScreen.main.scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            let bounds = CGRect(origin: .zero, size: size)
            let ringPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: cornerRadius
            )
            let innerBounds = bounds.insetBy(dx: lineWidth, dy: lineWidth)
            ringPath.append(
                UIBezierPath(
                    roundedRect: innerBounds,
                    cornerRadius: max(cornerRadius - lineWidth, 0)
                )
            )
            ringPath.usesEvenOddFillRule = true

            let graphicsContext = context.cgContext
            graphicsContext.saveGState()
            graphicsContext.addPath(ringPath.cgPath)
            graphicsContext.clip(using: .evenOdd)
            if let gradient = CGGradient(
                colorsSpace: nil,
                colors: colors.map(\.cgColor) as CFArray,
                locations: nil
            ) {
                graphicsContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: bounds.minX, y: bounds.midY),
                    end: CGPoint(x: bounds.maxX, y: bounds.midY),
                    options: []
                )
            } else {
                graphicsContext.setFillColor((colors.first ?? .clear).cgColor)
                graphicsContext.fill(bounds)
            }
            graphicsContext.restoreGState()
        }

        return image.resizableImage(
            withCapInsets: UIEdgeInsets(
                top: verticalCap,
                left: 0,
                bottom: verticalCap,
                right: 0
            ),
            resizingMode: .stretch
        )
    }
}

private final class ThemeCardExpansionTransitionView: UIView {
    private let clippingView = UIView()
    private let baseSurfaceView = UIView()
    private let expandedSurfaceView = UIView()
    private weak var destinationView: UIView?
    private weak var sourceContentView: UIView?
    private var sourceContentSize = CGSize.zero
    private var destinationProgressHandler: ((CGFloat) -> Void)?
    fileprivate let targetFrameInRoot: CGRect
    private let usesIntensityLayer: Bool
    private let gradientOutlineView: ThemeCardTransitionGradientOutlineView?
    private let gradientBorderWidth: CGFloat
    private let solidBorderColorOverride: UIColor?

    init(
        frame: CGRect,
        targetFrameInRoot: CGRect,
        surfaceColor: UIColor,
        borderColor: UIColor,
        borderWidth: CGFloat,
        cornerRadius: CGFloat,
        visualState: HomeThemeCardTransitionVisualState,
        shadow: AppShadowStyle,
        usesIntensityLayer: Bool = true,
        gradientOutlineConfiguration: ThemeCardTransitionGradientOutlineConfiguration? = nil,
        solidBorderColorOverride: UIColor? = nil
    ) {
        self.targetFrameInRoot = targetFrameInRoot
        self.usesIntensityLayer = usesIntensityLayer
        self.solidBorderColorOverride = solidBorderColorOverride
        if let gradientOutlineConfiguration, gradientOutlineConfiguration.lineWidth > 0 {
            self.gradientOutlineView = ThemeCardTransitionGradientOutlineView(
                configuration: gradientOutlineConfiguration
            )
            self.gradientBorderWidth = gradientOutlineConfiguration.lineWidth
        } else {
            self.gradientOutlineView = nil
            self.gradientBorderWidth = 0
        }
        super.init(frame: frame)

        backgroundColor = .clear
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        isUserInteractionEnabled = false
        layer.masksToBounds = false
        applyShadow(shadow)

        clippingView.frame = bounds
        clippingView.backgroundColor = .clear
        clippingView.layer.cornerRadius = cornerRadius
        clippingView.layer.cornerCurve = .continuous
        clippingView.layer.masksToBounds = true
        clippingView.layer.borderColor = (solidBorderColorOverride ?? borderColor).cgColor
        clippingView.layer.borderWidth = gradientOutlineView == nil ? borderWidth : 0
        addSubview(clippingView)

        if let gradientOutlineView {
            gradientOutlineView.updateGeometry(frame: clippingView.bounds)
            gradientOutlineView.apply(progress: visualState.progress)
            clippingView.addSubview(gradientOutlineView)
        }

        baseSurfaceView.frame = transitionSurfaceFrame(in: clippingView.bounds)
        baseSurfaceView.backgroundColor = surfaceColor
        baseSurfaceView.layer.cornerRadius = transitionSurfaceCornerRadius(from: cornerRadius)
        baseSurfaceView.layer.cornerCurve = .continuous
        baseSurfaceView.accessibilityIdentifier = "homeExpandedThemeCardTransitionChrome"
        baseSurfaceView.isAccessibilityElement = false
        baseSurfaceView.isUserInteractionEnabled = false
        clippingView.addSubview(baseSurfaceView)

        expandedSurfaceView.frame = transitionSurfaceFrame(in: clippingView.bounds)
        expandedSurfaceView.backgroundColor = surfaceColor
        expandedSurfaceView.layer.cornerRadius = transitionSurfaceCornerRadius(from: cornerRadius)
        expandedSurfaceView.layer.cornerCurve = .continuous
        expandedSurfaceView.alpha = visualState.expandedSurfaceLayerAlpha
        expandedSurfaceView.isHidden = !usesIntensityLayer
        expandedSurfaceView.accessibilityIdentifier = "homeExpandedThemeCardTransitionIntensity"
        expandedSurfaceView.isAccessibilityElement = false
        expandedSurfaceView.isUserInteractionEnabled = false
        clippingView.addSubview(expandedSurfaceView)

        updateShadowPath(cornerRadius: cornerRadius)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func install(
        destinationView: UIView,
        sourceContentView: UIView,
        visualState: HomeThemeCardTransitionVisualState,
        destinationProgressHandler: ((CGFloat) -> Void)? = nil
    ) {
        self.destinationView = destinationView
        self.sourceContentView = sourceContentView
        self.destinationProgressHandler = destinationProgressHandler
        sourceContentSize = sourceContentView.bounds.size
        destinationView.removeFromSuperview()
        sourceContentView.removeFromSuperview()
        destinationView.layer.zPosition = 2
        sourceContentView.layer.zPosition = 3
        clippingView.addSubview(destinationView)
        clippingView.addSubview(sourceContentView)
        updateContentFrames(containerFrame: frame)
        apply(visualState: visualState)
    }

    func move(
        to containerFrame: CGRect,
        cornerRadius: CGFloat,
        visualState: HomeThemeCardTransitionVisualState,
        shadow: AppShadowStyle,
        surfaceColor: UIColor? = nil,
        borderColor: UIColor? = nil,
        borderWidth: CGFloat? = nil
    ) {
        frame = containerFrame
        clippingView.frame = bounds
        clippingView.layer.cornerRadius = cornerRadius
        if let borderColor, gradientOutlineView == nil {
            clippingView.layer.borderColor = (solidBorderColorOverride ?? borderColor).cgColor
        }
        if let borderWidth, gradientOutlineView == nil {
            clippingView.layer.borderWidth = borderWidth
        }
        gradientOutlineView?.updateGeometry(frame: clippingView.bounds)
        baseSurfaceView.frame = transitionSurfaceFrame(in: clippingView.bounds)
        baseSurfaceView.layer.cornerRadius = transitionSurfaceCornerRadius(from: cornerRadius)
        if let surfaceColor {
            baseSurfaceView.backgroundColor = surfaceColor
            expandedSurfaceView.backgroundColor = surfaceColor
        }
        expandedSurfaceView.frame = transitionSurfaceFrame(in: clippingView.bounds)
        expandedSurfaceView.layer.cornerRadius = transitionSurfaceCornerRadius(from: cornerRadius)
        updateContentFrames(containerFrame: containerFrame)
        apply(visualState: visualState)
        applyShadow(shadow)
        updateShadowPath(cornerRadius: cornerRadius)
    }

    private func apply(visualState: HomeThemeCardTransitionVisualState) {
        sourceContentView?.alpha = visualState.sourceContentAlpha
        destinationView?.alpha = visualState.expandedContentAlpha
        destinationProgressHandler?(visualState.progress)
        gradientOutlineView?.apply(progress: visualState.progress)
        expandedSurfaceView.alpha = usesIntensityLayer
            ? visualState.expandedSurfaceLayerAlpha
            : 0
    }

    private func updateContentFrames(containerFrame: CGRect) {
        let geometry = HomeThemeCardTransitionGeometry(
            containerFrame: containerFrame,
            targetFrame: targetFrameInRoot
        )
        destinationView?.frame = geometry.cardFrameInContainer
        sourceContentView?.bounds = CGRect(origin: .zero, size: sourceContentSize)
        sourceContentView?.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func updateShadowPath(cornerRadius: CGFloat) {
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        ).cgPath
    }

    private func transitionSurfaceFrame(in bounds: CGRect) -> CGRect {
        gradientOutlineView == nil
            ? bounds
            : bounds.insetBy(dx: gradientBorderWidth, dy: gradientBorderWidth)
    }

    private func transitionSurfaceCornerRadius(from outerCornerRadius: CGFloat) -> CGFloat {
        gradientOutlineView == nil
            ? outerCornerRadius
            : max(outerCornerRadius - gradientBorderWidth, 0)
    }

}

private final class HomeThemesCollectionView: UICollectionView {
    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }
}

#if DEBUG
#Preview("Quiz") {
    QuizFactory.shared.startup1st = false
    QuizFactory.shared.themes = [
        QuizTheme(id: "music", theme: "Музыка", themeDescription: "Вопросы о треках, артистах и музыкальных эпохах.", questions: []),
        QuizTheme(id: "technology", theme: "Технологии", themeDescription: "Гаджеты, IT-компании и цифровая культура.", questions: []),
        QuizTheme(id: "history_culture", theme: "История и культура", themeDescription: "Исторические события, искусство и традиции.", questions: []),
        QuizTheme(id: "politics_business", theme: "Политика и бизнес", themeDescription: "Лидеры, компании и громкие решения.", questions: [])
    ]

    let viewController = QuizViewController()
    let navigationController = UINavigationController(rootViewController: viewController)
    navigationController.setNavigationBarHidden(true, animated: false)
    return navigationController
}
#endif
