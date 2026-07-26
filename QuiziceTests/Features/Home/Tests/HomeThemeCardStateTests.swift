import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeThemeCardStateTests: HomeScreenVisualStateTestCase {
    func testAppearanceRefreshDuringFlipCompletesReducerAndAllowsClose() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )

        infoButton.sendActions(for: .touchUpInside)
        viewController.applyLocalizedStrings()
        drainAnimations(0.34)

        let backButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )
        backButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        closeButton.sendActions(for: .touchUpInside)
        drainAnimations()

        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
    }

    func testExpandedThemeBackDisablesStartWhenNoSupportedCountIsAvailable() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 4)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let unavailableLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardUnavailableLabel") as? UILabel
        )
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        XCTAssertFalse(unavailableLabel.isHidden)
        XCTAssertEqual(unavailableLabel.text, L10n.Question.unavailableMessage)
        XCTAssertFalse(startButton.isEnabled)
    }

    func testThemeCardPrepareForReuseRestoresVisibleInteractiveState() {
        let cell = ThemeCardCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 160, height: 160))
        let theme = makeTheme(name: "Музыка", questionCount: 5)
        let appearance = AppAppearanceStore.shared.appearance(compatibleWith: .current)
        cell.configure(theme: theme, appearance: appearance, isSourceHidden: true)

        XCTAssertTrue(cell.actionButton.isHidden)
        XCTAssertFalse(cell.actionButton.isUserInteractionEnabled)
        XCTAssertEqual(cell.layer.shadowOpacity, 0)

        cell.prepareForReuse()

        XCTAssertFalse(cell.actionButton.isHidden)
        XCTAssertTrue(cell.actionButton.isUserInteractionEnabled)
        XCTAssertNil(cell.actionButton.accessibilityIdentifier)
        XCTAssertEqual(cell.actionButton.transform, .identity)
        XCTAssertEqual(cell.actionButton.alpha, 1)
    }

    func testExpandedThemeStartButtonShowsAndClearsLoadingIndicator() throws {
        let card = makeHostedExpandedThemeCard(
            motionProvider: HomeThemeCardMotionProviderFake(isAvailable: false)
        )
        let startButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        let activityIndicator = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartActivityIndicator")
                as? UIActivityIndicatorView
        )

        card.setStartLoading(true)

        XCTAssertFalse(startButton.isEnabled)
        XCTAssertNil(startButton.title(for: .normal))
        XCTAssertTrue(activityIndicator.isAnimating)

        card.setStartLoading(false)

        XCTAssertTrue(startButton.isEnabled)
        XCTAssertEqual(startButton.title(for: .normal), L10n.Common.start)
        XCTAssertFalse(activityIndicator.isAnimating)
    }

    func testBackendOnlyThemeStartsEvenWhenSessionCatalogIsStale() async throws {
        let metadata = QuizTheme(
            id: "space",
            theme: "Космос",
            themeDescription: "Backend-only theme",
            questions: [],
            sfSymbolName: "moon.stars.fill",
            emoji: "🚀",
            colorHex: "#BF5AF2",
            questionOrigin: .backend
        )
        let repository = BackendOnlyHomeThemeRepository(metadata: metadata)
        let session = RoutingSession()
        session.themes = []
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session,
            cardReduceMotionProvider: { true },
            quizPreparationProgressDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "space") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        try await waitUntil { viewController.homeCardState.phase == .expandedFront }
        XCTAssertEqual(session.chosenTheme?.themeID, "space")

        let infoButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardInfoButton"
            ) as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        try await waitUntil { viewController.homeCardState.phase == .expandedBack }

        let startButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "descriptionStartButton"
            ) as? UIButton
        )
        XCTAssertTrue(startButton.isEnabled)
        startButton.sendActions(for: .touchUpInside)
        try await waitUntil { router.showQuestionCallCount == 1 }

        XCTAssertEqual(repository.preparedThemeIDs, ["space"])
        XCTAssertEqual(session.chosenTheme?.questionsAndAnswers.count, 5)
    }

    func testSlowQuizPreparationShowsStartIndicatorAfterConfiguredDelay() async throws {
        let theme = makeTheme(name: "Музыка", questionCount: 15)
        let repository = HangingRoutingThemeRepository(themes: [theme])
        let session = RoutingSession()
        session.themes = [theme]
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session,
            cardReduceMotionProvider: { true },
            quizPreparationProgressDelay: {}
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        try await waitUntil { viewController.homeCardState.phase == .expandedFront }
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        try await waitUntil { viewController.homeCardState.phase == .expandedBack }
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        let activityIndicator = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartActivityIndicator")
                as? UIActivityIndicatorView
        )

        startButton.sendActions(for: .touchUpInside)
        try await waitUntil { repository.prepareQuizCallCount == 1 && activityIndicator.isAnimating }

        XCTAssertFalse(startButton.isEnabled)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        viewController.removeExpandedThemeCardViews()
        XCTAssertFalse(activityIndicator.isAnimating)
    }

}

private final class BackendOnlyHomeThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?
    private(set) var preparedThemeIDs: [String] = []

    init(metadata: QuizTheme) {
        themes = [metadata]
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }

    func prepareQuiz(
        themeID: String,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        guard let metadata = themes?.first(where: { $0.stableID == themeID }) else {
            throw QuizPreparationError.unavailable
        }
        preparedThemeIDs.append(themeID)
        let questions = (0..<questionCount).map { index in
            QuizQuestion(
                question: "Remote question \(index)?",
                answers: ["A", "B", "C", "D"],
                correctAnswer: "A"
            )
        }
        return QuizTheme(
            id: metadata.id,
            theme: metadata.theme,
            themeDescription: metadata.themeDescription,
            questions: questions,
            sfSymbolName: metadata.sfSymbolName,
            emoji: metadata.emoji,
            colorHex: metadata.colorHex,
            questionOrigin: .backend
        )
    }
}
