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
}
