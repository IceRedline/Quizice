import UIKit
#if DEBUG
import SwiftUI
#endif

final class QuizResultViewController: BaseQuizViewController, QuizResultViewControllerProtocol, QuizCardSlideTransitionDestination {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
    }
    
    private enum AccessibilityID {
        static let rootView = "resultRootView"
        static let cardView = "resultCardView"
        static let scoreLabel = "resultScoreLabel"
        static let descriptionLabel = "resultDescriptionLabel"
        static let restartButton = "resultRestartButton"
        static let contentStackView = "resultContentStackView"
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
        static let restartButtonHeight: CGFloat = 56
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

    private var resultCardView: UIView!
    private var contentStackView: UIStackView!
    private var resultLabel: UILabel!
    private var resultDescription: UILabel!
    
    private var restartButton: UIButton!
    weak var router: QuizRouting?
    
    var presenter: QuizResultPresenterProtocol?

    var cardSlideTransitionDestinationView: UIView { resultCardView }
    var cardSlideTransitionHorizontalInset: CGFloat { Layout.cardHorizontalInset }
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: Content.backgroundImageName) ?? UIImage())
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

    func configurePresenter(_ presenter: QuizResultPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    func updateResultLabels(resultText: String, descriptionText: String) {
        resultLabel.text = resultText
        resultDescription.text = descriptionText
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureResultCardView()
        configureLabels()
        configureRestartButton()
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
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = Typography.resultMinimumScaleFactor
        
        resultDescription = makeLabel(font: typography.font(size: Typography.descriptionFontSize, weight: .regular), accessibilityIdentifier: AccessibilityID.descriptionLabel)
        resultDescription.numberOfLines = Typography.unlimitedNumberOfLines
        resultDescription.textColor = UIColor.white.withAlphaComponent(Appearance.descriptionTextAlpha)
    }
    
    private func configureRestartButton() {
        restartButton = makeActionButton(title: L10n.Result.restart, accessibilityIdentifier: AccessibilityID.restartButton)
        restartButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    private func configureContentStackView() {
        contentStackView = UIStackView(arrangedSubviews: [resultLabel, resultDescription, restartButton])
        contentStackView.accessibilityIdentifier = AccessibilityID.contentStackView
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = Layout.contentStackSpacing
        contentStackView.setCustomSpacing(Layout.resultLabelBottomSpacing, after: resultLabel)
        contentStackView.setCustomSpacing(Layout.descriptionBottomSpacing, after: resultDescription)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func addSubviews(to rootView: UIView) {
        rootView.addSubview(resultCardView)
        resultCardView.addSubview(contentStackView)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            resultCardView.centerYAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.centerYAnchor),
            resultCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.cardHorizontalInset),
            resultCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.cardHorizontalInset),
            resultCardView.topAnchor.constraint(greaterThanOrEqualTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.cardVerticalMinimumInset),
            resultCardView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.cardVerticalMinimumInset),
            
            contentStackView.topAnchor.constraint(equalTo: resultCardView.topAnchor, constant: Layout.contentTopInset),
            contentStackView.leadingAnchor.constraint(equalTo: resultCardView.leadingAnchor, constant: Layout.contentHorizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: resultCardView.trailingAnchor, constant: -Layout.contentHorizontalInset),
            contentStackView.bottomAnchor.constraint(equalTo: resultCardView.bottomAnchor, constant: -Layout.contentBottomInset),
            
            restartButton.heightAnchor.constraint(equalToConstant: Layout.restartButtonHeight)
        ])
    }
    
    private func makeLabel(font: UIFont, accessibilityIdentifier: String) -> UILabel {
        let label = UILabel()
        label.accessibilityIdentifier = accessibilityIdentifier
        label.textColor = .white
        label.font = font
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
        restartButton?.applyActionAppearance(appearance.primaryButton, appearance: appearance, textColor: actionTextColor(appearance: appearance))
        restartButton?.titleLabel?.font = appearance.typography.font(size: Typography.buttonFontSize, weight: .semibold)
    }

    private func actionTextColor(appearance: AppAppearance) -> UIColor {
        if appearance.designStyle == .clean {
            return appearance.resolvedInterfaceStyle == .dark ? appearance.screenTextColor : .black
        }
        if appearance.designStyle == .pixel {
            return .black
        }
        return appearance.screenTextColor
    }

    @IBAction func backButtonTapped() {
        router?.restartQuiz()
    }

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        restartButton.setTitle(L10n.Result.restart, for: .normal)
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
