import SwiftUI
import UIKit

protocol HomeRouting: AnyObject {
    func showQuestion()
    func showSettings()
    func showOnboarding()
}

extension HomeRouting {
    func showOnboarding() {}
}

protocol QuizPlayRouting: AnyObject {
    func showResult(_ result: QuizResultState)
    func closeQuestion()
}

protocol QuizResultRouting: AnyObject {
    func replayQuiz()
    func returnToThemes()
}

protocol QuizRouting:
    HomeRouting,
    QuizPlayRouting,
    QuizResultRouting
{}

protocol QuizHomeReturnHandling: AnyObject {
    func quizFlowWillReturnToThemes()
}

final class QuizFlowCoordinator: NSObject, QuizRouting, UIViewControllerTransitioningDelegate {
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging
    private let aiQuizThemeService: AIQuizThemeServiceProtocol
    private let aiQuizAccessProvider: AIQuizAccessProviding
    private let onboardingProgressStore: OnboardingProgressStoring
    private let analytics: AnalyticsTracking
    private let randomQuestionsProvider: ([QuizQuestion]) -> [QuizQuestion]
    private let randomQuestionSelectionModeProvider: () -> CrossThemeQuestionSelectionMode
    private let cardSlideTransitionAnimator = QuizCardSlidePresentationAnimator()
    private let aiReplayAlertPresenter = QuizAlertPresenter()
    private weak var activeQuestionViewController: QuizQuestionViewController?
    private weak var resultViewController: QuizResultViewController?
    private weak var activeOnboardingViewController: UIViewController?
    private var pendingSystemViewController: UIViewController?
    private var catalogReplayTask: Task<Void, Never>?
    private var catalogReplayProgressTask: Task<Void, Never>?
    private var aiReplayTask: Task<Void, Never>?
    private var aiReplayProgressTask: Task<Void, Never>?
    private let catalogReplayProgressDelay: () async -> Void

    init(
        window: UIWindow,
        navigationController: UINavigationController = UINavigationController(),
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizSessionStore.shared,
        aiQuizThemeService: AIQuizThemeServiceProtocol? = nil,
        aiQuizAccessProvider: AIQuizAccessProviding? = nil,
        onboardingProgressStore: OnboardingProgressStoring = OnboardingProgressStore.shared,
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        randomQuestionsProvider: @escaping ([QuizQuestion]) -> [QuizQuestion] = { $0.shuffled() },
        randomQuestionSelectionModeProvider: @escaping () -> CrossThemeQuestionSelectionMode = {
            CrossThemeQuestionSelectionMode.allCases.randomElement() ?? .random
        },
        catalogReplayProgressDelay: @escaping () async -> Void = {
            try? await Task.sleep(nanoseconds: 750_000_000)
        }
    ) {
        let resolvedAIQuizAccessProvider = aiQuizAccessProvider ?? AIQuizAccessStore.shared
        self.window = window
        self.navigationController = navigationController
        self.themeRepository = themeRepository
        self.session = session
        self.aiQuizThemeService = aiQuizThemeService
            ?? Self.makeDefaultAIQuizThemeService(accessProvider: resolvedAIQuizAccessProvider)
        self.aiQuizAccessProvider = resolvedAIQuizAccessProvider
        self.onboardingProgressStore = onboardingProgressStore
        self.analytics = analytics
        self.randomQuestionsProvider = randomQuestionsProvider
        self.randomQuestionSelectionModeProvider = randomQuestionSelectionModeProvider
        self.catalogReplayProgressDelay = catalogReplayProgressDelay
        super.init()
    }

    deinit {
        catalogReplayTask?.cancel()
        catalogReplayProgressTask?.cancel()
        aiReplayTask?.cancel()
        aiReplayProgressTask?.cancel()
    }

    func start() {
        themeRepository.loadData(forceReload: false)
        let viewController = QuizViewController(
            themeRepository: themeRepository,
            session: session,
            aiQuizThemeService: aiQuizThemeService,
            aiQuizAccessProvider: aiQuizAccessProvider,
            analytics: analytics,
            randomQuestionsProvider: randomQuestionsProvider,
            randomQuestionSelectionModeProvider: randomQuestionSelectionModeProvider
        )
        viewController.router = self
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([viewController], animated: false)
        window.rootViewController = navigationController
    }

    @MainActor
    func prepareInitialCatalog() async {
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let didRefresh = await themeRepository.refreshBackendCatalog(locale: locale)
        guard !Task.isCancelled else { return }
        (navigationController.viewControllers.first as? QuizViewController)?
            .applyBackendCatalogRefresh(didRefresh: didRefresh, locale: locale)
    }

