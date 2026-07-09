//
//  SceneDelegate.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: QuizFlowCoordinator?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        if ProcessInfo.processInfo.environment["QUIZICE_XCTEST_SMOKE_HOST"] == "1" || NSClassFromString("XCTestCase") != nil {
            window.rootViewController = UIViewController()
        } else {
            let coordinator = QuizFlowCoordinator(window: window)
            coordinator.start()
            self.coordinator = coordinator
        }
        window.makeKeyAndVisible()
        self.window = window
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene becomes active.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}

protocol QuizRouting: AnyObject {
    func showDescription()
    func showQuestion()
    func showResult(_ result: QuizResultState)
    func showStatistics()
    func showAIThemeCreation()
    func showSettings()
    func closeDescription()
    func closeStatistics()
    func closeQuestion()
    func restartQuiz()
}

final class QuizFlowCoordinator: NSObject, QuizRouting, UIViewControllerTransitioningDelegate {
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging
    private let cardSlideTransitionAnimator = QuizCardSlidePresentationAnimator()

    init(
        window: UIWindow,
        navigationController: UINavigationController = UINavigationController(),
        themeRepository: ThemeRepository = QuizFactory.shared,
        session: QuizSessionManaging = QuizFactory.shared
    ) {
        self.window = window
        self.navigationController = navigationController
        self.themeRepository = themeRepository
        self.session = session
        super.init()
    }

    func start() {
        let viewController = QuizViewController(themeRepository: themeRepository, session: session)
        viewController.router = self
        viewController.configurePresenter(QuizPresenter(session: session))
        navigationController.setNavigationBarHidden(true, animated: false)
        navigationController.setViewControllers([viewController], animated: false)
        window.rootViewController = navigationController
    }

    func showDescription() {
        let viewController = QuizDescriptionViewController()
        viewController.router = self
        let content = QuizPresenter(session: session).descriptionContent()
        viewController.configurePresenter(QuizDescriptionPresenter(session: session, content: content))
        navigationController.pushViewController(viewController, animated: true)
    }

    func showQuestion() {
        let viewController = QuizQuestionViewController()
        viewController.router = self
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self
        let presentingViewController = navigationController.topViewController
        cardSlideTransitionAnimator.sourceViewController = presentingViewController as? QuizCardSlideTransitionSource
        presentingViewController?.present(viewController, animated: true)
    }

    func showResult(_ result: QuizResultState) {
        let viewController = QuizResultViewController()
        viewController.router = self
        viewController.modalPresentationStyle = .custom
        viewController.transitioningDelegate = self
        viewController.configurePresenter(QuizResultPresenter(result: result))
        let presentingViewController = presentedViewController
        cardSlideTransitionAnimator.sourceViewController = presentingViewController as? QuizCardSlideTransitionSource
        presentingViewController.present(viewController, animated: true)
    }

    func showStatistics() {
        let viewController = StatisticsViewController()
        viewController.router = self
        navigationController.pushViewController(viewController, animated: true)
    }

    func showAIThemeCreation() {
        let viewController = UIHostingController(rootView: QuizAIThemeCreationView(service: MockAIQuizThemeService()))
        viewController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = viewController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        presentedViewController.present(viewController, animated: true)
    }

    func showSettings() {
        let viewController = UIHostingController(rootView: QuizSettingsView())
        viewController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = viewController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        presentedViewController.present(viewController, animated: true)
    }

    func closeDescription() {
        navigationController.popViewController(animated: true)
    }

    func closeStatistics() {
        navigationController.popViewController(animated: true)
    }

    func closeQuestion() {
        navigationController.popToRootViewController(animated: false)
        navigationController.dismiss(animated: true)
    }

    func restartQuiz() {
        navigationController.popToRootViewController(animated: false)
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
}

protocol QuizCardSlideTransitionSource: AnyObject {
    var cardSlideTransitionSourceView: UIView { get }
    var cardSlideTransitionHorizontalInset: CGFloat { get }
}

protocol QuizCardSlideTransitionDestination: AnyObject {
    var cardSlideTransitionDestinationView: UIView { get }
    var cardSlideTransitionHorizontalInset: CGFloat { get }
    var cardSlideTransitionDestinationCompanionViews: [UIView] { get }
}

extension QuizCardSlideTransitionDestination {
    var cardSlideTransitionDestinationCompanionViews: [UIView] { [] }
}

private final class QuizCardSlidePresentationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    weak var sourceViewController: QuizCardSlideTransitionSource?

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        QuizCardSlideTransition.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: .to),
            let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        toView.frame = finalFrame.isEmpty ? containerView.bounds : finalFrame
        containerView.addSubview(toView)

        guard
            !UIAccessibility.isReduceMotionEnabled,
            let fromViewController = sourceViewController ?? (transitionContext.viewController(forKey: .from) as? QuizCardSlideTransitionSource),
            let toViewController = toViewController as? QuizCardSlideTransitionDestination
        else {
            sourceViewController = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        toView.setNeedsLayout()
        toView.layoutIfNeeded()

        let sourceView = fromViewController.cardSlideTransitionSourceView
        let destinationView = toViewController.cardSlideTransitionDestinationView
        let destinationCompanionViews = toViewController.cardSlideTransitionDestinationCompanionViews
        let originalBackgroundColor = toView.backgroundColor
        let horizontalInset = max(
            fromViewController.cardSlideTransitionHorizontalInset,
            toViewController.cardSlideTransitionHorizontalInset
        )
        let horizontalOffset = QuizCardSlideTransition.horizontalOffset(
            in: containerView,
            horizontalInset: horizontalInset
        )

        guard
            horizontalOffset > 0,
            let sourceSnapshot = sourceView.snapshotView(afterScreenUpdates: false)
        else {
            sourceViewController = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        sourceSnapshot.frame = sourceView.convert(sourceView.bounds, to: containerView)
        sourceView.isHidden = true
        toView.backgroundColor = .clear
        destinationView.transform = CGAffineTransform(translationX: horizontalOffset, y: 0)
        destinationCompanionViews.forEach { $0.alpha = 0 }
        destinationView.isUserInteractionEnabled = false
        containerView.addSubview(sourceSnapshot)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: {
                sourceSnapshot.transform = CGAffineTransform(translationX: -horizontalOffset, y: 0)
                destinationView.transform = .identity
                destinationCompanionViews.forEach { $0.alpha = 1 }
            },
            completion: { _ in
                let completed = !transitionContext.transitionWasCancelled
                sourceSnapshot.removeFromSuperview()
                sourceView.isHidden = false
                destinationView.transform = .identity
                destinationCompanionViews.forEach { $0.alpha = 1 }
                destinationView.isUserInteractionEnabled = true
                toView.backgroundColor = originalBackgroundColor
                self.sourceViewController = nil
                transitionContext.completeTransition(completed)
            }
        )
    }
}
