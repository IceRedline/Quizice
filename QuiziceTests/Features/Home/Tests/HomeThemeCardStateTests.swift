import SwiftData
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
            cardReduceMotionProvider: { true }
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

    func testSlowQuizPreparationShowsStartIndicatorImmediately() async throws {
        let theme = makeTheme(name: "Музыка", questionCount: 15)
        let repository = HangingRoutingThemeRepository(themes: [theme])
        let session = RoutingSession()
        session.themes = [theme]
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session,
            cardReduceMotionProvider: { true }
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
        XCTAssertFalse(startButton.isEnabled)
        XCTAssertTrue(activityIndicator.isAnimating)
        try await waitUntil { repository.prepareQuizCallCount == 1 }
        XCTAssertEqual(router.showQuestionCallCount, 0)
        viewController.removeExpandedThemeCardViews()
        XCTAssertFalse(activityIndicator.isAnimating)
    }

    // These two exercise the real production `ThemeCatalogRepository` end to
    // end (real JSON load / real backend-refresh bookkeeping) instead of a
    // hand-populated theme list, to catch regressions in the actual
    // availability pipeline behind the reported "Start always announces
    // unavailable" bug that a fully-mocked repository can't see.
    func testRealBundledCatalogEnablesStartButtonForDefaultThemes() async throws {
        let repository = ThemeCatalogRepository(backendContentAPI: nil)
        repository.loadData(forceReload: true)
        XCTAssertEqual(repository.catalogOrigin, .bundled)

        let session = RoutingSession()
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session,
            cardReduceMotionProvider: { true }
        )
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
        let unavailableLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardUnavailableLabel") as? UILabel
        )
        XCTAssertTrue(startButton.isEnabled, "Start should be enabled: the real bundled catalog has plenty of usable questions")
        XCTAssertTrue(unavailableLabel.isHidden)
    }

    func testRealBackendCatalogEnablesStartButtonEvenBeforeQuestionsAreFetched() async throws {
        let repository = ThemeCatalogRepository(
            backendContentAPI: RecordingBackendContentAPI()
        )
        repository.loadData(forceReload: true)
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let didRefresh = await repository.refreshBackendCatalog(locale: locale)
        XCTAssertTrue(didRefresh)
        XCTAssertEqual(repository.catalogOrigin, .backend)
        XCTAssertTrue(repository.themes?.first?.questions.isEmpty == true)

        let session = RoutingSession()
        let viewController = QuizViewController(
            themeRepository: repository,
            session: session,
            cardReduceMotionProvider: { true }
        )
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
        XCTAssertTrue(
            startButton.isEnabled,
            "Start should be enabled for backend-origin themes even though their questions aren't fetched yet"
        )
    }
}

private final class BackendOnlyHomeThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?
    let catalogOrigin: QuizCatalogOrigin = .backend
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

extension HomeThemeCardStateTests {
    func testCountryPickerAppearsOnlyOnPoliticsCardBackAndCanChangeEveryRound() throws {
        let card = ExpandedThemeCardView(frame: CGRect(x: 0, y: 0, width: 342, height: 550))
        let appearance = AppAppearance(
            designStyle: .clean, cleanColorSchemePreference: .dark,
            traitCollection: UITraitCollection(userInterfaceStyle: .dark)
        )
        let politics = makeTheme(name: "Политика и бизнес", questionCount: 15)
        politics.id = "politics_business"
        politics.countries = ["DE", "US", "ES", "FR", "IT", "RU"]
        card.configure(theme: politics, appearance: appearance, availableQuestionCounts: [5, 10, 15],
                       selectedQuestionCount: 5, selectedCountry: nil)
        card.setFace(.back, animated: false)
        card.layoutIfNeeded()
        XCTAssertFalse(card.countryButton.isHidden)
        XCTAssertTrue(card.countryButton.isDescendant(of: card.backFaceView))
        XCTAssertTrue(card.backControlsStack.arrangedSubviews.contains(card.countryButton))
        XCTAssertEqual(card.countryButton.menu?.children.count, 7)
        XCTAssertEqual(card.countryButton.accessibilityValue, L10n.ThemeCard.internationalQuestions)
        var choices: [String?] = []
        card.onCountryChanged = { choices.append($0) }
        card.selectCountry("US")
        XCTAssertEqual(card.selectedCountry, "US")
        card.selectCountry("DE")
        card.selectCountry(nil)
        XCTAssertEqual(choices, ["US", "DE", nil])
        card.selectCountry("GB")
        XCTAssertEqual(choices.count, 3)
        card.setStartLoading(true)
        card.selectCountry("US")
        XCTAssertNil(card.selectedCountry)
        XCTAssertFalse(card.countryButton.isEnabled)

        let music = makeTheme(name: "Music", questionCount: 15)
        music.countries = ["US"] // Even unexpected metadata must not expose the picker on other themes.
        card.configure(theme: music, appearance: appearance, availableQuestionCounts: [5], selectedQuestionCount: 5)
        XCTAssertTrue(card.countryButton.isHidden)
        politics.countries = []
        card.configure(theme: politics, appearance: appearance, availableQuestionCounts: [5], selectedQuestionCount: 5)
        XCTAssertTrue(card.countryButton.isHidden)
    }

    func testCountryMetadataSurvivesSwiftDataCacheRoundTrip() throws {
        let container = try ModelContainer(for: SwiftDataThemeStore.schema,
                                          configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let store = SwiftDataThemeStore(context: container.mainContext)
        let theme = makeTheme(name: "Politics", questionCount: 0)
        theme.id = "politics_business"
        theme.countries = ["DE", "US", "ES", "FR", "IT", "RU"]
        store.replaceThemes(with: [theme], locale: "ru", catalogOrigin: .backend)
        let restored = try XCTUnwrap(store.fetchThemes().first)
        XCTAssertEqual(restored.countries, theme.countries)
        XCTAssertEqual(restored.questionOrigin, theme.questionOrigin)
    }

    func testNextRoundOpensPoliticsCardBackForCountrySelection() throws {
        let previousCountry = QuestionCountryStore.shared.country
        defer { QuestionCountryStore.shared.country = previousCountry }
        QuestionCountryStore.shared.country = nil
        let theme = makeTheme(name: "Политика и бизнес", questionCount: 15)
        theme.id = "politics_business"
        theme.countries = ["US", "RU"]
        QuizFactory.shared.themes = [theme]
        let controller = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        controller.configureNextRound(themeID: theme.id)
        drainAnimations(0.8)
        XCTAssertEqual(controller.homeCardState.phase, .expandedBack)
        XCTAssertEqual(controller.expandedThemeCardView?.face, .back)
        XCTAssertEqual(controller.expandedThemeCardView?.countryButton.isHidden, false)
        controller.expandedThemeCardView?.selectCountry("US")
        XCTAssertEqual(QuestionCountryStore.shared.country, "US")
        controller.resetExpandedThemeCard()
        controller.configureNextRound(themeID: theme.id)
        drainAnimations(0.8)
        XCTAssertEqual(controller.expandedThemeCardView?.selectedCountry, "US")
        controller.expandedThemeCardView?.selectCountry("RU")
        XCTAssertEqual(QuestionCountryStore.shared.country, "RU")
    }
}
