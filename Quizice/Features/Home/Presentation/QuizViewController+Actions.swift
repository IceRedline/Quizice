import UIKit

extension QuizViewController {
    func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }

    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String) {
        animationsEngine.animateUpFloat(sender)
        guard
            homeCardState.phase == .grid,
            !isQuizLaunchPending,
            session.loadTheme(themeID: themeID),
            let theme = themeRepository.themes?.first(where: { $0.stableID == themeID }),
            let chosenTheme = session.chosenTheme
        else {
            updateThemeAvailabilityMessage()
            return
        }

        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha

        let effect = homeStore.send(
            .present(
                themeID: themeID,
                availableQuestionCounts: QuizQuestionCountPolicy.availableCounts(
                    for: chosenTheme.questionsAndAnswers
                ),
                preferredQuestionCount: session.questionsCount
            )
        )
        guard let effect else { return }

        analytics.track(.themeSelected(theme: session.chosenTheme?.analyticsTheme ?? .unknown, method: .manual))
        handleHomeCardEffect(effect, theme: theme, sourceView: sender)
    }

    func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }

    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        startRandomTheme(sourceView: sender)
    }

    func quizFlowWillReturnToThemes() {
        restoreHomeAfterQuizIfNeeded(force: true)
    }

    func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        guard homeCardState.phase == .grid, !isQuizLaunchPending else { return }
        let effect = homeStore.send(.presentAI)
        guard let effect else { return }
        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha
        handleHomeCardEffect(effect, sourceView: sender)
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        guard homeCardState.phase == .grid, !isQuizLaunchPending else { return }
        let effect = homeStore.send(.presentStatistics)
        guard let effect else { return }
        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha
        handleHomeCardEffect(effect, sourceView: sender)
    }

    func themesCollectionDidScroll(_ scrollView: UIScrollView) {
        updateMotivationHeaderVisibility(for: scrollView)
    }

    func updateThemeAvailabilityMessage() {
        let hasThemes = themeRepository.themes?.isEmpty == false
        if !hasThemes {
            motivationLabel.text = L10n.Home.unavailableThemes
            invalidateMotivationBlurredText()
        }
    }

    func refreshMotivationPrompt() {
        guard themeRepository.themes?.isEmpty == false else { return }
        motivationLabel.text = motivationPromptProvider(motivationLabel.text)
        invalidateMotivationBlurredText()
    }

    static func randomMotivationPrompt(excluding currentPrompt: String? = nil) -> String {
        let prompts = L10n.Home.motivationPrompts
        let availablePrompts = prompts.filter { $0 != currentPrompt }
        let prompt = (availablePrompts.isEmpty ? prompts : availablePrompts).randomElement() ?? ""
        return prompt.replacingOccurrences(of: "\\n", with: "\n")
    }

    func startRandomTheme(sourceView: UIView) {
        guard
            homeCardState.phase == .grid,
            !isQuizLaunchPending,
            let router
        else { return }
        guard let themes = themeRepository.themes else {
            updateThemeAvailabilityMessage()
            return
        }

        let eligibleThemes = themes.filter { theme in
            QuizQuestionCountPolicy.availableCounts(
                for: ThemeModel(quizTheme: theme).questionsAndAnswers
            ).contains(QuizQuestionCountPolicy.supportedCounts[0])
        }
        guard
            let themeID = randomThemeIDProvider(eligibleThemes),
            eligibleThemes.contains(where: { $0.stableID == themeID }),
            session.loadTheme(themeID: themeID)
        else {
            motivationLabel.text = L10n.Question.unavailableMessage
            invalidateMotivationBlurredText()
            return
        }

        session.questionsCount = QuizQuestionCountPolicy.supportedCounts[0]
        analytics.track(.themeSelected(theme: session.chosenTheme?.analyticsTheme ?? .unknown, method: .random))
        quizTransitionSourceView = sourceView
        isQuizLaunchPending = true
        hasQuizLaunchStarted = false
        themesCollectionService.isFeelingLuckyLoading = true
        themesCollectionView.isUserInteractionEnabled = false
        settingsButton.isEnabled = false
        updateCollectionScrollAvailability()

        let requestID = UUID()
        feelingLuckyRequestID = requestID
        feelingLuckyTask?.cancel()
        let minimumFeedbackDelay = feelingLuckyMinimumFeedbackDelay
        feelingLuckyTask = Task { @MainActor [weak self, router] in
            await minimumFeedbackDelay()
            guard !Task.isCancelled, let self else { return }
            guard
                self.feelingLuckyRequestID == requestID,
                self.isQuizLaunchPending,
                self.session.chosenTheme?.themeID == themeID
            else {
                self.cancelFeelingLuckyLaunch()
                return
            }

            self.feelingLuckyTask = nil
            self.session.questionsCount = QuizQuestionCountPolicy.supportedCounts[0]
            self.analytics.track(
                .quizStarted(
                    theme: self.session.chosenTheme?.analyticsTheme ?? .unknown,
                    questionCount: self.session.questionsCount
                )
            )
            self.hasQuizLaunchStarted = true
            router.showQuestion()
        }
    }

    func cancelFeelingLuckyLaunch() {
        let wasWaitingToLaunch = isQuizLaunchPending
            && !hasQuizLaunchStarted
            && feelingLuckyRequestID != nil
        feelingLuckyTask?.cancel()
        feelingLuckyTask = nil
        feelingLuckyRequestID = nil
        themesCollectionService.isFeelingLuckyLoading = false
        settingsButton?.isEnabled = true
        if wasWaitingToLaunch, isViewLoaded {
            isQuizLaunchPending = false
            quizTransitionSourceView = nil
            themesCollectionView.isUserInteractionEnabled = true
            updateCollectionScrollAvailability()
        }
    }

    func handleHomeCardEffect(
        _ effect: HomeThemeCardEffect,
        theme: QuizTheme? = nil,
        sourceView: UIView? = nil
    ) {
        switch effect {
        case let .expand(themeID):
            guard
                let theme,
                theme.stableID == themeID,
                let sourceView
            else { return }
            expandThemeCard(theme: theme, from: sourceView)

        case .expandStatistics:
            guard let sourceView else { return }
            expandStatisticsCard(
                summary: statisticsStore.loadSummary(),
                from: sourceView
            )

        case .expandAI:
            guard let sourceView else { return }
            expandAIThemeCard(from: sourceView)

        case let .flip(face):
            if homeCardState.isAIThemePresented {
                flipExpandedAIThemeCard(to: face)
            } else {
                flipExpandedThemeCard(to: face)
            }

        case .collapse:
            collapseExpandedThemeCard()

        case .collapseStatistics:
            collapseExpandedStatisticsCard()

        case .collapseAI:
            collapseExpandedAIThemeCard()

        case .reverseExpansion:
            reverseExpandedCardTransition()

        case let .launch(themeID, questionCount):
            updateExpandedThemeCardParallaxPhase()
            launchQuiz(themeID: themeID, questionCount: questionCount)
        }
    }

    func sendHomeCardAction(_ action: HomeThemeCardAction) {
        guard let effect = homeStore.send(action) else {
            return
        }
        handleHomeCardEffect(effect, theme: expandedTheme)
    }
}