    func showQuestion() {
        let viewController = QuizQuestionViewController()
        viewController.analytics = analytics
        viewController.router = self
        viewController.configurePresenter(
            QuizQuestionPresenter(session: session, analytics: analytics)
        )
        activeQuestionViewController = viewController
        guard let presentingViewController = navigationController.topViewController else { return }
        presentWithCardSlide(viewController, from: presentingViewController)
    }

    func showResult(_ result: QuizResultState) {
        let viewController = QuizResultViewController()
        resultViewController = viewController
        viewController.analytics = analytics
        viewController.router = self
        viewController.configurePresenter(QuizResultPresenter(result: result, session: session))
        presentWithCardSlide(viewController, from: presentedViewController)
    }

    func showSettings() {
        let viewController = UIHostingController(rootView: QuizSettingsView(analytics: analytics))
        viewController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = viewController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        presentedViewController.present(viewController, animated: true)
    }

    func presentInitialOnboardingIfNeeded() {
        guard onboardingProgressStore.needsOnboarding else { return }
        presentOnboarding(animated: false)
    }

    func showOnboarding() {
        presentOnboarding(animated: true)
    }

    func presentSystemViewController(_ viewController: UIViewController) {
        guard activeOnboardingViewController == nil else {
            pendingSystemViewController = viewController
            return
        }
        guard presentedViewController !== viewController else { return }
        presentedViewController.present(viewController, animated: true)
    }

    private func presentOnboarding(animated: Bool) {
        guard activeOnboardingViewController == nil else { return }

        let appearance = AppAppearanceStore.shared.appearance(
            compatibleWith: window.traitCollection
        )
        let onboardingView = QuizOnboardingView(
            appearance: appearance,
            themes: onboardingThemes,
            catalogOrigin: themeRepository.catalogOrigin,
            preferredThemeIDs: onboardingProgressStore.preferredThemeIDs,
            onComplete: { [weak self] preferredThemeIDs in
                self?.completeOnboarding(preferredThemeIDs: preferredThemeIDs)
            }
        )
        let viewController = UIHostingController(rootView: onboardingView)
        viewController.modalPresentationStyle = .fullScreen
        viewController.overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle
        viewController.view.backgroundColor = .clear
        activeOnboardingViewController = viewController
        analytics.track(.screenView(screen: .onboarding))
        presentedViewController.present(viewController, animated: animated)
    }

    private var onboardingThemes: [OnboardingTheme] {
        (themeRepository.themes ?? themeRepository.fetchQuizThemes()).map {
            OnboardingTheme(
                id: $0.stableID,
                title: $0.theme,
                sfSymbolName: $0.sfSymbolName
            )
        }
    }

    func completeOnboarding(preferredThemeIDs: Set<String>) {
        onboardingProgressStore.complete(preferredThemeIDs: preferredThemeIDs)
        let viewController = activeOnboardingViewController
        activeOnboardingViewController = nil
        guard let viewController else {
            presentPendingSystemViewControllerIfNeeded()
            return
        }
        viewController.dismiss(animated: true) { [weak self] in
            self?.presentPendingSystemViewControllerIfNeeded()
        }
    }

    private func presentPendingSystemViewControllerIfNeeded() {
        guard let viewController = pendingSystemViewController else { return }
        pendingSystemViewController = nil
        presentSystemViewController(viewController)
    }

    func closeQuestion() {
        returnToThemes()
    }

