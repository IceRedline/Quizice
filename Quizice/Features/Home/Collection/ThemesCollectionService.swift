import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    enum Content {
        static let themeCellReuseIdentifier = "themeCell"
        static let themeImageAccessibilityIDPrefix = "homeThemeImageView"
        static let themeTitleAccessibilityIDPrefix = "homeThemeTitleLabel"
        static let themeCatalogAccessibilityID = "homeThemeCatalogCollectionView"
        static let moreThemesAccessibilityID = "homeMoreThemesButton"
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

    }

    private enum Layout {
        static let sectionInsets = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        static let itemSpacing: CGFloat = 16
        static let visibleThemeRowCount = 4
        static let themeColumnCount = 2
        static let secondaryActionButtonHeight: CGFloat = 54
        static let statisticsCardHeight: CGFloat = 112
        static let lastItemBottomInset: CGFloat = 24
        static let aiThemeBadgeTrailingInset: CGFloat = 16
        static let aiThemeBadgeHorizontalInset: CGFloat = 10
        static let aiThemeBadgeVerticalInset: CGFloat = 5
        static let aiThemeBadgeMinimumWidth: CGFloat = 48
        static let cellShadowOffset = CGSize(width: 0, height: 12)
        static let cellShadowRadius: CGFloat = 22
        static let moreThemesButtonHeight: CGFloat = 82
        static let moreThemesVisibilityThreshold: CGFloat = 5
    }

    private enum Appearance {
        static let themeCardBackgroundAlpha: CGFloat = 0.20
        static let themeCardBorderAlpha: CGFloat = 0.45
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
    private let preferredThemeIDsProvider: () -> [String]?
    private let appearanceStore = AppAppearanceStore.shared
    private weak var observedCollectionView: UICollectionView?
    private weak var themeItemsCollectionView: UICollectionView?
    private weak var moreThemesButton: MoreThemesFadeButton?

    var catalogCollectionView: UICollectionView? {
        themeItemsCollectionView
    }

    var visibleThemeCells: [ThemeCardCollectionViewCell] {
        themeItemsCollectionView?.visibleCells.compactMap {
            $0 as? ThemeCardCollectionViewCell
        } ?? []
    }

    private var displayedThemes: [QuizTheme] {
        let themes = themeRepository.themes ?? []
        let preferredThemeIDs = preferredThemeIDsProvider()
            ?? themes.filter(\.isFavorite).map(\.stableID)
        guard !preferredThemeIDs.isEmpty else { return themes }
        let preferredRank = Dictionary(
            uniqueKeysWithValues: preferredThemeIDs.enumerated().map { ($0.element, $0.offset) }
        )

        return themes.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = preferredRank[lhs.element.stableID]
                let rhsRank = preferredRank[rhs.element.stableID]
                switch (lhsRank, rhsRank) {
                case let (.some(lhsRank), .some(rhsRank)):
                    return lhsRank < rhsRank
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.offset < rhs.offset
                }
            }
            .map { $0.element }
    }

    private var visibleThemeLimit: Int {
        Layout.visibleThemeRowCount * Layout.themeColumnCount
    }

    private var showsMoreThemesButton: Bool {
        displayedThemes.count > visibleThemeLimit
    }

    private var viewportRowCount: Int {
        min(
            Layout.visibleThemeRowCount,
            max(
                Int(ceil(Double(themeCount) / Double(Layout.themeColumnCount))),
                1
            )
        )
    }

    private var themeCount: Int { displayedThemes.count }

    private let themesViewportIndex = 0
    private let aiThemeIndex = 1
    private let feelingLuckyIndex = 2
    private let statisticsIndex = 3
    private let outerItemCount = 4

    init(
        themeRepository: ThemeRepository = QuizFactory.shared,
        statisticsStore: StatisticsStore = StatisticsStore(),
        preferredThemeIDsProvider: @escaping () -> [String]? = {
            OnboardingProgressStore.shared.storedPreferredThemeIDs(
                locale: AppLocalizationStore.shared.resolvedLanguageCode
            )
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

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if isThemeItemsCollectionView(collectionView) {
            themeItemsCollectionView = collectionView
            return themeCount
        }
        observedCollectionView = collectionView
        return outerItemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let appearance = appearanceStore.appearance(compatibleWith: collectionView.traitCollection)

        if isThemeItemsCollectionView(collectionView) {
            themeItemsCollectionView = collectionView
            guard let theme = displayedThemes[safe: indexPath.item] else {
                preconditionFailure("Expected catalog theme at \(indexPath)")
            }
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

        observedCollectionView = collectionView
        if indexPath.item == themesViewportIndex {
            guard let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: ThemesViewportCollectionViewCell.reuseIdentifier,
                for: indexPath
            ) as? ThemesViewportCollectionViewCell else {
                preconditionFailure("Expected ThemesViewportCollectionViewCell")
            }
            themeItemsCollectionView = cell.themesCollectionView
            cell.configure(
                dataSource: self,
                delegate: self,
                canScroll: displayedThemes.count > visibleThemeLimit
            )
            installMoreThemesButtonIfNeeded(in: cell)
            configureMoreThemesButton()
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
        if isThemeItemsCollectionView(collectionView) {
            let twoColumnWidth = floor((collectionView.bounds.width - Layout.itemSpacing) / 2)
            return CGSize(
                width: twoColumnWidth,
                height: themeRowHeight(
                    containing: indexPath.item,
                    cardWidth: twoColumnWidth,
                    traitCollection: collectionView.traitCollection
                )
            )
        }

        let availableWidth = max(
            collectionView.bounds.width - Layout.sectionInsets.left - Layout.sectionInsets.right,
            0
        )
        if indexPath.item == themesViewportIndex {
            return CGSize(
                width: availableWidth,
                height: themesViewportHeight(
                    width: availableWidth,
                    traitCollection: collectionView.traitCollection
                )
            )
        }

        if indexPath.item == statisticsIndex {
            return CGSize(
                width: availableWidth,
                height: Layout.statisticsCardHeight + Layout.lastItemBottomInset
            )
        }

        if indexPath.item == aiThemeIndex || indexPath.item == feelingLuckyIndex {
            return CGSize(width: availableWidth, height: Layout.secondaryActionButtonHeight)
        }

        return CGSize(width: availableWidth, height: Layout.secondaryActionButtonHeight)
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { Layout.itemSpacing }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        isThemeItemsCollectionView(collectionView) ? .zero : Layout.sectionInsets
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if let collectionView = scrollView as? UICollectionView,
           isThemeItemsCollectionView(collectionView) {
            updateMoreThemesButtonVisibility(animated: true)
            return
        }
        delegate?.themesCollectionDidScroll(scrollView)
    }

    private func themeRowHeight(
        containing itemIndex: Int,
        cardWidth: CGFloat,
        traitCollection: UITraitCollection
    ) -> CGFloat {
        let rowStartIndex = (itemIndex / Layout.themeColumnCount) * Layout.themeColumnCount
        guard rowStartIndex < themeCount else {
            return ThemeCardLayoutMetrics.singleLineHeight
        }
        let rowTitles = displayedThemes[
            rowStartIndex..<min(rowStartIndex + Layout.themeColumnCount, themeCount)
        ].map(\.theme)
        let font = appearanceStore
            .appearance(compatibleWith: traitCollection)
            .typography
            .font(size: ThemeCardLayoutMetrics.titleFontSize, weight: .semibold)
        return ThemeCardLayoutMetrics.rowHeight(
            titles: rowTitles,
            cardWidth: cardWidth,
            font: font
        )
    }

    private func isThemeItemsCollectionView(_ collectionView: UICollectionView) -> Bool {
        collectionView === themeItemsCollectionView
            || collectionView.accessibilityIdentifier == Content.themeCatalogAccessibilityID
    }

    private func themesViewportHeight(
        width: CGFloat,
        traitCollection: UITraitCollection
    ) -> CGFloat {
        let cardWidth = floor((width - Layout.itemSpacing) / 2)
        let rowHeights = (0..<viewportRowCount).map { row in
            themeRowHeight(
                containing: row * Layout.themeColumnCount,
                cardWidth: cardWidth,
                traitCollection: traitCollection
            )
        }
        return rowHeights.reduce(0, +)
            + Layout.itemSpacing * CGFloat(viewportRowCount - 1)
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
            let collectionView = themeItemsCollectionView,
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

    private func installMoreThemesButtonIfNeeded(in cell: ThemesViewportCollectionViewCell) {
        if moreThemesButton?.superview === cell.contentView {
            return
        }

        moreThemesButton?.removeFromSuperview()
        let button = MoreThemesFadeButton()
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(moreThemesButtonTapped), for: .touchUpInside)
        cell.contentView.addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: Layout.moreThemesButtonHeight)
        ])
        moreThemesButton = button
    }

    private func configureMoreThemesButton() {
        guard let button = moreThemesButton else { return }
        guard showsMoreThemesButton else {
            button.setVisible(false, animated: false)
            (themeItemsCollectionView as? HomeThemesCollectionView)?
                .updateBottomFade(visibility: 0, height: 0)
            return
        }
        guard let collectionView = themeItemsCollectionView else { return }
        button.configure(
            appearance: appearanceStore.appearance(compatibleWith: collectionView.traitCollection)
        )
        updateMoreThemesButtonVisibility(animated: false)
    }

    private func updateMoreThemesButtonVisibility(animated: Bool) {
        guard
            showsMoreThemesButton,
            let collectionView = themeItemsCollectionView,
            let button = moreThemesButton
        else { return }

        let distanceFromTop = collectionView.contentOffset.y
            + collectionView.adjustedContentInset.top
        let isVisible = distanceFromTop < Layout.moreThemesVisibilityThreshold
        button.setVisible(isVisible, animated: animated)
        (collectionView as? HomeThemesCollectionView)?.updateBottomFade(
            visibility: isVisible ? 1 : 0,
            height: Layout.moreThemesButtonHeight,
            animated: animated
        )
        if !button.isHidden {
            button.superview?.bringSubviewToFront(button)
        }
    }

    @objc private func moreThemesButtonTapped() {
        guard
            showsMoreThemesButton,
            let collectionView = themeItemsCollectionView,
            collectionView.numberOfItems(inSection: 0) > visibleThemeLimit
        else { return }

        collectionView.scrollToItem(
            at: IndexPath(item: visibleThemeLimit, section: 0),
            at: .top,
            animated: true
        )
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
