import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    enum Content {
        static let themeCellReuseIdentifier = "themeCell"
        static let themeImageAccessibilityIDPrefix = "homeThemeImageView"
        static let themeTitleAccessibilityIDPrefix = "homeThemeTitleLabel"
        static let aiThemeAccessibilityID = "homeCreateWithAIButton"
        static let aiThemeBetaBadgeAccessibilityID = "homeCreateWithAIBetaBadge"
        static let aiThemeGradientBorderAccessibilityID = "homeCreateWithAIGradientBorder"
        static let feelingLuckyAccessibilityID = "homeFeelingLuckyButton"
        static let statisticsAccessibilityID = "homeStatisticsCard"
        static let statisticsPlayedValueAccessibilityID = "homeStatisticsPlayedValueLabel"
        static let statisticsPlayedTitleAccessibilityID = "homeStatisticsPlayedTitleLabel"
        static let statisticsAccuracyValueAccessibilityID = "homeStatisticsAccuracyValueLabel"
        static let statisticsAccuracyTitleAccessibilityID = "homeStatisticsAccuracyTitleLabel"

        static let musicThemeLogoImageName = "theme_logo_music"
        static let technologyThemeLogoImageName = "theme_logo_tech.png"
        static let cultureThemeLogoImageName = "theme_logo_culture.png"
        static let politicsThemeLogoImageName = "theme_logo_politics"
        static let musicThemeLogoCleanImageName = "theme_logo_music_clean"
        static let technologyThemeLogoCleanImageName = "theme_logo_tech_clean"
        static let cultureThemeLogoCleanImageName = "theme_logo_culture_clean"
        static let politicsThemeLogoCleanImageName = "theme_logo_politics_clean"
        static let musicThemeLogoRadarImageName = "theme_logo_music_radar"
        static let technologyThemeLogoRadarImageName = "theme_logo_tech_radar"
        static let cultureThemeLogoRadarImageName = "theme_logo_culture_radar"
        static let politicsThemeLogoRadarImageName = "theme_logo_politics_radar"

        static let musicThemeTintColorName = "themeMusicTint"
        static let technologyThemeTintColorName = "themeTechnologyTint"
        static let cultureThemeTintColorName = "themeCultureTint"
        static let politicsThemeTintColorName = "themePoliticsTint"
    }

    private enum Layout {
        static let sectionInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        static let itemSpacing: CGFloat = 16
        static let secondaryActionButtonHeight: CGFloat = 54
        static let statisticsCardHeight: CGFloat = 112
        static let cardContentHorizontalInset: CGFloat = 24
        static let aiThemeBadgeTrailingInset: CGFloat = 16
        static let aiThemeBadgeHorizontalInset: CGFloat = 10
        static let aiThemeBadgeVerticalInset: CGFloat = 5
        static let aiThemeBadgeMinimumWidth: CGFloat = 48
        static let statisticsStackSpacing: CGFloat = 6
        static let statisticsContentSpacing: CGFloat = 16
        static let statisticsMetricsSpacing: CGFloat = 8
        static let statisticsMetricSpacing: CGFloat = 8
        static let themeImageTopInset: CGFloat = 14
        static let themeImageHorizontalInset: CGFloat = 4
        static let themeImageToTitleSpacing: CGFloat = 0
        static let themeTitleHorizontalInset: CGFloat = 8
        static let themeTitleBottomInset: CGFloat = 6
        static let themeTitleHeight: CGFloat = 56
        static let cellShadowOffset = CGSize(width: 0, height: 12)
        static let cellShadowRadius: CGFloat = 22
    }

    private enum Appearance {
        static let themeCardBackgroundAlpha: CGFloat = 0.20
        static let themeCardBorderAlpha: CGFloat = 0.45
        static let themeCardCornerRadius: CGFloat = 28
        static let statisticsCardBackgroundAlpha: CGFloat = 0.18
        static let statisticsCardBorderAlpha: CGFloat = 0.40
        static let statisticsCardCornerRadius: CGFloat = 30
        static let feelingLuckyButtonBackgroundAlpha: CGFloat = 0.14
        static let feelingLuckyButtonBorderAlpha: CGFloat = 0.36
        static let feelingLuckyButtonCornerRadius: CGFloat = 20
        static let buttonBorderWidth: CGFloat = 1
        static let aiThemeGradientBorderWidth: CGFloat = 1.6
        static let aiThemeGradientPink = UIColor(hex: 0xFF4FD8)
        static let aiThemeGradientBlue = UIColor(hex: 0x36A3FF)
        static let radarAIThemeGlowOpacity: Float = 0.65
        static let radarAIThemeGlowRadius: CGFloat = 18
        static let radarAIThemeGlowOffset = CGSize(width: 0, height: 0)
        static let aiThemeBadgeBackgroundAlpha: CGFloat = 0.18
        static let aiThemeBadgeBorderAlpha: CGFloat = 0.52
        static let aiThemeBadgeCornerRadius: CGFloat = 11
        static let cellShadowOpacity: Float = 0.22
        static let titleFontSize: CGFloat = 24
        static let descriptionFontSize: CGFloat = 15
        static let statisticsMetricValueFontSize: CGFloat = 18
        static let statisticsMetricTitleFontSize: CGFloat = 14
        static let luckyFontSize: CGFloat = 19
        static let betaBadgeFontSize: CGFloat = 12
        static let themeTitleFontSize: CGFloat = 18
    }

    weak var delegate: ThemeCollectionDelegate?

    private let themeRepository: ThemeRepository
    private let statisticsStore: StatisticsStore
    private let appearanceStore = AppAppearanceStore.shared

    private var themeCount: Int { themeRepository.themes?.count ?? 0 }

    private var aiThemeIndex: Int { themeCount }

    private var feelingLuckyIndex: Int { themeCount + 1 }

    private var statisticsIndex: Int { themeCount + 2 }

    init(themeRepository: ThemeRepository = QuizFactory.shared, statisticsStore: StatisticsStore = StatisticsStore()) {
        self.themeRepository = themeRepository
        self.statisticsStore = statisticsStore
        super.init()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { themeCount + 3 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Content.themeCellReuseIdentifier, for: indexPath)
        let appearance = appearanceStore.appearance(compatibleWith: collectionView.traitCollection)
        prepare(cell, appearance: appearance)

        if indexPath.item == statisticsIndex {
            configureStatisticsCard(in: cell, appearance: appearance)
            return cell
        }

        if indexPath.item == feelingLuckyIndex {
            configureFeelingLuckyCard(in: cell, appearance: appearance)
            return cell
        }

        if indexPath.item == aiThemeIndex {
            configureAIThemeCard(in: cell, appearance: appearance)
            return cell
        }

        guard let theme = themeRepository.themes?[safe: indexPath.item] else {
            return cell
        }
        configureThemeCard(in: cell, theme: theme, appearance: appearance)
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = max(collectionView.bounds.width - Layout.sectionInsets.left - Layout.sectionInsets.right, 0)
        if indexPath.item == statisticsIndex {
            return CGSize(width: availableWidth, height: Layout.statisticsCardHeight)
        }

        if indexPath.item == aiThemeIndex || indexPath.item == feelingLuckyIndex {
            return CGSize(width: availableWidth, height: Layout.secondaryActionButtonHeight)
        }

        let twoColumnWidth = floor((availableWidth - Layout.itemSpacing) / 2)
        return CGSize(width: twoColumnWidth, height: twoColumnWidth)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets { Layout.sectionInsets }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        delegate?.themesCollectionDidScroll(scrollView)
    }

    private func prepare(_ cell: UICollectionViewCell, appearance: AppAppearance) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = .clear
        cell.contentView.clipsToBounds = false
        cell.backgroundColor = .clear
        cell.layer.masksToBounds = false
        cell.applyShadow(appearance.themeCardShadow)
    }

    private func configureThemeCard(in cell: UICollectionViewCell, theme: QuizTheme, appearance: AppAppearance) {
        let button = UIButton(type: .custom)
        let themeID = theme.stableID
        let themeName = theme.theme
        let themeImageName = themeLogoImageName(for: themeID, appearance: appearance)
        let themeTintColor = themeTintColor(for: themeID)

        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeID
        button.accessibilityLabel = L10n.ThemeCard.accessibilityLabel(themeName: themeName)
        button.accessibilityHint = L10n.ThemeCard.accessibilityHint
        button.backgroundColor = appearance.themeCardBackground(baseColor: themeTintColor)
        button.layer.cornerRadius = appearance.themeCardCornerRadius
        button.layer.borderWidth = appearance.themeCardBorderWidth
        button.layer.borderColor = appearance.themeCardBorder(baseColor: themeTintColor).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: themeImageName))
        imageView.accessibilityIdentifier = themeImageAccessibilityIdentifier(themeID: themeID)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.accessibilityIdentifier = themeTitleAccessibilityIdentifier(themeID: themeID)
        titleLabel.text = themeName
        titleLabel.textColor = appearance.themeCardTextColor(baseColor: themeTintColor)
        titleLabel.font = appearance.typography.font(size: Appearance.themeTitleFontSize, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.adjustsFontSizeToFitWidth = false
        titleLabel.isUserInteractionEnabled = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        pin(button, to: cell.contentView)
        button.addSubview(imageView)
        button.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: button.topAnchor, constant: Layout.themeImageTopInset),
            imageView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Layout.themeImageHorizontalInset),
            imageView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Layout.themeImageHorizontalInset),

            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: Layout.themeImageToTitleSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Layout.themeTitleHorizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Layout.themeTitleHorizontalInset),
            titleLabel.bottomAnchor.constraint(equalTo: button.bottomAnchor, constant: -Layout.themeTitleBottomInset),
            titleLabel.heightAnchor.constraint(equalToConstant: Layout.themeTitleHeight)
        ])
    }

    private func configureFeelingLuckyCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        configureSecondaryActionCard(
            in: cell,
            accessibilityIdentifier: Content.feelingLuckyAccessibilityID,
            accessibilityLabel: L10n.Home.feelingLucky,
            accessibilityHint: L10n.Home.feelingLuckyAccessibilityHint,
            title: L10n.Home.feelingLucky,
            action: #selector(feelingLuckyButtonTouchedUpInside(_:)),
            appearance: appearance
        )
    }

    private func configureAIThemeCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        let button = makeSecondaryActionButton(
            accessibilityIdentifier: Content.aiThemeAccessibilityID,
            accessibilityLabel: L10n.Home.createWithAI,
            accessibilityHint: L10n.Home.createWithAIAccessibilityHint,
            title: L10n.Home.createWithAI,
            action: #selector(aiThemeButtonTouchedUpInside(_:)),
            appearance: appearance
        )
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        applyRadarGreenGlowStyleIfNeeded(to: button, appearance: appearance)

        let betaBadge = InsetLabel(
            contentInsets: UIEdgeInsets(
                top: Layout.aiThemeBadgeVerticalInset,
                left: Layout.aiThemeBadgeHorizontalInset,
                bottom: Layout.aiThemeBadgeVerticalInset,
                right: Layout.aiThemeBadgeHorizontalInset
            )
        )
        betaBadge.accessibilityIdentifier = Content.aiThemeBetaBadgeAccessibilityID
        betaBadge.text = L10n.Home.createWithAIBetaBadge
        betaBadge.textColor = appearance.screenTextColor
        betaBadge.font = appearance.typography.font(size: Appearance.betaBadgeFontSize, weight: .bold)
        betaBadge.textAlignment = .center
        betaBadge.backgroundColor = appearance.screenTextColor.withAlphaComponent(Appearance.aiThemeBadgeBackgroundAlpha)
        betaBadge.layer.cornerRadius = Appearance.aiThemeBadgeCornerRadius
        betaBadge.layer.borderWidth = Appearance.buttonBorderWidth
        betaBadge.layer.borderColor = appearance.screenTextColor.withAlphaComponent(Appearance.aiThemeBadgeBorderAlpha).cgColor
        betaBadge.clipsToBounds = true
        betaBadge.isUserInteractionEnabled = false
        betaBadge.translatesAutoresizingMaskIntoConstraints = false

        pin(button, to: cell.contentView)
        button.addSubview(betaBadge)
        let gradientBorderView: GradientBorderView?
        if appearance.designStyle == .radar {
            gradientBorderView = nil
        } else {
            let borderView = GradientBorderView(
                colors: [Appearance.aiThemeGradientPink, Appearance.aiThemeGradientBlue],
                lineWidth: Appearance.aiThemeGradientBorderWidth
            )
            borderView.accessibilityIdentifier = Content.aiThemeGradientBorderAccessibilityID
            borderView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(borderView)
            gradientBorderView = borderView
        }

        NSLayoutConstraint.activate([
            betaBadge.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Layout.aiThemeBadgeTrailingInset),
            betaBadge.centerYAnchor.constraint(equalTo: button.centerYAnchor),

            betaBadge.leadingAnchor.constraint(greaterThanOrEqualTo: button.centerXAnchor),
            betaBadge.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.aiThemeBadgeMinimumWidth)
        ])

        if let gradientBorderView {
            NSLayoutConstraint.activate([
                gradientBorderView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                gradientBorderView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                gradientBorderView.topAnchor.constraint(equalTo: button.topAnchor),
                gradientBorderView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
        }
    }

    private func configureSecondaryActionCard(
        in cell: UICollectionViewCell,
        accessibilityIdentifier: String,
        accessibilityLabel: String,
        accessibilityHint: String,
        title: String,
        action: Selector,
        appearance: AppAppearance
    ) {
        let button = makeSecondaryActionButton(
            accessibilityIdentifier: accessibilityIdentifier,
            accessibilityLabel: accessibilityLabel,
            accessibilityHint: accessibilityHint,
            title: title,
            action: action,
            appearance: appearance
        )

        pin(button, to: cell.contentView)
    }

    private func makeSecondaryActionButton(
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

    private func configureStatisticsCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        let summary = statisticsStore.loadSummary()
        let accuracyDisplay = "\(summary.percentage)%"

        let button = UIButton(type: .system)
        button.accessibilityIdentifier = Content.statisticsAccessibilityID
        button.accessibilityLabel = L10n.Home.statisticsAccessibilityLabel
        button.accessibilityHint = L10n.Home.statisticsAccessibilityHint
        button.accessibilityValue = L10n.Home.statisticsAccessibilityValue(
            playedQuizzes: summary.playedQuizzes,
            percentage: summary.percentage
        )
        button.applyActionAppearance(appearance.row, appearance: appearance, textColor: appearance.surfaceTextColor)
        applyCleanOutlineStyleIfNeeded(
            to: button,
            appearance: appearance,
            borderColor: appearance.screenTextColor.withAlphaComponent(0.18)
        )
        applyRadarTransparentStyleIfNeeded(to: button, appearance: appearance)
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(statisticsButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)

        let titleLabel = UILabel()
        titleLabel.text = L10n.Statistics.title
        titleLabel.textColor = appearance.surfaceTextColor
        titleLabel.font = appearance.typography.font(size: Appearance.titleFontSize, weight: .bold)
        titleLabel.textAlignment = .left
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = L10n.Home.statisticsDescription
        descriptionLabel.textColor = appearance.secondarySurfaceTextColor
        descriptionLabel.font = appearance.typography.font(size: Appearance.descriptionFontSize, weight: .semibold)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let textStackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        textStackView.axis = .vertical
        textStackView.alignment = .leading
        textStackView.spacing = Layout.statisticsStackSpacing
        textStackView.isUserInteractionEnabled = false
        textStackView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textStackView.translatesAutoresizingMaskIntoConstraints = false

        let playedMetricView = makeStatisticsMetricView(
            title: L10n.Home.statisticsPlayedShort,
            value: "\(summary.playedQuizzes)",
            titleAccessibilityIdentifier: Content.statisticsPlayedTitleAccessibilityID,
            valueAccessibilityIdentifier: Content.statisticsPlayedValueAccessibilityID,
            appearance: appearance
        )
        let accuracyMetricView = makeStatisticsMetricView(
            title: L10n.Home.statisticsAccuracyShort,
            value: accuracyDisplay,
            titleAccessibilityIdentifier: Content.statisticsAccuracyTitleAccessibilityID,
            valueAccessibilityIdentifier: Content.statisticsAccuracyValueAccessibilityID,
            appearance: appearance
        )

        let metricsStackView = UIStackView(arrangedSubviews: [playedMetricView, accuracyMetricView])
        metricsStackView.axis = .vertical
        metricsStackView.alignment = .fill
        metricsStackView.spacing = Layout.statisticsMetricsSpacing
        metricsStackView.isUserInteractionEnabled = false
        metricsStackView.setContentCompressionResistancePriority(.required, for: .horizontal)
        metricsStackView.translatesAutoresizingMaskIntoConstraints = false

        let contentStackView = UIStackView(arrangedSubviews: [textStackView, metricsStackView])
        contentStackView.axis = .horizontal
        contentStackView.alignment = .center
        contentStackView.distribution = .fill
        contentStackView.spacing = Layout.statisticsContentSpacing
        contentStackView.isUserInteractionEnabled = false
        contentStackView.translatesAutoresizingMaskIntoConstraints = false

        pin(button, to: cell.contentView)
        button.addSubview(contentStackView)

        NSLayoutConstraint.activate([
            contentStackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Layout.cardContentHorizontalInset),
            contentStackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Layout.cardContentHorizontalInset),
            contentStackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }

    private func makeStatisticsMetricView(
        title: String,
        value: String,
        titleAccessibilityIdentifier: String,
        valueAccessibilityIdentifier: String,
        appearance: AppAppearance
    ) -> UIStackView {
        let valueLabel = UILabel()
        valueLabel.accessibilityIdentifier = valueAccessibilityIdentifier
        valueLabel.text = value
        valueLabel.textColor = appearance.surfaceTextColor
        valueLabel.font = appearance.typography.font(size: Appearance.statisticsMetricValueFontSize, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.8
        valueLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.accessibilityIdentifier = titleAccessibilityIdentifier
        titleLabel.text = title
        titleLabel.textColor = appearance.secondarySurfaceTextColor
        titleLabel.font = appearance.typography.font(size: Appearance.statisticsMetricTitleFontSize, weight: .semibold)
        titleLabel.textAlignment = .left
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [titleLabel, valueLabel])
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.spacing = Layout.statisticsMetricSpacing
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }

    private func applyCleanOutlineStyleIfNeeded(to button: UIButton, appearance: AppAppearance, borderColor: UIColor) {
        guard appearance.designStyle == .clean else { return }
        button.backgroundColor = appearance.card.backgroundColor
        button.layer.borderColor = borderColor.cgColor
        button.layer.borderWidth = max(button.layer.borderWidth, Appearance.buttonBorderWidth)
    }

    private func applyRadarTransparentStyleIfNeeded(to button: UIButton, appearance: AppAppearance) {
        guard appearance.designStyle == .radar else { return }
        button.backgroundColor = .clear
    }

    private func applyRadarGreenGlowStyleIfNeeded(to button: UIButton, appearance: AppAppearance) {
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
    }

    private func pin(_ view: UIView, to container: UIView) {
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func themeImageAccessibilityIdentifier(themeID: String) -> String {
        "\(Content.themeImageAccessibilityIDPrefix)-\(themeID)"
    }

    private func themeTitleAccessibilityIdentifier(themeID: String) -> String {
        "\(Content.themeTitleAccessibilityIDPrefix)-\(themeID)"
    }

    private func themeLogoImageName(for themeID: String, appearance: AppAppearance) -> String {
        ThemeVisualCatalog.logoImageName(for: themeID, designStyle: appearance.designStyle)
    }

    private func themeTintColor(for themeID: String) -> UIColor {
        ThemeVisualCatalog.tintColor(for: themeID)
    }

    @objc func buttonTouchedDown(_ sender: UIButton) {
        delegate?.themeButtonTouchedDown(sender)
    }

    @objc func buttonTouchedUpInside(_ sender: UIButton) {
        guard
            let themeID = sender.accessibilityIdentifier,
            themeRepository.themes?.contains(where: { $0.stableID == themeID }) == true
        else { return }
        delegate?.themeButtonTouchedUpInside(sender, themeID: themeID)
    }

    @objc func buttonTouchedUpOutside(_ sender: UIButton) {
        delegate?.themeButtonTouchedUpOutside(sender)
    }

    @objc func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.feelingLuckyButtonTouchedUpInside(sender)
    }

    @objc func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.aiThemeButtonTouchedUpInside(sender)
    }

    @objc func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.statisticsButtonTouchedUpInside(sender)
    }

}

