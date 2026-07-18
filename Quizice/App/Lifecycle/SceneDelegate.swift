import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var coordinator: QuizFlowCoordinator?
    private let launchOverlayPresenter = LaunchOverlayPresenter()
    private var authenticationService: GameCenterAuthenticationService?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        AppAppearanceStore.shared.registerInitialDefaults()
        let window = UIWindow(windowScene: windowScene)
        let isRunningTests = ProcessInfo.processInfo.environment["QUIZICE_XCTEST_SMOKE_HOST"] == "1"
            || NSClassFromString("XCTestCase") != nil
        if isRunningTests {
            window.rootViewController = UIViewController()
        } else {
            let coordinator = QuizFlowCoordinator(window: window)
            coordinator.start()
            self.coordinator = coordinator
            let appearance = AppAppearanceStore.shared.appearance(
                compatibleWith: window.traitCollection
            )
            launchOverlayPresenter.present(in: window, appearance: appearance)
        }
        window.makeKeyAndVisible()
        self.window = window

        if isRunningTests == false, let coordinator {
            let authenticationService = GameCenterAuthenticationService.live()
            self.authenticationService = authenticationService
            authenticationService.start { [weak coordinator] viewController in
                coordinator?.presentSystemViewController(viewController)
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
        launchOverlayPresenter.dismiss(animated: false)
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        authenticationService?.retrySynchronization()
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
