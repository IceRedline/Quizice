import UIKit

extension ExpandedThemeCardView {
    func applyAppearance(
        _ appearance: AppAppearance,
        themeID: String,
        themeTintColor: UIColor,
        borderColor: UIColor
    ) {
        overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle
        cardCornerRadius = appearance.themeCardCornerRadius

        configuredSurfaceColor = appearance.themeCardBackground(baseColor: themeTintColor)
        configuredBorderColor = borderColor
        configuredBorderWidth = appearance.themeCardBorderWidth
        applyConfiguredSurfaceAppearance()
        configuredShadowStyle = appearance.card.shadow
        let shadow = isTransitionShadowHidden ? AppShadowStyle.none : configuredShadowStyle
        shadowProxyView.applyShadow(shadow)

        frontTitleLabel.font = appearance.typography.font(
            size: Typography.frontTitleSize,
            weight: .bold
        )
        frontTitleLabel.textColor = appearance.themeCardTextColor(baseColor: themeTintColor)

        backTitleLabel.font = appearance.typography.font(
            size: Typography.backTitleSize,
            weight: .bold
        )
        backTitleLabel.textColor = appearance.surfaceTextColor
        backDescriptionLabel.font = appearance.typography.font(
            size: Typography.descriptionSize,
            weight: .regular
        )
        backDescriptionLabel.textColor = appearance.secondarySurfaceTextColor
        questionCountLabel.font = appearance.typography.font(
            size: Typography.captionSize,
            weight: .semibold
        )
        questionCountLabel.textColor = appearance.secondarySurfaceTextColor
        unavailableLabel.font = appearance.typography.font(
            size: Typography.unavailableSize,
            weight: .medium
        )
        unavailableLabel.textColor = appearance.destructiveColor

        [closeButton, infoButton, backButton].forEach { button in
            button.applyActionAppearance(
                appearance.iconButton,
                appearance: appearance,
                textColor: appearance.themeCardTextColor(baseColor: themeTintColor)
            )
        }

        let primaryButtonStyle = QuizThemeAccentStyle.primaryButtonStyle(
            themeID: themeID,
            appearance: appearance
        )
        startButton.titleLabel?.font = appearance.typography.font(
            size: Typography.buttonSize,
            weight: .semibold
        )
        startButton.applyActionAppearance(
            primaryButtonStyle,
            appearance: appearance,
            textColor: QuizThemeAccentStyle.primaryButtonTextColor(
                themeID: themeID,
                appearance: appearance
            )
        )

        questionCountControl.backgroundColor = appearance.row.backgroundColor
        questionCountControl.selectedSegmentTintColor = primaryButtonStyle.backgroundColor
        questionCountControl.layer.cornerRadius = appearance.row.cornerRadius
        questionCountControl.layer.borderWidth = appearance.row.borderWidth
        questionCountControl.layer.borderColor = appearance.row.borderColor.cgColor
        let segmentFont = appearance.typography.font(
            size: Typography.segmentSize,
            weight: .semibold
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: appearance.surfaceTextColor
            ],
            for: .normal
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: QuizThemeAccentStyle.primaryButtonTextColor(
                    themeID: themeID,
                    appearance: appearance
                )
            ],
            for: .selected
        )
        questionCountControl.setTitleTextAttributes(
            [
                .font: segmentFont,
                .foregroundColor: appearance.disabledTextColor
            ],
            for: .disabled
        )
    }

    func applyConfiguredSurfaceAppearance() {
        let surfaceColor = isTransitionSurfaceHidden ? UIColor.clear : configuredSurfaceColor
        let borderColor = isTransitionSurfaceHidden ? UIColor.clear : configuredBorderColor
        let borderWidth = isTransitionSurfaceHidden ? CGFloat.zero : configuredBorderWidth

        [frontSurfaceView, backSurfaceView].forEach { surfaceView in
            surfaceView.backgroundColor = surfaceColor
            surfaceView.layer.cornerRadius = cardCornerRadius
            surfaceView.layer.cornerCurve = .continuous
            surfaceView.layer.borderWidth = borderWidth
            surfaceView.layer.borderColor = borderColor.cgColor
        }
        frontFaceView.backgroundColor = surfaceColor
        backFaceView.backgroundColor = surfaceColor
    }

    func configureQuestionCounts(selectedQuestionCount: Int?) {
        for (index, count) in Self.supportedQuestionCounts.enumerated() {
            questionCountControl.setEnabled(
                availableQuestionCounts.contains(count),
                forSegmentAt: index
            )
        }

        let resolvedSelection = selectedQuestionCount.flatMap { selection in
            availableQuestionCounts.contains(selection) ? selection : nil
        }
            ?? Self.supportedQuestionCounts.first(where: availableQuestionCounts.contains)

        self.selectedQuestionCount = resolvedSelection
        if let resolvedSelection,
           let index = Self.supportedQuestionCounts.firstIndex(of: resolvedSelection) {
            questionCountControl.selectedSegmentIndex = index
        } else {
            questionCountControl.selectedSegmentIndex = UISegmentedControl.noSegment
        }

        let isAvailable = resolvedSelection != nil
        unavailableLabel.isHidden = isAvailable
        unavailableLabel.accessibilityElementsHidden = isAvailable
        startButton.isEnabled = isAvailable
        startButton.accessibilityHint = isAvailable ? nil : L10n.Question.unavailableMessage
    }

    func frontArtworkImage(themeID: String, appearance: AppAppearance) -> UIImage? {
        guard let image = ThemeVisualCatalog.logoImage(
            for: themeID,
            designStyle: appearance.designStyle
        ) else {
            return nil
        }

        switch appearance.designStyle {
        case .clean:
            let configuration = UIImage.SymbolConfiguration(
                pointSize: Layout.cleanFrontArtworkPointSize,
                weight: .regular
            )
            return image.applyingSymbolConfiguration(configuration) ?? image

        case .classic:
            return image

        case .radar:
            return image
        }
    }

    func frontArtworkPointSize(for designStyle: AppDesignStyle) -> CGFloat {
        switch designStyle {
        case .classic:
            return Layout.classicFrontArtworkSize.width
        case .clean:
            return Layout.cleanFrontArtworkPointSize
        case .radar:
            return Layout.radarFrontArtworkPointSize
        }
    }

}
