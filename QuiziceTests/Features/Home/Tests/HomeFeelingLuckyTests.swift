import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeFeelingLuckyTests: HomeScreenVisualStateTestCase {
    func testFeelingLuckyStartsFiveQuestionsWithoutDescription() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        QuizFactory.shared.questionsCount = 15

        let viewController = QuizViewController(
            randomThemeIDProvider: { _ in "music" },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        luckyButton.sendActions(for: .touchUpInside)
        drainAnimations(0.01)

        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertEqual(router.showDescriptionCallCount, 0)
    }

    func testFeelingLuckyAnalyticsTracksRandomFiveQuestionStart() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let analytics = HomeAnalyticsTrackingSpy()
        let viewController = QuizViewController(
            analytics: analytics,
            randomThemeIDProvider: { _ in "music" },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)
        analytics.reset()

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        luckyButton.sendActions(for: .touchUpInside)
        drainAnimations(0.01)

        let luckyEvents = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(luckyEvents.map(\.name), ["theme_selected", "quiz_started"])
        guard luckyEvents.count == 2 else { return }
        XCTAssertEqual(luckyEvents[0].parameters["selection_method"] as? String, "random")
        XCTAssertEqual(luckyEvents[0].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(luckyEvents[1].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(luckyEvents[1].parameters["question_count"] as? Int, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyOffersOnlyThemesThatCanSupplyFiveQuestions() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка", questionCount: 4),
            makeTheme(name: "Технологии", questionCount: 5)
        ]
        var offeredThemeIDs: [String] = []
        let viewController = QuizViewController(
            randomThemeIDProvider: { themes in
                offeredThemeIDs = themes.map(\.stableID)
                return themes.first?.stableID
            },
            feelingLuckyMinimumFeedbackDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        drainAnimations(0.01)

        XCTAssertEqual(offeredThemeIDs, ["technology"])
        XCTAssertEqual(QuizFactory.shared.chosenTheme?.themeID, "technology")
        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyShowsProgressUntilMinimumFeedbackDelayCompletes() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        var releaseDelay: (() -> Void)?
        let viewController = QuizViewController(
            randomThemeIDProvider: { _ in "music" },
            feelingLuckyMinimumFeedbackDelay: {
                await withCheckedContinuation { continuation in
                    releaseDelay = { continuation.resume() }
                }
            }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView
        )
        let progressView = try XCTUnwrap(
            luckyButton.descendant(withAccessibilityIdentifier: "homeFeelingLuckyProgressView")
                as? UIActivityIndicatorView
        )

        luckyButton.sendActions(for: .touchUpInside)
        luckyButton.sendActions(for: .touchUpInside)
        drainAnimations(0.01)

        XCTAssertFalse(luckyButton.isEnabled)
        XCTAssertTrue(progressView.isAnimating)
        XCTAssertEqual(luckyButton.accessibilityLabel, L10n.Home.feelingLuckyLoading)
        XCTAssertFalse(collectionView.isUserInteractionEnabled)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        XCTAssertTrue(viewController.cardSlideTransitionSourceView === luckyButton)
        XCTAssertNotNil(releaseDelay)

        QuizFactory.shared.questionsCount = 10
        releaseDelay?()
        drainAnimations(0.01)

        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertTrue(progressView.isAnimating)
        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
    }

    func testFeelingLuckyCancellationRestoresHomeAndIgnoresStaleDelayCompletion() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        var releaseDelay: (() -> Void)?
        let viewController = QuizViewController(
            randomThemeIDProvider: { _ in "music" },
            feelingLuckyMinimumFeedbackDelay: {
                await withCheckedContinuation { continuation in
                    releaseDelay = { continuation.resume() }
                }
            }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        let progressView = try XCTUnwrap(
            luckyButton.descendant(withAccessibilityIdentifier: "homeFeelingLuckyProgressView")
                as? UIActivityIndicatorView
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView")
                as? UICollectionView
        )
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        drainAnimations(0.01)
        XCTAssertNotNil(releaseDelay)
        XCTAssertTrue(progressView.isAnimating)

        viewController.quizFlowWillReturnToThemes()

        XCTAssertTrue(luckyButton.isEnabled)
        XCTAssertFalse(progressView.isAnimating)
        XCTAssertEqual(luckyButton.accessibilityLabel, L10n.Home.feelingLucky)
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertTrue(settingsButton.isEnabled)
        XCTAssertEqual(router.showQuestionCallCount, 0)

        releaseDelay?()
        drainAnimations(0.01)

        XCTAssertEqual(router.showQuestionCallCount, 0)
        XCTAssertTrue(luckyButton.isEnabled)
        XCTAssertFalse(progressView.isAnimating)
    }

    func testFeelingLuckyRejectsProviderResultOutsideEligibleThemes() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка", questionCount: 4),
            makeTheme(name: "Технологии", questionCount: 5)
        ]
        let viewController = QuizViewController(randomThemeIDProvider: { _ in "music" })
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        let motivationLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel
        )
        XCTAssertEqual(motivationLabel.text, L10n.Question.unavailableMessage)
    }

}
