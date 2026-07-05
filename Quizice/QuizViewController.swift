import UIKit
import AVKit
import SwiftUI

final class QuizViewController: BaseQuizViewController, QuizViewControllerProtocol, ThemeCollectionDelegate {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
        static let logoImageName = "Quizice"
        static let settingsIconName = "gear"
        static let startupSoundName = "Quizice Enter"
        static let startupSoundExtension = "m4a"
        static let themeCellReuseIdentifier = "themeCell"

        static let logoAccessibilityLabel = "Quizice"
    }

    private enum AccessibilityID {
        static let rootView = "homeRootView"
        static let welcomeLabel = "homeWelcomeLabel"
        static let logoImageView = "homeLogoImageView"
        static let logoTextLabel = "homeLogoTextLabel"
        static let chooseThemeLabel = "homeChooseThemeLabel"
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
        static let headerToCollectionSpacing: CGFloat = 18
        static let collectionItemSpacing: CGFloat = 16
        static let collectionHorizontalInset: CGFloat = 24
        static let collectionTopInset: CGFloat = 0
        static let collectionBottomInset: CGFloat = 0
        static let logoWidthMultiplier: CGFloat = 0.7
        static let logoHeight: CGFloat = 84
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
        static let welcomeFontSize: CGFloat = 26
        static let chooseThemeFontSize: CGFloat = 24
        static let logoTextFontSize: CGFloat = 52
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
        static let welcomeFadeInDuration: TimeInterval = 1
        static let logoFadeInDelay: TimeInterval = 1
        static let logoFadeInDuration: TimeInterval = 2
        static let controlsFadeInDelay: TimeInterval = 2
        static let controlsFadeInDuration: TimeInterval = 1
        static let cellFadeInDuration: TimeInterval = 1
        static let cellFadeInStagger: TimeInterval = 0.15
    }

    private var welcomeLabel: UILabel!
    private var quiziceLabel: UIImageView!
    private var quiziceTextLabel: UILabel!
    private var chooseThemeLabel: UILabel!
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
        [welcomeLabel, quiziceLabel, quiziceTextLabel, themesCollectionView, chooseThemeLabel, settingsButton]
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
        welcomeLabel = makeLabel(text: L10n.Home.welcome, font: typography.font(size: Typography.welcomeFontSize, weight: .semibold))
        welcomeLabel.accessibilityIdentifier = AccessibilityID.welcomeLabel
        welcomeLabel.adjustsFontForContentSizeCategory = true

        quiziceLabel = UIImageView(image: UIImage(named: Content.logoImageName))
        quiziceLabel.accessibilityIdentifier = AccessibilityID.logoImageView
        quiziceLabel.accessibilityLabel = Content.logoAccessibilityLabel
        quiziceLabel.contentMode = .scaleAspectFit
        quiziceLabel.translatesAutoresizingMaskIntoConstraints = false

        quiziceTextLabel = makeLabel(text: Content.logoAccessibilityLabel, font: typography.font(size: Typography.logoTextFontSize, weight: .bold))
        quiziceTextLabel.accessibilityIdentifier = AccessibilityID.logoTextLabel
        quiziceTextLabel.accessibilityLabel = Content.logoAccessibilityLabel
        quiziceTextLabel.adjustsFontForContentSizeCategory = true

        chooseThemeLabel = makeLabel(text: L10n.Home.chooseTheme, font: typography.font(size: Typography.chooseThemeFontSize, weight: .semibold))
        chooseThemeLabel.accessibilityIdentifier = AccessibilityID.chooseThemeLabel
        chooseThemeLabel.adjustsFontForContentSizeCategory = true
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
        headerStackView = UIStackView(arrangedSubviews: [welcomeLabel, quiziceLabel, quiziceTextLabel, chooseThemeLabel])
        headerStackView.accessibilityIdentifier = AccessibilityID.headerStackView
        headerStackView.axis = .vertical
        headerStackView.alignment = .center
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

        themesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        themesCollectionView.accessibilityIdentifier = AccessibilityID.themesCollectionView
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        themesCollectionView.alwaysBounceVertical = false
        themesCollectionView.bounces = false
        themesCollectionView.delaysContentTouches = false
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
        let logoHeightConstraint = quiziceLabel.heightAnchor.constraint(equalToConstant: Layout.logoHeight)
        logoHeightConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            screenStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            screenStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            screenStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            screenStackView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor),

            settingsButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.settingsButtonTopInset),
            settingsButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.settingsButtonTrailingInset),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),

            welcomeLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStackView.layoutMarginsGuide.widthAnchor),
            quiziceLabel.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, multiplier: Layout.logoWidthMultiplier),
            logoHeightConstraint,
            quiziceTextLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStackView.layoutMarginsGuide.widthAnchor),
            chooseThemeLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStackView.layoutMarginsGuide.widthAnchor)
        ])
    }

    private func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = font
        label.textAlignment = .center
        label.numberOfLines = Typography.unlimitedNumberOfLines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    override func applyAppearance() {
        guard isViewLoaded else { return }
        let appearance = currentAppearance()
        appearance.applyBackground(to: view)
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        welcomeLabel?.textColor = appearance.screenTextColor
        welcomeLabel?.font = appearance.typography.font(size: Typography.welcomeFontSize, weight: .semibold)
        welcomeLabel?.textAlignment = homeHeaderTextAlignment(for: appearance)
        quiziceTextLabel?.textColor = appearance.screenTextColor
        quiziceTextLabel?.font = appearance.typography.font(size: Typography.logoTextFontSize, weight: .bold)
        quiziceTextLabel?.textAlignment = homeHeaderTextAlignment(for: appearance)
        updateLogoVisibility(for: appearance)
        chooseThemeLabel?.textColor = appearance.screenTextColor
        chooseThemeLabel?.font = appearance.typography.font(size: Typography.chooseThemeFontSize, weight: .semibold)
        chooseThemeLabel?.textAlignment = homeHeaderTextAlignment(for: appearance)
        headerStackView?.alignment = homeHeaderStackAlignment(for: appearance)

        settingsButton?.applyActionAppearance(appearance.iconButton, appearance: appearance)
        settingsButton?.layer.cornerRadius = Layout.settingsButtonSize / 2
        settingsButton?.tintColor = appearance.screenTextColor

        themesCollectionView?.backgroundColor = .clear
        themesCollectionView?.reloadData()
    }

    private func updateLogoVisibility(for appearance: AppAppearance) {
        let usesImageLogo = appearance.designStyle == .classic
        quiziceLabel?.isHidden = !usesImageLogo
        quiziceTextLabel?.isHidden = usesImageLogo
        if !session.startup1st {
            activeLogoView()?.alpha = Appearance.visibleAlpha
        }
    }

    private func homeHeaderTextAlignment(for appearance: AppAppearance) -> NSTextAlignment {
        appearance.designStyle == .clean ? .left : .center
    }

    private func homeHeaderStackAlignment(for appearance: AppAppearance) -> UIStackView.Alignment {
        appearance.designStyle == .clean ? .leading : .center
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

        welcomeLabel.fadeIn(duration: AnimationTiming.welcomeFadeInDuration)

        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.logoFadeInDelay) { [weak self] in
            guard let self else { return }
            self.soundPlayer?.play()
            self.activeLogoView()?.fadeIn(duration: AnimationTiming.logoFadeInDuration)
            self.themesCollectionView.alpha = Appearance.visibleAlpha

            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.controlsFadeInDelay) { [weak self] in
                guard let self else { return }
                self.chooseThemeLabel.fadeIn(duration: AnimationTiming.controlsFadeInDuration)
                self.settingsButton.fadeIn(duration: AnimationTiming.controlsFadeInDuration)
                self.animateThemeCells(visibleCells)
            }
        }
    }

    private func activeLogoView() -> UIView? {
        quiziceLabel.isHidden ? quiziceTextLabel : quiziceLabel
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
        chooseThemeLabel.text = hasThemes ? L10n.Home.chooseTheme : L10n.Home.unavailableThemes
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
        welcomeLabel.text = L10n.Home.welcome
        settingsButton.accessibilityLabel = L10n.Settings.title
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        updateThemeAvailabilityMessage()
        themesCollectionView.reloadData()
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
