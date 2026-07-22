import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorOnboardingTests: QuizFlowCoordinatorTestCase {
    func testInitialOnboardingPresentsOnceWhenCurrentVersionIsIncomplete() throws {
        let harness = makeOnboardingHarness(isCompleted: false)

        harness.coordinator.start()
        harness.coordinator.presentInitialOnboardingIfNeeded()
        harness.coordinator.presentInitialOnboardingIfNeeded()

        XCTAssertEqual(harness.navigationController.presentedControllers.count, 1)
        let hostingController = try XCTUnwrap(
            harness.navigationController.presentedControllers.first
                as? UIHostingController<QuizOnboardingView>
        )
        XCTAssertEqual(hostingController.modalPresentationStyle, .fullScreen)
        XCTAssertEqual(hostingController.rootView.themes.map(\.id), ["music", "space"])
        XCTAssertEqual(hostingController.rootView.themes.map(\.title), ["Music", "Space"])
        XCTAssertEqual(hostingController.rootView.themes.map(\.sfSymbolName), ["music.note.list", "globe"])
        XCTAssertEqual(hostingController.rootView.catalogOrigin, .backend)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags, [false])
        XCTAssertEqual(harness.analytics.onboardingScreenViewCount, 1)
    }

    func testCompletedVersionSkipsInitialOnboarding() {
        let harness = makeOnboardingHarness(isCompleted: true)

        harness.coordinator.start()
        harness.coordinator.presentInitialOnboardingIfNeeded()

        XCTAssertTrue(harness.navigationController.presentedControllers.isEmpty)
        XCTAssertEqual(harness.analytics.onboardingScreenViewCount, 0)
    }

    func testFinishingOnboardingPersistsThemesAndPreventsNextLaunchPresentation() throws {
        let harness = makeOnboardingHarness(isCompleted: false)
        harness.coordinator.start()
        harness.coordinator.presentInitialOnboardingIfNeeded()
        let hostingController = try XCTUnwrap(
            harness.navigationController.presentedControllers.first
                as? UIHostingController<QuizOnboardingView>
        )

        hostingController.rootView.onComplete(["music", "history_culture"])

        XCTAssertFalse(harness.store.needsOnboarding)
        XCTAssertEqual(harness.store.preferredThemeIDs, ["music", "history_culture"])
    }

    func testManualReplayPresentsAnimatedWithoutResettingCompletion() {
        let harness = makeOnboardingHarness(isCompleted: true)
        harness.coordinator.start()

        harness.coordinator.showOnboarding()

        XCTAssertEqual(harness.navigationController.presentedControllers.count, 1)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags, [true])
        XCTAssertFalse(harness.store.needsOnboarding)
    }

    func testSystemPresentationWaitsUntilInitialOnboardingCompletes() {
        let harness = makeOnboardingHarness(isCompleted: false)
        let systemViewController = UIViewController()
        harness.coordinator.start()
        harness.coordinator.presentInitialOnboardingIfNeeded()

        harness.coordinator.presentSystemViewController(systemViewController)

        XCTAssertEqual(harness.navigationController.presentedControllers.count, 1)
        XCTAssertFalse(harness.navigationController.presentedControllers.contains(systemViewController))

        harness.coordinator.completeOnboarding(preferredThemeIDs: [])

        XCTAssertEqual(harness.navigationController.presentedControllers.count, 2)
        XCTAssertTrue(harness.navigationController.presentedControllers.last === systemViewController)
        XCTAssertEqual(harness.navigationController.presentedAnimationFlags, [false, true])
    }

    private func makeOnboardingHarness(isCompleted: Bool) -> OnboardingHarness {
        let suiteName = "QuizFlowCoordinatorOnboardingTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = OnboardingProgressStore(userDefaults: defaults)
        if isCompleted {
            store.complete(preferredThemeIDs: ["technology"])
        }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let analytics = OnboardingAnalyticsSpy()
        let themes = [
            QuizTheme(
                id: "music",
                theme: "Music",
                themeDescription: "",
                questions: [],
                sfSymbolName: "music.note.list"
            ),
            QuizTheme(
                id: "space",
                theme: "Space",
                themeDescription: "",
                questions: [],
                sfSymbolName: "globe"
            )
        ]
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: themes, catalogOrigin: .backend),
            session: RoutingSession(),
            aiQuizThemeService: MockAIQuizThemeService(),
            onboardingProgressStore: store,
            analytics: analytics
        )
        return OnboardingHarness(
            coordinator: coordinator,
            navigationController: navigationController,
            store: store,
            analytics: analytics
        )
    }
}

@MainActor
private struct OnboardingHarness {
    let coordinator: QuizFlowCoordinator
    let navigationController: RoutingNavigationControllerSpy
    let store: OnboardingProgressStore
    let analytics: OnboardingAnalyticsSpy
}

private final class OnboardingAnalyticsSpy: AnalyticsTracking {
    private(set) var onboardingScreenViewCount = 0

    func track(_ event: AnalyticsEvent) {
        if case .screenView(.onboarding, _) = event {
            onboardingScreenViewCount += 1
        }
    }

    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {}
}
