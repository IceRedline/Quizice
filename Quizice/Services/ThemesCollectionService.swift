import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum Content {
        static let themeCellReuseIdentifier = "themeCell"
        static let themeImageAccessibilityIDPrefix = "homeThemeImageView"
        static let themeTitleAccessibilityIDPrefix = "homeThemeTitleLabel"
        static let feelingLuckyAccessibilityID = "homeFeelingLuckyButton"
        static let statisticsAccessibilityID = "homeStatisticsCard"

        static let musicThemeName = "Музыка"
        static let technologyThemeName = "Технологии"
        static let historyThemeName = "История"
        static let cultureThemeName = "История и культура"
        static let cultureThemeDisplayTitle = "Культура и история"
        static let politicsThemeName = "Политика"
        static let politicsBusinessThemeName = "Политика и бизнес"

        static let musicThemeLogoImageName = "theme_logo_music"
        static let technologyThemeLogoImageName = "theme_logo_tech.png"
        static let cultureThemeLogoImageName = "theme_logo_culture.png"
        static let politicsThemeLogoImageName = "theme_logo_politics"

        static let musicThemeTintColorName = "themeMusicTint"
        static let technologyThemeTintColorName = "themeTechnologyTint"
        static let cultureThemeTintColorName = "themeCultureTint"
        static let politicsThemeTintColorName = "themePoliticsTint"
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
        static let themeTitleHeight: CGFloat = 48
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
        static let themeTitleMinimumScaleFactor: CGFloat = 0.78
    }

    weak var delegate: ThemeCollectionDelegate?

    private let quizFactory = QuizFactory.shared

    private var themeCount: Int { quizFactory.themes?.count ?? 0 }

    private var feelingLuckyIndex: Int { themeCount }

    private var statisticsIndex: Int { themeCount + 1 }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { themeCount + 2 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: Content.themeCellReuseIdentifier, for: indexPath)
        prepare(cell)

        if indexPath.item == statisticsIndex {
            configureStatisticsCard(in: cell)
            return cell
        }

        if indexPath.item == feelingLuckyIndex {
            configureFeelingLuckyCard(in: cell)
            return cell
        }

        guard let theme = quizFactory.themes?[safe: indexPath.item] else {
            return cell
        }
        configureThemeCard(in: cell, themeName: theme.theme)
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

    private func prepare(_ cell: UICollectionViewCell) {
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = .clear
        cell.contentView.clipsToBounds = false
        cell.backgroundColor = .clear
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = Layout.cellShadowOffset
        cell.layer.shadowRadius = Layout.cellShadowRadius
        cell.layer.shadowOpacity = Appearance.cellShadowOpacity
    }

    private func configureThemeCard(in cell: UICollectionViewCell, themeName: String) {
        let button = UIButton(type: .custom)
        let themeImageName = themeLogoImageName(for: themeName)
        let themeDisplayTitle = themeDisplayTitle(for: themeName)
        let themeTintColor = themeTintColor(for: themeName)

        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeName
        button.accessibilityLabel = L10n.ThemeCard.accessibilityLabel(themeName: themeDisplayTitle)
        button.accessibilityHint = L10n.ThemeCard.accessibilityHint
        button.backgroundColor = themeTintColor.withAlphaComponent(Appearance.themeCardBackgroundAlpha)
        button.layer.cornerRadius = Appearance.themeCardCornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = themeTintColor.withAlphaComponent(Appearance.themeCardBorderAlpha).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false

        let imageView = UIImageView(image: UIImage(named: themeImageName))
        imageView.accessibilityIdentifier = themeImageAccessibilityIdentifier(themeName: themeName)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = false
        imageView.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = UILabel()
        titleLabel.accessibilityIdentifier = themeTitleAccessibilityIdentifier(themeName: themeName)
        titleLabel.text = themeDisplayTitle
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: Appearance.themeTitleFontSize, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 2
        titleLabel.lineBreakMode = .byWordWrapping
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = Appearance.themeTitleMinimumScaleFactor
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

    private func configureFeelingLuckyCard(in cell: UICollectionViewCell) {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = Content.feelingLuckyAccessibilityID
        button.accessibilityLabel = L10n.Home.feelingLucky
        button.accessibilityHint = L10n.Home.feelingLuckyAccessibilityHint
        button.backgroundColor = UIColor.white.withAlphaComponent(Appearance.feelingLuckyButtonBackgroundAlpha)
        button.layer.cornerRadius = Appearance.feelingLuckyButtonCornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.feelingLuckyButtonBorderAlpha).cgColor
        button.clipsToBounds = true
        button.setTitle(L10n.Home.feelingLucky, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: Appearance.luckyFontSize, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(feelingLuckyButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)

        pin(button, to: cell.contentView)
    }

    private func configureStatisticsCard(in cell: UICollectionViewCell) {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = Content.statisticsAccessibilityID
        button.accessibilityLabel = L10n.Home.statisticsAccessibilityLabel
        button.accessibilityHint = L10n.Home.statisticsAccessibilityHint
        button.backgroundColor = UIColor.white.withAlphaComponent(Appearance.statisticsCardBackgroundAlpha)
        button.layer.cornerRadius = Appearance.statisticsCardCornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.statisticsCardBorderAlpha).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(statisticsButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)

        let titleLabel = UILabel()
        titleLabel.text = L10n.Statistics.title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: Appearance.titleFontSize, weight: .bold)
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        let descriptionLabel = UILabel()
        descriptionLabel.text = L10n.Home.statisticsDescription
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.84)
        descriptionLabel.font = .systemFont(ofSize: Appearance.descriptionFontSize, weight: .semibold)
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

    private func pin(_ view: UIView, to container: UIView) {
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }

    private func themeImageAccessibilityIdentifier(themeName: String) -> String {
        "\(Content.themeImageAccessibilityIDPrefix)-\(themeName)"
    }

    private func themeTitleAccessibilityIdentifier(themeName: String) -> String {
        "\(Content.themeTitleAccessibilityIDPrefix)-\(themeName)"
    }

    private func themeDisplayTitle(for themeName: String) -> String {
        switch themeName {
        case Content.historyThemeName, Content.cultureThemeName:
            return Content.cultureThemeDisplayTitle
        case Content.politicsThemeName:
            return Content.politicsBusinessThemeName
        default:
            return themeName
        }
    }

    private func themeLogoImageName(for themeName: String) -> String {
        switch themeName {
        case Content.musicThemeName:
            return Content.musicThemeLogoImageName
        case Content.technologyThemeName:
            return Content.technologyThemeLogoImageName
        case Content.historyThemeName, Content.cultureThemeName, Content.cultureThemeDisplayTitle:
            return Content.cultureThemeLogoImageName
        case Content.politicsThemeName, Content.politicsBusinessThemeName:
            return Content.politicsThemeLogoImageName
        default:
            return themeName
        }
    }

    private func themeTintColor(for themeName: String) -> UIColor {
        let colorName: String
        switch themeName {
        case Content.musicThemeName:
            colorName = Content.musicThemeTintColorName
        case Content.technologyThemeName:
            colorName = Content.technologyThemeTintColorName
        case Content.historyThemeName, Content.cultureThemeName, Content.cultureThemeDisplayTitle:
            colorName = Content.cultureThemeTintColorName
        case Content.politicsThemeName, Content.politicsBusinessThemeName:
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
            let themeName = sender.accessibilityIdentifier,
            quizFactory.themes?.contains(where: { $0.theme == themeName }) == true
        else { return }
        delegate?.themeButtonTouchedUpInside(sender, themeName: themeName)
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
