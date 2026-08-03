import UIKit

extension ThemesCollectionService {
    @discardableResult
    func configureSecondaryActionCard(
        in cell: UICollectionViewCell,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        title: String,
        action: Selector,
        appearance: AppAppearance
    ) -> UIButton {
        let button = makeSecondaryActionButton(
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            title: title,
            action: action,
            appearance: appearance
        )

        pin(button, to: cell.contentView)
        return button
    }

    func configureFeelingLuckyContent(in button: UIButton, appearance: AppAppearance) {
        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.accessibilityIdentifier = Content.feelingLuckyProgressAccessibilityID
        activityIndicator.color = appearance.screenTextColor
        activityIndicator.hidesWhenStopped = true
        activityIndicator.isUserInteractionEnabled = false

        let titleLabel = UILabel()
        titleLabel.text = isFeelingLuckyLoading ? L10n.Home.feelingLuckyLoading : L10n.Home.feelingLucky
        titleLabel.textColor = appearance.screenTextColor
        titleLabel.font = appearance.typography.font(size: Appearance.luckyFontSize, weight: .semibold)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.minimumScaleFactor = 0.78
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.isUserInteractionEnabled = false

        let contentStack = UIStackView(arrangedSubviews: [activityIndicator, titleLabel])
        contentStack.axis = .horizontal
        contentStack.alignment = .center
        contentStack.spacing = 10
        contentStack.isUserInteractionEnabled = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        button.addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: button.centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: button.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -20)
        ])

        applyFeelingLuckyLoadingState(
            to: button,
            loadingContentView: contentStack,
            activityIndicator: activityIndicator,
            titleLabel: titleLabel
        )
    }

    func applyFeelingLuckyLoadingState(
        to button: UIButton,
        loadingContentView: UIStackView,
        activityIndicator: UIActivityIndicatorView,
        titleLabel: UILabel
    ) {
        button.isEnabled = !isFeelingLuckyLoading
        button.accessibilityLabel = isFeelingLuckyLoading
            ? L10n.Home.feelingLuckyLoading
            : L10n.Home.feelingLucky
        button.accessibilityHint = isFeelingLuckyLoading
            ? nil
            : L10n.Home.feelingLuckyAccessibilityHint
        if isFeelingLuckyLoading {
            button.setTitle(nil, for: .normal)
            titleLabel.text = L10n.Home.feelingLuckyLoading
            loadingContentView.isHidden = false
            button.accessibilityTraits.insert(.updatesFrequently)
            activityIndicator.startAnimating()
        } else {
            button.setTitle(L10n.Home.feelingLucky, for: .normal)
            loadingContentView.isHidden = true
            button.accessibilityTraits.remove(.updatesFrequently)
            activityIndicator.stopAnimating()
        }
    }

    func refreshVisibleFeelingLuckyButton() {
        guard let collectionView = observedCollectionView else { return }
        let button = collectionView.visibleCells
            .lazy
            .flatMap(\.contentView.subviews)
            .compactMap { $0 as? UIButton }
            .first(where: { $0.accessibilityIdentifier == Content.feelingLuckyAccessibilityID })
        guard
            let button,
            let activityIndicator = button.subviews
                .lazy
                .flatMap(\.subviews)
                .compactMap({ $0 as? UIActivityIndicatorView })
                .first(where: { $0.accessibilityIdentifier == Content.feelingLuckyProgressAccessibilityID }),
            let loadingContentView = activityIndicator.superview as? UIStackView,
            let titleLabel = button.subviews
                .lazy
                .flatMap(\.subviews)
                .compactMap({ $0 as? UILabel })
                .first
        else { return }

        applyFeelingLuckyLoadingState(
            to: button,
            loadingContentView: loadingContentView,
            activityIndicator: activityIndicator,
            titleLabel: titleLabel
        )
    }

    func makeSecondaryActionButton(
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        title: String,
        action: Selector,
        appearance: AppAppearance
    ) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.accessibilityLabel = accessibilityLabel
        button.accessibilityHint = accessibilityHint
        button.applyActionAppearance(appearance.secondaryButton, appearance: appearance)
        applyCleanOutlineStyleIfNeeded(
            to: button,
            appearance: appearance,
            borderColor: appearance.screenTextColor.withAlphaComponent(0.18)
        )
        button.clipsToBounds = true
        button.setTitle(title, for: .normal)
        button.setTitleColor(appearance.screenTextColor, for: .normal)
        button.titleLabel?.font = appearance.typography.font(size: Appearance.luckyFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        return button
    }

    func applyCleanOutlineStyleIfNeeded(
        to button: UIButton,
        appearance: AppAppearance,
        borderColor: UIColor
    ) {
        guard appearance.designStyle == .clean else { return }
        button.backgroundColor = appearance.card.backgroundColor
        button.layer.borderColor = borderColor.cgColor
        button.layer.borderWidth = max(button.layer.borderWidth, Appearance.buttonBorderWidth)
    }

    func applyRadarTransparentStyleIfNeeded(to button: UIButton, appearance: AppAppearance) {
        guard appearance.designStyle == .radar else { return }
        button.backgroundColor = .clear
    }

    func applyRadarGreenGlowStyleIfNeeded(to button: UIButton, appearance: AppAppearance) {
        guard appearance.designStyle == .radar else { return }
        button.backgroundColor = .clear
        button.clipsToBounds = false
        button.layer.masksToBounds = false
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = appearance.accentColor.cgColor
        button.layer.shadowColor = appearance.accentColor.cgColor
        button.layer.shadowOpacity = Appearance.radarAIThemeGlowOpacity
        button.layer.shadowRadius = Appearance.radarAIThemeGlowRadius
        button.layer.shadowOffset = Appearance.radarAIThemeGlowOffset
        button.layer.shadowPath = UIBezierPath(
            roundedRect: button.bounds,
            cornerRadius: button.layer.cornerRadius
        ).cgPath
    }

    func pin(_ view: UIView, to container: UIView, bottomInset: CGFloat = .zero) {
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomInset)
        ])
    }

    func configureFeelingLuckyCard(
        in cell: UICollectionViewCell,
        appearance: AppAppearance
    ) {
        cell.applyShadow(.none)
        let button = configureSecondaryActionCard(
            in: cell,
            accessibilityIdentifier: Content.feelingLuckyAccessibilityID,
            accessibilityLabel: L10n.Home.feelingLucky,
            accessibilityHint: L10n.Home.feelingLuckyAccessibilityHint,
            title: L10n.Home.feelingLucky,
            action: #selector(feelingLuckyButtonTouchedUpInside(_:)),
            appearance: appearance
        )
        configureFeelingLuckyContent(in: button, appearance: appearance)
    }

    func configureAIThemeCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        cell.applyShadow(.none)
        let usesAccessibilityLayout = cell.traitCollection
            .preferredContentSizeCategory
            .isAccessibilityCategory
        let button = makeSecondaryActionButton(
            accessibilityIdentifier: Content.aiThemeAccessibilityID,
            accessibilityLabel: L10n.Home.createWithAIAccessibilityLabel,
            accessibilityHint: L10n.Home.createWithAIAccessibilityHint,
            title: L10n.Home.createWithAI,
            action: #selector(aiThemeButtonTouchedUpInside(_:)),
            appearance: appearance
        )
        button.isHidden = isAIThemePresented
        button.isEnabled = !isAIThemePresented
        button.isAccessibilityElement = !isAIThemePresented
        button.accessibilityElementsHidden = isAIThemePresented
        button.accessibilityValue = hasActivePlusSubscription
            ? L10n.Subscription.aiCardSubtitle
            : nil
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        let aiThemeCornerRadius = Layout.aiThemeButtonHeight / 2

        let titleLabel = UILabel()
        titleLabel.accessibilityIdentifier = Content.aiThemeTitleAccessibilityID
        titleLabel.text = L10n.Home.createWithAI
        titleLabel.textColor = appearance.screenTextColor
        titleLabel.font = appearance.typography.font(
            size: Appearance.aiThemeTitleFontSize,
            weight: .semibold
        )
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.numberOfLines = usesAccessibilityLayout ? 2 : 1
        titleLabel.minimumScaleFactor = 0.82
        titleLabel.adjustsFontSizeToFitWidth = !usesAccessibilityLayout
        titleLabel.isUserInteractionEnabled = false

        let subtitleLabel = UILabel()
        subtitleLabel.accessibilityIdentifier = Content.aiThemeSubtitleAccessibilityID
        subtitleLabel.text = L10n.Subscription.aiCardSubtitle
        subtitleLabel.textColor = appearance.screenTextColor.withAlphaComponent(0.64)
        subtitleLabel.font = appearance.typography.font(
            size: Appearance.aiThemeSubtitleFontSize,
            weight: .regular
        )
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.numberOfLines = 2
        subtitleLabel.lineBreakMode = .byWordWrapping
        subtitleLabel.isHidden = !hasActivePlusSubscription
        subtitleLabel.isUserInteractionEnabled = false

        let textStack = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
        textStack.axis = .vertical
        textStack.alignment = .fill
        textStack.spacing = 2
        textStack.accessibilityIdentifier = Content.aiThemeTextStackAccessibilityID
        textStack.isUserInteractionEnabled = false
        textStack.translatesAutoresizingMaskIntoConstraints = false

        let tierBadge = InsetLabel(
            contentInsets: UIEdgeInsets(
                top: Layout.aiThemeBadgeVerticalInset,
                left: Layout.aiThemeBadgeHorizontalInset,
                bottom: Layout.aiThemeBadgeVerticalInset,
                right: Layout.aiThemeBadgeHorizontalInset
            )
        )
        tierBadge.accessibilityIdentifier = Content.aiThemeBadgeAccessibilityID
        tierBadge.text = (
            hasActivePlusSubscription
                ? L10n.Subscription.plus
                : L10n.Subscription.freeBadge
        ).uppercased(
            with: AppLocalizationStore.shared.resolvedLocale
        )
        let tierBadgeAccentColor = appearance.designStyle == .radar
            ? appearance.accentColor
            : AIThemeVisualStyle.accentColor
        tierBadge.textColor = hasActivePlusSubscription
            ? tierBadgeAccentColor
            : appearance.screenTextColor
        tierBadge.font = appearance.typography.font(
            size: Appearance.aiThemeBadgeFontSize,
            weight: .bold
        )
        tierBadge.adjustsFontForContentSizeCategory = true
        tierBadge.textAlignment = .center
        tierBadge.backgroundColor = (
            hasActivePlusSubscription
                ? tierBadgeAccentColor
                : appearance.screenTextColor
        ).withAlphaComponent(Appearance.aiThemeBadgeBackgroundAlpha)
        tierBadge.layer.cornerRadius = Appearance.aiThemeBadgeCornerRadius
        tierBadge.layer.borderWidth = Appearance.buttonBorderWidth
        tierBadge.layer.borderColor = (
            hasActivePlusSubscription
                ? tierBadgeAccentColor
                : appearance.screenTextColor
        ).withAlphaComponent(
            Appearance.aiThemeBadgeBorderAlpha
        ).cgColor
        tierBadge.clipsToBounds = true
        tierBadge.isUserInteractionEnabled = false
        tierBadge.translatesAutoresizingMaskIntoConstraints = false

        pin(button, to: cell.contentView)
        cell.contentView.layoutIfNeeded()
        applyRadarGreenGlowStyleIfNeeded(to: button, appearance: appearance)
        button.setTitle(nil, for: .normal)
        button.addSubview(textStack)
        if !usesAccessibilityLayout {
            button.addSubview(tierBadge)
        }
        let gradientBorderView: GradientBorderView?
        if appearance.designStyle == .radar {
            gradientBorderView = nil
        } else {
            let borderView = GradientBorderView(
                colors: AIThemeVisualStyle.gradientColors,
                lineWidth: Appearance.aiThemeGradientBorderWidth,
                cornerRadius: aiThemeCornerRadius
            )
            button.layer.cornerRadius = aiThemeCornerRadius
            borderView.accessibilityIdentifier = Content.aiThemeGradientBorderAccessibilityID
            borderView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(borderView)
            gradientBorderView = borderView
        }

        var contentConstraints = [
            textStack.leadingAnchor.constraint(
                equalTo: button.leadingAnchor,
                constant: Layout.aiThemeContentLeadingInset
            ),
            textStack.centerYAnchor.constraint(equalTo: button.centerYAnchor),
            textStack.topAnchor.constraint(greaterThanOrEqualTo: button.topAnchor, constant: 8),
            textStack.bottomAnchor.constraint(lessThanOrEqualTo: button.bottomAnchor, constant: -8)
        ]

        if usesAccessibilityLayout {
            contentConstraints.append(
                textStack.trailingAnchor.constraint(
                    equalTo: button.trailingAnchor,
                    constant: -Layout.aiThemeContentLeadingInset
                )
            )
        } else {
            contentConstraints.append(contentsOf: [
                tierBadge.leadingAnchor.constraint(
                    greaterThanOrEqualTo: textStack.trailingAnchor,
                    constant: Layout.aiThemeContentTrailingSpacing
                ),
                tierBadge.trailingAnchor.constraint(
                    equalTo: button.trailingAnchor,
                    constant: -Layout.aiThemeBadgeTrailingInset
                ),
                tierBadge.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                tierBadge.widthAnchor.constraint(
                    greaterThanOrEqualToConstant: Layout.aiThemeBadgeMinimumWidth
                )
            ])
        }
        NSLayoutConstraint.activate(contentConstraints)

        if let gradientBorderView {
            NSLayoutConstraint.activate([
                gradientBorderView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                gradientBorderView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                gradientBorderView.topAnchor.constraint(equalTo: button.topAnchor),
                gradientBorderView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
    }

    @objc func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.feelingLuckyButtonTouchedUpInside(sender)
    }

    @objc func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.aiThemeButtonTouchedUpInside(sender)
    }

    @objc func subscriptionPromoButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.subscriptionPromoButtonTouchedUpInside(sender)
    }

    @objc func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.statisticsButtonTouchedUpInside(sender)
    }
}
