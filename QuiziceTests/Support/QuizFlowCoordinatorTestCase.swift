import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
class QuizFlowCoordinatorTestCase: XCTestCase {
    override func tearDown() {
        resetSharedQuizFactoryForTests()
        super.tearDown()
    }

    func makeHarness() -> (
        coordinator: QuizFlowCoordinator,
        navigationController: RoutingNavigationControllerSpy,
        session: RoutingSession
    ) {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        session.chosenTheme = ThemeModel(quizTheme: SnapshotSupport.makeTheme(id: "music", name: "Music"))
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: []),
            session: session,
            aiQuizThemeService: MockAIQuizThemeService()
        )
        return (coordinator, navigationController, session)
    }

    func makeInlineAIHarness(
        service: ControllableRoutingAIQuizThemeService
    ) throws -> InlineAIHarness {
        let session = RoutingSession()
        let router = InlineAIRouterSpy()
        let analytics = InlineAIAnalyticsSpy()
        let viewController = QuizViewController(
            themeRepository: RoutingThemeRepository(themes: []),
            session: session,
            aiQuizThemeService: service,
            analytics: analytics,
            motivationPromptProvider: { _ in "Prompt" },
            cardReduceMotionProvider: { true },
            cardDeviceParallaxEnabledProvider: { false }
        )
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.loadViewIfNeeded()
        viewController.view.frame = window.bounds
        viewController.view.layoutIfNeeded()
        let collectionView = try XCTUnwrap(
            descendant(
                in: viewController.view,
                accessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()

        return InlineAIHarness(
            window: window,
            viewController: viewController,
            router: router,
            session: session,
            analytics: analytics,
            service: service
        )
    }

    func revealInlineAIBack(
        in viewController: QuizViewController,
        prompt: String
    ) throws -> InlineAIControls {
        let sourceButton = try XCTUnwrap(
            descendant(
                in: viewController.view,
                accessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainMainRunLoop(for: 0.4)

        let card = try XCTUnwrap(
            descendant(
                in: viewController.view,
                accessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
        let promptEditor = try XCTUnwrap(
            descendant(
                in: card,
                accessibilityIdentifier: "aiThemePromptEditor"
            ) as? UITextView
        )
        let playButton = try XCTUnwrap(
            descendant(
                in: card,
                accessibilityIdentifier: "expandedAIThemeCardPlayButton"
            ) as? UIButton
        )
        promptEditor.text = prompt
        promptEditor.delegate?.textViewDidChange?(promptEditor)
        XCTAssertTrue(playButton.isEnabled)
        // Flip mechanics have dedicated UI coverage. Keep these integration tests
        // deterministic by exposing the back form without waiting on a 3D animator.
        try XCTUnwrap(card as? ExpandedAIThemeCardView).setFace(.back, animated: false)

        let submitButton = try XCTUnwrap(
            descendant(
                in: card,
                accessibilityIdentifier: "aiThemeSubmitButton"
            ) as? UIButton
        )
        XCTAssertFalse(
            try XCTUnwrap(
                descendant(
                    in: card,
                    accessibilityIdentifier: "expandedAIThemeCardBackView"
                )
            ).isHidden
        )
        return InlineAIControls(
            card: card,
            promptEditor: promptEditor,
            submitButton: submitButton
        )
    }

    func closeInlineAICard(in viewController: QuizViewController) throws {
        let dismissButton = try XCTUnwrap(
            descendant(
                in: viewController.view,
                accessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        dismissButton.sendActions(for: .touchUpInside)
        drainMainRunLoop(for: 0.4)
    }

    func makeGeneratedAITheme(
        questionCount: Int,
        id: String = "generated_ai_theme"
    ) -> QuizTheme {
        let questions = (0..<questionCount).map { index in
            QuizQuestion(
                question: "Question \(index)",
                answers: ["A", "B", "C", "D"],
                correctAnswer: "A"
            )
        }
        return QuizTheme(
            id: id,
            theme: "Generated AI Theme",
            themeDescription: "Generated description",
            questions: questions,
            source: .ai
        )
    }

    func waitUntil(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else {
                XCTFail("Timed out waiting for inline AI state")
                return
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    func drainMainRunLoop(for duration: TimeInterval) {
        RunLoop.main.run(until: Date().addingTimeInterval(duration))
    }

    func descendant(in rootView: UIView, accessibilityIdentifier: String) -> UIView? {
        if rootView.accessibilityIdentifier == accessibilityIdentifier {
            return rootView
        }
        for subview in rootView.subviews {
            if let match = descendant(
                in: subview,
                accessibilityIdentifier: accessibilityIdentifier
            ) {
                return match
            }
        }
        return nil
    }

    func makeLaunchAppearance(
        designStyle: AppDesignStyle,
        cleanColorSchemePreference: CleanColorSchemePreference = .dark
    ) -> AppAppearance {
        AppAppearance(
            designStyle: designStyle,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: .slate5x5,
            traitCollection: UITraitCollection(
                userInterfaceStyle: cleanColorSchemePreference == .light ? .light : .dark
            )
        )
    }

    func assertColor(
        _ actual: UIColor?,
        equals expected: UIColor,
        accuracy: CGFloat = 0.000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual else {
            XCTFail("Expected a color", file: file, line: line)
            return
        }

        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0
        XCTAssertTrue(
            actual.getRed(
                &actualRed,
                green: &actualGreen,
                blue: &actualBlue,
                alpha: &actualAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertTrue(
            expected.getRed(
                &expectedRed,
                green: &expectedGreen,
                blue: &expectedBlue,
                alpha: &expectedAlpha
            ),
            file: file,
            line: line
        )
        XCTAssertEqual(actualRed, expectedRed, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualGreen, expectedGreen, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualBlue, expectedBlue, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actualAlpha, expectedAlpha, accuracy: accuracy, file: file, line: line)
    }
}

final class RoutingNavigationControllerSpy: UINavigationController {
    private(set) var presentedControllers: [UIViewController] = []
    private(set) var presentedAnimationFlags: [Bool] = []
    private(set) var popCallCount = 0
    private(set) var popToRootCallCount = 0
    private(set) var popToRootAnimationFlags: [Bool] = []
    private(set) var dismissCallCount = 0
    private(set) var dismissAnimationFlags: [Bool] = []
    private(set) var pushedControllers: [UIViewController] = []
    private(set) var pushAnimationFlags: [Bool] = []
    var topViewControllerOverride: UIViewController?

    override var topViewController: UIViewController? {
        topViewControllerOverride ?? super.topViewController
    }

    override func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {
        presentedControllers.append(viewControllerToPresent)
        presentedAnimationFlags.append(flag)
        completion?()
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        popCallCount += 1
        return viewControllers.popLast()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        pushedControllers.append(viewController)
        pushAnimationFlags.append(animated)
        super.pushViewController(viewController, animated: animated)
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        popToRootCallCount += 1
        popToRootAnimationFlags.append(animated)
        return []
    }

    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        dismissCallCount += 1
        dismissAnimationFlags.append(flag)
        completion?()
    }
}

final class RoutingThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?

    init(themes: [QuizTheme]) {
        self.themes = themes
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }
}

final class RoutingSession: QuizSessionManaging {
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount = 5
    var startup1st = false

    func loadTheme(themeID: String) -> Bool {
        guard let theme = themes?.first(where: { $0.stableID == themeID }) else {
            return false
        }
        chosenTheme = ThemeModel(quizTheme: theme)
        return true
    }
}

@MainActor
struct InlineAIHarness {
    let window: UIWindow
    let viewController: QuizViewController
    let router: InlineAIRouterSpy
    let session: RoutingSession
    let analytics: InlineAIAnalyticsSpy
    let service: ControllableRoutingAIQuizThemeService

    func dispose() {
        service.resolveAll(with: .failure(CancellationError()))
        viewController.dismiss(animated: false)
        window.isHidden = true
        window.rootViewController = nil
    }
}

struct InlineAIControls {
    let card: UIView
    let promptEditor: UITextView
    let submitButton: UIButton
}

final class InlineAIRouterSpy: QuizRouting {
    private(set) var showDescriptionCallCount = 0

    func showDescription() { showDescriptionCallCount += 1 }
    func showQuestion() {}
    func showResult(_ result: QuizResultState) {}
    func showStatistics() {}
    func showSettings() {}
    func closeDescription() {}
    func closeStatistics() {}
    func closeQuestion() {}
    func replayQuiz() {}
    func returnToThemes() {}
}

final class InlineAIAnalyticsSpy: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    var aiGenerationCancelledCount: Int {
        events.reduce(into: 0) { count, event in
            if case .aiGenerationCancelled = event {
                count += 1
            }
        }
    }

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {}
}

final class ControllableRoutingAIQuizThemeService: AIQuizThemeServiceProtocol, @unchecked Sendable {
    private struct PendingRequest {
        let continuation: CheckedContinuation<QuizTheme, Error>
    }

    private let lock = NSLock()
    private var configurations: [AIQuizGenerationConfiguration] = []
    private var pendingRequests: [PendingRequest] = []

    var generatedConfigurations: [AIQuizGenerationConfiguration] {
        withLock { configurations }
    }

    func generateQuizTheme(
        configuration: AIQuizGenerationConfiguration
    ) async throws -> QuizTheme {
        try await withCheckedThrowingContinuation { continuation in
            withLock {
                configurations.append(configuration)
                pendingRequests.append(PendingRequest(continuation: continuation))
            }
        }
    }

    func resolveNext(with result: Result<QuizTheme, Error>) {
        let continuation = withLock {
            pendingRequests.isEmpty ? nil : pendingRequests.removeFirst().continuation
        }
        continuation?.resume(with: result)
    }

    func resolveAll(with result: Result<QuizTheme, Error>) {
        let continuations = withLock {
            let continuations = pendingRequests.map(\.continuation)
            pendingRequests.removeAll()
            return continuations
        }
        continuations.forEach { $0.resume(with: result) }
    }

    private func withLock<Value>(_ operation: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

extension UIView {
    var allDescendants: [UIView] {
        subviews + subviews.flatMap(\.allDescendants)
    }
}
