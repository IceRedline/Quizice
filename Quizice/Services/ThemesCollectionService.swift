import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum Content {
        static let themeCellReuseIdentifier = "themeCell"
        static let themeImageAccessibilityIDPrefix = "homeThemeImageView"
        static let themeTitleAccessibilityIDPrefix = "homeThemeTitleLabel"
        static let feelingLuckyAccessibilityID = "homeFeelingLuckyButton"
        static let statisticsAccessibilityID = "homeStatisticsCard"

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

    private enum ThemeID {
        static let music = "music"
        static let technology = "technology"
        static let historyCulture = "history_culture"
        static let politicsBusiness = "politics_business"
    }

    private enum Layout {
        static let sectionInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        static let itemSpacing: CGFloat = 16
        static let feelingLuckyButtonHeight: CGFloat = 54
        static let statisticsCardHeight: CGFloat = 112
        static let cardContentHorizontalInset: CGFloat = 24
        static let statisticsStackSpacing: CGFloat = 6
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
        static let cellShadowOpacity: Float = 0.22
        static let titleFontSize: CGFloat = 24
        static let descriptionFontSize: CGFloat = 15
        static let luckyFontSize: CGFloat = 19
        static let themeTitleFontSize: CGFloat = 18
    }

    weak var delegate: ThemeCollectionDelegate?

    private let quizFactory = QuizFactory.shared
    private let appearanceStore = AppAppearanceStore.shared

    private var themeCount: Int { quizFactory.themes?.count ?? 0 }

    private var feelingLuckyIndex: Int { themeCount }

    private var statisticsIndex: Int { themeCount + 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { themeCount + 2 }

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

        guard let theme = quizFactory.themes?[safe: indexPath.item] else {
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

        if indexPath.item == feelingLuckyIndex {
            return CGSize(width: availableWidth, height: Layout.feelingLuckyButtonHeight)
        }

        let twoColumnWidth = floor((availableWidth - Layout.itemSpacing) / 2)
        return CGSize(width: twoColumnWidth, height: twoColumnWidth)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets { Layout.sectionInsets }

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
        button.adjustsImageWhenHighlighted = false
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
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = Content.feelingLuckyAccessibilityID
        button.accessibilityLabel = L10n.Home.feelingLucky
        button.accessibilityHint = L10n.Home.feelingLuckyAccessibilityHint
        button.applyActionAppearance(appearance.secondaryButton, appearance: appearance)
        applyCleanOutlineStyleIfNeeded(
            to: button,
            appearance: appearance,
            borderColor: appearance.screenTextColor.withAlphaComponent(0.18)
        )
        button.clipsToBounds = true
        button.setTitle(L10n.Home.feelingLucky, for: .normal)
        button.setTitleColor(appearance.screenTextColor, for: .normal)
        button.titleLabel?.font = appearance.typography.font(size: Appearance.luckyFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(feelingLuckyButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)

        pin(button, to: cell.contentView)
    }

    private func configureStatisticsCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = Content.statisticsAccessibilityID
        button.accessibilityLabel = L10n.Home.statisticsAccessibilityLabel
        button.accessibilityHint = L10n.Home.statisticsAccessibilityHint
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
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = L10n.Home.statisticsDescription
        descriptionLabel.textColor = appearance.secondarySurfaceTextColor
        descriptionLabel.font = appearance.typography.font(size: Appearance.descriptionFontSize, weight: .semibold)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false

        let stackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = Layout.statisticsStackSpacing
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false

        pin(button, to: cell.contentView)
        button.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: Layout.cardContentHorizontalInset),
            stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -Layout.cardContentHorizontalInset),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
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
        switch appearance.designStyle {
        case .clean:
            return cleanThemeLogoImageName(for: themeID)
        case .radar:
            return radarThemeLogoImageName(for: themeID)
        case .pixel, .classic:
            return classicThemeLogoImageName(for: themeID)
        }
    }

    private func cleanThemeLogoImageName(for themeID: String) -> String {
        switch themeID {
        case ThemeID.music:
            return Content.musicThemeLogoCleanImageName
        case ThemeID.technology:
            return Content.technologyThemeLogoCleanImageName
        case ThemeID.historyCulture:
            return Content.cultureThemeLogoCleanImageName
        case ThemeID.politicsBusiness:
            return Content.politicsThemeLogoCleanImageName
        default:
            return themeID
        }
    }

    private func radarThemeLogoImageName(for themeID: String) -> String {
        switch themeID {
        case ThemeID.music:
            return Content.musicThemeLogoRadarImageName
        case ThemeID.technology:
            return Content.technologyThemeLogoRadarImageName
        case ThemeID.historyCulture:
            return Content.cultureThemeLogoRadarImageName
        case ThemeID.politicsBusiness:
            return Content.politicsThemeLogoRadarImageName
        default:
            return themeID
        }
    }

    private func classicThemeLogoImageName(for themeID: String) -> String {
        switch themeID {
        case ThemeID.music:
            return Content.musicThemeLogoImageName
        case ThemeID.technology:
            return Content.technologyThemeLogoImageName
        case ThemeID.historyCulture:
            return Content.cultureThemeLogoImageName
        case ThemeID.politicsBusiness:
            return Content.politicsThemeLogoImageName
        default:
            return themeID
        }
    }

    private func themeTintColor(for themeID: String) -> UIColor {
        let colorName: String
        switch themeID {
        case ThemeID.music:
            colorName = Content.musicThemeTintColorName
        case ThemeID.technology:
            colorName = Content.technologyThemeTintColorName
        case ThemeID.historyCulture:
            colorName = Content.cultureThemeTintColorName
        case ThemeID.politicsBusiness:
            colorName = Content.politicsThemeTintColorName
        default:
            return .white
        }

        return UIColor(named: colorName) ?? .white
    }

    @objc func buttonTouchedDown(_ sender: UIButton) {
        delegate?.themeButtonTouchedDown(sender)
    }

    @objc func buttonTouchedUpInside(_ sender: UIButton) {
        guard
            let themeID = sender.accessibilityIdentifier,
            quizFactory.themes?.contains(where: { $0.stableID == themeID }) == true
        else { return }
        delegate?.themeButtonTouchedUpInside(sender, themeID: themeID)
    }

    @objc func buttonTouchedUpOutside(_ sender: UIButton) {
        delegate?.themeButtonTouchedUpOutside(sender)
    }

    @objc func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.feelingLuckyButtonTouchedUpInside(sender)
    }

    @objc func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.statisticsButtonTouchedUpInside(sender)
    }

}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
