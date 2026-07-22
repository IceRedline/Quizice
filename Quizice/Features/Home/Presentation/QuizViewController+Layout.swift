import UIKit

extension QuizViewController {
    func configureProgrammaticSubviews(in rootView: UIView) {
        configureHeaderViews()
        configureSettingsButton()
        configureHeaderStack()
        configureThemesCollectionView()
        configureScreenStack()
        configureInitialStartupVisibilityIfNeeded()

        rootView.addSubview(headerStackView)
        rootView.addSubview(screenStackView)
        rootView.addSubview(settingsButton)
        applyLayerOrdering()
        activateLayoutConstraints(in: rootView)
    }

    func configureThemesCollectionService() {
        themesCollectionView.backgroundColor = .clear
        themesCollectionService.delegate = self
        themesCollectionView.delegate = themesCollectionService
        themesCollectionView.dataSource = themesCollectionService
        themesCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: Content.themeCellReuseIdentifier)
        themesCollectionView.register(
            ThemeCardCollectionViewCell.self,
            forCellWithReuseIdentifier: ThemeCardCollectionViewCell.reuseIdentifier
        )
        themesCollectionView.register(
            StatisticsCardCollectionViewCell.self,
            forCellWithReuseIdentifier: StatisticsCardCollectionViewCell.reuseIdentifier
        )
    }

    func configureHeaderViews() {
        let typography = currentAppearance().typography
        motivationContainerView = UIView()
        motivationContainerView.translatesAutoresizingMaskIntoConstraints = false

        motivationLabel = makeLabel(text: motivationPromptProvider(nil), font: typography.font(size: Typography.motivationFontSize, weight: .bold))
        motivationLabel.numberOfLines = 2
        motivationLabel.accessibilityIdentifier = AccessibilityID.motivationLabel
        motivationLabel.adjustsFontForContentSizeCategory = true

        motivationContainerView.addSubview(motivationLabel)

        NSLayoutConstraint.activate([
            motivationLabel.leadingAnchor.constraint(equalTo: motivationContainerView.leadingAnchor),
            motivationLabel.trailingAnchor.constraint(equalTo: motivationContainerView.trailingAnchor),
            motivationLabel.topAnchor.constraint(equalTo: motivationContainerView.topAnchor),
            motivationLabel.bottomAnchor.constraint(equalTo: motivationContainerView.bottomAnchor)
        ])

#if DEBUG
        debugCatalogSourceLabel = InsetLabel(
            contentInsets: UIEdgeInsets(top: 4, left: 7, bottom: 4, right: 7)
        )
        debugCatalogSourceLabel.accessibilityIdentifier = AccessibilityID.backendCatalogSource
        debugCatalogSourceLabel.font = .monospacedSystemFont(
            ofSize: Typography.backendSourceFontSize,
            weight: .semibold
        )
        debugCatalogSourceLabel.textColor = .white
        debugCatalogSourceLabel.layer.cornerRadius = 9
        debugCatalogSourceLabel.clipsToBounds = true
        debugCatalogSourceLabel.isHidden = !DebugBackendSettings.shouldShowSourceIndicators
        debugCatalogSourceLabel.setContentHuggingPriority(.required, for: .horizontal)
        debugCatalogSourceLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        updateDebugCatalogSourceIndicator()
#endif
    }

    func configureSettingsButton() {
        settingsButton = UIButton(type: .system)
        settingsButtonVisualSurface = UIView()
        settingsButtonVisualSurface.accessibilityIdentifier = AccessibilityID.settingsVisualSurface
        settingsButtonVisualSurface.isUserInteractionEnabled = false
        settingsButtonVisualSurface.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.accessibilityIdentifier = AccessibilityID.settingsButton
        settingsButton.accessibilityLabel = L10n.Settings.title
        let settingsIcon = UIImage(
            systemName: Content.settingsIconName,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: Typography.settingsIconPointSize, weight: .semibold)
        )
        settingsButton.setImage(settingsIcon, for: .normal)
        settingsButton.tintColor = .white
        settingsButton.insertSubview(settingsButtonVisualSurface, at: 0)
        NSLayoutConstraint.activate([
            settingsButtonVisualSurface.centerXAnchor.constraint(equalTo: settingsButton.centerXAnchor),
            settingsButtonVisualSurface.centerYAnchor.constraint(equalTo: settingsButton.centerYAnchor),
            settingsButtonVisualSurface.widthAnchor.constraint(equalToConstant: Layout.settingsButtonVisualSize),
            settingsButtonVisualSurface.heightAnchor.constraint(equalToConstant: Layout.settingsButtonVisualSize)
        ])
        settingsButton.translatesAutoresizingMaskIntoConstraints = false
        settingsButton.addTarget(self, action: #selector(settingsButtonTapped), for: .touchUpInside)
#if DEBUG
        settingsButton.showsMenuAsPrimaryAction = false
        settingsButton.changesSelectionAsPrimaryAction = false
#endif
        settingsButton.installPressFeedback()
    }

    func configureHeaderStack() {
        var arrangedSubviews: [UIView] = [motivationContainerView]
#if DEBUG
        arrangedSubviews.append(debugCatalogSourceLabel)
#endif
        headerStackView = UIStackView(arrangedSubviews: arrangedSubviews)
        headerStackView.accessibilityIdentifier = AccessibilityID.headerStackView
        headerStackView.axis = .vertical
        headerStackView.alignment = .leading
        headerStackView.spacing = Layout.headerStackSpacing
        headerStackView.isLayoutMarginsRelativeArrangement = true
        headerStackView.directionalLayoutMargins = Layout.headerMargins
        headerStackView.isUserInteractionEnabled = false
        headerStackView.translatesAutoresizingMaskIntoConstraints = false
    }

