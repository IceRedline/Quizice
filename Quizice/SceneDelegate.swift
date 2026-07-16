//
//  SceneDelegate.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit
import SwiftUI
#if DEBUG
import Security
#endif

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    private var coordinator: QuizFlowCoordinator?
    private let launchOverlayPresenter = LaunchOverlayPresenter()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        if ProcessInfo.processInfo.environment["QUIZICE_XCTEST_SMOKE_HOST"] == "1" || NSClassFromString("XCTestCase") != nil {
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
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
        launchOverlayPresenter.dismiss(animated: false)
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

enum FakeLaunchCompletionStyle: Equatable {
    case revealHome
    case crossfade
}

struct FakeLaunchMotion {
    static let standard = FakeLaunchMotion(
        logoZoomScale: 42,
        logoZoomDuration: 0.82
    )

    let logoZoomScale: CGFloat
    let logoZoomDuration: TimeInterval

    var logoZoomAnimation: Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: logoZoomDuration)
    }
}

enum FakeLaunchMarkStyle: Equatable {
    case classicImage
    case radarText
    case cleanText
}

struct FakeLaunchVisualStyle {
    let markStyle: FakeLaunchMarkStyle
    let backgroundColor: UIColor
    let foregroundColor: UIColor?
    let revealsAppBackground: Bool

    init(appearance: AppAppearance) {
        switch appearance.designStyle {
        case .classic:
            markStyle = .classicImage
            backgroundColor = UIColor(hex: 0x111620)
            foregroundColor = nil
            revealsAppBackground = true
        case .radar:
            markStyle = .radarText
            backgroundColor = .black
            foregroundColor = appearance.accentColor
            revealsAppBackground = false
        case .clean:
            markStyle = .cleanText
            backgroundColor = appearance.accentForegroundColor
            foregroundColor = appearance.accentColor
            revealsAppBackground = false
        }
    }
}

struct FakeLaunchScreenView: View {
    private enum Phase {
        case holding
        case zooming
    }

    private enum Layout {
        static let logoWidthRatio: CGFloat = 0.7
        static let maximumLogoWidth: CGFloat = 360
        static let logoAspectRatio: CGFloat = 399 / 742
        static let centerGapRatio: CGFloat = 0.05
        static let radarFontSizeRatio: CGFloat = 0.52
        static let radarHorizontalOffsetRatio: CGFloat = -0.105
        static let radarVerticalOffsetRatio: CGFloat = -0.035
        static let radarItalicShear: CGFloat = -0.18
        static let cleanFontSizeRatio: CGFloat = 0.684
        static let cleanHorizontalOffsetRatio: CGFloat = 0.052
        static let cleanVerticalOffsetRatio: CGFloat = -0.037
    }

    private enum Motion {
        static let revealDuration: TimeInterval = 0.35
    }

    let appearance: AppAppearance
    private let holdDuration: TimeInterval
    private let motion: FakeLaunchMotion
    private let onFinished: (FakeLaunchCompletionStyle) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false
    @State private var phase = Phase.holding
    @State private var didFinish = false

    init(
        appearance: AppAppearance,
        holdDuration: TimeInterval = 1.15,
        motion: FakeLaunchMotion = .standard,
        onFinished: @escaping (FakeLaunchCompletionStyle) -> Void = { _ in }
    ) {
        self.appearance = appearance
        self.holdDuration = holdDuration
        self.motion = motion
        self.onFinished = onFinished
    }

