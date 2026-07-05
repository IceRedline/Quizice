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

final class QuizFlowCoordinator: QuizRouting {
    private let window: UIWindow
    private let navigationController: UINavigationController
    private let themeRepository: ThemeRepository
    private let session: QuizSessionManaging

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
        viewController.modalPresentationStyle = .fullScreen
        navigationController.topViewController?.present(viewController, animated: true)
    }

    func showResult(_ result: QuizResultState) {
        let viewController = QuizResultViewController()
        viewController.router = self
        viewController.modalPresentationStyle = .fullScreen
        viewController.configurePresenter(QuizResultPresenter(result: result))
        presentedViewController.present(viewController, animated: true)
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
}