    func replayQuiz() {
        guard aiReplayTask == nil, catalogReplayTask == nil else { return }
        if session.chosenTheme?.themeID == RandomQuizSelection.themeID {
            replayRandomSelectionQuiz()
            return
        }
        guard let configuration = session.chosenTheme?.aiGenerationConfiguration else {
            replayCatalogQuiz()
            return
        }
        guard aiQuizAccessProvider.isAIQuizAvailable else {
            presentAIReplayFailure(YandexAIQuizThemeServiceError.authenticationRequired)
            return
        }

        let service = aiQuizThemeService
        let startedAt = Date()
        analytics.track(
            .aiGenerationStarted(
                locale: configuration.locale.identifier,
                promptLength: configuration.theme.count,
                questionCount: configuration.questionCount,
                difficulty: configuration.difficulty
            )
        )
        resultViewController?.setReplayGenerationPhase(.analyzing)
        startAIReplayProgressUpdates()
        aiReplayTask = Task { @MainActor [weak self] in
            do {
                let theme = try await service.generateQuizTheme(configuration: configuration)
                try Task.checkCancellation()
                guard let self else { return }

                theme.aiGenerationConfiguration = configuration
                self.session.chosenTheme = ThemeModel(quizTheme: theme)
                self.session.questionsCount = configuration.questionCount
                self.analytics.track(
                    .aiGenerationSucceeded(
                        locale: configuration.locale.identifier,
                        questionCount: theme.questions.count,
                        difficulty: configuration.difficulty,
                        durationMilliseconds: Self.durationMilliseconds(since: startedAt)
                    )
                )
                self.stopAIReplayLoading()
                self.presentFreshQuestionController()
            } catch is CancellationError {
                self?.stopAIReplayLoading()
            } catch {
                guard let self else { return }
                self.stopAIReplayLoading()
                let errorCode = (error as? YandexAIQuizThemeServiceError)?.analyticsCode ?? "unexpected"
                self.analytics.track(
                    .aiGenerationFailed(
                        locale: configuration.locale.identifier,
                        errorCode: errorCode,
                        durationMilliseconds: Self.durationMilliseconds(since: startedAt)
                    )
                )
                self.analytics.reportOperationalError(error, context: .aiGeneration(code: errorCode))
                self.presentAIReplayFailure(error)
            }
        }
    }

