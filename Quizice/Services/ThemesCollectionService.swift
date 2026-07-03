import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    private enum Content {
        static let themeCellReuseIdentifier = "themeCell"
        static let feelingLuckyAccessibilityID = "homeFeelingLuckyButton"
        static let statisticsAccessibilityID = "homeStatisticsCard"
    }

    private enum Layout {
        static let sectionInsets = UIEdgeInsets(top: 0, left: 24, bottom: 32, right: 24)
        static let itemSpacing: CGFloat = 16
        static let feelingLuckyButtonHeight: CGFloat = 54
        static let statisticsCardHeight: CGFloat = 112
        static let cardContentHorizontalInset: CGFloat = 24
        static let statisticsStackSpacing: CGFloat = 6
        static let themeImageInset: CGFloat = 18
        static let cellShadowOffset = CGSize(width: 0, height: 12)
        static let cellShadowRadius: CGFloat = 22
    }

    private enum Appearance {
        static let themeCardBackgroundAlpha: CGFloat = 0.14
        static let themeCardBorderAlpha: CGFloat = 0.28
        static let themeCardCornerRadius: CGFloat = 28
        static let statisticsCardBackgroundAlpha: CGFloat = 0.18
        static let statisticsCardBorderAlpha: CGFloat = 0.40
        static let statisticsCardCornerRadius: CGFloat = 30
        static let feelingLuckyButtonBackgroundAlpha: CGFloat = 0.14
        static let feelingLuckyButtonBorderAlpha: CGFloat = 0.36
        static let feelingLuckyButtonCornerRadius: CGFloat = 20
        static let buttonBorderWidth: CGFloat = 1
        static let cellShadowOpacity: Float = 0.22
        static let titleFontSize: CGFloat = 22
        static let descriptionFontSize: CGFloat = 15
        static let luckyFontSize: CGFloat = 19
    }

    weak var delegate: ThemeCollectionDelegate?

    private let quizFactory = QuizFactory.shared

    private var themeCount: Int {
        quizFactory.themes?.count ?? 0
    }

    private var feelingLuckyIndex: Int {
        themeCount
    }

    private var statisticsIndex: Int {
        themeCount + 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        themeCount + 2
    }

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

        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeName
        button.accessibilityLabel = L10n.ThemeCard.accessibilityLabel(themeName: themeName)
        button.accessibilityHint = L10n.ThemeCard.accessibilityHint
        button.backgroundColor = UIColor.white.withAlphaComponent(Appearance.themeCardBackgroundAlpha)
        button.layer.cornerRadius = Appearance.themeCardCornerRadius
        button.layer.borderWidth = Appearance.buttonBorderWidth
        button.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.themeCardBorderAlpha).cgColor
        button.clipsToBounds = true
        button.adjustsImageWhenHighlighted = false
        button.imageEdgeInsets = UIEdgeInsets(
            top: Layout.themeImageInset,
            left: Layout.themeImageInset,
            bottom: Layout.themeImageInset,
            right: Layout.themeImageInset
        )
        button.setImage(UIImage(named: themeName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        pin(button, to: cell.contentView)
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
