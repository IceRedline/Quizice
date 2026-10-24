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
        XCTAssertEqual(hostingController.rootView.themes.map(\.emoji), ["🎵", "🚀"])
        XCTAssertEqual(hostingController.rootView.themes.map(\.colorHex), ["#FF8252", "#304FFE"])
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

    func testNewUserOnboardingIsAlreadyVisibleWhenSplashDisappears() async throws {
        try await assertInitialScreenAtLaunchReveal(isCompleted: false)
    }

    func testReturningUserHomeIsAlreadyVisibleWhenSplashDisappears() async throws {
        try await assertInitialScreenAtLaunchReveal(isCompleted: true)
    }

    func testFinishingOnboardingPersistsThemesAndPreventsNextLaunchPresentation() throws {
        let harness = makeOnboardingHarness(isCompleted: false)
        harness.coordinator.start()
        harness.coordinator.presentInitialOnboardingIfNeeded()
        let hostingController = try XCTUnwrap(
            harness.navigationController.presentedControllers.first
                as? UIHostingController<QuizOnboardingView>
        )

        hostingController.rootView.onComplete(["space", "music"])

        XCTAssertFalse(harness.store.needsOnboarding)
        XCTAssertEqual(harness.store.preferredThemeIDs, ["music", "space"])
        XCTAssertEqual(
            harness.store.orderedPreferredThemeIDs(
                locale: AppLocalizationStore.shared.resolvedLanguageCode
            ),
            ["music", "space"]
        )
        XCTAssertTrue(
            harness.store.hasPendingThemePreferences(
                locale: AppLocalizationStore.shared.resolvedLanguageCode
            )
        )
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

    func testTopicsPageUsesAvailableVerticalSpaceForFallingThemes() throws {
        let themes = [
            OnboardingTheme(id: "music", title: "Музыка"),
            OnboardingTheme(id: "technology", title: "Технологии")
        ]
        let hostingController = UIHostingController(
            rootView: QuizOnboardingView(
                appearance: SnapshotSupport.appearance(designStyle: .clean),
                themes: themes,
                initialPage: .topics,
                onComplete: { _ in }
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.frame = window.bounds
        hostingController.view.setNeedsLayout()
        hostingController.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let physicsView = try XCTUnwrap(
            firstDescendant(of: TopicsPhysicsView.self, in: hostingController.view)
        )

        XCTAssertGreaterThan(
            physicsView.bounds.height,
            400,
            "The topics stage should consume the space that used to remain empty above the footer"
        )
    }

    func testFallingTopicCardsSizeToBackendTitlesWithoutWrapping() throws {
        let themes = [
            "Музыка",
            "Технологии",
            "История и культура",
            "Политика и бизнес",
            "Кино и сериалы",
            "Наука",
            "Спорт",
            "География",
            "Литература",
            "Природа и животные",
            "Игры",
            "Кулинария",
            "Изобретения и открытия",
            "Космос"
        ].enumerated().map { index, title in
            OnboardingTheme(id: "theme-\(index)", title: title)
        }
        let hostingController = UIHostingController(
            rootView: QuizOnboardingView(
                appearance: SnapshotSupport.appearance(designStyle: .clean),
                themes: themes,
                initialPage: .topics,
                onComplete: { _ in }
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.frame = window.bounds
        hostingController.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let physicsView = try XCTUnwrap(
            firstDescendant(of: TopicsPhysicsView.self, in: hostingController.view)
        )
        physicsView.layoutIfNeeded()

        for theme in themes {
            let card = try XCTUnwrap(
                physicsView.descendant(
                    withAccessibilityIdentifier: "onboardingTopic-\(theme.id)"
                )
            )
            card.layoutIfNeeded()
            let titleLabel = try XCTUnwrap(
                card.subviews.compactMap { $0 as? UILabel }.first
            )
            let requiredWidth = (theme.title as NSString).size(
                withAttributes: [.font: titleLabel.font as Any]
            ).width

            XCTAssertEqual(titleLabel.numberOfLines, 1)
            XCTAssertLessThanOrEqual(
                ceil(requiredWidth * titleLabel.minimumScaleFactor),
                floor(titleLabel.bounds.width),
                "\(theme.title) should fit on one line at the label's supported scale"
            )
        }
    }

    func testFallingTopicUsesBackendTintAndAnimatesExpressiveSelection() throws {
        let theme = OnboardingTheme(
            id: "cinema",
            title: "Кино",
            sfSymbolName: "film",
            emoji: "🎬",
            colorHex: "#FF2D55"
        )
        let hostingController = UIHostingController(
            rootView: QuizOnboardingView(
                appearance: SnapshotSupport.appearance(designStyle: .classic),
                themes: [theme],
                initialPage: .topics,
                onComplete: { _ in }
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.frame = window.bounds
        hostingController.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let card = try XCTUnwrap(
            hostingController.view.descendant(
                withAccessibilityIdentifier: "onboardingTopic-cinema"
            ) as? UIControl
        )
        let icon = try XCTUnwrap(
            card.descendant(
                withAccessibilityIdentifier: "onboardingTopicIcon-cinema"
            ) as? UIImageView
        )
        let selectionOverlay = try XCTUnwrap(
            card.descendant(
                withAccessibilityIdentifier: "onboardingTopicSelectionOverlay-cinema"
            )
        )
        let expectedTint = try XCTUnwrap(ThemeVisualCatalog.color(from: "#FF2D55"))
        let initialBorderWidth = card.layer.borderWidth

        XCTAssertEqual(icon.tintColor, expectedTint)
        XCTAssertEqual(selectionOverlay.alpha, 0)
        XCTAssertFalse(card.accessibilityTraits.contains(.selected))

        card.sendActions(for: .touchUpInside)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))

        XCTAssertGreaterThan(selectionOverlay.alpha, 0)
        XCTAssertGreaterThan(card.layer.borderWidth, initialBorderWidth)
        XCTAssertFalse(icon.transform.isIdentity)
        XCTAssertTrue(card.accessibilityTraits.contains(.selected))
        XCTAssertEqual(
            OnboardingTopicSelectionAnimationTiming.iconDuration,
            OnboardingTopicSelectionAnimationTiming.selectionDuration * 3,
            accuracy: 0.001
        )
    }

    func testSelectedTopicGlowStaysInsidePhysicsStageEdges() throws {
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        let themes = [
            OnboardingTheme(
                id: "history_culture",
                title: "История и культура",
                sfSymbolName: "theatermask.and.paintbrush.fill",
                colorHex: "#FF9500"
            ),
            OnboardingTheme(
                id: "videogames",
                title: "Видеоигры",
                sfSymbolName: "gamecontroller",
                colorHex: "#34C759"
            ),
            OnboardingTheme(
                id: "music",
                title: "Музыка",
                sfSymbolName: "music.note.list",
                colorHex: "#AF52DE"
            ),
            OnboardingTheme(
                id: "technology",
                title: "Технологии",
                sfSymbolName: "cpu.fill",
                colorHex: "#007AFF"
            )
        ]
        let hostingController = UIHostingController(
            rootView: QuizOnboardingView(
                appearance: SnapshotSupport.appearance(designStyle: .classic),
                themes: themes,
                initialPage: .topics,
                preferredThemeIDs: Set(themes.map(\.id)),
                onComplete: { _ in }
            )
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = hostingController
        window.makeKeyAndVisible()
        hostingController.view.frame = window.bounds
        hostingController.view.layoutIfNeeded()
        defer {
            window.isHidden = true
            window.rootViewController = nil
        }

        let physicsView = try XCTUnwrap(
            firstDescendant(of: TopicsPhysicsView.self, in: hostingController.view)
        )
        physicsView.layoutIfNeeded()

        for theme in themes {
            let card = try XCTUnwrap(
                physicsView.descendant(
                    withAccessibilityIdentifier: "onboardingTopic-\(theme.id)"
                )
            )
            let glowFrame = card.frame.insetBy(
                dx: -card.layer.shadowRadius,
                dy: -card.layer.shadowRadius
            )
            XCTAssertGreaterThanOrEqual(glowFrame.minX, physicsView.bounds.minX)
            XCTAssertLessThanOrEqual(glowFrame.maxX, physicsView.bounds.maxX)
            XCTAssertGreaterThanOrEqual(glowFrame.minY, physicsView.bounds.minY)
            XCTAssertLessThanOrEqual(glowFrame.maxY, physicsView.bounds.maxY)
        }
    }

    private func assertInitialScreenAtLaunchReveal(isCompleted: Bool) async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let suiteName = "QuizFlowCoordinatorOnboardingLaunchTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let store = OnboardingProgressStore(userDefaults: defaults)
        if isCompleted { store.complete(preferredThemeIDs: []) }
        let window = UIWindow(windowScene: scene)
        // A real navigation controller is required: a presentation spy would
        // complete synchronously and miss the frame of Home reported on device.
        let navigationController = UINavigationController()
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(
                themes: [SnapshotSupport.makeTheme(id: "music", name: "Music")]
            ),
            session: RoutingSession(),
            aiQuizThemeService: MockAIQuizThemeService(),
            onboardingProgressStore: store,
            analytics: OnboardingAnalyticsSpy()
        )
        let presenter = LaunchOverlayPresenter()
        let revealed = expectation(description: "The correct initial screen is revealed")
        var initialPresentationCompleted = false
        UIView.setAnimationsEnabled(false)
        defer {
            presenter.dismiss(animated: false)
            navigationController.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
            defaults.removePersistentDomain(forName: suiteName)
        }
        coordinator.start()
        window.isHidden = false
        window.layoutIfNeeded()

        presenter.present(
            in: window,
            appearance: makeLaunchAppearance(designStyle: .classic),
            holdDuration: 0,
            preparation: { await coordinator.prepareInitialCatalog() },
            prepareContentForReveal: { completion in
                coordinator.presentInitialOnboardingIfNeeded {
                    initialPresentationCompleted = true
                    if !isCompleted {
                        let onboarding = navigationController.presentedViewController
                            as? UIHostingController<QuizOnboardingView>
                        XCTAssertNotNil(onboarding)
                        XCTAssertTrue(onboarding?.view.window === window)
                    }
                    completion()
                }
            },
            onDismissed: {
                XCTAssertTrue(initialPresentationCompleted)
                if isCompleted {
                    XCTAssertNil(navigationController.presentedViewController)
                    let home = navigationController.topViewController as? QuizViewController
                    XCTAssertNotNil(home)
                    XCTAssertTrue(home?.view.window === window)
                } else {
                    let onboarding = navigationController.presentedViewController
                        as? UIHostingController<QuizOnboardingView>
                    XCTAssertNotNil(onboarding)
                    XCTAssertTrue(onboarding?.view.window === window)
                    if let view = onboarding?.view {
                        XCTAssertEqual(view.convert(view.bounds, to: window), window.bounds)
                    }
                }
                revealed.fulfill()
            }
        )

        await fulfillment(of: [revealed], timeout: 5)
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
                sfSymbolName: "music.note.list",
                emoji: "🎵",
                colorHex: "#FF8252"
            ),
            QuizTheme(
                id: "space",
                theme: "Space",
                themeDescription: "",
                questions: [],
                sfSymbolName: "globe",
                emoji: "🚀",
                colorHex: "#304FFE"
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
private func firstDescendant<T: UIView>(of type: T.Type, in root: UIView) -> T? {
    if let match = root as? T {
        return match
    }
    for subview in root.subviews {
        if let match = firstDescendant(of: type, in: subview) {
            return match
        }
    }
    return nil
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

extension QuizFlowCoordinatorOnboardingTests {
    func testQuestionStrategyBindingDefaultsToHideAnsweredWithoutWritingAChoice() {
        withStrategyOnboarding { harness in
            XCTAssertEqual(harness.controller.rootView.questionRepeatStrategy.wrappedValue, .hideAnswered)
            XCTAssertEqual(QuestionRepeatStrategyStore(defaults: harness.defaults).strategy, .hideAnswered)
            XCTAssertNil(harness.defaults.object(forKey: QuestionRepeatStrategyStore.defaultsKey))
            XCTAssertTrue(harness.completion.selections.isEmpty)
        }
    }

    func testQuestionStrategyBindingRespectsEverySavedChoiceDuringCompletedOnboardingReplay() {
        for strategy in QuestionRepeatStrategy.allCases {
            withStrategyOnboarding(savedStrategy: strategy, alreadyCompleted: true) { harness in
                XCTAssertEqual(harness.controller.rootView.questionRepeatStrategy.wrappedValue, strategy)
                XCTAssertEqual(harness.defaults.string(forKey: QuestionRepeatStrategyStore.defaultsKey), strategy.rawValue)
                XCTAssertFalse(OnboardingProgressStore(userDefaults: harness.defaults).needsOnboarding)
                XCTAssertTrue(harness.completion.selections.isEmpty)
            }
        }
    }

    func testQuestionStrategyBindingImmediatelyUpdatesSettingsWithoutCompletingOnboarding() {
        withStrategyOnboarding { harness in
            for strategy in [QuestionRepeatStrategy.showAll, .retryIncorrect, .hideAnswered] {
                harness.controller.rootView.questionRepeatStrategy.wrappedValue = strategy

                XCTAssertEqual(QuestionRepeatStrategyStore(defaults: harness.defaults).strategy, strategy)
                XCTAssertEqual(harness.defaults.string(forKey: QuestionRepeatStrategyStore.defaultsKey), strategy.rawValue)
                XCTAssertEqual(harness.controller.rootView.questionRepeatStrategy.wrappedValue, strategy)
                XCTAssertTrue(harness.completion.selections.isEmpty)
                XCTAssertTrue(OnboardingProgressStore(userDefaults: harness.defaults).needsOnboarding)
            }
        }
    }

    func testQuestionStrategyBindingSurvivesCompletionAndWelcomePageReopen() {
        withStrategyOnboarding { harness in
            harness.controller.rootView.questionRepeatStrategy.wrappedValue = .showAll
            harness.controller.rootView.onComplete(["music"])
            XCTAssertEqual(harness.completion.selections, [Set(["music"])])

            let replay = makeStrategyOnboardingController(
                defaults: harness.defaults, completion: harness.completion, initialPage: .welcome
            )
            harness.window.rootViewController = replay
            replay.view.frame = harness.window.bounds
            replay.view.layoutIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            XCTAssertEqual(replay.rootView.questionRepeatStrategy.wrappedValue, .showAll)
            XCTAssertEqual(QuestionRepeatStrategyStore(defaults: harness.defaults).strategy, .showAll)
            XCTAssertEqual(harness.defaults.string(forKey: QuestionRepeatStrategyStore.defaultsKey), "showAll")
            XCTAssertEqual(harness.completion.selections.count, 1)
        }
    }

    func testQuestionStrategyBindingFallsBackWithoutOverwritingUnknownSavedValue() {
        withStrategyOnboarding(rawStrategy: "unknown-future-strategy") { harness in
            XCTAssertEqual(harness.controller.rootView.questionRepeatStrategy.wrappedValue, .hideAnswered)
            XCTAssertEqual(harness.defaults.string(forKey: QuestionRepeatStrategyStore.defaultsKey), "unknown-future-strategy")

            harness.controller.rootView.questionRepeatStrategy.wrappedValue = .retryIncorrect

            XCTAssertEqual(QuestionRepeatStrategyStore(defaults: harness.defaults).strategy, .retryIncorrect)
            XCTAssertEqual(harness.defaults.string(forKey: QuestionRepeatStrategyStore.defaultsKey), "retryIncorrect")
            XCTAssertTrue(harness.completion.selections.isEmpty)
        }
    }

    func testQuestionStrategyBindingObservesChangesMadeThroughSharedSettingsStore() {
        withStrategyOnboarding(savedStrategy: .hideAnswered) { harness in
            QuestionRepeatStrategyStore(defaults: harness.defaults).strategy = .retryIncorrect
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))

            XCTAssertEqual(harness.controller.rootView.questionRepeatStrategy.wrappedValue, .retryIncorrect)
            XCTAssertTrue(harness.completion.selections.isEmpty)
        }
    }

    private func withStrategyOnboarding(
        savedStrategy: QuestionRepeatStrategy? = nil,
        rawStrategy: String? = nil,
        alreadyCompleted: Bool = false,
        _ operation: (OnboardingStrategyHarness) -> Void
    ) {
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let suiteName = "QuizFlowCoordinatorOnboardingTests.Strategy.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        if let savedStrategy { QuestionRepeatStrategyStore(defaults: defaults).strategy = savedStrategy }
        if let rawStrategy { defaults.set(rawStrategy, forKey: QuestionRepeatStrategyStore.defaultsKey) }
        if alreadyCompleted {
            OnboardingProgressStore(userDefaults: defaults).complete(preferredThemeIDs: ["music"])
        }
        let completion = OnboardingStrategyCompletionSpy()
        let controller = makeStrategyOnboardingController(defaults: defaults, completion: completion)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = controller
        window.makeKeyAndVisible()
        controller.view.frame = window.bounds
        controller.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        defer {
            window.isHidden = true
            window.rootViewController = nil
            defaults.removePersistentDomain(forName: suiteName)
            UIView.setAnimationsEnabled(animationsWereEnabled)
        }
        operation(OnboardingStrategyHarness(
            defaults: defaults, controller: controller, window: window, completion: completion
        ))
    }

    private func makeStrategyOnboardingController(
        defaults: UserDefaults,
        completion: OnboardingStrategyCompletionSpy,
        initialPage: OnboardingPage = .tutorial
    ) -> UIHostingController<QuizOnboardingView> {
        UIHostingController(rootView: QuizOnboardingView(
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            themes: [OnboardingTheme(id: "music", title: L10n.Onboarding.topicMusic)],
            initialPage: initialPage,
            preferredThemeIDs: ["music"],
            strategyDefaults: defaults,
            onComplete: { completion.selections.append($0) }
        ))
    }
}

@MainActor
private struct OnboardingStrategyHarness {
    let defaults: UserDefaults
    let controller: UIHostingController<QuizOnboardingView>
    let window: UIWindow
    let completion: OnboardingStrategyCompletionSpy
}

private final class OnboardingStrategyCompletionSpy {
    var selections: [Set<String>] = []
}