private struct ThemeVisualDescriptor {
    let classicLogoName: String
    let cleanLogoName: String
    let radarLogoName: String
    let tintColorName: String

    func logoName(for designStyle: AppDesignStyle) -> String {
        switch designStyle {
        case .clean:
            return cleanLogoName
        case .radar:
            return radarLogoName
        case .pixel, .classic:
            return classicLogoName
        }
    }
}

private enum ThemeVisualCatalog {
    private static let descriptors: [String: ThemeVisualDescriptor] = [
        "music": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.musicThemeLogoImageName,
            cleanLogoName: ThemesCollectionService.Content.musicThemeLogoCleanImageName,
            radarLogoName: ThemesCollectionService.Content.musicThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.musicThemeTintColorName
        ),
        "technology": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.technologyThemeLogoImageName,
            cleanLogoName: ThemesCollectionService.Content.technologyThemeLogoCleanImageName,
            radarLogoName: ThemesCollectionService.Content.technologyThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.technologyThemeTintColorName
        ),
        "history_culture": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.cultureThemeLogoImageName,
            cleanLogoName: ThemesCollectionService.Content.cultureThemeLogoCleanImageName,
            radarLogoName: ThemesCollectionService.Content.cultureThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.cultureThemeTintColorName
        ),
        "politics_business": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.politicsThemeLogoImageName,
            cleanLogoName: ThemesCollectionService.Content.politicsThemeLogoCleanImageName,
            radarLogoName: ThemesCollectionService.Content.politicsThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.politicsThemeTintColorName
        )
    ]

    static func logoImageName(for themeID: String, designStyle: AppDesignStyle) -> String {
        descriptors[themeID]?.logoName(for: designStyle) ?? themeID
    }

    static func tintColor(for themeID: String) -> UIColor {
        guard let colorName = descriptors[themeID]?.tintColorName else { return .white }
        return UIColor(named: colorName) ?? .white
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

private final class InsetLabel: UILabel {
    private let contentInsets: UIEdgeInsets

    init(contentInsets: UIEdgeInsets) {
        self.contentInsets = contentInsets
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}

private final class GradientBorderView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()
    private let lineWidth: CGFloat

    init(colors: [UIColor], lineWidth: CGFloat) {
        self.lineWidth = lineWidth
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.mask = borderMaskLayer
        layer.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        let inset = lineWidth / 2
        let cornerRadius = max((superview?.layer.cornerRadius ?? 0) - inset, 0)
        borderMaskLayer.frame = bounds
        borderMaskLayer.fillColor = UIColor.clear.cgColor
        borderMaskLayer.strokeColor = UIColor.black.cgColor
        borderMaskLayer.lineWidth = lineWidth
        borderMaskLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: inset, dy: inset),
            cornerRadius: cornerRadius
        ).cgPath
    }
}
