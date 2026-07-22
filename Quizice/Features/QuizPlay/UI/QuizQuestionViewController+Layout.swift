import UIKit
import AVKit
import SwiftUI

extension QuizQuestionViewController {
    func configureProgrammaticSubviews(in rootView: UIView) {
        configureHeaderLabels()
        configureQuestionCard()
        configureQuestionContent()
        configureTimerViews()
        configureAnswerButtons()
        configureAnswersStackView()
        configureQuestionExplanation()
        configureActionButtons()
        addSubviews(to: rootView)
        activateLayoutConstraints(in: rootView)
    }
    
    func configureHeaderLabels() {
        let typography = currentAppearance().typography
        themeNameLabel = makeLabel(font: typography.font(size: Typography.themeFontSize, weight: .semibold))
        themeNameLabel.accessibilityIdentifier = AccessibilityID.themeLabel
        themeNameLabel.numberOfLines = 1
        themeNameLabel.adjustsFontSizeToFitWidth = true
        themeNameLabel.minimumScaleFactor = Typography.themeMinimumScaleFactor
        themeNameLabel.allowsDefaultTighteningForTruncation = true
        themeNameLabel.baselineAdjustment = .alignCenters
        themeNameLabel.setContentHuggingPriority(.required, for: .vertical)
        
        questionNumberLabel = makeLabel(font: typography.font(size: Typography.questionNumberFontSize, weight: .medium))
        questionNumberLabel.accessibilityIdentifier = AccessibilityID.questionNumberLabel
        questionNumberLabel.setContentHuggingPriority(.required, for: .vertical)

#if DEBUG
        debugQuestionSourceLabel = UILabel()
        debugQuestionSourceLabel.accessibilityIdentifier = AccessibilityID.backendQuestionSource
        debugQuestionSourceLabel.font = .monospacedSystemFont(
            ofSize: Typography.backendSourceFontSize,
            weight: .bold
        )
        debugQuestionSourceLabel.textColor = .white
        debugQuestionSourceLabel.textAlignment = .center
        debugQuestionSourceLabel.layer.cornerRadius = 9
        debugQuestionSourceLabel.clipsToBounds = true
        debugQuestionSourceLabel.translatesAutoresizingMaskIntoConstraints = false
        debugQuestionSourceLabel.isHidden = !DebugBackendSettings.shouldShowSourceIndicators
        debugQuestionSourceLabel.setContentHuggingPriority(.required, for: .horizontal)
        debugQuestionSourceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateDebugQuestionSourceIndicator()
#endif
    }
    
    func configureQuestionCard() {
        questionCardView = UIView()
        questionCardView.accessibilityIdentifier = AccessibilityID.questionCardView
        questionCardView.backgroundColor = .clear
        questionCardView.clipsToBounds = false
        questionCardView.translatesAutoresizingMaskIntoConstraints = false

        questionCardShadowView = UIView()
        questionCardShadowView.backgroundColor = .clear
        questionCardShadowView.isUserInteractionEnabled = false
        questionCardShadowView.translatesAutoresizingMaskIntoConstraints = false

        questionCardContentView = UIView()
        questionCardContentView.accessibilityIdentifier = AccessibilityID.questionCardContentView
        questionCardContentView.translatesAutoresizingMaskIntoConstraints = false

        questionCardView.addSubview(questionCardShadowView)
        questionCardView.addSubview(questionCardContentView)

        NSLayoutConstraint.activate([
            questionCardShadowView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor),
            questionCardShadowView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor),
            questionCardShadowView.topAnchor.constraint(equalTo: questionCardView.topAnchor),
            questionCardShadowView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor),

