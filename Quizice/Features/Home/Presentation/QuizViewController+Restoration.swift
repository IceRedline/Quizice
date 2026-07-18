import UIKit

extension QuizViewController {
    func setBackgroundAccessibilityHidden(_ isHidden: Bool) {
        headerStackView.accessibilityElementsHidden = isHidden
        screenStackView.accessibilityElementsHidden = isHidden
        settingsButton.accessibilityElementsHidden = isHidden
    }

    func refreshExpandedThemeCardAppearance() {
        switch homeCardState.phase {
        case .expanding, .flippingToBack, .flippingToFront:
            expandedCardNeedsRefresh = true
            return
        case .grid, .collapsing:
            return
        case .expandedFront, .expandedBack, .launching:
            break
        }

        if homeCardState.isStatisticsPresented,
           let cardView = expandedStatisticsCardView {
            expandedCardNeedsRefresh = false
            let summary = statisticsStore.loadSummary()
            expandedStatisticsSummary = summary
            cardView.configure(summary: summary, appearance: currentAppearance())
            if expandedCardBlurView == nil {
                expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                    Appearance.reducedTransparencyBackdropAlpha
                )
            }
            return
        }

        if homeCardState.isAIThemePresented,
           let cardView = expandedAIThemeCardView {
            expandedCardNeedsRefresh = false
            let face = cardView.face
            cardView.configure(state: homeAIThemeCardState, appearance: currentAppearance())
            cardView.setFace(face, animated: false)
            if expandedCardBlurView == nil {
                expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                    Appearance.reducedTransparencyBackdropAlpha
                )
            }
            return
        }

        guard
            let cardView = expandedThemeCardView,
            let themeID = homeCardState.themeID,
            let theme = themeRepository.themes?.first(where: { $0.stableID == themeID }) ?? expandedTheme
        else { return }

        expandedCardNeedsRefresh = false
        let face = cardView.face
        expandedTheme = theme
        cardView.configure(
            theme: theme,
            appearance: currentAppearance(),
            availableQuestionCounts: homeCardState.availableQuestionCounts,
            selectedQuestionCount: homeCardState.selectedQuestionCount
        )
        cardView.setFace(face, animated: false)
        updateExpandedThemeCardParallaxPhase()
        if expandedCardBlurView == nil {
            expandedCardBackdropView?.backgroundColor = currentAppearance().backgroundColor.withAlphaComponent(
                Appearance.reducedTransparencyBackdropAlpha
            )
        }
    }

    func resetExpandedThemeCard() {
        expandedCardAnimator?.stopAnimation(true)
        expandedCardAnimator = nil
        if let effect = homeStore.sendAI(.reset) {
            handleAIThemeCardEffect(effect)
        }
        removeExpandedThemeCardViews()
        homeStore.send(.reset)
        guard isViewLoaded else {
            quizTransitionSourceView = nil
            return
        }
        restoreGridAfterExpandedCard(presentedCard: nil)
    }

    func restoreHomeAfterQuizIfNeeded(force: Bool = false) {
        guard force || (isQuizLaunchPending && hasQuizLaunchStarted) else { return }
        cancelFeelingLuckyLaunch()
        quizTransitionSourceView?.isHidden = false
        isQuizLaunchPending = false
        hasQuizLaunchStarted = false
        resetExpandedThemeCard()
    }

    func removeExpandedThemeCardViews() {
        aiAlertPresentationTask?.cancel()
        aiAlertPresentationTask = nil
        aiAlertPresenter.dismiss()
        expandedAIKeyboardAnimator?.stopAnimation(true)
        expandedAIKeyboardAnimator = nil
        expandedThemeCardView?.setParallaxPresentationPhase(.inactive)
        expandedThemeCardView?.removeFromSuperview()
        expandedStatisticsCardView?.removeFromSuperview()
        expandedAIThemeCardView?.removeFromSuperview()
        expandedCardSnapshotView?.removeFromSuperview()
        expandedCardSourceContentView?.removeFromSuperview()
        expandedCardTransitionView?.removeFromSuperview()
        expandedCardInteractionButton?.removeFromSuperview()
        expandedCardBackdropDismissButton?.removeFromSuperview()
        expandedCardBackdropView?.removeFromSuperview()
        expandedThemeCardView = nil
        expandedStatisticsCardView = nil
        expandedAIThemeCardView = nil
        expandedCardSnapshotView = nil
        expandedCardSourceContentView = nil
        expandedCardSourceContentGeometry = nil
        expandedCardTransitionView = nil
        expandedCardInteractionButton = nil
        expandedCardBackdropDismissButton = nil
        expandedCardBackdropView = nil
        expandedCardBlurView = nil
        expandedTheme = nil
        expandedStatisticsSummary = nil
        aiSubmissionTask?.cancel()
        aiSubmissionTask = nil
        aiProgressTask?.cancel()
        aiProgressTask = nil
        if let effect = homeStore.sendAI(.reset) {
            handleAIThemeCardEffect(effect)
        }
        closeAfterFlipToFront = false
        focusAIThemePromptAfterFlip = false
        expandedCardNeedsRefresh = false
        expandedCardScreenViewTracked = false
        expandedCardLastTrackedFace = nil
        expandedAIKeyboardLift = 0
    }

    func updateExpandedThemeCardParallaxPhase() {
        expandedThemeCardView?.setParallaxPresentationPhase(
            homeCardState.phase.parallaxPresentationPhase
        )
    }

    func restoreGridAfterExpandedCard(presentedCard: HomePresentedCard?) {
        themesCollectionService.presentedThemeID = nil
        themesCollectionService.isStatisticsPresented = false
        themesCollectionService.isAIThemePresented = false
        themesCollectionView.isUserInteractionEnabled = true
        setBackgroundAccessibilityHidden(false)
        updateCollectionScrollAvailability()
        quizTransitionSourceView = nil

        guard let presentedCard else { return }
        themesCollectionView.layoutIfNeeded()
        let focusView: UIView?
        switch presentedCard {
        case let .theme(themeID):
            focusView = sourceButton(themeID: themeID)
        case .statistics:
            focusView = sourceStatisticsButton()
        case .ai:
            focusView = sourceAIThemeButton()
        }
        UIAccessibility.post(
            notification: .screenChanged,
            argument: focusView
        )
    }

