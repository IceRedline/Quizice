import UIKit
import AVKit
import SwiftUI

final class QuizViewController: BaseQuizViewController, QuizViewControllerProtocol, ThemeCollectionDelegate {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
        static let settingsIconName = "gear"
        static let startupSoundName = "Quizice Enter"
        static let startupSoundExtension = "m4a"
        static let themeCellReuseIdentifier = "themeCell"
    }

    private enum AccessibilityID {
        static let rootView = "homeRootView"
        static let motivationLabel = "homeMotivationLabel"
        static let headerStackView = "homeHeaderStackView"
        static let themesCollectionView = "homeThemesCollectionView"
        static let screenStackView = "homeScreenStackView"
        static let settingsButton = "homeSettingsButton"
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
        static let settingsButtonTopInset: CGFloat = 8
        static let settingsButtonTrailingInset: CGFloat = 14
        static let settingsButtonSize: CGFloat = 36
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
        static let motivationFadeInDuration: TimeInterval = 0.65
        static let contentRevealDelay: TimeInterval = 0.45
        static let controlsFadeInDelay: TimeInterval = 0.2
        static let controlsFadeInDuration: TimeInterval = 0.45
        static let cellFadeInDuration: TimeInterval = 0.55
        static let cellFadeInStagger: TimeInterval = 0.08
    }

    private var motivationLabel: UILabel!
    private var headerStackView: UIStackView!
    private var screenStackView: UIStackView!
    private var settingsButton: UIButton!

    private var themesCollectionView: UICollectionView!

    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging
    private let statisticsStore: StatisticsStore
    private let themesCollectionService: ThemesCollectionService
    private let animationsEngine = Animations()
    private var soundPlayer: AVAudioPlayer!
    weak var router: QuizRouting?
    var presenter: QuizPresenterProtocol?

    private var startupAnimatedViews: [UIView] {
        [motivationLabel, themesCollectionView, settingsButton]
    }

    init(
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizFactory.shared,
        statisticsStore: StatisticsStore = StatisticsStore()
    ) {
        self.themeRepository = themeRepository
        self.session = session
        self.statisticsStore = statisticsStore
        self.themesCollectionService = ThemesCollectionService(
            themeRepository: themeRepository,
            statisticsStore: statisticsStore
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        let rootView = UIView()
        if let backgroundImage = UIImage(named: Content.backgroundImageName) {
            rootView.backgroundColor = UIColor(patternImage: backgroundImage)
        } else {
            rootView.backgroundColor = .systemBackground
        }
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
        updateCollectionScrollAvailability()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshMotivationPrompt()
        themesCollectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if session.startup1st {
            animateViewsAndPlaySound()
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

        rootView.addSubview(screenStackView)
        rootView.addSubview(settingsButton)
        activateLayoutConstraints(in: rootView)
    }

    private func configureThemesCollectionService() {
        themesCollectionView.backgroundColor = .clear
        themesCollectionService.delegate = self
        themesCollectionView.delegate = themesCollectionService
        themesCollectionView.dataSource = themesCollectionService
        themesCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Content.themeCellReuseIdentifier)
    }

    private func configureHeaderViews() {
        let typography = currentAppearance().typography
        motivationLabel = makeLabel(text: randomMotivationPrompt(), font: typography.font(size: Typography.motivationFontSize, weight: .bold))
        motivationLabel.numberOfLines = 2
        motivationLabel.accessibilityIdentifier = AccessibilityID.motivationLabel
        motivationLabel.adjustsFontForContentSizeCategory = true
    }

    private func configureSettingsButton() {
        settingsButton = UIButton(type: .system)
        settingsButton.accessibilityIdentifier = AccessibilityID.settingsButton
        settingsButton.accessibilityLabel = L10n.Settings.title
        let settingsIcon = UIImage(
            systemName: Content.settingsIconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Typography.settingsIconPointSize, weight: .semibold)
        )
        settingsButton.setImage(settingsIcon, for: .normal)
        settingsButton.tintColor = .white
        settingsButton.backgroundColor = UIColor.white.withAlphaComponent(Appearance.settingsButtonBackgroundAlpha)
        settingsButton.layer.cornerRadius = Layout.settingsButtonSize / 2
        settingsButton.layer.borderWidth = 1
        settingsButton.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.settingsButtonBorderAlpha).cgColor
        settingsButton.layer.shadowColor = UIColor.black.cgColor
        settingsButton.layer.shadowOpacity = Appearance.settingsButtonShadowOpacity
        settingsButton.layer.shadowRadius = Appearance.settingsButtonShadowRadius
        settingsButton.layer.shadowOffset = Appearance.settingsButtonShadowOffset
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
    }

    private func configureHeaderStack() {
        headerStackView = UIStackView(arrangedSubviews: [motivationLabel])
        headerStackView.accessibilityIdentifier = AccessibilityID.headerStackView
        headerStackView.axis = .vertical
        headerStackView.alignment = .leading
        headerStackView.spacing = Layout.headerStackSpacing
        headerStackView.isLayoutMarginsRelativeArrangement = true
        headerStackView.directionalLayoutMargins = Layout.headerMargins
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
        screenStackView = UIStackView(arrangedSubviews: [headerStackView, themesCollectionView])
        screenStackView.accessibilityIdentifier = AccessibilityID.screenStackView
        screenStackView.axis = .vertical
        screenStackView.alignment = .fill
        screenStackView.spacing = Layout.screenStackSpacing
        screenStackView.isLayoutMarginsRelativeArrangement = true
        screenStackView.directionalLayoutMargins = Layout.screenMargins
        screenStackView.setCustomSpacing(Layout.headerToCollectionSpacing, after: headerStackView)
        screenStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            screenStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            screenStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            screenStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            screenStackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            settingsButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.settingsButtonTopInset),
            settingsButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.settingsButtonTrailingInset),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),

            motivationLabel.widthAnchor.constraint(equalTo: headerStackView.layoutMarginsGuide.widthAnchor)
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

        settingsButton?.applyActionAppearance(appearance.iconButton, appearance: appearance)
        settingsButton?.layer.cornerRadius = Layout.settingsButtonSize / 2
        settingsButton?.tintColor = appearance.screenTextColor

        themesCollectionView?.backgroundColor = .clear
        themesCollectionView?.reloadData()
    }

    private func configureInitialStartupVisibilityIfNeeded() {
        guard session.startup1st else { return }
        startupAnimatedViews.forEach { $0.alpha = Appearance.hiddenAlpha }
    }

    private func updateCollectionScrollAvailability() {
        themesCollectionView.layoutIfNeeded()
        let contentHeight = themesCollectionView.collectionViewLayout.collectionViewContentSize.height
        let viewportHeight = max(
            themesCollectionView.bounds.height - themesCollectionView.adjustedContentInset.top - themesCollectionView.adjustedContentInset.bottom,
            .zero
        )
        let shouldScroll = contentHeight > viewportHeight + Layout.scrollActivationTolerance

        themesCollectionView.isScrollEnabled = shouldScroll
        themesCollectionView.alwaysBounceVertical = shouldScroll
        themesCollectionView.bounces = shouldScroll
    }

    private func animateViewsAndPlaySound() {
        let visibleCells = sortedVisibleThemeCells()
        prepareStartupAnimation(visibleCells: visibleCells)
        loadStartupSound()

        motivationLabel.fadeIn(duration: AnimationTiming.motivationFadeInDuration)

        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.contentRevealDelay) { [weak self] in
            guard let self else { return }
            self.soundPlayer?.play()
            self.themesCollectionView.alpha = Appearance.visibleAlpha

            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.controlsFadeInDelay) { [weak self] in
                guard let self else { return }
                self.settingsButton.fadeIn(duration: AnimationTiming.controlsFadeInDuration)
                self.animateThemeCells(visibleCells)
            }
        }
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
        startupAnimatedViews.forEach { view in
            view.alpha = Appearance.hiddenAlpha
        }

        visibleCells.forEach { cell in
            cell.alpha = Appearance.hiddenAlpha
            cell.isUserInteractionEnabled = false
        }
    }

    private func loadStartupSound() {
        if let startupSoundURL = Bundle.main.url(forResource: Content.startupSoundName, withExtension: Content.startupSoundExtension) {
            soundPlayer = try? AVAudioPlayer(contentsOf: startupSoundURL)
        }
    }

    private func animateThemeCells(_ visibleCells: [UICollectionViewCell]) {
        for (index, cell) in visibleCells.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * AnimationTiming.cellFadeInStagger) {
                cell.fadeIn(duration: AnimationTiming.cellFadeInDuration) {
                    cell.isUserInteractionEnabled = true
                }
            }
        }
    }

    func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }

    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String) {
        animationsEngine.animateUpFloat(sender)
        guard session.loadTheme(themeID: themeID) else {
            updateThemeAvailabilityMessage()
            return
        }
        showDescriptionViewController()
    }

    func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }

    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        startRandomTheme()
    }

    func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        showAIThemeCreationView()
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        router?.showStatistics()
    }

    private func showDescriptionViewController() {
        router?.showDescription()
    }

    private func updateThemeAvailabilityMessage() {
        let hasThemes = themeRepository.themes?.isEmpty == false
        if !hasThemes {
            motivationLabel.text = L10n.Home.unavailableThemes
        }
    }

    private func refreshMotivationPrompt() {
        guard themeRepository.themes?.isEmpty == false else { return }
        motivationLabel.text = randomMotivationPrompt(excluding: motivationLabel.text)
    }

    private func randomMotivationPrompt(excluding currentPrompt: String? = nil) -> String {
        let prompts = L10n.Home.motivationPrompts
        let availablePrompts = prompts.filter { $0 != currentPrompt }
        return (availablePrompts.isEmpty ? prompts : availablePrompts).randomElement() ?? ""
    }

    private func startRandomTheme() {
        guard
            let themeID = themeRepository.themes?.randomElement()?.stableID,
            session.loadTheme(themeID: themeID)
        else {
            updateThemeAvailabilityMessage()
            return
        }
        showDescriptionViewController()
    }

    private func showAIThemeCreationView() {
        router?.showAIThemeCreation()
    }

    @objc private func settingsButtonTapped() {
        router?.showSettings()
    }

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        refreshMotivationPrompt()
        settingsButton.accessibilityLabel = L10n.Settings.title
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        updateThemeAvailabilityMessage()
        themesCollectionView.reloadData()
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
