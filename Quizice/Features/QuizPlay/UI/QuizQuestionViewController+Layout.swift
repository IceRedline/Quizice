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
        questionCardFaceTransitionDriver.normalize()
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

        questionCardRotatingView = TwoSidedCardTransformCarrierView()
        questionCardRotatingView.backgroundColor = .clear
        questionCardRotatingView.layer.masksToBounds = false
        questionCardRotatingView.translatesAutoresizingMaskIntoConstraints = false

        questionCardFrontPlaneView = UIView()
        questionCardBackPlaneView = UIView()
        questionCardFrontView = UIView()
        questionCardBackView = UIView()
        questionCardFrontView.accessibilityIdentifier = AccessibilityID.questionCardFrontView
        questionCardBackView.accessibilityIdentifier = AccessibilityID.questionCardBackView

        let planes: [(UIView, UIView)] = [
            (questionCardFrontPlaneView, questionCardFrontView),
            (questionCardBackPlaneView, questionCardBackView)
        ]
        planes.forEach { plane in
            let (planeView, faceView) = plane
            planeView.backgroundColor = .clear
            planeView.layer.isDoubleSided = false
            planeView.translatesAutoresizingMaskIntoConstraints = false
            faceView.translatesAutoresizingMaskIntoConstraints = false
            questionCardRotatingView.addSubview(planeView)
            planeView.addSubview(faceView)
        }

        questionCardFlipInteractionButton = UIButton(type: .custom)
        questionCardFlipInteractionButton.isAccessibilityElement = false
        questionCardFlipInteractionButton.isHidden = true
        questionCardFlipInteractionButton.translatesAutoresizingMaskIntoConstraints = false

        questionCardView.addSubview(questionCardShadowView)
        questionCardView.addSubview(questionCardRotatingView)
        questionCardView.addSubview(questionCardFlipInteractionButton)

        var cardHierarchyConstraints: [NSLayoutConstraint] = [
            questionCardShadowView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor),
            questionCardShadowView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor),
            questionCardShadowView.topAnchor.constraint(equalTo: questionCardView.topAnchor),
            questionCardShadowView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor),

            questionCardRotatingView.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor),
            questionCardRotatingView.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor),
            questionCardRotatingView.topAnchor.constraint(equalTo: questionCardView.topAnchor),
            questionCardRotatingView.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor),

            questionCardFlipInteractionButton.leadingAnchor.constraint(equalTo: questionCardView.leadingAnchor),
            questionCardFlipInteractionButton.trailingAnchor.constraint(equalTo: questionCardView.trailingAnchor),
            questionCardFlipInteractionButton.topAnchor.constraint(equalTo: questionCardView.topAnchor),
            questionCardFlipInteractionButton.bottomAnchor.constraint(equalTo: questionCardView.bottomAnchor)
        ]
        planes.forEach { plane in
            let (planeView, faceView) = plane
            cardHierarchyConstraints.append(contentsOf: [
                planeView.leadingAnchor.constraint(equalTo: questionCardRotatingView.leadingAnchor),
                planeView.trailingAnchor.constraint(equalTo: questionCardRotatingView.trailingAnchor),
                planeView.topAnchor.constraint(equalTo: questionCardRotatingView.topAnchor),
                planeView.bottomAnchor.constraint(equalTo: questionCardRotatingView.bottomAnchor),
                faceView.leadingAnchor.constraint(equalTo: planeView.leadingAnchor),
                faceView.trailingAnchor.constraint(equalTo: planeView.trailingAnchor),
                faceView.topAnchor.constraint(equalTo: planeView.topAnchor),
                faceView.bottomAnchor.constraint(equalTo: planeView.bottomAnchor)
            ])
        }
        NSLayoutConstraint.activate(cardHierarchyConstraints)
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

        questionExplanationScrollView = UIScrollView()
        questionExplanationScrollView.alwaysBounceVertical = false
        questionExplanationScrollView.isDirectionalLockEnabled = true
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
        questionExplanationLabel.textAlignment = .left
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
            questionInfoButton
        ]
        frontContentViews.forEach {
            questionCardFrontView.addSubview($0)
        }
        timerContainerView.addSubview(timerBar)
        questionTopSpacingGuide = UILayoutGuide()
        questionBottomSpacingGuide = UILayoutGuide()
        questionCardFrontView.addLayoutGuide(questionTopSpacingGuide)
        questionCardFrontView.addLayoutGuide(questionBottomSpacingGuide)

        questionCardBackView.addSubview(questionExplanationBackButton)
        questionCardBackView.addSubview(questionExplanationScrollView)
        questionExplanationScrollView.addSubview(questionExplanationLabel)
    }
    
    func activateLayoutConstraints(in rootView: UIView) {
        let timerLeadingToCardConstraint = timerContainerView.leadingAnchor.constraint(
            equalTo: questionCardFrontView.leadingAnchor,
            constant: Layout.timerHorizontalInset
        )
        let timerLeadingToInfoConstraint = timerContainerView.leadingAnchor.constraint(
            equalTo: questionInfoButton.trailingAnchor,
            constant: Layout.timerToInfoSpacing
        )
        self.timerLeadingToCardConstraint = timerLeadingToCardConstraint
        self.timerLeadingToInfoConstraint = timerLeadingToInfoConstraint

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
                equalTo: questionCardFrontView.topAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionInfoButton.leadingAnchor.constraint(
                equalTo: questionCardFrontView.leadingAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionInfoButton.widthAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),
            questionInfoButton.heightAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),

            timerContainerView.topAnchor.constraint(equalTo: questionCardFrontView.topAnchor, constant: Layout.timerTopInset),
            timerLeadingToCardConstraint,
            timerContainerView.trailingAnchor.constraint(
                equalTo: questionCardFrontView.trailingAnchor,
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

            questionLabel.leadingAnchor.constraint(equalTo: questionCardFrontView.leadingAnchor, constant: Layout.questionHorizontalInset),
            questionLabel.trailingAnchor.constraint(equalTo: questionCardFrontView.trailingAnchor, constant: -Layout.questionHorizontalInset),

            questionBottomSpacingGuide.topAnchor.constraint(equalTo: questionLabel.bottomAnchor),
            questionBottomSpacingGuide.bottomAnchor.constraint(equalTo: answersStackView.topAnchor),
            questionBottomSpacingGuide.heightAnchor.constraint(
                greaterThanOrEqualToConstant: Layout.questionSurroundingMinimumSpacing
            ),
            questionTopSpacingGuide.heightAnchor.constraint(equalTo: questionBottomSpacingGuide.heightAnchor),

            answersStackView.leadingAnchor.constraint(equalTo: questionCardFrontView.leadingAnchor, constant: Layout.answersHorizontalInset),
            answersStackView.trailingAnchor.constraint(equalTo: questionCardFrontView.trailingAnchor, constant: -Layout.answersHorizontalInset),
            answersStackView.bottomAnchor.constraint(equalTo: questionCardFrontView.bottomAnchor, constant: -Layout.answersBottomInset),

            questionExplanationBackButton.topAnchor.constraint(
                equalTo: questionCardBackView.topAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionExplanationBackButton.leadingAnchor.constraint(
                equalTo: questionCardBackView.leadingAnchor,
                constant: Layout.cardIconButtonInset
            ),
            questionExplanationBackButton.widthAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),
            questionExplanationBackButton.heightAnchor.constraint(equalToConstant: Layout.cardIconButtonSize),

            questionExplanationScrollView.topAnchor.constraint(
                equalTo: questionExplanationBackButton.bottomAnchor,
                constant: Layout.explanationVerticalSpacing
            ),
            questionExplanationScrollView.leadingAnchor.constraint(
                equalTo: questionCardBackView.leadingAnchor,
                constant: Layout.explanationHorizontalInset
            ),
            questionExplanationScrollView.trailingAnchor.constraint(
                equalTo: questionCardBackView.trailingAnchor,
                constant: -Layout.explanationHorizontalInset
            ),
            questionExplanationScrollView.bottomAnchor.constraint(
                equalTo: questionCardBackView.bottomAnchor,
                constant: -Layout.explanationHorizontalInset
            ),

            questionExplanationLabel.topAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.topAnchor
            ),
            questionExplanationLabel.leadingAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.leadingAnchor
            ),
            questionExplanationLabel.trailingAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.trailingAnchor
            ),
            questionExplanationLabel.bottomAnchor.constraint(
                equalTo: questionExplanationScrollView.contentLayoutGuide.bottomAnchor
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
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
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