    var body: some View {
        GeometryReader { geometry in
            let visualStyle = FakeLaunchVisualStyle(appearance: appearance)
            let logoWidth = min(
                geometry.size.width * Layout.logoWidthRatio,
                Layout.maximumLogoWidth
            )
            let logoHeight = logoWidth * Layout.logoAspectRatio

            ZStack {
                Color(uiColor: visualStyle.backgroundColor)

                if visualStyle.revealsAppBackground {
                    AppBackgroundView(appearance: appearance)
                        .opacity(isRevealed ? 1 : 0)
                }

                launchMark(
                    style: visualStyle,
                    width: logoWidth,
                    height: logoHeight
                )
                .scaleEffect(phase == .zooming && !reduceMotion ? motion.logoZoomScale : 1)
                .offset(
                    x: phase == .holding
                        ? horizontalMarkOffset(for: visualStyle.markStyle, width: logoWidth)
                        : 0
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear(perform: reveal)
        .task {
            await runSequence()
        }
    }

    @ViewBuilder
    private func launchMark(
        style: FakeLaunchVisualStyle,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        switch style.markStyle {
        case .classicImage:
            Image("QII")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: width)
        case .radarText:
            splitTextMark(
                font: radarFont(size: width * Layout.radarFontSizeRatio),
                color: style.foregroundColor ?? appearance.accentColor,
                width: width,
                height: height
            )
            .transformEffect(
                CGAffineTransform(
                    a: 1,
                    b: 0,
                    c: Layout.radarItalicShear,
                    d: 1,
                    tx: 0,
                    ty: 0
                )
            )
            .offset(y: width * Layout.radarVerticalOffsetRatio)
        case .cleanText:
            splitTextMark(
                font: .system(
                    size: width * Layout.cleanFontSizeRatio,
                    weight: .bold,
                    design: .default
                ),
                color: style.foregroundColor ?? appearance.accentColor,
                width: width,
                height: height
            )
            .italic()
            .offset(y: width * Layout.cleanVerticalOffsetRatio)
        }
    }

    private func splitTextMark(
        font: Font,
        color: UIColor,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let centerGap = width * Layout.centerGapRatio
        let sideWidth = (width - centerGap) / 2

        return HStack(spacing: centerGap) {
            Text("Q")
                .font(font)
                .fixedSize()
                .frame(width: sideWidth, alignment: .trailing)

            Text("II")
                .font(font)
                .fixedSize()
                .frame(width: sideWidth, alignment: .leading)
        }
        .foregroundStyle(Color(uiColor: color))
        .frame(width: width, height: height)
    }

    private func radarFont(size: CGFloat) -> Font {
        if let fontName = AppFontFamily.jetBrainsMono.fontName(weight: .medium) {
            return .custom(fontName, fixedSize: size)
        }
        return .system(size: size, weight: .medium, design: .monospaced)
    }

    private func horizontalMarkOffset(
        for style: FakeLaunchMarkStyle,
        width: CGFloat
    ) -> CGFloat {
        switch style {
        case .classicImage:
            return 0
        case .radarText:
            return width * Layout.radarHorizontalOffsetRatio
        case .cleanText:
            return width * Layout.cleanHorizontalOffsetRatio
        }
    }

    private func reveal() {
        guard FakeLaunchVisualStyle(appearance: appearance).revealsAppBackground else {
            isRevealed = true
            return
        }

        guard !reduceMotion, UIView.areAnimationsEnabled else {
            isRevealed = true
            return
        }

        withAnimation(.easeOut(duration: Motion.revealDuration)) {
            isRevealed = true
        }
    }

    @MainActor
    private func runSequence() async {
        let nanoseconds = UInt64(max(0, holdDuration) * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        guard !reduceMotion, UIView.areAnimationsEnabled else {
            finish(with: .crossfade)
            return
        }

        withAnimation(
            motion.logoZoomAnimation,
            completionCriteria: .logicallyComplete
        ) {
            phase = .zooming
        } completion: {
            finish(with: .revealHome)
        }
    }

    private func finish(with style: FakeLaunchCompletionStyle) {
        guard !didFinish else { return }
        didFinish = true
        onFinished(style)
    }
}

@MainActor
final class LaunchOverlayPresenter {
    private enum Timing {
        static let holdDuration: TimeInterval = 1.15
        static let homeRevealDuration: TimeInterval = 0.24
        static let reducedMotionRevealDuration: TimeInterval = 0.18
    }

    static let accessibilityIdentifier = "fakeLaunchScreen"

    private var overlayWindow: UIWindow?
    private var activePresentationID: UUID?
    private var activeDismissalID: UUID?
    private weak var coveredAccessibilityView: UIView?
    private var coveredViewWasAccessibilityHidden = false

    func present(
        in window: UIWindow,
        appearance: AppAppearance,
        holdDuration: TimeInterval = Timing.holdDuration,
        motion: FakeLaunchMotion = .standard
    ) {
        guard
            overlayWindow == nil,
            let windowScene = window.windowScene,
            let coveredView = window.rootViewController?.view
        else { return }

        let visualStyle = FakeLaunchVisualStyle(appearance: appearance)
        let presentationID = UUID()
        let hostingController = UIHostingController(
            rootView: FakeLaunchScreenView(
                appearance: appearance,
                holdDuration: holdDuration,
                motion: motion,
                onFinished: { [weak self] style in
                    self?.completePresentation(presentationID, with: style)
                }
            )
        )
        let overlayView = hostingController.view!
        overlayView.accessibilityIdentifier = Self.accessibilityIdentifier
        overlayView.accessibilityElementsHidden = true
        overlayView.backgroundColor = visualStyle.backgroundColor
        hostingController.overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.accessibilityIdentifier = Self.accessibilityIdentifier
        overlayWindow.accessibilityViewIsModal = true
        overlayWindow.backgroundColor = visualStyle.backgroundColor
        overlayWindow.windowLevel = UIWindow.Level(rawValue: window.windowLevel.rawValue + 1)
        overlayWindow.rootViewController = hostingController

        coveredAccessibilityView = coveredView
        coveredViewWasAccessibilityHidden = coveredView.accessibilityElementsHidden
        coveredView.accessibilityElementsHidden = true
        activePresentationID = presentationID
        self.overlayWindow = overlayWindow
        overlayWindow.isHidden = false
    }

    func dismiss(animated: Bool = true) {
        let duration = UIAccessibility.isReduceMotionEnabled
            ? Timing.reducedMotionRevealDuration
            : Timing.homeRevealDuration
        dismiss(animated: animated, duration: duration)
    }

    private func dismiss(animated: Bool, duration: TimeInterval) {
        activePresentationID = nil

        guard let overlayWindow else { return }

        guard animated, UIView.areAnimationsEnabled else {
            activeDismissalID = nil
            overlayWindow.layer.removeAllAnimations()
            finishDismissal(expectedWindow: overlayWindow)
            return
        }

        let dismissalID = UUID()
        activeDismissalID = dismissalID
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            overlayWindow.alpha = 0
        } completion: { [weak self, weak overlayWindow] _ in
            guard
                let self,
                let overlayWindow,
                activeDismissalID == dismissalID
            else { return }
            finishDismissal(expectedWindow: overlayWindow)
        }
    }

    private func completePresentation(
        _ presentationID: UUID,
        with style: FakeLaunchCompletionStyle
    ) {
        guard activePresentationID == presentationID else { return }

        switch style {
        case .revealHome:
            dismiss(animated: true, duration: Timing.homeRevealDuration)
        case .crossfade:
            dismiss(animated: true, duration: Timing.reducedMotionRevealDuration)
        }
    }

    private func finishDismissal(expectedWindow: UIWindow? = nil) {
        if let expectedWindow, overlayWindow !== expectedWindow {
            return
        }

        overlayWindow?.layer.removeAllAnimations()
        activePresentationID = nil
        activeDismissalID = nil
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil

        coveredAccessibilityView?.accessibilityElementsHidden = coveredViewWasAccessibilityHidden
        coveredAccessibilityView = nil
        UIAccessibility.post(notification: .screenChanged, argument: nil)
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
    func replayQuiz()
    func returnToThemes()
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
        viewController.configurePresenter(QuizResultPresenter(result: result))
        presentWithCardSlide(viewController, from: presentedViewController)
    }

    func showStatistics() {
        let viewController = StatisticsViewController(analytics: analytics)
        viewController.router = self
        navigationController.pushViewController(viewController, animated: true)
    }

    func showAIThemeCreation() {
        AppLog.quiz.debug("Opening AI quiz theme creation sheet")
        let viewControllerReference = WeakViewControllerReference()
        let appearance = AppAppearanceStore.shared.appearance(
            compatibleWith: presentedViewController.traitCollection
        )
        let rootView = QuizAIThemeCreationView(
            service: aiQuizThemeService,
            analytics: analytics,
            onGenerated: { [weak self, viewControllerReference] theme in
                guard let viewController = viewControllerReference.viewController else {
                    AppLog.quiz.error("AI quiz result could not be handled: creation sheet reference is missing")
                    self?.analytics.reportOperationalError(
                        AnalyticsOperationalIssue.missingAIViewController,
                        context: .aiResultHandling
                    )
                    return
                }
                self?.handleGeneratedAITheme(theme, dismissing: viewController)
            }
        )
        let viewController = UIHostingController(rootView: rootView)
        viewController.overrideUserInterfaceStyle = AIThemeKeyboardStyle(
            appearance: appearance
        ).interfaceStyle
        viewControllerReference.viewController = viewController
        viewController.modalPresentationStyle = .pageSheet
        if let sheetPresentationController = viewController.sheetPresentationController {
            sheetPresentationController.detents = [.large()]
            sheetPresentationController.prefersGrabberVisible = true
        }
        presentedViewController.present(viewController, animated: true)
    }

    func handleGeneratedAITheme(_ theme: QuizTheme, dismissing viewController: UIViewController) {
        AppLog.quiz.info("AI quiz result accepted: questions=\(theme.questions.count, privacy: .public)")
        session.chosenTheme = ThemeModel(quizTheme: theme)
        session.questionsCount = theme.questions.count
        analytics.track(.themeSelected(theme: .ai, method: .ai))
        viewController.dismiss(animated: true) { [weak self] in
            self?.showDescription()
        }
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

private final class WeakViewControllerReference {
    weak var viewController: UIViewController?
}

#if DEBUG
private enum DebugYandexAIAPIKeyStore {
    private static let environmentKey = "YANDEX_AI_API_KEY"
    private static let service = "ru.avtabenskiy.Quizice.debug-yandex-ai"
    private static let account = environmentKey

    static func resolveAPIKey() -> String? {
        let environmentValue = ProcessInfo.processInfo.environment[environmentKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let environmentValue, !environmentValue.isEmpty {
            save(environmentValue)
            AppLog.quiz.info("Yandex AI API key loaded from Xcode environment")
            return environmentValue
        }

        guard let storedValue = load() else {
            AppLog.quiz.error("Yandex AI API key is missing from both environment and Debug Keychain")
            return nil
        }

        AppLog.quiz.info("Yandex AI API key loaded from Debug Keychain")
        return storedValue
    }

    private static func save(_ value: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }

        if status != errSecSuccess {
            AppLog.quiz.error("Failed to save Yandex AI API key to Debug Keychain: status=\(status, privacy: .public)")
        }
    }

    private static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            AppLog.quiz.error("Failed to load Yandex AI API key from Debug Keychain: status=\(status, privacy: .public)")
            return nil
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            AppLog.quiz.error("Yandex AI API key in Debug Keychain has invalid data")
            return nil
        }
        return value
    }
}
#endif
