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
        static let feelingLuckyProgressAccessibilityID = "homeFeelingLuckyProgressView"
        static let statisticsAccessibilityID = "homeStatisticsCard"
        static let statisticsTitleAccessibilityID = "homeStatisticsTitleLabel"
        static let statisticsDescriptionAccessibilityID = "homeStatisticsDescriptionLabel"
        static let statisticsPlayedValueAccessibilityID = "homeStatisticsPlayedValueLabel"
        static let statisticsPlayedTitleAccessibilityID = "homeStatisticsPlayedTitleLabel"
        static let statisticsAccuracyValueAccessibilityID = "homeStatisticsAccuracyValueLabel"
        static let statisticsAccuracyTitleAccessibilityID = "homeStatisticsAccuracyTitleLabel"

        static let musicThemeLogoCleanSymbolName = "music.note.square.stack"
        static let technologyThemeLogoCleanSymbolName = "gamecontroller"
        static let cultureThemeLogoCleanSymbolName = "theatermask.and.paintbrush"
        static let politicsThemeLogoCleanSymbolName = "building.columns"
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
        static let lastItemBottomInset: CGFloat = 24
        static let aiThemeBadgeTrailingInset: CGFloat = 16
        static let aiThemeBadgeHorizontalInset: CGFloat = 10
        static let aiThemeBadgeVerticalInset: CGFloat = 5
        static let aiThemeBadgeMinimumWidth: CGFloat = 48
        static let cellShadowOffset = CGSize(width: 0, height: 12)
        static let cellShadowRadius: CGFloat = 22
    }

    private enum Appearance {
        static let themeCardBackgroundAlpha: CGFloat = 0.20
        static let themeCardBorderAlpha: CGFloat = 0.45
        static let themeCardCornerRadius: CGFloat = 28
        static let feelingLuckyButtonBackgroundAlpha: CGFloat = 0.14
        static let feelingLuckyButtonBorderAlpha: CGFloat = 0.36
        static let feelingLuckyButtonCornerRadius: CGFloat = 20
        static let buttonBorderWidth: CGFloat = 1
        static let aiThemeGradientBorderWidth: CGFloat = 1.6
        static let radarAIThemeGlowOpacity: Float = 0.22
        static let radarAIThemeGlowRadius: CGFloat = 10
        static let radarAIThemeGlowOffset = CGSize(width: 0, height: 0)
        static let aiThemeBadgeBackgroundAlpha: CGFloat = 0.18
        static let aiThemeBadgeBorderAlpha: CGFloat = 0.52
        static let aiThemeBadgeCornerRadius: CGFloat = 11
        static let cellShadowOpacity: Float = 0.22
        static let titleFontSize: CGFloat = 24
        static let descriptionFontSize: CGFloat = 15
        static let luckyFontSize: CGFloat = 19
        static let betaBadgeFontSize: CGFloat = 12
    }

    weak var delegate: ThemeCollectionDelegate?

    var presentedThemeID: String? {
        didSet {
            guard oldValue != presentedThemeID else { return }
            reconfigureThemeCells(withIDs: [oldValue, presentedThemeID].compactMap { $0 })
        }
    }

    var isStatisticsPresented = false {
        didSet {
            guard oldValue != isStatisticsPresented else { return }
            reconfigureStatisticsCell()
        }
    }

    var isAIThemePresented = false {
        didSet {
            guard oldValue != isAIThemePresented else { return }
            reconfigureAIThemeCell()
        }
    }

    var isFeelingLuckyLoading = false {
        didSet {
            guard oldValue != isFeelingLuckyLoading else { return }
            refreshVisibleFeelingLuckyButton()
        }
    }

    private let themeRepository: ThemeRepository
    private let statisticsStore: StatisticsStore
    private let preferredThemeIDsProvider: () -> Set<String>
    private let appearanceStore = AppAppearanceStore.shared
    private weak var observedCollectionView: UICollectionView?

    private var displayedThemes: [QuizTheme] {
        let themes = themeRepository.themes ?? []
        let preferredThemeIDs = preferredThemeIDsProvider()
        guard !preferredThemeIDs.isEmpty else { return themes }

        return themes.enumerated()
            .sorted { lhs, rhs in
                let lhsIsPreferred = preferredThemeIDs.contains(lhs.element.stableID)
                let rhsIsPreferred = preferredThemeIDs.contains(rhs.element.stableID)
                if lhsIsPreferred != rhsIsPreferred {
                    return lhsIsPreferred
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }
    }

    private var themeCount: Int { displayedThemes.count }

    private var aiThemeIndex: Int { themeCount }

    private var feelingLuckyIndex: Int { themeCount + 1 }

    private var statisticsIndex: Int { themeCount + 2 }

    init(
        themeRepository: ThemeRepository = QuizFactory.shared,
        statisticsStore: StatisticsStore = StatisticsStore(),
        preferredThemeIDsProvider: @escaping () -> Set<String> = {
            OnboardingProgressStore.shared.preferredThemeIDs
        }
    ) {
        self.themeRepository = themeRepository
        self.statisticsStore = statisticsStore
        self.preferredThemeIDsProvider = preferredThemeIDsProvider
        super.init()
    }

    func refreshStatistics() {
        reconfigureStatisticsCell()
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int { themeCount + 3 }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        observedCollectionView = collectionView
        let appearance = appearanceStore.appearance(compatibleWith: collectionView.traitCollection)

        if let theme = displayedThemes[safe: indexPath.item] {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ThemeCardCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? ThemeCardCollectionViewCell else {
                preconditionFailure("Expected ThemeCardCollectionViewCell for catalog theme")
            }
            cell.configure(
                theme: theme,
                appearance: appearance,
                isSourceHidden: theme.stableID == presentedThemeID
            )
            cell.actionButton.removeTarget(self, action: nil, for: .allEvents)
            cell.actionButton.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
            cell.actionButton.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
            cell.actionButton.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
            return cell
        }

        if indexPath.item == statisticsIndex {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: StatisticsCardCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? StatisticsCardCollectionViewCell else {
                preconditionFailure("Expected StatisticsCardCollectionViewCell")
            }
            cell.configure(
                summary: statisticsStore.loadSummary(),
                appearance: appearance,
                isSourceHidden: isStatisticsPresented
            )
            cell.actionButton.removeTarget(self, action: nil, for: .allEvents)
            cell.actionButton.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
            cell.actionButton.addTarget(self, action: #selector(statisticsButtonTouchedUpInside(_:)), for: .touchUpInside)
            cell.actionButton.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
            return cell
        }

        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: Content.themeCellReuseIdentifier,
            for: indexPath
        )
        prepare(cell, appearance: appearance)

        if indexPath.item == feelingLuckyIndex {
            configureFeelingLuckyCard(in: cell, appearance: appearance)
            return cell
        }

        if indexPath.item == aiThemeIndex {
            configureAIThemeCard(in: cell, appearance: appearance)
            return cell
        }

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = max(collectionView.bounds.width - Layout.sectionInsets.left - Layout.sectionInsets.right, 0)
        if indexPath.item == statisticsIndex {
            return CGSize(
                width: availableWidth,
                height: Layout.statisticsCardHeight + Layout.lastItemBottomInset
            )
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

    private func configureFeelingLuckyCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
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

    private func configureAIThemeCard(in cell: UICollectionViewCell, appearance: AppAppearance) {
        cell.applyShadow(.none)
        let button = makeSecondaryActionButton(
            accessibilityIdentifier: Content.aiThemeAccessibilityID,
            accessibilityLabel: L10n.Home.createWithAI,
            accessibilityHint: L10n.Home.createWithAIAccessibilityHint,
            title: L10n.Home.createWithAI,
            action: #selector(aiThemeButtonTouchedUpInside(_:)),
            appearance: appearance
        )
        button.isHidden = isAIThemePresented
        button.isEnabled = !isAIThemePresented
        button.isAccessibilityElement = !isAIThemePresented
        button.accessibilityElementsHidden = isAIThemePresented
        button.layer.borderWidth = 0
        button.layer.borderColor = UIColor.clear.cgColor
        applyRadarGreenGlowStyleIfNeeded(to: button, appearance: appearance)
        let aiThemeCornerRadius = Layout.secondaryActionButtonHeight / 2

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
        betaBadge.adjustsFontForContentSizeCategory = true
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

    @discardableResult
    private func configureSecondaryActionCard(
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

    private func configureFeelingLuckyContent(in button: UIButton, appearance: AppAppearance) {
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

    private func applyFeelingLuckyLoadingState(
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

    private func refreshVisibleFeelingLuckyButton() {
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

    private func pin(_ view: UIView, to container: UIView, bottomInset: CGFloat = .zero) {
        container.addSubview(view)

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            view.topAnchor.constraint(equalTo: container.topAnchor),
            view.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -bottomInset)
        ])
    }

    private func reconfigureThemeCells(withIDs themeIDs: [String]) {
        guard
            let collectionView = observedCollectionView,
            !themeIDs.isEmpty
        else {
            return
        }

        let identifiers = Set(themeIDs)
        let indexPaths = displayedThemes.enumerated().compactMap { index, theme in
            identifiers.contains(theme.stableID) ? IndexPath(item: index, section: 0) : nil
        }
        guard !indexPaths.isEmpty else { return }

        UIView.performWithoutAnimation {
            collectionView.reconfigureItems(at: indexPaths)
        }
    }

    private func reconfigureStatisticsCell() {
        guard let collectionView = observedCollectionView else { return }
        let indexPath = IndexPath(item: statisticsIndex, section: 0)
        guard collectionView.numberOfItems(inSection: 0) > indexPath.item else { return }

        UIView.performWithoutAnimation {
            collectionView.reconfigureItems(at: [indexPath])
        }
    }

    private func reconfigureAIThemeCell() {
        guard let collectionView = observedCollectionView else { return }
        let indexPath = IndexPath(item: aiThemeIndex, section: 0)
        guard collectionView.numberOfItems(inSection: 0) > indexPath.item else { return }

        UIView.performWithoutAnimation {
            collectionView.reconfigureItems(at: [indexPath])
        }
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