#if DEBUG
    func updateDebugCatalogSourceIndicator() {
        guard let debugCatalogSourceLabel else { return }
        debugCatalogSourceLabel.text = debugCatalogSourceState.title
        debugCatalogSourceLabel.accessibilityLabel = debugCatalogSourceState.title
        switch debugCatalogSourceState {
        case .loading:
            debugCatalogSourceLabel.backgroundColor = .systemGray
        case .backend:
            debugCatalogSourceLabel.backgroundColor = .systemGreen
        case .backendStale:
            debugCatalogSourceLabel.backgroundColor = .systemYellow
        case .local:
            debugCatalogSourceLabel.backgroundColor = .systemOrange
        }
    }
#endif

    func configureThemesCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = Layout.collectionItemSpacing
        layout.minimumInteritemSpacing = Layout.collectionItemSpacing
        layout.sectionInset = Layout.collectionSectionInsets

        themesCollectionView = HomeThemesCollectionView(frame: .zero, collectionViewLayout: layout)
        themesCollectionView.accessibilityIdentifier = AccessibilityID.themesCollectionView
        themesCollectionView.accessibilityLabel = L10n.Home.themesCollectionAccessibilityLabel
        themesCollectionView.alwaysBounceVertical = false
        themesCollectionView.bounces = false
        themesCollectionView.canCancelContentTouches = true
        themesCollectionView.contentInsetAdjustmentBehavior = .never
        themesCollectionView.delaysContentTouches = true
        themesCollectionView.showsVerticalScrollIndicator = false
        themesCollectionView.isScrollEnabled = false
        themesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        themesCollectionView.setContentHuggingPriority(.defaultLow, for: .vertical)
        themesCollectionView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
    }

    func configureScreenStack() {
        screenStackView = UIStackView(arrangedSubviews: [themesCollectionView])
        screenStackView.accessibilityIdentifier = AccessibilityID.screenStackView
        screenStackView.axis = .vertical
        screenStackView.alignment = .fill
        screenStackView.spacing = Layout.screenStackSpacing
        screenStackView.isLayoutMarginsRelativeArrangement = false
        screenStackView.translatesAutoresizingMaskIntoConstraints = false
    }

    func applyLayerOrdering() {
        headerStackView.layer.zPosition = Appearance.headerLayerZPosition
        motivationContainerView.layer.zPosition = Appearance.headerLayerZPosition
        screenStackView.layer.zPosition = Appearance.collectionLayerZPosition
        themesCollectionView.layer.zPosition = Appearance.collectionLayerZPosition
        settingsButton.layer.zPosition = Appearance.controlsLayerZPosition
    }

    func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            screenStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            screenStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            screenStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            screenStackView.bottomAnchor.constraint(equalTo: rootView.bottomAnchor),

            headerStackView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.screenTopInset),
            headerStackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            headerStackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),

            settingsButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.settingsButtonTopInset),
            settingsButton.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.settingsButtonTrailingInset),
            settingsButton.widthAnchor.constraint(equalToConstant: Layout.settingsButtonSize),
            settingsButton.heightAnchor.constraint(equalToConstant: Layout.settingsButtonSize),

            motivationContainerView.widthAnchor.constraint(equalTo: headerStackView.layoutMarginsGuide.widthAnchor)
        ])
    }

    func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = font
        label.textAlignment = .left
        label.numberOfLines = Typography.unlimitedNumberOfLines
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    func configureInitialStartupVisibilityIfNeeded() {
        guard session.startup1st else { return }
        startupAnimatedViews.forEach { $0.alpha = AnimationTiming.initialVisibleAlpha }
    }

    func updateCollectionScrollAvailability() {
        themesCollectionView.layoutIfNeeded()
        let contentHeight = themesCollectionView.collectionViewLayout.collectionViewContentSize.height
        let viewportHeight = max(
            themesCollectionView.bounds.height - themesCollectionView.adjustedContentInset.top - themesCollectionView.adjustedContentInset.bottom,
            .zero
        )
        let shouldScroll = contentHeight > viewportHeight + Layout.scrollActivationTolerance

        let isGridInteractive = homeCardState.phase == .grid && !isQuizLaunchPending
        themesCollectionView.isScrollEnabled = shouldScroll
        themesCollectionView.alwaysBounceVertical = shouldScroll
        themesCollectionView.bounces = shouldScroll
        if !isGridInteractive {
            themesCollectionView.isScrollEnabled = false
            themesCollectionView.alwaysBounceVertical = false
            themesCollectionView.bounces = false
        }
    }

    func updateCollectionTopInset() {
        let oldTopInset = themesCollectionView.contentInset.top
        let topInset = headerStackView.bounds.height + Layout.screenTopInset + Layout.headerToCollectionSpacing
        guard abs(oldTopInset - topInset) > Layout.scrollActivationTolerance else { return }

        let contentOffsetFromTopInset = themesCollectionView.contentOffset.y + oldTopInset
        themesCollectionView.contentInset.top = topInset
        themesCollectionView.verticalScrollIndicatorInsets.top = topInset

        if !themesCollectionView.isDragging && !themesCollectionView.isDecelerating {
            themesCollectionView.contentOffset.y = contentOffsetFromTopInset - topInset
        }
    }

    func updateMotivationHeaderVisibility(for scrollView: UIScrollView) {
        let scrolledDistance = max(scrollView.contentOffset.y + scrollView.adjustedContentInset.top, .zero)
        let progress = min(scrolledDistance / Layout.motivationFadeDistance, 1)
        let alpha = 1 - progress

        motivationLabel.alpha = alpha
    }

    func animateStartupViews() {
        let visibleCells = sortedVisibleThemeCells()
        prepareStartupAnimation(visibleCells: visibleCells)

        guard !UIAccessibility.isReduceMotionEnabled else {
            startupAnimatedViews.forEach { $0.alpha = Appearance.visibleAlpha }
            visibleCells.forEach { $0.alpha = Appearance.visibleAlpha }
            return
        }

        UIView.animate(
            withDuration: AnimationTiming.revealDuration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            self.startupAnimatedViews.forEach { $0.alpha = Appearance.visibleAlpha }
        }
        animateThemeCells(visibleCells)
    }

    func sortedVisibleThemeCells() -> [UICollectionViewCell] {
        themesCollectionView.visibleCells.sorted { lhs, rhs in
            let verticalDistance = abs(lhs.frame.minY - rhs.frame.minY)
            if verticalDistance > Layout.visibleCellRowSortingTolerance {
                return lhs.frame.minY < rhs.frame.minY
            }
            return lhs.frame.minX < rhs.frame.minX
        }
    }

    func prepareStartupAnimation(visibleCells: [UICollectionViewCell]) {
        visibleCells.forEach { cell in
            cell.alpha = AnimationTiming.initialVisibleAlpha
        }
    }

    func animateThemeCells(_ visibleCells: [UICollectionViewCell]) {
        for (index, cell) in visibleCells.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * AnimationTiming.cellFadeInStagger) {
                UIView.animate(
                    withDuration: AnimationTiming.revealDuration,
                    delay: 0,
                    options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
                ) {
                    cell.alpha = Appearance.visibleAlpha
                }
            }
        }
    }
}
