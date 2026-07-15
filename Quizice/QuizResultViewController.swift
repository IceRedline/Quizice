import UIKit
#if DEBUG
import SwiftUI
#endif

final class QuizResultViewController: BaseQuizViewController, QuizResultViewControllerProtocol, QuizCardSlideTransitionDestination {
    private enum AccessibilityID {
        static let rootView = "resultRootView"
        static let cardView = "resultCardView"
        static let scoreLabel = "resultScoreLabel"
        static let descriptionLabel = "resultDescriptionLabel"
        static let replayButton = "resultReplayButton"
        static let themesButton = "resultThemesButton"
        static let contentStackView = "resultContentStackView"
        static let scrollView = "resultScrollView"
    }
    
    private enum Layout {
        static let contentStackSpacing: CGFloat = 22
        static let resultLabelBottomSpacing: CGFloat = 26
        static let descriptionBottomSpacing: CGFloat = 38
        static let cardHorizontalInset: CGFloat = 20
        static let cardVerticalMinimumInset: CGFloat = 48
        static let contentTopInset: CGFloat = 34
        static let contentHorizontalInset: CGFloat = 24
        static let contentBottomInset: CGFloat = 30
        static let actionButtonHeight: CGFloat = 56
        static let maximumContentWidth: CGFloat = 430
        static let actionButtonSpacing: CGFloat = 12
    }
    
    private enum Typography {
        static let resultFontSize: CGFloat = 38
        static let descriptionFontSize: CGFloat = 21
        static let buttonFontSize: CGFloat = 20
        static let unlimitedNumberOfLines = 0
        static let resultMinimumScaleFactor: CGFloat = 0.82
    }
    
    private enum Appearance {
        static let cardBackgroundAlpha: CGFloat = 0.26
        static let cardCornerRadius: CGFloat = 30
        static let cardBorderWidth: CGFloat = 1
        static let cardBorderAlpha: CGFloat = 0.18
        static let cardShadowOpacity: Float = 0.22
        static let cardShadowRadius: CGFloat = 16
        static let cardShadowOffset = CGSize(width: 0, height: 10)
        
        static let descriptionTextAlpha: CGFloat = 0.9
        static let disabledButtonTitleAlpha: CGFloat = 0.45
        static let buttonBackgroundAlpha: CGFloat = 0.22
        static let buttonCornerRadius: CGFloat = 22
        static let buttonBorderWidth: CGFloat = 1
        static let buttonBorderAlpha: CGFloat = 0.5
        static let buttonShadowOpacity: Float = 0.2
        static let buttonShadowRadius: CGFloat = 10
        static let buttonShadowOffset = CGSize(width: 0, height: 6)
    }

    private var scrollView: UIScrollView!
    private var resultCardView: UIView!
    private var contentStackView: UIStackView!
    private var resultLabel: UILabel!
    private var resultDescription: UILabel!
    
    private var replayButton: UIButton!
    private var themesButton: UIButton!
    weak var router: QuizRouting?
    var analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared
    
    var presenter: QuizResultPresenterProtocol?

