import UIKit
import SwiftUI

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
        static let expandedCardBackdrop = "homeExpandedThemeCardBackdrop"
        static let expandedCardTransition = "homeExpandedThemeCardTransition"
        static let expandedCardSourceSnapshot = "homeExpandedThemeCardSourceSnapshot"
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
    private let analytics: AnalyticsTracking
    private let themesCollectionService: ThemesCollectionService
    private let motivationPromptProvider: (String?) -> String
    private let randomThemeIDProvider: ([QuizTheme]) -> String?
    private let cardReduceMotionProvider: () -> Bool
    private let cardReduceTransparencyProvider: () -> Bool
    private let animationsEngine = Animations()
    private let motivationBlurContext = CIContext(options: nil)
    private var motivationBlurSnapshotSignature: String?
    private var homeCardState = HomeThemeCardState()
    private var expandedThemeCardView: ExpandedThemeCardView?
    private var expandedCardBackdropView: UIView?
    private var expandedCardBlurView: UIVisualEffectView?
    private var expandedCardSnapshotView: UIView?
    private var expandedCardSourceContentView: UIView?
    private var expandedCardSourceContentGeometry: HomeThemeCardContentGeometry?
    private var expandedCardTransitionView: ThemeCardExpansionTransitionView?
    private var expandedCardInteractionButton: ThemeCardTransitionInteractionButton?
    private var expandedCardAnimator: UIViewPropertyAnimator?
    private var expandedTheme: QuizTheme?
    private weak var quizTransitionSourceView: UIView?
    private var isQuizLaunchPending = false
    private var closeAfterFlipToFront = false
    private var expandedCardNeedsRefresh = false
    private var expandedCardScreenViewTracked = false
    weak var router: QuizRouting?
    var presenter: QuizPresenterProtocol?

    var cardSlideTransitionSourceView: UIView {
        quizTransitionSourceView
            ?? expandedThemeCardView?.transitionSourceView
            ?? themesCollectionView
    }

    var cardSlideTransitionHorizontalInset: CGFloat { ExpandedCardLayout.horizontalInset }

    private var startupAnimatedViews: [UIView] {
        [motivationLabel, motivationBlurredImageView, themesCollectionView, settingsButton]
    }

    init(
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizSessionStore.shared,
        statisticsStore: StatisticsStore = StatisticsStore(),
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        motivationPromptProvider: @escaping (String?) -> String = QuizViewController.randomMotivationPrompt,
        randomThemeIDProvider: @escaping ([QuizTheme]) -> String? = { $0.randomElement()?.stableID },
        cardReduceMotionProvider: @escaping () -> Bool = { UIAccessibility.isReduceMotionEnabled },
        cardReduceTransparencyProvider: @escaping () -> Bool = { UIAccessibility.isReduceTransparencyEnabled }
    ) {
        self.themeRepository = themeRepository
        self.session = session
        self.statisticsStore = statisticsStore
        self.analytics = analytics
        self.motivationPromptProvider = motivationPromptProvider
        self.randomThemeIDProvider = randomThemeIDProvider
        self.themesCollectionService = ThemesCollectionService(
            themeRepository: themeRepository,
            statisticsStore: statisticsStore
        )
        self.cardReduceMotionProvider = cardReduceMotionProvider
        self.cardReduceTransparencyProvider = cardReduceTransparencyProvider
        super.init(nibName: nil, bundle: nil)
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
        if expandedCardAnimator == nil,
           homeCardState.phase == .expandedFront || homeCardState.phase == .expandedBack {
            expandedThemeCardView?.frame = expandedThemeCardFrame()
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
        showAIThemeCreationView()
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        router?.showStatistics()
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
        analytics.track(
            .quizStarted(
                theme: session.chosenTheme?.analyticsTheme ?? .unknown,
                questionCount: session.questionsCount
            )
        )
        quizTransitionSourceView = sourceView
        isQuizLaunchPending = true
        router.showQuestion()
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

        case let .flip(face):
            flipExpandedThemeCard(to: face)

        case .collapse:
            collapseExpandedThemeCard()

        case let .reverseExpansion(shouldPresent):
            if !shouldPresent {
                analytics.track(
                    .quizSetupCancelled(theme: session.chosenTheme?.analyticsTheme ?? .unknown)
                )
            }
            reverseExpandedCardTransition()

        case let .launch(themeID, questionCount):
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

        let cardView = ExpandedThemeCardView(frame: targetFrame)
        cardView.reduceMotionProvider = cardReduceMotionProvider
        cardView.accessibilityIdentifier = AccessibilityID.expandedCard
        cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
        cardView.configure(
            theme: theme,
            appearance: appearance,
            availableQuestionCounts: homeCardState.availableQuestionCounts,
            selectedQuestionCount: homeCardState.selectedQuestionCount
        )
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
                cardView: cardView,
                sourceContentView: sourceContentView,
                sourceContentGeometry: sourceContent.geometry,
                visualState: HomeThemeCardTransitionVisualState(progress: 0)
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

    private func wireExpandedThemeCardActions(_ cardView: ExpandedThemeCardView) {
        cardView.onClose = { [weak self] in
            self?.sendHomeCardAction(.closeRequested)
        }
        cardView.onFlip = { [weak self] in
            self?.sendHomeCardAction(.flipRequested)
        }
        cardView.onBack = { [weak self] in
            self?.sendHomeCardAction(.flipRequested)
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

    private func flipExpandedThemeCard(to face: HomeThemeCardFace) {
        expandedThemeCardView?.setFace(face, animated: true) { [weak self] completedFace in
            guard let self else { return }
            _ = HomeThemeCardReducer.reduce(
                state: &self.homeCardState,
                action: .flipCompleted(completedFace)
            )
            if self.expandedCardNeedsRefresh {
                self.refreshExpandedThemeCardAppearance()
            }
            if self.closeAfterFlipToFront, completedFace == .front {
                self.closeAfterFlipToFront = false
                self.sendHomeCardAction(.closeRequested)
            }
        }
    }

    private func handleExpandedCardAccessibilityEscape() {
        switch homeCardState.phase {
        case .expandedBack:
            closeAfterFlipToFront = true
            sendHomeCardAction(.flipRequested)
        case .expandedFront:
            sendHomeCardAction(.closeRequested)
        case .grid, .expanding, .flippingToBack, .flippingToFront, .collapsing, .launching:
            break
        }
    }

    private func collapseExpandedThemeCard() {
        guard let cardView = expandedThemeCardView else {
            resetExpandedThemeCard()
            return
        }

        analytics.track(
            .quizSetupCancelled(theme: session.chosenTheme?.analyticsTheme ?? .unknown)
        )

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
                    cardView: cardView,
                    sourceContentView: sourceContentView,
                    sourceContentGeometry: sourceContentGeometry,
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
            self?.sendHomeCardAction(.closeRequested)
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
        if expandedCardNeedsRefresh {
            refreshExpandedThemeCardAppearance()
        }
        if !expandedCardScreenViewTracked {
            expandedCardScreenViewTracked = true
            analytics.track(
                .screenView(
                    screen: .quizDescription,
                    theme: session.chosenTheme?.analyticsTheme ?? .unknown
                )
            )
        }
        UIAccessibility.post(
            notification: .screenChanged,
            argument: expandedThemeCardView?.frontFocusView
        )
    }

    private func completeExpandedCardCollapse() {
        let themeID = homeCardState.themeID
        themesCollectionService.presentedThemeID = nil
        themesCollectionView.layoutIfNeeded()
        removeExpandedThemeCardViews()
        _ = HomeThemeCardReducer.reduce(
            state: &homeCardState,
            action: .collapseCompleted
        )
        restoreGridAfterExpandedCard(themeID: themeID)
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

    private func completeExpandedCardTransition(targetFrame: CGRect) {
        guard
            let cardView = expandedThemeCardView,
            expandedCardTransitionView != nil
        else {
            expandedThemeCardView?.alpha = 1
            return
        }

        UIView.performWithoutAnimation {
            cardView.removeFromSuperview()
            cardView.frame = targetFrame
            cardView.alpha = 1
            cardView.layer.zPosition = Appearance.expandedCardLayerZPosition
            cardView.setTransitionSurfaceHidden(false)
            cardView.setTransitionShadowHidden(false)
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
            expandedCardBlurView = blurView
            backdropView = blurView
        }

        backdropView.accessibilityIdentifier = AccessibilityID.expandedCardBackdrop
        backdropView.accessibilityElementsHidden = true
        backdropView.isUserInteractionEnabled = true
        return backdropView
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
        if expandedCardBlurView == nil {
            expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                Appearance.reducedTransparencyBackdropAlpha
            )
        }
    }

    private func resetExpandedThemeCard() {
        expandedCardAnimator?.stopAnimation(true)
        expandedCardAnimator = nil
        removeExpandedThemeCardViews()
        _ = HomeThemeCardReducer.reduce(state: &homeCardState, action: .reset)
        guard isViewLoaded else {
            quizTransitionSourceView = nil
            return
        }
        restoreGridAfterExpandedCard(themeID: nil)
    }

    private func restoreHomeAfterQuizIfNeeded(force: Bool = false) {
        guard force || isQuizLaunchPending else { return }
        quizTransitionSourceView?.isHidden = false
        isQuizLaunchPending = false
        resetExpandedThemeCard()
    }

    private func removeExpandedThemeCardViews() {
        expandedThemeCardView?.removeFromSuperview()
        expandedCardSnapshotView?.removeFromSuperview()
        expandedCardSourceContentView?.removeFromSuperview()
        expandedCardTransitionView?.removeFromSuperview()
        expandedCardInteractionButton?.removeFromSuperview()
        expandedCardBackdropView?.removeFromSuperview()
        expandedThemeCardView = nil
        expandedCardSnapshotView = nil
        expandedCardSourceContentView = nil
        expandedCardSourceContentGeometry = nil
        expandedCardTransitionView = nil
        expandedCardInteractionButton = nil
        expandedCardBackdropView = nil
        expandedCardBlurView = nil
        expandedTheme = nil
        closeAfterFlipToFront = false
        expandedCardNeedsRefresh = false
        expandedCardScreenViewTracked = false
    }

    private func restoreGridAfterExpandedCard(themeID: String?) {
        themesCollectionService.presentedThemeID = nil
        themesCollectionView.isUserInteractionEnabled = true
        setBackgroundAccessibilityHidden(false)
        updateCollectionScrollAvailability()
        quizTransitionSourceView = nil

        guard let themeID else { return }
        themesCollectionView.layoutIfNeeded()
        UIAccessibility.post(
            notification: .screenChanged,
            argument: sourceButton(themeID: themeID)
        )
    }

    private func showAIThemeCreationView() {
        router?.showAIThemeCreation()
    }

#if DEBUG
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

private final class ThemeCardExpansionTransitionView: UIView {
    private let clippingView = UIView()
    private let baseSurfaceView = UIView()
    private let expandedSurfaceView = UIView()
    private weak var cardView: ExpandedThemeCardView?
    private weak var sourceContentView: UIView?
    private var sourceContentSize = CGSize.zero
    private var sourceContentGeometry: HomeThemeCardContentGeometry?
    private let targetFrameInRoot: CGRect

    init(
        frame: CGRect,
        targetFrameInRoot: CGRect,
        surfaceColor: UIColor,
        borderColor: UIColor,
        borderWidth: CGFloat,
        cornerRadius: CGFloat,
        visualState: HomeThemeCardTransitionVisualState,
        shadow: AppShadowStyle
    ) {
        self.targetFrameInRoot = targetFrameInRoot
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
        clippingView.layer.borderColor = borderColor.cgColor
        clippingView.layer.borderWidth = borderWidth
        addSubview(clippingView)

        baseSurfaceView.frame = clippingView.bounds
        baseSurfaceView.backgroundColor = surfaceColor
        baseSurfaceView.layer.cornerRadius = cornerRadius
        baseSurfaceView.layer.cornerCurve = .continuous
        baseSurfaceView.accessibilityIdentifier = "homeExpandedThemeCardTransitionChrome"
        baseSurfaceView.isAccessibilityElement = false
        baseSurfaceView.isUserInteractionEnabled = false
        clippingView.addSubview(baseSurfaceView)

        expandedSurfaceView.frame = clippingView.bounds
        expandedSurfaceView.backgroundColor = surfaceColor
        expandedSurfaceView.layer.cornerRadius = cornerRadius
        expandedSurfaceView.layer.cornerCurve = .continuous
        expandedSurfaceView.alpha = visualState.expandedSurfaceLayerAlpha
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
        cardView: ExpandedThemeCardView,
        sourceContentView: UIView,
        sourceContentGeometry: HomeThemeCardContentGeometry,
        visualState: HomeThemeCardTransitionVisualState
    ) {
        self.cardView = cardView
        self.sourceContentView = sourceContentView
        self.sourceContentGeometry = sourceContentGeometry
        sourceContentSize = sourceContentView.bounds.size
        cardView.removeFromSuperview()
        sourceContentView.removeFromSuperview()
        cardView.layer.zPosition = 2
        sourceContentView.layer.zPosition = 3
        clippingView.addSubview(cardView)
        clippingView.addSubview(sourceContentView)
        updateContentFrames(containerFrame: frame)
        apply(visualState: visualState)
    }

    func move(
        to containerFrame: CGRect,
        cornerRadius: CGFloat,
        visualState: HomeThemeCardTransitionVisualState,
        shadow: AppShadowStyle
    ) {
        frame = containerFrame
        clippingView.frame = bounds
        clippingView.layer.cornerRadius = cornerRadius
        baseSurfaceView.frame = clippingView.bounds
        baseSurfaceView.layer.cornerRadius = cornerRadius
        expandedSurfaceView.frame = clippingView.bounds
        expandedSurfaceView.layer.cornerRadius = cornerRadius
        updateContentFrames(containerFrame: containerFrame)
        apply(visualState: visualState)
        applyShadow(shadow)
        updateShadowPath(cornerRadius: cornerRadius)
    }

    private func apply(visualState: HomeThemeCardTransitionVisualState) {
        sourceContentView?.alpha = visualState.sourceContentAlpha
        cardView?.alpha = visualState.expandedContentAlpha
        if let sourceContentGeometry {
            cardView?.setTransitionContentProgress(
                visualState.progress,
                sourceGeometry: sourceContentGeometry
            )
        }
        expandedSurfaceView.alpha = visualState.expandedSurfaceLayerAlpha
    }

    private func updateContentFrames(containerFrame: CGRect) {
        let geometry = HomeThemeCardTransitionGeometry(
            containerFrame: containerFrame,
            targetFrame: targetFrameInRoot
        )
        cardView?.frame = geometry.cardFrameInContainer
        sourceContentView?.bounds = CGRect(origin: .zero, size: sourceContentSize)
        sourceContentView?.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }

    private func updateShadowPath(cornerRadius: CGFloat) {
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: cornerRadius
        ).cgPath
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