#if DEBUG
    var expandedCardAnimatorForTesting: UIViewPropertyAnimator? {
        expandedCardAnimator
    }

    var expandedAIKeyboardAnimatorForTesting: UIViewPropertyAnimator? {
        expandedAIKeyboardAnimator
    }

    var expandedAIKeyboardAnimationCurveForTesting: UIView.AnimationCurve? {
        (expandedAIKeyboardAnimator?.timingParameters as? UICubicTimingParameters)?.animationCurve
    }

    var expandedCardTransitionInitialFrameForTesting: CGRect? {
        expandedCardTransitionView?.targetFrameInRoot
    }

    func updateExpandedAIThemeCardFrameForTesting(
        keyboardFrameInWindow: CGRect?,
        duration: TimeInterval,
        curveRawValue: UInt = UInt(UIView.AnimationCurve.easeInOut.rawValue)
    ) {
        guard let cardView = expandedAIThemeCardView else { return }
        updateExpandedAIThemeCardFrame(
            cardView,
            keyboardFrameInWindow: keyboardFrameInWindow,
            duration: duration,
            options: UIView.AnimationOptions(
                rawValue: curveRawValue << 16
            )
        )
    }

    func freezeExpandedAIKeyboardAnimationForTesting(visibleFrame: CGRect) {
        guard let cardView = expandedAIThemeCardView else { return }
        freezeExpandedAIKeyboardAnimation(
            on: cardView,
            visibleFrameOverride: visibleFrame
        )
    }

    func updateSettingsDebugMenu(appearance: AppAppearance) {
        guard let settingsButton else { return }

        let interfaceAction = UIAction(
            title: isDebugInterfaceHidden ? "Show UI" : "Hide UI",
            image: UIImage(
                systemName: isDebugInterfaceHidden
                    ? Content.showInterfaceIconName
                    : Content.hideInterfaceIconName
            )
        ) { [weak self] _ in
            self?.toggleDebugInterfaceVisibility()
        }

        let usesLocalhostBackend = UserDefaults.standard.bool(forKey: DebugBackendSettings.useLocalhostKey)
        let localhostAction = UIAction(
            title: L10n.Settings.localhostBackend,
            subtitle: L10n.Settings.localhostBackendSubtitle,
            image: UIImage(systemName: "server.rack"),
            state: usesLocalhostBackend ? .on : .off
        ) { [weak self] _ in
            self?.toggleDebugLocalhostBackend()
        }

        var menuElements: [UIMenuElement] = [interfaceAction, localhostAction]
        if appearance.designStyle == .classic {
            let backgroundMenu = UIMenu(
                title: L10n.Home.backgroundStyleSwitcher,
                image: UIImage(systemName: Content.backgroundStyleIconName),
                options: .displayInline,
                children: AppBackgroundStyle.allCases.map { [weak self] style in
                    UIAction(
                        title: style.title,
                        image: UIImage(systemName: style.systemImageName),
                        state: style == appearance.backgroundStyle ? .on : .off
                    ) { _ in
                        self?.selectBackgroundStyle(style)
                    }
                }
            )
            menuElements.append(backgroundMenu)
        }

        settingsButton.menu = UIMenu(children: menuElements)
    }

    func selectBackgroundStyle(_ style: AppBackgroundStyle) {
        let store = AppAppearanceStore.shared
        guard store.backgroundStyle != style else { return }

        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        store.backgroundStyle = style
        feedback.selectionChanged()
    }

    func toggleDebugLocalhostBackend() {
        let defaults = UserDefaults.standard
        let usesLocalhostBackend = !defaults.bool(forKey: DebugBackendSettings.useLocalhostKey)
        defaults.set(usesLocalhostBackend, forKey: DebugBackendSettings.useLocalhostKey)

        let feedback = UISelectionFeedbackGenerator()
        feedback.prepare()
        feedback.selectionChanged()
        updateSettingsDebugMenu(appearance: currentAppearance())

        DispatchQueue.main.async { [weak self] in
            guard let self, self.presentedViewController == nil else { return }
            let alert = UIAlertController(
                title: L10n.Settings.restartRequiredTitle,
                message: L10n.Settings.restartRequiredMessage(selection: L10n.Settings.localhostBackend),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: L10n.Settings.alertAction, style: .default))
            self.present(alert, animated: true)
        }
    }
#endif

    @objc func settingsButtonTapped() {
        guard !isQuizLaunchPending else { return }
        router?.showSettings()
    }

#if DEBUG
    func toggleDebugInterfaceVisibility() {
        isDebugInterfaceHidden.toggle()

        headerStackView.isHidden = isDebugInterfaceHidden
        screenStackView.isHidden = isDebugInterfaceHidden
        updateSettingsDebugMenu(appearance: currentAppearance())
    }
#endif

}