    var cardSlideTransitionDestinationView: UIView { resultCardView }
    var cardSlideTransitionHorizontalInset: CGFloat { Layout.cardHorizontalInset }
    
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
        presenter?.viewDidLoad()
        installLocalizationObserver()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        analytics.track(.screenView(screen: .quizResult, theme: presenter?.analyticsTheme ?? .unknown))
    }

    func configurePresenter(_ presenter: QuizResultPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
        applyAppearance()
    }
    
    func updateResultLabels(resultText: String, descriptionText: String) {
        resultLabel.text = resultText
        resultDescription.text = descriptionText
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureResultCardView()
        configureLabels()
        configureActionButtons()
        configureContentStackView()
        addSubviews(to: rootView)
        activateLayoutConstraints(in: rootView)
    }
    
    private func configureResultCardView() {
        resultCardView = UIView()
        resultCardView.accessibilityIdentifier = AccessibilityID.cardView
        resultCardView.backgroundColor = UIColor.black.withAlphaComponent(Appearance.cardBackgroundAlpha)
        resultCardView.layer.cornerRadius = Appearance.cardCornerRadius
        resultCardView.layer.borderWidth = Appearance.cardBorderWidth
        resultCardView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.cardBorderAlpha).cgColor
        resultCardView.layer.shadowColor = UIColor.black.cgColor
        resultCardView.layer.shadowOpacity = Appearance.cardShadowOpacity
        resultCardView.layer.shadowRadius = Appearance.cardShadowRadius
        resultCardView.layer.shadowOffset = Appearance.cardShadowOffset
        resultCardView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureLabels() {
        let typography = currentAppearance().typography
        resultLabel = makeLabel(font: typography.font(size: Typography.resultFontSize, weight: .bold), accessibilityIdentifier: AccessibilityID.scoreLabel)
        resultLabel.numberOfLines = Typography.unlimitedNumberOfLines
        
        resultDescription = makeLabel(font: typography.font(size: Typography.descriptionFontSize, weight: .regular), accessibilityIdentifier: AccessibilityID.descriptionLabel)
        resultDescription.numberOfLines = Typography.unlimitedNumberOfLines
        resultDescription.textColor = UIColor.white.withAlphaComponent(Appearance.descriptionTextAlpha)
    }
    
    private func configureActionButtons() {
        replayButton = makeActionButton(
            title: L10n.Result.playAgain,
            accessibilityIdentifier: AccessibilityID.replayButton
        )
        replayButton.addTarget(self, action: #selector(replayButtonTapped), for: .touchUpInside)

        themesButton = makeActionButton(
            title: L10n.Result.toThemes,
            accessibilityIdentifier: AccessibilityID.themesButton
        )
        themesButton.addTarget(self, action: #selector(themesButtonTapped), for: .touchUpInside)
    }
    
    private func configureContentStackView() {
        let actionsStackView = UIStackView(arrangedSubviews: [replayButton, themesButton])
        actionsStackView.axis = .vertical
        actionsStackView.spacing = Layout.actionButtonSpacing

        contentStackView = UIStackView(arrangedSubviews: [resultLabel, resultDescription, actionsStackView])
        contentStackView.accessibilityIdentifier = AccessibilityID.contentStackView
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = Layout.contentStackSpacing
        contentStackView.setCustomSpacing(Layout.resultLabelBottomSpacing, after: resultLabel)
        contentStackView.setCustomSpacing(Layout.descriptionBottomSpacing, after: resultDescription)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func addSubviews(to rootView: UIView) {
        scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = AccessibilityID.scrollView
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(scrollView)
        scrollView.addSubview(resultCardView)
        resultCardView.addSubview(contentStackView)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollView.contentLayoutGuide.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),

            resultCardView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            resultCardView.centerYAnchor.constraint(equalTo: scrollView.contentLayoutGuide.centerYAnchor),
            resultCardView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Layout.cardHorizontalInset),
            resultCardView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Layout.cardHorizontalInset),
            resultCardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            resultCardView.topAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.cardVerticalMinimumInset),
            resultCardView.bottomAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.cardVerticalMinimumInset),
            
            contentStackView.topAnchor.constraint(equalTo: resultCardView.topAnchor, constant: Layout.contentTopInset),
            contentStackView.leadingAnchor.constraint(equalTo: resultCardView.leadingAnchor, constant: Layout.contentHorizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: resultCardView.trailingAnchor, constant: -Layout.contentHorizontalInset),
            contentStackView.bottomAnchor.constraint(equalTo: resultCardView.bottomAnchor, constant: -Layout.contentBottomInset),
            
            replayButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.actionButtonHeight),
            themesButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.actionButtonHeight)
        ])

        let cardWidthConstraint = resultCardView.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor,
            constant: -(Layout.cardHorizontalInset * 2)
        )
        cardWidthConstraint.priority = .defaultHigh
        cardWidthConstraint.isActive = true
    }
    
    private func makeLabel(font: UIFont, accessibilityIdentifier: String) -> UILabel {
        let label = UILabel()
        label.accessibilityIdentifier = accessibilityIdentifier
        label.textColor = .white
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makeActionButton(title: String, accessibilityIdentifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(Appearance.disabledButtonTitleAlpha), for: .disabled)
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.buttonFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIColor.white.withAlphaComponent(Appearance.buttonBackgroundAlpha)
        button.layer.cornerRadius = Appearance.buttonCornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.buttonBorderAlpha).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = Appearance.buttonShadowOpacity
        button.layer.shadowRadius = Appearance.buttonShadowRadius
        button.layer.shadowOffset = Appearance.buttonShadowOffset
        button.translatesAutoresizingMaskIntoConstraints = false
        button.installPressFeedback()
        return button
    }

    override func applyAppearance() {
        guard isViewLoaded else { return }
        let appearance = currentAppearance()
        appearance.applyBackground(to: view)
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        resultCardView?.applySurfaceStyle(appearance.card)
        resultLabel?.textColor = appearance.surfaceTextColor
        resultLabel?.font = appearance.typography.font(size: Typography.resultFontSize, weight: .bold)
        resultDescription?.textColor = appearance.secondarySurfaceTextColor
        resultDescription?.font = appearance.typography.font(size: Typography.descriptionFontSize, weight: .regular)
        replayButton?.applyActionAppearance(
            QuizThemeAccentStyle.primaryButtonStyle(themeID: presenter?.themeID, appearance: appearance),
            appearance: appearance,
            textColor: actionTextColor(appearance: appearance)
        )
        replayButton?.titleLabel?.font = appearance.typography.font(size: Typography.buttonFontSize, weight: .semibold)
        themesButton?.applyActionAppearance(
            QuizThemeAccentStyle.secondaryButtonStyle(themeID: presenter?.themeID, appearance: appearance),
            appearance: appearance,
            textColor: QuizThemeAccentStyle.secondaryButtonTextColor(themeID: presenter?.themeID, appearance: appearance)
        )
        themesButton?.titleLabel?.font = appearance.typography.font(size: Typography.buttonFontSize, weight: .semibold)
    }

    private func actionTextColor(appearance: AppAppearance) -> UIColor {
        if appearance.designStyle == .clean {
            return appearance.resolvedInterfaceStyle == .dark ? appearance.screenTextColor : .black
        }
        return appearance.screenTextColor
    }

    @objc private func replayButtonTapped() {
        analytics.track(.quizResultAction(theme: presenter?.analyticsTheme ?? .unknown, action: .replay))
        router?.replayQuiz()
    }

    @objc private func themesButtonTapped() {
        analytics.track(.quizResultAction(theme: presenter?.analyticsTheme ?? .unknown, action: .themes))
        router?.returnToThemes()
    }

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        replayButton.setTitle(L10n.Result.playAgain, for: .normal)
        themesButton.setTitle(L10n.Result.toThemes, for: .normal)
        presenter?.viewDidLoad()
    }
}

#if DEBUG
#Preview("Result") {
    let viewController = QuizResultViewController()
    viewController.loadViewIfNeeded()
    viewController.updateResultLabels(
        resultText: "Твой результат:\n 8/10",
        descriptionText: "Ещё чуть-чуть и был бы как сам создатель квиза, молодец!"
    )
    return viewController
}
#endif
