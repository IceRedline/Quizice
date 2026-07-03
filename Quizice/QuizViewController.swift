import UIKit
import AVKit
#if DEBUG
import SwiftUI
#endif

final class QuizViewController: UIViewController, QuizViewControllerProtocol, ThemeCollectionDelegate {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
        static let logoImageName = "Quizice"
        static let startupSoundName = "Quizice Enter"
        static let startupSoundExtension = "m4a"
        static let themeCellReuseIdentifier = "themeCell"

        static let logoAccessibilityLabel = "Quizice"
    }

    private enum AccessibilityID {
        static let rootView = "homeRootView"
        static let welcomeLabel = "homeWelcomeLabel"
        static let logoImageView = "homeLogoImageView"
        static let chooseThemeLabel = "homeChooseThemeLabel"
        static let headerStackView = "homeHeaderStackView"
        static let themesCollectionView = "homeThemesCollectionView"
        static let screenStackView = "homeScreenStackView"
        static let actionButtonsStackView = "homeActionButtonsStackView"
        static let exitButton = "homeExitButton"
    }

    private enum Layout {
        static let headerStackSpacing: CGFloat = 0
        static let headerHorizontalInset: CGFloat = 24
        static let screenTopInset: CGFloat = 28
        static let screenBottomInset: CGFloat = 24
        static let screenStackSpacing: CGFloat = 0
        static let headerToCollectionSpacing: CGFloat = 18
        static let collectionToActionsSpacing: CGFloat = 24
        static let actionHorizontalInset: CGFloat = 32
        static let collectionItemSpacing: CGFloat = 16
        static let collectionHorizontalInset: CGFloat = 24
        static let collectionTopInset: CGFloat = 0
        static let collectionBottomInset: CGFloat = 24
        static let logoWidthMultiplier: CGFloat = 0.7
        static let logoHeight: CGFloat = 84
        static let visibleCellRowSortingTolerance: CGFloat = 1
        static let secondaryActionButtonHeight: CGFloat = 50

        static var headerMargins: NSDirectionalEdgeInsets {
            NSDirectionalEdgeInsets(
                top: .zero,
                leading: headerHorizontalInset,
                bottom: .zero,
                trailing: headerHorizontalInset
            )
        }

        static var actionButtonMargins: NSDirectionalEdgeInsets {
            NSDirectionalEdgeInsets(
                top: .zero,
                leading: actionHorizontalInset,
                bottom: .zero,
                trailing: actionHorizontalInset
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
        static let actionButtonFontSize: CGFloat = 19
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

    private enum ProcessExit {
        static let userConfirmedExitCode: Int32 = -1
    }

    private var welcomeLabel: UILabel!
    private var quiziceLabel: UIImageView!
    private var chooseThemeLabel: UILabel!
    private var headerStackView: UIStackView!
    private var screenStackView: UIStackView!

    private var exitButton: UIButton!
    private var actionButtonsStackView: UIStackView!

    private var themesCollectionView: UICollectionView!

    private let animationsEngine = Animations()
    private var soundPlayer: AVAudioPlayer!

    private let themesCollectionService = ThemesCollectionService()
    var presenter: QuizPresenterProtocol?

    private var startupAnimatedViews: [UIView] {
        [welcomeLabel, quiziceLabel, themesCollectionView, chooseThemeLabel, actionButtonsStackView]
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
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if QuizFactory.shared.startup1st {
            QuizFactory.shared.loadData()
        }

        configurePresenter(QuizPresenter())

        configureThemesCollectionService()
        updateThemeAvailabilityMessage()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if QuizFactory.shared.startup1st {
            animateViewsAndPlaySound()
            QuizFactory.shared.startup1st = false
        }
    }

    func configurePresenter(_ presenter: any QuizPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }

    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureHeaderViews()
        configureActionButtons()
        configureHeaderStack()
        configureActionButtonsStack()
        configureThemesCollectionView()
        configureScreenStack()

        rootView.addSubview(screenStackView)
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
        welcomeLabel = makeLabel(text: L10n.Home.welcome, font: .systemFont(ofSize: Typography.welcomeFontSize, weight: .semibold))
        welcomeLabel.accessibilityIdentifier = AccessibilityID.welcomeLabel
        welcomeLabel.adjustsFontForContentSizeCategory = true

        quiziceLabel = UIImageView(image: UIImage(named: Content.logoImageName))
        quiziceLabel.accessibilityIdentifier = AccessibilityID.logoImageView
        quiziceLabel.accessibilityLabel = Content.logoAccessibilityLabel
        quiziceLabel.contentMode = .scaleAspectFit
        quiziceLabel.translatesAutoresizingMaskIntoConstraints = false

        chooseThemeLabel = makeLabel(text: L10n.Home.chooseTheme, font: .systemFont(ofSize: Typography.chooseThemeFontSize, weight: .semibold))
        chooseThemeLabel.accessibilityIdentifier = AccessibilityID.chooseThemeLabel
        chooseThemeLabel.adjustsFontForContentSizeCategory = true
    }

    private func configureHeaderStack() {
        headerStackView = UIStackView(arrangedSubviews: [welcomeLabel, quiziceLabel, chooseThemeLabel])
        headerStackView.accessibilityIdentifier = AccessibilityID.headerStackView
        headerStackView.axis = .vertical
        headerStackView.alignment = .center
        headerStackView.spacing = Layout.headerStackSpacing
        headerStackView.isLayoutMarginsRelativeArrangement = true
        headerStackView.directionalLayoutMargins = Layout.headerMargins
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureActionButtons() {
        exitButton = makePrimaryActionButton(title: L10n.Common.exit)
        exitButton.accessibilityIdentifier = AccessibilityID.exitButton
        exitButton.accessibilityLabel = L10n.Common.exit
        exitButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }

    private func configureActionButtonsStack() {
        actionButtonsStackView = UIStackView(arrangedSubviews: [exitButton])
        actionButtonsStackView.accessibilityIdentifier = AccessibilityID.actionButtonsStackView
        actionButtonsStackView.axis = .vertical
        actionButtonsStackView.alignment = .fill
        actionButtonsStackView.distribution = .fill
        actionButtonsStackView.isLayoutMarginsRelativeArrangement = true
        actionButtonsStackView.directionalLayoutMargins = Layout.actionButtonMargins
        actionButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
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
        themesCollectionView.alwaysBounceVertical = true
        themesCollectionView.showsVerticalScrollIndicator = false
        themesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        themesCollectionView.setContentHuggingPriority(.defaultLow, for: .vertical)
        themesCollectionView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    private func configureScreenStack() {
        screenStackView = UIStackView(arrangedSubviews: [headerStackView, themesCollectionView, actionButtonsStackView])
        screenStackView.accessibilityIdentifier = AccessibilityID.screenStackView
        screenStackView.axis = .vertical
        screenStackView.alignment = .fill
        screenStackView.spacing = Layout.screenStackSpacing
        screenStackView.isLayoutMarginsRelativeArrangement = true
        screenStackView.directionalLayoutMargins = Layout.screenMargins
        screenStackView.setCustomSpacing(Layout.headerToCollectionSpacing, after: headerStackView)
        screenStackView.setCustomSpacing(Layout.collectionToActionsSpacing, after: themesCollectionView)
        screenStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            screenStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            screenStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            screenStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            screenStackView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor),

            welcomeLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStackView.layoutMarginsGuide.widthAnchor),
            quiziceLabel.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, multiplier: Layout.logoWidthMultiplier),
            quiziceLabel.heightAnchor.constraint(equalToConstant: Layout.logoHeight),
            chooseThemeLabel.widthAnchor.constraint(lessThanOrEqualTo: headerStackView.layoutMarginsGuide.widthAnchor),

            exitButton.heightAnchor.constraint(equalToConstant: Layout.secondaryActionButtonHeight)
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

    private func makePrimaryActionButton(title: String) -> UIButton {
        let button = makeBaseActionButton(title: title)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(Appearance.primaryButtonBackgroundAlpha)
        button.layer.cornerRadius = Appearance.primaryButtonCornerRadius
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = Appearance.primaryButtonShadowOpacity
        button.layer.shadowRadius = Appearance.primaryButtonShadowRadius
        button.layer.shadowOffset = Appearance.primaryButtonShadowOffset
        return button
    }

    private func makeBaseActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: Typography.actionButtonFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    private func animateViewsAndPlaySound() {
        let visibleCells = sortedVisibleThemeCells()
        prepareStartupAnimation(visibleCells: visibleCells)
        loadStartupSound()

        welcomeLabel.fadeIn(duration: AnimationTiming.welcomeFadeInDuration)

        DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.logoFadeInDelay) { [weak self] in
            guard let self else { return }
            self.soundPlayer?.play()
            self.quiziceLabel.fadeIn(duration: AnimationTiming.logoFadeInDuration)
            self.themesCollectionView.alpha = Appearance.visibleAlpha

            DispatchQueue.main.asyncAfter(deadline: .now() + AnimationTiming.controlsFadeInDelay) { [weak self] in
                guard let self else { return }
                self.chooseThemeLabel.fadeIn(duration: AnimationTiming.controlsFadeInDuration)
                self.actionButtonsStackView.fadeIn(duration: AnimationTiming.controlsFadeInDuration)
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

    func themeButtonTouchedUpInside(_ sender: UIButton, themeName: String) {
        animationsEngine.animateUpFloat(sender)
        guard QuizFactory.shared.loadTheme(themeName: themeName) else {
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

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        let viewController = StatisticsViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func showDescriptionViewController() {
        let viewController = QuizDescriptionViewController()
        presenter?.configureDescriptionPresenter(viewController: viewController)
        navigationController?.pushViewController(viewController, animated: true)
    }

    private func updateThemeAvailabilityMessage() {
        let hasThemes = QuizFactory.shared.themes?.isEmpty == false
        chooseThemeLabel.text = hasThemes ? L10n.Home.chooseTheme : L10n.Home.unavailableThemes
    }

    private func startRandomTheme() {
        guard
            let theme = QuizFactory.shared.themes?.randomElement()?.theme,
            QuizFactory.shared.loadTheme(themeName: theme)
        else {
            updateThemeAvailabilityMessage()
            return
        }
        showDescriptionViewController()
    }

    @objc private func backButtonTapped() {
        let alert = UIAlertController(
            title: L10n.Common.exit,
            message: L10n.Home.exitAlertMessage,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: L10n.Common.no, style: .cancel))
        alert.addAction(UIAlertAction(title: L10n.Common.yes, style: .destructive, handler: { _ in
            exit(ProcessExit.userConfirmedExitCode)
        }))
        present(alert, animated: true)
    }
}

#if DEBUG
#Preview("Quiz") {
    QuizFactory.shared.startup1st = false
    QuizFactory.shared.themes = [
        QuizTheme(theme: "Музыка", themeDescription: "Вопросы о треках, артистах и музыкальных эпохах.", questions: []),
        QuizTheme(theme: "Технологии", themeDescription: "Гаджеты, IT-компании и цифровая культура.", questions: []),
        QuizTheme(theme: "История и культура", themeDescription: "Исторические события, искусство и традиции.", questions: []),
        QuizTheme(theme: "Политика и бизнес", themeDescription: "Лидеры, компании и громкие решения.", questions: [])
    ]

    let viewController = QuizViewController()
    let navigationController = UINavigationController(rootViewController: viewController)
    navigationController.setNavigationBarHidden(true, animated: false)
    return navigationController
}
#endif
