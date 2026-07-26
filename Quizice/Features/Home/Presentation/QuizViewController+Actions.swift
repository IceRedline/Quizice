import UIKit

extension QuizViewController {
    func refreshBackendCatalog() {
        backendCatalogRefreshTask?.cancel()
#if DEBUG
        debugCatalogSourceState = .loading
#endif
        let requestID = UUID()
        backendCatalogRefreshRequestID = requestID
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        backendCatalogRefreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let didRefresh = await self.themeRepository.refreshBackendCatalog(locale: locale)
            let didSynchronizePreferences = await self.themeRepository.synchronizeThemePreferences(
                locale: locale
            )
            guard self.backendCatalogRefreshRequestID == requestID else { return }
            self.backendCatalogRefreshTask = nil
            self.backendCatalogRefreshRequestID = nil
            self.applyBackendCatalogRefresh(
                didRefresh: didRefresh || didSynchronizePreferences,
                locale: locale
            )
        }
    }

    func applyBackendCatalogRefresh(didRefresh: Bool, locale: String) {
#if DEBUG
        if didRefresh {
            debugCatalogSourceState = .backend
        } else if themeRepository.catalogOrigin == .backend {
            debugCatalogSourceState = .backendStale
        } else {
            debugCatalogSourceState = .local
        }
#endif
        guard
            didRefresh,
            !Task.isCancelled,
            AppLocalizationStore.shared.resolvedLanguageCode == locale
        else { return }
        updateThemeAvailabilityMessage()
        applyThemePreferencesRefresh(locale: locale)
    }

    func applyThemePreferencesRefresh(locale: String) {
        guard
            isViewLoaded,
            AppLocalizationStore.shared.resolvedLanguageCode == locale
        else { return }
        themesCollectionView.reloadData()
        refreshExpandedThemeCardAppearance()
    }

    func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }

    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String) {
        animationsEngine.animateUpFloat(sender)
        guard
            homeCardState.phase == .grid,
            !isQuizLaunchPending,
            let theme = themeRepository.themes?.first(where: { $0.stableID == themeID })
        else {
            updateThemeAvailabilityMessage()
            return
        }
        let chosenTheme = ThemeModel(quizTheme: theme)
        session.chosenTheme = chosenTheme

        sender.layer.removeAllAnimations()
        sender.transform = .identity
        sender.alpha = Appearance.visibleAlpha

        let effect = homeStore.send(
            .present(
                themeID: themeID,
                availableQuestionCounts: chosenTheme.questionOrigin == .backend
                    && chosenTheme.questionsAndAnswers.isEmpty
                    ? QuizQuestionCountPolicy.supportedCounts
                    : QuizQuestionCountPolicy.availableCounts(for: chosenTheme.questionsAndAnswers),
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
        themesCollectionService.refreshStatistics()
    }

    func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        guard aiQuizAccessProvider.isAIQuizAvailable else {
            AppLog.quiz.notice("🔒 AI unavailable: Game Center authentication required")
            presentAIAuthenticationRequiredAlert()
            return
        }
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
        }
    }

    func refreshMotivationPrompt() {
        guard themeRepository.themes?.isEmpty == false else { return }
        motivationLabel.text = motivationPromptProvider(motivationLabel.text)
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

        guard let randomSelectionTheme = RandomQuizSelection.makeTheme(
            from: themes,
            title: L10n.Home.randomSelection,
            description: L10n.Home.feelingLucky,
            randomizing: randomQuestionsProvider
        ) else {
            motivationLabel.text = L10n.Question.unavailableMessage
            return
        }

        session.chosenTheme = ThemeModel(quizTheme: randomSelectionTheme)
        session.questionsCount = RandomQuizSelection.questionCount
        let selectionMode = randomQuestionSelectionModeProvider()
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        AppLog.content.notice(
            "🎲 FEELING LUCKY: selected backend mode=\(selectionMode.rawValue, privacy: .public) locale=\(locale, privacy: .public)"
        )
        analytics.track(.themeSelected(theme: session.chosenTheme?.analyticsTheme ?? .unknown, method: .random))
        quizTransitionSourceView = sourceView
        isQuizLaunchPending = true
        hasQuizLaunchStarted = false
        themesCollectionService.isFeelingLuckyLoading = true
        themesCollectionView.isUserInteractionEnabled = false
        settingsButton.isEnabled = false
        helpButton.isEnabled = false
        updateCollectionScrollAvailability()

        let requestID = UUID()
        feelingLuckyRequestID = requestID
        feelingLuckyTask?.cancel()
        let minimumFeedbackDelay = feelingLuckyMinimumFeedbackDelay
        feelingLuckyTask = Task { @MainActor [weak self, router] in
            async let feedbackDelay: Void = minimumFeedbackDelay()
            do {
                guard let self else { return }
                let preparedTheme = try await self.themeRepository.prepareRandomQuiz(
                    selectionMode: selectionMode,
                    localFallback: randomSelectionTheme,
                    questionCount: RandomQuizSelection.questionCount,
                    locale: locale
                )
                await feedbackDelay
                try Task.checkCancellation()
                guard
                    self.feelingLuckyRequestID == requestID,
                    self.isQuizLaunchPending,
                    self.session.chosenTheme?.themeID == randomSelectionTheme.stableID,
                    AppLocalizationStore.shared.resolvedLanguageCode == locale
                else {
                    throw CancellationError()
                }

                self.feelingLuckyTask = nil
                self.session.chosenTheme = ThemeModel(quizTheme: preparedTheme)
                self.session.questionsCount = RandomQuizSelection.questionCount
                self.analytics.track(
                    .quizStarted(
                        theme: self.session.chosenTheme?.analyticsTheme ?? .unknown,
                        questionCount: self.session.questionsCount
                    )
                )
                self.hasQuizLaunchStarted = true
                router.showQuestion()
            } catch is CancellationError {
                self?.cancelFeelingLuckyLaunch()
            } catch {
                self?.analytics.reportOperationalError(error, context: .contentLoad)
                self?.finishFailedFeelingLuckyLaunch()
            }
        }
    }

    private func finishFailedFeelingLuckyLaunch() {
        cancelFeelingLuckyLaunch()
        motivationLabel.text = L10n.Question.unavailableMessage
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
        helpButton?.isEnabled = true
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
