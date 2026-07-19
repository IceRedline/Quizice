import SwiftUI
import UIKit

protocol HomeRouting: AnyObject {
    func showQuestion()
    func showSettings()
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
    private let analytics: AnalyticsTracking
    private let randomQuestionsProvider: ([QuizQuestion]) -> [QuizQuestion]
    private let cardSlideTransitionAnimator = QuizCardSlidePresentationAnimator()
    private let aiReplayAlertPresenter = QuizAlertPresenter()
    private weak var activeQuestionViewController: QuizQuestionViewController?
    private weak var resultViewController: QuizResultViewController?
    private var catalogReplayTask: Task<Void, Never>?
    private var aiReplayTask: Task<Void, Never>?
    private var aiReplayProgressTask: Task<Void, Never>?

    init(
        window: UIWindow,
        navigationController: UINavigationController = UINavigationController(),
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizSessionStore.shared,
        aiQuizThemeService: AIQuizThemeServiceProtocol? = nil,
        aiQuizAccessProvider: AIQuizAccessProviding? = nil,
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        randomQuestionsProvider: @escaping ([QuizQuestion]) -> [QuizQuestion] = { $0.shuffled() }
    ) {
        let resolvedAIQuizAccessProvider = aiQuizAccessProvider ?? AIQuizAccessStore.shared
        self.window = window
        self.navigationController = navigationController
        self.themeRepository = themeRepository
        self.session = session
        self.aiQuizThemeService = aiQuizThemeService
            ?? Self.makeDefaultAIQuizThemeService(accessProvider: resolvedAIQuizAccessProvider)
        self.aiQuizAccessProvider = resolvedAIQuizAccessProvider
        self.analytics = analytics
        self.randomQuestionsProvider = randomQuestionsProvider
        super.init()
    }

    deinit {
        catalogReplayTask?.cancel()
        aiReplayTask?.cancel()
        aiReplayProgressTask?.cancel()
    }

    func start() {
        let viewController = QuizViewController(
            themeRepository: themeRepository,
            session: session,
            aiQuizThemeService: aiQuizThemeService,
            aiQuizAccessProvider: aiQuizAccessProvider,
            analytics: analytics,
            randomQuestionsProvider: randomQuestionsProvider
        )
        viewController.router = self
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([viewController], animated: false)
        window.rootViewController = navigationController
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

    func presentSystemViewController(_ viewController: UIViewController) {
        guard presentedViewController !== viewController else { return }
        presentedViewController.present(viewController, animated: true)
    }

    func closeQuestion() {
        returnToThemes()
    }

    func replayQuiz() {
        guard aiReplayTask == nil, catalogReplayTask == nil else { return }
        if replayRandomSelectionQuiz() {
            presentFreshQuestionController()
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
                self.catalogReplayTask = nil
                self.session.chosenTheme = ThemeModel(quizTheme: preparedTheme)
                self.session.questionsCount = questionCount
                self.presentFreshQuestionController()
            } catch is CancellationError {
                self.catalogReplayTask = nil
            } catch {
                self.catalogReplayTask = nil
                self.analytics.reportOperationalError(error, context: .contentLoad)
                self.presentFreshQuestionController()
            }
        }
    }

    private func replayRandomSelectionQuiz() -> Bool {
        guard
            let previousTheme = session.chosenTheme,
            previousTheme.themeID == RandomQuizSelection.themeID,
            let randomSelectionTheme = RandomQuizSelection.makeTheme(
                from: themeRepository.themes ?? themeRepository.fetchQuizThemes(),
                excluding: previousTheme.quizTheme.questions,
                title: L10n.Home.randomSelection,
                description: L10n.Home.feelingLucky,
                randomizing: randomQuestionsProvider
            )
        else { return false }

        session.chosenTheme = ThemeModel(quizTheme: randomSelectionTheme)
        session.questionsCount = RandomQuizSelection.questionCount
        return true
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
        catalogReplayTask = nil
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