            questionCardContentView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor),
            questionCardContentView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor),
            questionCardContentView.topAnchor.constraint(equalTo: questionCardView.topAnchor),
            questionCardContentView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor)
        ])
    }
    
    func configureQuestionContent() {
        questionLabel = makeLabel(font: currentAppearance().typography.font(size: Typography.questionFontSize, weight: .bold))
        questionLabel.accessibilityIdentifier = AccessibilityID.questionTextLabel
        questionLabel.numberOfLines = Typography.unlimitedNumberOfLines
        questionLabel.lineBreakMode = .byWordWrapping
        questionLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    func configureTimerViews() {
        timerContainerView = UIView()
        timerContainerView.accessibilityIdentifier = AccessibilityID.timerContainerView
        timerContainerView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.timerContainerBackgroundAlpha)
        timerContainerView.layer.cornerRadius = Appearance.timerContainerCornerRadius
        timerContainerView.translatesAutoresizingMaskIntoConstraints = false
        
        timerBar = UIProgressView(progressViewStyle: .default)
        timerBar.accessibilityIdentifier = AccessibilityID.timerProgressView
        timerBar.accessibilityLabel = L10n.Question.timeRemaining
        timerBar.isAccessibilityElement = true
        timerBar.translatesAutoresizingMaskIntoConstraints = false
        setTimerBarColor(Appearance.timerActiveColor)
        timerBar.trackTintColor = UIColor.white.withAlphaComponent(Appearance.timerTrackAlpha)
        timerBar.layer.cornerRadius = Appearance.timerBarCornerRadius
        timerBar.clipsToBounds = true
    }
    
    func configureAnswerButtons() {
        answer1Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 1))
        answer2Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 2))
        answer3Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 3))
        answer4Button = makeAnswerButton(accessibilityIdentifier: answerButtonAccessibilityIdentifier(index: 4))
        
        answerButtons.forEach { button in
            button.addTarget(self, action: #selector(answerChosen(_:)), for: .touchUpInside)
        }
    }
    
    func configureAnswersStackView() {
        answersStackView = UIStackView(arrangedSubviews: answerButtons)
        answersStackView.accessibilityIdentifier = AccessibilityID.answersStackView
        answersStackView.axis = .vertical
        answersStackView.spacing = Layout.answersStackSpacing
        answersStackView.distribution = .fill
        answersStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    func configureQuestionExplanation() {
        questionInfoButton = makeCardIconButton(
            systemName: "info",
            accessibilityIdentifier: AccessibilityID.questionInfoButton,
            accessibilityLabel: L10n.Question.showExplanation
        )
        questionInfoButton.isHidden = true
        questionInfoButton.addTarget(self, action: #selector(questionInfoButtonTapped), for: .touchUpInside)

        questionExplanationBackButton = makeCardIconButton(
            systemName: "chevron.left",
            accessibilityIdentifier: AccessibilityID.questionExplanationBackButton,
            accessibilityLabel: L10n.Question.showQuestion
        )
        questionExplanationBackButton.addTarget(
            self,
            action: #selector(questionExplanationBackButtonTapped),
            for: .touchUpInside
        )
        questionExplanationBackButton.isHidden = true

        questionExplanationScrollView = UIScrollView()
        questionExplanationScrollView.accessibilityIdentifier = AccessibilityID.questionExplanationScrollView
        questionExplanationScrollView.alwaysBounceVertical = false
        questionExplanationScrollView.isDirectionalLockEnabled = true
        questionExplanationScrollView.isHidden = true
        questionExplanationScrollView.translatesAutoresizingMaskIntoConstraints = false

        questionExplanationLabel = makeLabel(
            font: currentAppearance().typography.font(
                size: Typography.explanationFontSize,
                weight: .regular
            )
        )
        questionExplanationLabel.accessibilityIdentifier = AccessibilityID.questionExplanationLabel
        questionExplanationLabel.numberOfLines = Typography.unlimitedNumberOfLines
        questionExplanationLabel.lineBreakMode = .byWordWrapping
        questionExplanationLabel.textAlignment = .center
        questionExplanationLabel.setContentCompressionResistancePriority(.required, for: .vertical)
    }
    
    func configureActionButtons() {
        nextButton = makeActionButton(title: L10n.Common.next, accessibilityIdentifier: AccessibilityID.nextButton, style: .primary)
        nextButton.setContentHuggingPriority(.required, for: .vertical)
        nextButton.addTarget(self, action: #selector(nextButtonTapped), for: .touchUpInside)

        closeButton = UIButton(type: .system)
        closeButton.accessibilityIdentifier = AccessibilityID.closeButton
        closeButton.accessibilityLabel = L10n.Common.exit
        closeButton.setImage(
            UIImage(
                systemName: "xmark",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)
            ),
            for: .normal
        )
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.installPressFeedback()
    }
    
    func addSubviews(to rootView: UIView) {
        scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = AccessibilityID.scrollView
        scrollView.alwaysBounceVertical = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        var rootSubviews: [UIView] = [themeNameLabel, questionNumberLabel, closeButton, scrollView, nextButton]
#if DEBUG
        rootSubviews.append(debugQuestionSourceLabel)
#endif
        rootSubviews.forEach(rootView.addSubview)
        scrollView.addSubview(questionCardView)
        let frontContentViews: [UIView] = [
            timerContainerView,
            questionLabel,
            answersStackView,
            questionInfoButton,
            questionExplanationBackButton,
            questionExplanationScrollView
        ]
        frontContentViews.forEach {
            questionCardContentView.addSubview($0)
        }
        timerContainerView.addSubview(timerBar)
        questionTopSpacingGuide = UILayoutGuide()
        questionBottomSpacingGuide = UILayoutGuide()
        questionCardContentView.addLayoutGuide(questionTopSpacingGuide)
        questionCardContentView.addLayoutGuide(questionBottomSpacingGuide)

        questionExplanationScrollView.addSubview(questionExplanationLabel)
    }
    
    func activateLayoutConstraints(in rootView: UIView) {
        let explanationContentHeightConstraint = questionExplanationScrollView.contentLayoutGuide.heightAnchor.constraint(
            equalTo: questionExplanationLabel.heightAnchor,
            constant: Layout.explanationContentVerticalInset * 2
        )
        explanationContentHeightConstraint.priority = UILayoutPriority(
            rawValue: UILayoutPriority.defaultLow.rawValue - 1
        )

        var debugSourceConstraints: [NSLayoutConstraint] = []
#if DEBUG
        debugSourceConstraints = [
            debugQuestionSourceLabel.centerYAnchor.constraint(equalTo: themeNameLabel.centerYAnchor),
            debugQuestionSourceLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 8),
            debugQuestionSourceLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 54),
            debugQuestionSourceLabel.heightAnchor.constraint(equalToConstant: 20)
        ]
#endif

        let constraints = [
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.topInset),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset + Layout.closeButtonSize),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -(Layout.rootHorizontalInset + Layout.closeButtonSize)),
            closeButton.centerYAnchor.constraint(equalTo: themeNameLabel.centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.closeButtonTrailingInset),
            closeButton.widthAnchor.constraint(equalToConstant: Layout.closeButtonSize),
            closeButton.heightAnchor.constraint(equalToConstant: Layout.closeButtonSize),
            
            questionNumberLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: Layout.questionNumberTopSpacing),
            questionNumberLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.rootHorizontalInset),
            questionNumberLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.rootHorizontalInset),
            
            scrollView.topAnchor.constraint(equalTo: questionNumberLabel.bottomAnchor, constant: Layout.cardTopSpacing),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: nextButton.topAnchor, constant: -Layout.actionTopSpacing),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),

            questionCardView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            questionCardView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            questionCardView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: Layout.cardHorizontalInset),
            questionCardView.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -Layout.cardHorizontalInset),
            questionCardView.widthAnchor.constraint(lessThanOrEqualToConstant: Layout.maximumContentWidth),
            questionCardView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -Layout.cardBottomInset),
            
            questionInfoButton.topAnchor.constraint(
                equalTo: questionCardContentView.topAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionInfoButton.leadingAnchor.constraint(
                equalTo: questionCardContentView.leadingAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionInfoButton.widthAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),
            questionInfoButton.heightAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),

            questionExplanationBackButton.topAnchor.constraint(equalTo: questionInfoButton.topAnchor),
            questionExplanationBackButton.leadingAnchor.constraint(equalTo: questionInfoButton.leadingAnchor),
            questionExplanationBackButton.widthAnchor.constraint(equalTo: questionInfoButton.widthAnchor),
            questionExplanationBackButton.heightAnchor.constraint(equalTo: questionInfoButton.heightAnchor),

            timerContainerView.topAnchor.constraint(equalTo: questionCardContentView.topAnchor, constant: Layout.timerTopInset),
            timerContainerView.leadingAnchor.constraint(
                equalTo: questionCardContentView.leadingAnchor,
                constant: Layout.timerHorizontalInset
            ),
            timerContainerView.trailingAnchor.constraint(
                equalTo: questionCardContentView.trailingAnchor,
                constant: -Layout.timerHorizontalInset
            ),
            timerContainerView.heightAnchor.constraint(equalToConstant: Layout.timerContainerHeight),
            
            timerBar.centerYAnchor.constraint(equalTo: timerContainerView.centerYAnchor),
            timerBar.leadingAnchor.constraint(equalTo: timerContainerView.leadingAnchor, constant: Layout.timerBarHorizontalInset),
            timerBar.trailingAnchor.constraint(equalTo: timerContainerView.trailingAnchor, constant: -Layout.timerBarHorizontalInset),
            timerBar.heightAnchor.constraint(equalToConstant: Layout.timerBarHeight),

            questionTopSpacingGuide.topAnchor.constraint(equalTo: timerBar.bottomAnchor),
            questionTopSpacingGuide.bottomAnchor.constraint(equalTo: questionLabel.topAnchor),
            questionTopSpacingGuide.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.questionSurroundingMinimumSpacing
            ),

            questionLabel.leadingAnchor.constraint(equalTo: questionCardContentView.leadingAnchor, constant: Layout.questionHorizontalInset),
            questionLabel.trailingAnchor.constraint(equalTo: questionCardContentView.trailingAnchor, constant: -Layout.questionHorizontalInset),

            questionBottomSpacingGuide.topAnchor.constraint(equalTo: questionLabel.bottomAnchor),
            questionBottomSpacingGuide.bottomAnchor.constraint(equalTo: answersStackView.topAnchor),
            questionBottomSpacingGuide.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.questionSurroundingMinimumSpacing
            ),
            questionTopSpacingGuide.heightAnchor.constraint(equalTo: questionBottomSpacingGuide.heightAnchor),

            answersStackView.leadingAnchor.constraint(equalTo: questionCardContentView.leadingAnchor, constant: Layout.answersHorizontalInset),
            answersStackView.trailingAnchor.constraint(equalTo: questionCardContentView.trailingAnchor, constant: -Layout.answersHorizontalInset),
            answersStackView.bottomAnchor.constraint(equalTo: questionCardContentView.bottomAnchor, constant: -Layout.answersBottomInset),

            questionExplanationScrollView.topAnchor.constraint(
                equalTo: timerBar.bottomAnchor,
                constant: Layout.questionSurroundingMinimumSpacing
            ),
            questionExplanationScrollView.leadingAnchor.constraint(equalTo: questionLabel.leadingAnchor),
            questionExplanationScrollView.trailingAnchor.constraint(equalTo: questionLabel.trailingAnchor),
            questionExplanationScrollView.bottomAnchor.constraint(
                equalTo: answersStackView.topAnchor,
                constant: -Layout.questionSurroundingMinimumSpacing
            ),

            questionExplanationScrollView.contentLayoutGuide.heightAnchor.constraint(
                greaterThanOrEqualTo: questionExplanationScrollView.frameLayoutGuide.heightAnchor
            ),
            explanationContentHeightConstraint,
            questionExplanationLabel.centerYAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.centerYAnchor
            ),
            questionExplanationLabel.topAnchor.constraint(
                greaterThanOrEqualTo: questionExplanationScrollView.contentLayoutGuide.topAnchor,
                constant: Layout.explanationContentVerticalInset
            ),
            questionExplanationLabel.leadingAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.leadingAnchor
            ),
            questionExplanationLabel.trailingAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.trailingAnchor
            ),
            questionExplanationLabel.bottomAnchor.constraint(
                lessThanOrEqualTo: questionExplanationScrollView.contentLayoutGuide.bottomAnchor,
                constant: -Layout.explanationContentVerticalInset
            ),
            questionExplanationLabel.widthAnchor.constraint(
                equalTo: questionExplanationScrollView.frameLayoutGuide.widthAnchor
            ),
            
            nextButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            nextButton.widthAnchor.constraint(equalToConstant: Layout.actionButtonWidth),
            nextButton.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.primaryActionButtonHeight),
            nextButton.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.bottomMaximumInset)
        ]
        NSLayoutConstraint.activate(constraints + debugSourceConstraints)

        let cardWidthConstraint = questionCardView.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor,
            constant: -(Layout.cardHorizontalInset * 2)
        )
        cardWidthConstraint.priority = .defaultHigh
        cardWidthConstraint.isActive = true

        questionCardView.heightAnchor.constraint(
            greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor,
            constant: -Layout.cardBottomInset
        ).isActive = true

        answerHeightConstraints = answerButtons.map { button in
            let constraint = button.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.answerMinimumHeight)
            constraint.isActive = true
            return constraint
        }
    }
    
    func answerButtonAccessibilityIdentifier(index: Int) -> String {
        "\(AccessibilityID.answerButtonPrefix)\(index)"
    }
    
    func makeLabel(font: UIFont) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = font
        label.adjustsFontForContentSizeCategory = true
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    func makeAnswerButton(accessibilityIdentifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(Appearance.answerDisabledTitleColor, for: .disabled)
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.answerButtonFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = Typography.answerButtonNumberOfLines
        button.titleLabel?.lineBreakMode = .byWordWrapping
        button.titleLabel?.textAlignment = .center
        button.backgroundColor = .defaultButton
        button.layer.cornerRadius = Appearance.answerCornerRadius
        button.layer.borderWidth = Appearance.answerBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.answerBorderAlpha).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    func makeActionButton(title: String, accessibilityIdentifier: String, style: ActionButtonStyle) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(Appearance.disabledButtonTitleAlpha), for: .disabled)
        button.titleLabel?.font = currentAppearance().typography.font(size: Typography.actionButtonFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIColor.white.withAlphaComponent(style.backgroundAlpha)
        button.layer.cornerRadius = style.cornerRadius
        button.layer.borderWidth = Appearance.actionButtonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(style.borderAlpha).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = style.shadowOpacity
        button.layer.shadowRadius = Appearance.actionButtonShadowRadius
        button.layer.shadowOffset = Appearance.actionButtonShadowOffset
        button.translatesAutoresizingMaskIntoConstraints = false
        button.installPressFeedback()
        return button
    }

    func makeCardIconButton(
        systemName: String,
        accessibilityIdentifier: String,
        accessibilityLabel: String
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = accessibilityLabel
        button.setImage(
            UIImage(
                systemName: systemName,
                withConfiguration: UIImage.SymbolConfiguration(
                    pointSize: Layout.cardIconSymbolPointSize,
                    weight: .semibold
                )
            ),
            for: .normal
        )
        button.layer.cornerRadius = Layout.cardIconButtonSize / 2
        button.layer.cornerCurve = .circular
        button.translatesAutoresizingMaskIntoConstraints = false
        button.installPressFeedback()
        return button
    }
}
