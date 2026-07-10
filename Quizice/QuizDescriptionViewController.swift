import UIKit
#if DEBUG
import SwiftUI
#endif

final class QuizDescriptionViewController: BaseQuizViewController, QuizDescriptionViewControllerProtocol, QuizCardSlideTransitionSource {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
    }
    
    private enum AccessibilityID {
        static let rootView = "descriptionRootView"
        static let contentCardView = "descriptionContentCardView"
        static let themeNameLabel = "descriptionThemeNameLabel"
        static let textLabel = "descriptionTextLabel"
        static let pickerCaptionLabel = "descriptionPickerCaptionLabel"
        static let questionCountPicker = "descriptionQuestionCountPicker"
        static let startButton = "descriptionStartButton"
        static let backButton = "descriptionBackButton"
        static let contentStackView = "descriptionContentStackView"
        static let scrollView = "descriptionScrollView"
    }
    
    private enum Layout {
        static let contentStackSpacing: CGFloat = 18
        static let themeNameBottomSpacing: CGFloat = 24
        static let descriptionBottomSpacing: CGFloat = 26
        static let pickerCaptionBottomSpacing: CGFloat = 8
        
        static let cardTopInset: CGFloat = 72
        static let cardHorizontalInset: CGFloat = 20
        static let contentTopInset: CGFloat = 28
        static let contentHorizontalInset: CGFloat = 22
        static let contentBottomInset: CGFloat = 26
        static let pickerHeight: CGFloat = 136
        static let primaryButtonHeight: CGFloat = 54
        static let actionTopSpacing: CGFloat = 22
        static let cardBottomInset: CGFloat = 18
        static let actionButtonWidth: CGFloat = 238
        static let bottomMaximumInset: CGFloat = 22
        static let backButtonSize: CGFloat = 44
        static let backButtonTopInset: CGFloat = 16
        static let backButtonLeadingInset: CGFloat = 20
        static let maximumContentWidth: CGFloat = 430
    }
    
    private enum Typography {
        static let themeNameFontSize: CGFloat = 34
        static let descriptionFontSize: CGFloat = 19
        static let pickerCaptionFontSize: CGFloat = 17
        static let buttonFontSize: CGFloat = 20
        static let unlimitedNumberOfLines = 0
        static let themeNameMinimumScaleFactor: CGFloat = 0.82
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
        static let pickerCaptionTextAlpha: CGFloat = 0.82
        static let pickerBackgroundAlpha: CGFloat = 0.08
        static let pickerCornerRadius: CGFloat = 22
        static let pickerBorderWidth: CGFloat = 1
        static let pickerBorderAlpha: CGFloat = 0.16
        
        static let disabledButtonTitleAlpha: CGFloat = 0.45
        static let primaryButtonBackgroundAlpha: CGFloat = 0.22
        static let secondaryButtonBackgroundAlpha: CGFloat = 0.12
        static let primaryButtonCornerRadius: CGFloat = 22
        static let secondaryButtonCornerRadius: CGFloat = 20
        static let buttonBorderWidth: CGFloat = 1
        static let primaryButtonBorderAlpha: CGFloat = 0.5
        static let secondaryButtonBorderAlpha: CGFloat = 0.34
        static let primaryButtonShadowOpacity: Float = 0.2
        static let secondaryButtonShadowOpacity: Float = 0
        static let buttonShadowRadius: CGFloat = 10
        static let buttonShadowOffset = CGSize(width: 0, height: 6)
    }
    
    private enum ActionButtonStyle {
        case primary
        case secondary
        
        var backgroundAlpha: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonBackgroundAlpha
            case .secondary:
                return Appearance.secondaryButtonBackgroundAlpha
            }
        }
        
        var cornerRadius: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonCornerRadius
            case .secondary:
                return Appearance.secondaryButtonCornerRadius
            }
        }
        
        var borderAlpha: CGFloat {
            switch self {
            case .primary:
                return Appearance.primaryButtonBorderAlpha
            case .secondary:
                return Appearance.secondaryButtonBorderAlpha
            }
        }
        
        var shadowOpacity: Float {
            switch self {
            case .primary:
                return Appearance.primaryButtonShadowOpacity
            case .secondary:
                return Appearance.secondaryButtonShadowOpacity
            }
        }
    }
    
    private var contentCardView: UIView!
    private var scrollView: UIScrollView!
    private var contentStackView: UIStackView!
    private var themeNameLabel: UILabel!
    private var themeDescriptionLabel: UILabel!
    private var pickerCaptionLabel: UILabel!
    private var numberOfQuestionsPickerView: UIPickerView!
    
    private var startButton: UIButton!
    private var backButton: UIButton!
    weak var router: QuizRouting?
    
    var presenter: QuizDescriptionPresenterProtocol?

    var cardSlideTransitionSourceView: UIView { contentCardView }
    var cardSlideTransitionHorizontalInset: CGFloat { Layout.cardHorizontalInset }

    private var descriptionActionViews: [UIView] {
        let views: [UIView?] = [startButton, backButton]
        return views.compactMap { $0 }
    }
    
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
        numberOfQuestionsPickerView.delegate = self
        numberOfQuestionsPickerView.dataSource = self
        presenter?.viewDidLoad()
        installLocalizationObserver()
    }

    func updateLabels(themeName: String, themeDescription: String) {
        themeNameLabel.text = themeName
        themeDescriptionLabel.text = themeDescription
    }
    
    func configurePresenter(_ presenter: QuizDescriptionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
        applyAppearance()
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        configureContentCardView()
        configureLabels()
        configurePickerView()
        configureButtons()
        configureContentStackView()
        addSubviews(to: rootView)
        activateLayoutConstraints(in: rootView)
    }
    
    private func configureContentCardView() {
        contentCardView = UIView()
        contentCardView.accessibilityIdentifier = AccessibilityID.contentCardView
        contentCardView.backgroundColor = UIColor.black.withAlphaComponent(Appearance.cardBackgroundAlpha)
        contentCardView.layer.cornerRadius = Appearance.cardCornerRadius
        contentCardView.layer.borderWidth = Appearance.cardBorderWidth
        contentCardView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.cardBorderAlpha).cgColor
        contentCardView.layer.shadowColor = UIColor.black.cgColor
        contentCardView.layer.shadowOpacity = Appearance.cardShadowOpacity
        contentCardView.layer.shadowRadius = Appearance.cardShadowRadius
        contentCardView.layer.shadowOffset = Appearance.cardShadowOffset
        contentCardView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureLabels() {
        let typography = currentAppearance().typography
        themeNameLabel = makeLabel(font: typography.font(size: Typography.themeNameFontSize, weight: .bold), accessibilityIdentifier: AccessibilityID.themeNameLabel)
        themeNameLabel.numberOfLines = Typography.unlimitedNumberOfLines
        
        themeDescriptionLabel = makeLabel(font: typography.font(size: Typography.descriptionFontSize, weight: .regular), accessibilityIdentifier: AccessibilityID.textLabel)
        themeDescriptionLabel.numberOfLines = Typography.unlimitedNumberOfLines
        themeDescriptionLabel.textColor = UIColor.white.withAlphaComponent(Appearance.descriptionTextAlpha)
        
        pickerCaptionLabel = makeLabel(font: typography.font(size: Typography.pickerCaptionFontSize, weight: .semibold), accessibilityIdentifier: AccessibilityID.pickerCaptionLabel)
        pickerCaptionLabel.text = L10n.Description.questionCount
        pickerCaptionLabel.textColor = UIColor.white.withAlphaComponent(Appearance.pickerCaptionTextAlpha)
    }
    
    private func configurePickerView() {
        numberOfQuestionsPickerView = UIPickerView()
        numberOfQuestionsPickerView.accessibilityIdentifier = AccessibilityID.questionCountPicker
        numberOfQuestionsPickerView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.pickerBackgroundAlpha)
        numberOfQuestionsPickerView.layer.cornerRadius = Appearance.pickerCornerRadius
        numberOfQuestionsPickerView.layer.borderWidth = Appearance.pickerBorderWidth
        numberOfQuestionsPickerView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.pickerBorderAlpha).cgColor
        numberOfQuestionsPickerView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func configureButtons() {
        startButton = makeActionButton(title: L10n.Common.start, accessibilityIdentifier: AccessibilityID.startButton, style: .primary)
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)

        backButton = UIButton(type: .system)
        backButton.accessibilityIdentifier = AccessibilityID.backButton
        backButton.accessibilityLabel = L10n.Common.back
        backButton.setImage(
            UIImage(
                systemName: "chevron.left",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)
            ),
            for: .normal
        )
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        backButton.installPressFeedback()
    }
    
    private func configureContentStackView() {
        contentStackView = UIStackView(arrangedSubviews: [
            themeNameLabel,
            themeDescriptionLabel,
            pickerCaptionLabel,
            numberOfQuestionsPickerView
        ])
        contentStackView.accessibilityIdentifier = AccessibilityID.contentStackView
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = Layout.contentStackSpacing
        contentStackView.setCustomSpacing(Layout.themeNameBottomSpacing, after: themeNameLabel)
        contentStackView.setCustomSpacing(Layout.descriptionBottomSpacing, after: themeDescriptionLabel)
        contentStackView.setCustomSpacing(Layout.pickerCaptionBottomSpacing, after: pickerCaptionLabel)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func addSubviews(to rootView: UIView) {
        scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = AccessibilityID.scrollView
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        rootView.addSubview(scrollView)
        rootView.addSubview(backButton)
        rootView.addSubview(startButton)
        scrollView.addSubview(contentCardView)
        contentCardView.addSubview(contentStackView)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: startButton.topAnchor, constant: -Layout.actionTopSpacing),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            backButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.backButtonTopInset),
            backButton.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.backButtonLeadingInset),
            backButton.widthAnchor.constraint(equalToConstant: Layout.backButtonSize),
            backButton.heightAnchor.constraint(equalToConstant: Layout.backButtonSize),

            contentCardView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: Layout.cardTopInset),
            contentCardView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            contentCardView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Layout.cardHorizontalInset),
            contentCardView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Layout.cardHorizontalInset),
            contentCardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            contentCardView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.cardBottomInset),
            
            contentStackView.topAnchor.constraint(equalTo: contentCardView.topAnchor, constant: Layout.contentTopInset),
            contentStackView.leadingAnchor.constraint(equalTo: contentCardView.leadingAnchor, constant: Layout.contentHorizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: contentCardView.trailingAnchor, constant: -Layout.contentHorizontalInset),
            contentStackView.bottomAnchor.constraint(equalTo: contentCardView.bottomAnchor, constant: -Layout.contentBottomInset),
            
            numberOfQuestionsPickerView.heightAnchor.constraint(equalToConstant: Layout.pickerHeight),

            startButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: Layout.actionButtonWidth),
            startButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.primaryButtonHeight),
            startButton.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.bottomMaximumInset)
        ])

        let cardWidthConstraint = contentCardView.widthAnchor.constraint(
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
    
    private func makeActionButton(title: String, accessibilityIdentifier: String, style: ActionButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(Appearance.disabledButtonTitleAlpha), for: .disabled)
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.buttonFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIColor.white.withAlphaComponent(style.backgroundAlpha)
        button.layer.cornerRadius = style.cornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(style.borderAlpha).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = style.shadowOpacity
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

        contentCardView?.applySurfaceStyle(appearance.card)
        themeNameLabel?.textColor = appearance.surfaceTextColor
        themeNameLabel?.font = appearance.typography.font(size: Typography.themeNameFontSize, weight: .bold)
        themeDescriptionLabel?.textColor = appearance.secondarySurfaceTextColor
        themeDescriptionLabel?.font = appearance.typography.font(size: Typography.descriptionFontSize, weight: .regular)
        pickerCaptionLabel?.textColor = appearance.secondarySurfaceTextColor
        pickerCaptionLabel?.font = appearance.typography.font(size: Typography.pickerCaptionFontSize, weight: .semibold)

        numberOfQuestionsPickerView?.backgroundColor = appearance.row.backgroundColor
        numberOfQuestionsPickerView?.layer.cornerRadius = appearance.row.cornerRadius
        numberOfQuestionsPickerView?.layer.borderWidth = appearance.row.borderWidth
        numberOfQuestionsPickerView?.layer.borderColor = appearance.row.borderColor.cgColor
        numberOfQuestionsPickerView?.reloadAllComponents()

        startButton?.applyActionAppearance(
            QuizThemeAccentStyle.primaryButtonStyle(themeID: presenter?.themeID, appearance: appearance),
            appearance: appearance,
            textColor: actionTextColor(for: .primary, appearance: appearance)
        )
        startButton?.titleLabel?.font = appearance.typography.font(size: Typography.buttonFontSize, weight: .semibold)
        backButton?.applyActionAppearance(
            appearance.iconButton,
            appearance: appearance,
            textColor: appearance.screenTextColor
        )
    }

    private func actionTextColor(for style: ActionButtonStyle, appearance: AppAppearance) -> UIColor {
        switch (style, appearance.designStyle) {
        case (.primary, .clean):
            return appearance.resolvedInterfaceStyle == .dark ? appearance.screenTextColor : UIColor.black
        case (.secondary, .clean):
            return QuizThemeAccentStyle.secondaryButtonTextColor(themeID: presenter?.themeID, appearance: appearance)
        case (.primary, .pixel):
            return UIColor.black
        default:
            return appearance.screenTextColor
        }
    }
    
    @objc private func startButtonTapped() {
        presenter?.saveNumberOfQuestions(chosenRow: numberOfQuestionsPickerView.selectedRow(inComponent: .zero))
        fadeActionButtonsForQuestionTransition()
        router?.showQuestion()
    }

    private func fadeActionButtonsForQuestionTransition() {
        let changes = {
            self.descriptionActionViews.forEach { $0.alpha = 0 }
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        UIView.animate(
            withDuration: QuizCardSlideTransition.presentationDuration,
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: changes
        )
    }
    
    @objc private func backButtonTapped() {
        router?.closeDescription()
    }

    override func applyLocalizedStrings() {
        guard isViewLoaded else { return }
        pickerCaptionLabel.text = L10n.Description.questionCount
        startButton.setTitle(L10n.Common.start, for: .normal)
        backButton.accessibilityLabel = L10n.Common.back
    }
}

extension QuizDescriptionViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int { 1 }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        presenter?.numberOfQuestionsOptionCount ?? 0
    }

    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        guard let title = presenter?.numberOfQuestionsTitle(at: row) else { return nil }
        return NSAttributedString(
            string: title,
            attributes: [
                .foregroundColor: currentAppearance().surfaceTextColor,
                .font: currentAppearance().typography.font(size: Typography.buttonFontSize, weight: .semibold)
            ]
        )
    }
}

#if DEBUG
#Preview("Description") {
    let presenter = QuizDescriptionPresenter(
        content: QuizDescriptionContent(
            themeName: "Технологии",
            themeDescription: "Проверь, насколько уверенно ты ориентируешься в гаджетах, IT-компаниях, цифровой культуре и технологических продуктах последних лет."
        )
    )

    let viewController = QuizDescriptionViewController()
    viewController.configurePresenter(presenter)
    return viewController
}
#endif