    private func replayCatalogQuiz() {
        guard let previousTheme = session.chosenTheme else {
            presentFreshQuestionController()
            return
        }
        let themeID = previousTheme.themeID
        let questionCount = session.questionsCount
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        catalogReplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let preparedTheme = try await self.themeRepository.prepareQuiz(
                    themeID: themeID,
                    questionCount: questionCount,
                    locale: locale
                )
                try Task.checkCancellation()
                guard
                    self.session.chosenTheme?.themeID == themeID,
                    AppLocalizationStore.shared.resolvedLanguageCode == locale
                else {
                    throw CancellationError()
                }
                self.stopCatalogReplayLoading()
                self.session.chosenTheme = ThemeModel(quizTheme: preparedTheme)
                self.session.questionsCount = questionCount
                self.presentFreshQuestionController()
            } catch is CancellationError {
                self.stopCatalogReplayLoading()
            } catch {
                self.stopCatalogReplayLoading()
                self.analytics.reportOperationalError(error, context: .contentLoad)
                self.presentFreshQuestionController()
            }
        }
        startCatalogReplayProgress()
    }

    private func startCatalogReplayProgress() {
        catalogReplayProgressTask?.cancel()
        let delay = catalogReplayProgressDelay
        catalogReplayProgressTask = Task { @MainActor [weak self] in
            await delay()
            guard
                !Task.isCancelled,
                let self,
                self.catalogReplayTask != nil
            else { return }
            self.resultViewController?.setReplayLoading(true)
        }
    }

    private func stopCatalogReplayLoading() {
        catalogReplayTask = nil
        catalogReplayProgressTask?.cancel()
        catalogReplayProgressTask = nil
        resultViewController?.setReplayLoading(false)
    }

    private func replayRandomSelectionQuiz() {
        guard
            let previousTheme = session.chosenTheme,
            previousTheme.themeID == RandomQuizSelection.themeID,
            let localFallback = RandomQuizSelection.makeTheme(
                from: themeRepository.themes ?? themeRepository.fetchQuizThemes(),
                excluding: previousTheme.quizTheme.questions,
                title: L10n.Home.randomSelection,
                description: L10n.Home.feelingLucky,
                randomizing: randomQuestionsProvider
            )
        else {
            presentFreshQuestionController()
            return
        }

        let selectionMode = randomQuestionSelectionModeProvider()
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        AppLog.content.notice(
            "🎲 FEELING LUCKY REPLAY: selected backend mode=\(selectionMode.rawValue, privacy: .public) locale=\(locale, privacy: .public)"
        )
        catalogReplayTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let preparedTheme = try await self.themeRepository.prepareRandomQuiz(
                    selectionMode: selectionMode,
                    localFallback: localFallback,
                    questionCount: RandomQuizSelection.questionCount,
                    locale: locale
                )
                try Task.checkCancellation()
                guard
                    self.session.chosenTheme?.themeID == RandomQuizSelection.themeID,
                    AppLocalizationStore.shared.resolvedLanguageCode == locale
                else {
                    throw CancellationError()
                }
                self.stopCatalogReplayLoading()
                self.session.chosenTheme = ThemeModel(quizTheme: preparedTheme)
                self.session.questionsCount = RandomQuizSelection.questionCount
                self.presentFreshQuestionController()
            } catch is CancellationError {
                self.stopCatalogReplayLoading()
            } catch {
                self.stopCatalogReplayLoading()
                self.analytics.reportOperationalError(error, context: .contentLoad)
                self.presentFreshQuestionController()
            }
        }
        startCatalogReplayProgress()
    }

    private func startAIReplayProgressUpdates() {
        aiReplayProgressTask?.cancel()
        aiReplayProgressTask = Task { @MainActor [weak self] in
            do {
                for update in AIQuizGenerationPhase.delayedUpdates {
                    try await Task.sleep(nanoseconds: update.delayNanoseconds)
                    try Task.checkCancellation()
                    guard let self, self.aiReplayTask != nil else { return }
                    self.resultViewController?.setReplayGenerationPhase(update.phase)
                }
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    private func stopAIReplayLoading() {
        aiReplayTask = nil
        aiReplayProgressTask?.cancel()
        aiReplayProgressTask = nil
        resultViewController?.setReplayGenerationPhase(nil)
    }

    private func presentFreshQuestionController() {
        if let activeQuestionViewController {
            activeQuestionViewController.prepareForReplay(
                QuizQuestionPresenter(session: session, analytics: analytics)
            )
            let replayResultViewController = resultViewController
            resultViewController = nil
            replayResultViewController?.dismiss(animated: false)
            return
        }

        navigationController.dismiss(animated: false) { [weak self] in
            self?.showQuestion()
        }
    }

    func returnToThemes() {
        catalogReplayTask?.cancel()
        stopCatalogReplayLoading()
        aiReplayTask?.cancel()
        stopAIReplayLoading()
        aiReplayAlertPresenter.dismiss()
        navigationController.popToRootViewController(animated: false)
        (navigationController.viewControllers.first as? QuizHomeReturnHandling)?
            .quizFlowWillReturnToThemes()
        navigationController.dismiss(animated: true)
    }

    private func presentAIReplayFailure(_ error: Error) {
        guard let resultViewController else { return }
        let alert = AIQuizGenerationAlert(error: error)
        let dismissAction = QuizAlertAction(
            title: alert.offersEditAction ? L10n.Common.back : L10n.Settings.alertAction,
            emphasis: alert.canRetry ? .secondary : .primary,
            accessibilityIdentifier: "aiReplayAlertDismissButton",
            action: { [weak self] in self?.aiReplayAlertPresenter.dismiss() }
        )
        let retryAction = QuizAlertAction(
            title: L10n.AITheme.retry,
            emphasis: .primary,
            accessibilityIdentifier: "aiReplayAlertRetryButton",
            action: { [weak self] in
                self?.aiReplayAlertPresenter.dismiss { [weak self] in
                    self?.replayQuiz()
                }
            }
        )
        let overlay = QuizAlertOverlay(
            title: alert.title,
            message: alert.message,
            systemImage: alert.kind.systemImage,
            iconColor: alert.kind.iconColor(in: resultViewController.currentAppearance()),
            primaryAction: alert.canRetry ? retryAction : dismissAction,
            secondaryAction: alert.canRetry ? dismissAction : nil,
            onEscape: { [weak self] in self?.aiReplayAlertPresenter.dismiss() }
        )
        aiReplayAlertPresenter.presentingViewController = resultViewController
        _ = aiReplayAlertPresenter.present(
            overlay,
            appearance: resultViewController.currentAppearance(),
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        )
    }

    private static func durationMilliseconds(since startDate: Date) -> Int {
        max(Int(Date().timeIntervalSince(startDate) * 1_000), 0)
    }

    private var presentedViewController: UIViewController {
        var viewController: UIViewController = navigationController
        while let presented = viewController.presentedViewController {
            viewController = presented
        }
        return viewController
    }

    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        presented is QuizCardSlideTransitionDestination ? cardSlideTransitionAnimator : nil
    }

    private func presentWithCardSlide(
        _ viewController: UIViewController & QuizCardSlideTransitionDestination,
        from presentingViewController: UIViewController
    ) {
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self
        cardSlideTransitionAnimator.sourceViewController = presentingViewController as? QuizCardSlideTransitionSource
        presentingViewController.present(viewController, animated: true)
    }

    private static func makeDefaultAIQuizThemeService(
        accessProvider: AIQuizAccessProviding
    ) -> AIQuizThemeServiceProtocol {
        if let configuration = BackendConfiguration.load() {
            return BackendAIQuizThemeService(
                configuration: configuration,
                metrics: AppMetricaAnalyticsTracker.shared,
                accessProvider: accessProvider
            )
        }
        return YandexAIQuizThemeService(apiKey: nil)
    }
}
