import SwiftUI
import UIKit

protocol HomeRouting: AnyObject {
    func showDescription()
    func showQuestion()
    func showSettings()
}

protocol QuizDescriptionRouting: AnyObject {
    func showQuestion()
    func closeDescription()
}

protocol QuizPlayRouting: AnyObject {
    func showResult(_ result: QuizResultState)
    func closeQuestion()
}

protocol QuizResultRouting: AnyObject {
    func replayQuiz()
    func returnToThemes()
}

protocol StatisticsRouting: AnyObject {
    func closeStatistics()
}

protocol QuizRouting:
    HomeRouting,
    QuizDescriptionRouting,
    QuizPlayRouting,
    QuizResultRouting,
    StatisticsRouting
{
    func showStatistics()
}

protocol QuizHomeReturnHandling: AnyObject {
    func quizFlowWillReturnToThemes()
}

final class QuizFlowCoordinator: NSObject, QuizRouting, UIViewControllerTransitioningDelegate {
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging
    private let aiQuizThemeService: AIQuizThemeServiceProtocol
    private let analytics: AnalyticsTracking
    private let cardSlideTransitionAnimator = QuizCardSlidePresentationAnimator()

    init(
        window: UIWindow,
        navigationController: UINavigationController = UINavigationController(),
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizSessionStore.shared,
        aiQuizThemeService: AIQuizThemeServiceProtocol? = nil,
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared
    ) {
        self.window = window
        self.navigationController = navigationController
        self.themeRepository = themeRepository
        self.session = session
        self.aiQuizThemeService = aiQuizThemeService ?? Self.makeDefaultAIQuizThemeService()
        self.analytics = analytics
        super.init()
    }

    func start() {
        let viewController = QuizViewController(
            themeRepository: themeRepository,
            session: session,
            aiQuizThemeService: aiQuizThemeService,
            analytics: analytics
        )
        viewController.router = self
        viewController.configurePresenter(QuizPresenter(session: session))
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([viewController], animated: false)
        window.rootViewController = navigationController
    }

    func showDescription() {
        let viewController = QuizDescriptionViewController()
        viewController.analytics = analytics
        viewController.router = self
        let content = QuizPresenter(session: session).descriptionContent()
        viewController.configurePresenter(QuizDescriptionPresenter(session: session, content: content))
        navigationController.pushViewController(viewController, animated: true)
    }

    func showQuestion() {
        let viewController = QuizQuestionViewController()
        viewController.analytics = analytics
        viewController.router = self
        viewController.configurePresenter(
            QuizQuestionPresenter(session: session, analytics: analytics)
        )
        guard let presentingViewController = navigationController.topViewController else { return }
        presentWithCardSlide(viewController, from: presentingViewController)
    }

    func showResult(_ result: QuizResultState) {
        let viewController = QuizResultViewController()
        viewController.analytics = analytics
        viewController.router = self
        viewController.configurePresenter(QuizResultPresenter(result: result, session: session))
        presentWithCardSlide(viewController, from: presentedViewController)
    }

    func showStatistics() {
        let viewController = StatisticsViewController(analytics: analytics)
        viewController.router = self
        navigationController.pushViewController(viewController, animated: true)
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

    func closeDescription() {
        navigationController.popViewController(animated: true)
    }

    func closeStatistics() {
        navigationController.popViewController(animated: true)
    }

    func closeQuestion() {
        returnToThemes()
    }

    func replayQuiz() {
        navigationController.dismiss(animated: false) { [weak self] in
            self?.showQuestion()
        }
    }

    func returnToThemes() {
        navigationController.popToRootViewController(animated: false)
        (navigationController.viewControllers.first as? QuizHomeReturnHandling)?
            .quizFlowWillReturnToThemes()
        navigationController.dismiss(animated: true)
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

    private static func makeDefaultAIQuizThemeService() -> AIQuizThemeServiceProtocol {
        #if DEBUG
        let apiKey = DebugYandexAIAPIKeyStore.resolveAPIKey()
        return YandexAIQuizThemeService(apiKey: apiKey)
        #else
        return YandexAIQuizThemeService(apiKey: nil)
        #endif
    }
}
