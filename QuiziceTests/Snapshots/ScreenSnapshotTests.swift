import UIKit
import XCTest
import SnapshotTesting
@testable import Quizice

@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let portraitSize = CGSize(width: 390, height: 844)
    private let compactPortraitSize = CGSize(width: 375, height: 667)
    private let landscapeSize = CGSize(width: 844, height: 390)
    private var defaultsSuiteNames: [String] = []

    override func setUp() {
        super.setUp()
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .light)
    }

    override func tearDown() {
        defaultsSuiteNames.forEach { UserDefaults.standard.removePersistentDomain(forName: $0) }
        defaultsSuiteNames.removeAll()
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testHomeScreenSnapshot() {
        SnapshotSupport.assertScreen(makeHomeViewController(), named: "clean-home", size: portraitSize)
    }

    func testHomeCompactPortraitSnapshot() {
        SnapshotSupport.assertScreen(
            makeHomeViewController(),
            named: "clean-home-iphone-se",
            device: .iPhone8
        )
    }

    func testHomeCompactPortraitBottomSnapshot() {
        let viewController = BottomScrolledHomeSnapshotViewController(
            homeViewController: makeHomeViewController()
        )
        SnapshotSupport.assertScreen(
            viewController,
            named: "clean-home-iphone-se-bottom",
            device: .iPhone8
        )
    }

    func testRadarHomeCompactPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeHomeViewController(),
            named: "radar-home-iphone-se",
            device: .iPhone8
        )
    }

    func testRadarExpandedStatisticsLargeHistorySnapshot() throws {
        SnapshotSupport.setUp(designStyle: .radar)
        let size = try XCTUnwrap(SnapshotSupport.iPhone17Pro.size)

        SnapshotSupport.assertScreen(
            try makeExpandedStatisticsCardViewController(size: size),
            named: "radar-home-expanded-statistics-large-history-iphone-17-pro",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testClassicExpandedThemeCardFrontSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .classic)

        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(face: .front, size: portraitSize),
            named: "classic-home-expanded-theme-front",
            size: portraitSize
        )
    }

    func testRadarExpandedThemeCardBackSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(face: .back, size: portraitSize),
            named: "radar-home-expanded-theme-back",
            size: portraitSize
        )
    }

    func testCleanLightExpandedThemeCardFrontSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(face: .front, size: portraitSize),
            named: "clean-light-home-expanded-theme-front",
            size: portraitSize
        )
    }

    func testCleanDarkExpandedThemeCardBackSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .dark)

        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(
                face: .back,
                size: portraitSize,
                userInterfaceStyle: .dark
            ),
            named: "clean-dark-home-expanded-theme-back",
            size: portraitSize
        )
    }

    func testCleanExpandedThemeCardCompactFrontSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(face: .front, size: compactPortraitSize),
            named: "clean-home-expanded-theme-front-iphone-se",
            device: .iPhone8
        )
    }

    func testCleanExpandedThemeCardAccessibilityXXXLBackSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedThemeCardViewController(
                face: .back,
                size: portraitSize,
                contentSizeCategory: .accessibilityExtraExtraExtraLarge
            ),
            named: "clean-home-expanded-theme-back-accessibility-xxxl",
            size: portraitSize,
            contentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
    }

    func testClassicExpandedAIThemeCardFrontSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .classic)

        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(face: .front, size: portraitSize),
            named: "classic-home-expanded-ai-theme-front",
            size: portraitSize
        )
    }

    func testRadarExpandedAIThemeCardBackSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(face: .back, size: portraitSize),
            named: "radar-home-expanded-ai-theme-back",
            size: portraitSize
        )
    }

    func testCleanLightExpandedAIThemeCardFrontSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(face: .front, size: portraitSize),
            named: "clean-light-home-expanded-ai-theme-front",
            size: portraitSize
        )
    }

    func testCleanDarkExpandedAIThemeCardBackSnapshot() throws {
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .dark)

        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(
                face: .back,
                size: portraitSize,
                userInterfaceStyle: .dark
            ),
            named: "clean-dark-home-expanded-ai-theme-back",
            size: portraitSize
        )
    }

    func testCleanExpandedAIThemeCardCompactFrontSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(face: .front, size: compactPortraitSize),
            named: "clean-home-expanded-ai-theme-front-iphone-se",
            device: .iPhone8
        )
    }

    func testCleanExpandedAIThemeCardAccessibilityXXXLBackSnapshot() throws {
        SnapshotSupport.assertScreen(
            try makeExpandedAIThemeCardViewController(
                face: .back,
                size: portraitSize,
                contentSizeCategory: .accessibilityExtraExtraExtraLarge
            ),
            named: "clean-home-expanded-ai-theme-back-accessibility-xxxl",
            size: portraitSize,
            contentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
    }

    func testQuestionScreenSnapshot() {
        SnapshotSupport.assertScreen(makeQuestionViewController(), named: "clean-question", size: portraitSize)
    }

    func testClassicLongAnswerModernPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .classic)

        SnapshotSupport.assertScreen(
            makeLongAnswerQuestionViewController(),
            named: "classic-long-answer-iphone-17-pro",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testClassicLongAnswerCompactPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .classic)

        SnapshotSupport.assertScreen(
            makeLongAnswerQuestionViewController(),
            named: "classic-long-answer-iphone-se",
            device: .iPhone8
        )
    }

    func testRadarLongAnswerModernPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeLongAnswerQuestionViewController(),
            named: "radar-long-answer-iphone-17-pro",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testRadarLongAnswerCompactPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeLongAnswerQuestionViewController(),
            named: "radar-long-answer-iphone-se",
            device: .iPhone8
        )
    }

    func testRadarJapanQuestionInitialModernPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeJapanQuestionViewController(),
            named: "radar-japan-question-initial-iphone-17-pro",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testRadarJapanQuestionInitialCompactPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeJapanQuestionViewController(),
            named: "radar-japan-question-initial-iphone-se",
            device: .iPhone8
        )
    }

    func testCleanLongAnswerCompactPortraitSnapshot() {
        SnapshotSupport.assertScreen(
            makeLongAnswerQuestionViewController(),
            named: "clean-long-answer-iphone-se",
            device: .iPhone8
        )
    }

    func testResultScreenSnapshot() {
        SnapshotSupport.assertScreen(makeResultViewController(), named: "clean-result", size: portraitSize)
    }

    func testQuestionAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: { self.makeQuestionViewController() }, screenName: "question")
    }

    func testResultAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeResultViewController, screenName: "result")
    }

    private func assertAdaptiveSnapshots(
        makeViewController: () -> UIViewController,
        screenName: String
    ) {
        SnapshotSupport.assertScreen(
            makeViewController(),
            named: "clean-\(screenName)-landscape",
            size: landscapeSize
        )
        SnapshotSupport.assertScreen(
            makeViewController(),
            named: "clean-\(screenName)-compact-portrait",
            device: .iPhone8
        )
        SnapshotSupport.assertScreen(
            makeViewController(),
            named: "clean-\(screenName)-accessibility-xxxl",
            size: portraitSize,
            contentSizeCategory: .accessibilityExtraExtraExtraLarge
        )
    }

    private func makeHomeViewController(
        themes: [QuizTheme]? = nil,
        statisticsAttempts: [(correctAnswers: Int, totalQuestions: Int)] = [],
        cardDeviceParallaxEnabledProvider: @escaping () -> Bool = { true }
    ) -> QuizViewController {
        let suiteName = "ScreenSnapshotTests.home.\(UUID().uuidString)"
        defaultsSuiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        QuizFactory.shared.themes = themes ?? [
            SnapshotSupport.makeTheme(id: "music", name: "Музыка"),
            SnapshotSupport.makeTheme(id: "technology", name: "Технологии"),
            SnapshotSupport.makeTheme(id: "history_culture", name: "История и культура"),
            SnapshotSupport.makeTheme(id: "politics_business", name: "Политика и бизнес")
        ]
        QuizFactory.shared.startup1st = false
        let statisticsStore = StatisticsStore(userDefaults: defaults, key: "attempts")
        statisticsAttempts.forEach {
            statisticsStore.recordAttempt(
                correctAnswers: $0.correctAnswers,
                totalQuestions: $0.totalQuestions
            )
        }
        return QuizViewController(
            statisticsStore: statisticsStore,
            motivationPromptProvider: { _ in "Время\nпроверить факты" },
            cardDeviceParallaxEnabledProvider: cardDeviceParallaxEnabledProvider
        )
    }

    private func makeExpandedStatisticsCardViewController(size: CGSize) throws -> QuizViewController {
        let attempts = Array(repeating: (correctAnswers: 5, totalQuestions: 5), count: 10)
            + Array(repeating: (correctAnswers: 1, totalQuestions: 5), count: 24)
            + Array(repeating: (correctAnswers: 0, totalQuestions: 5), count: 19)
        let viewController = makeHomeViewController(
            themes: [makeExpandedCardTheme()],
            statisticsAttempts: attempts,
            cardDeviceParallaxEnabledProvider: { false }
        )
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let statisticsButton = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeStatisticsCard"
            ) as? UIButton
        )
        statisticsButton.sendActions(for: .touchUpInside)
        drainHomeCardAnimations()
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        _ = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeExpandedStatisticsCard"
            )
        )
        return viewController
    }

    private func makeExpandedThemeCardViewController(
        face: HomeThemeCardFace,
        size: CGSize,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified,
        contentSizeCategory: UIContentSizeCategory? = nil
    ) throws -> QuizViewController {
        let theme = makeExpandedCardTheme()
        // Device attitude is intentionally nondeterministic. Snapshot tests
        // exercise the neutral visual state; lifecycle tests cover live effects.
        let viewController = makeHomeViewController(
            themes: [theme],
            cardDeviceParallaxEnabledProvider: { false }
        )
        viewController.overrideUserInterfaceStyle = userInterfaceStyle
        if let contentSizeCategory {
            viewController.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        }
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let themeButton = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: theme.stableID
            ) as? UIButton
        )
        themeButton.sendActions(for: .touchUpInside)
        drainHomeCardAnimations()

        if face == .back {
            let infoButton = try XCTUnwrap(
                viewController.view.snapshotDescendant(
                    withAccessibilityIdentifier: "expandedThemeCardInfoButton"
                ) as? UIButton
            )
            infoButton.sendActions(for: .touchUpInside)
            drainHomeCardAnimations()
        }

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        return viewController
    }

    private func makeExpandedAIThemeCardViewController(
        face: HomeThemeCardFace,
        size: CGSize,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified,
        contentSizeCategory: UIContentSizeCategory? = nil
    ) throws -> QuizViewController {
        let viewController = makeHomeViewController(
            themes: [makeExpandedCardTheme()],
            cardDeviceParallaxEnabledProvider: { false }
        )
        viewController.overrideUserInterfaceStyle = userInterfaceStyle
        if let contentSizeCategory {
            viewController.traitOverrides.preferredContentSizeCategory = contentSizeCategory
        }
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(origin: .zero, size: size)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let collectionView = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let aiButton = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )
        aiButton.sendActions(for: .touchUpInside)
        drainHomeCardAnimations()

        let promptEditor = try XCTUnwrap(
            viewController.view.snapshotDescendant(
                withAccessibilityIdentifier: "aiThemePromptEditor"
            ) as? UITextView
        )
        promptEditor.text = "Космические миссии и открытия"
        promptEditor.delegate?.textViewDidChange?(promptEditor)
        promptEditor.resignFirstResponder()

        if face == .back {
            let playButton = try XCTUnwrap(
                viewController.view.snapshotDescendant(
                    withAccessibilityIdentifier: "expandedAIThemeCardPlayButton"
                ) as? UIButton
            )
            playButton.sendActions(for: .touchUpInside)
            drainHomeCardAnimations()
        }

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        return viewController
    }

    private func makeExpandedCardTheme() -> QuizTheme {
        let questions = (1...15).map { index in
            QuizQuestion(
                question: "Какой музыкальный факт верен в вопросе \(index)?",
                answers: [
                    "Верный ответ \(index)",
                    "Альтернатива B \(index)",
                    "Альтернатива C \(index)",
                    "Альтернатива D \(index)"
                ],
                correctAnswer: "Верный ответ \(index)"
            )
        }

        return SnapshotSupport.makeTheme(
            id: "music",
            name: "Музыка",
            description: "Музыка сопровождает нас в дороге, на сцене и в самые важные моменты. "
                + "Эта тема проверит, насколько хорошо вы знаете историю жанров, знаменитых исполнителей и культовые альбомы. "
                + "Вспомните рекорды, инструменты и мелодии, которые изменили поп-культуру. "
                + "Выберите длину квиза и попробуйте услышать правильный ответ ещё до того, как увидите варианты.",
            questions: questions
        )
    }

    private func drainHomeCardAnimations() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
    }

    private func makeQuestionViewController(
        themeName: String = "Музыка",
        questionText: String = "Какой инструмент обычно ассоциируется с рок-группой?",
        questionNumberText: String = L10n.Question.number(1),
        answerTitles: [String] = ["Гитара", "Скрипка", "Флейта", "Арфа"]
    ) -> QuizQuestionViewController {
        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: themeName,
                questionText: questionText,
                questionNumberText: questionNumberText,
                answers: answerTitles.enumerated().map { index, title in
                    QuizAnswerOption(id: "\(index)", title: title)
                }
            )
        )
        viewController.updateProgress(0.62)
        return viewController
    }

    private func makeLongAnswerQuestionViewController() -> QuizQuestionViewController {
        makeQuestionViewController(
            themeName: "Цитаты философов",
            questionText: "Какое из высказываний принадлежит Иммануилу Канту?",
            questionNumberText: L10n.Question.number(2),
            answerTitles: [
                "«Поступай так, чтобы максима твоей воли могла бы быть всеобщим законом»",
                "«Бытие определяет сознание»",
                "«Человек — это то, что должно быть преодолено»",
                "«Жизнь — это страдание»"
            ]
        )
    }

    private func makeJapanQuestionViewController() -> QuizQuestionViewController {
        makeQuestionViewController(
            themeName: "История Японии",
            questionText: "Какое событие положило конец периоду феодальной раздробленности и способствовало объединению Японии в конце XVI века?",
            answerTitles: [
                "Деятельность Оды Нобунаги, Тоётоми Хидэёси и Токугавы Иэясу",
                "Приход к власти Токугавы Иэясу",
                "Восстание крестьян",
                "Битва при Сэкигахаре"
            ]
        )
    }

    private func makeResultViewController() -> QuizResultViewController {
        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(
            resultText: "Ваш результат: 4/5",
            descriptionText: "Отличный результат. Можно закрепить успех новой попыткой."
        )
        return viewController
    }

}

@MainActor
private final class BottomScrolledHomeSnapshotViewController: UIViewController {
    private let homeViewController: QuizViewController

    init(homeViewController: QuizViewController) {
        self.homeViewController = homeViewController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(homeViewController)
        view.addSubview(homeViewController.view)
        homeViewController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            homeViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            homeViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            homeViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            homeViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        homeViewController.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        homeViewController.view.layoutIfNeeded()
        guard let collectionView = homeViewController.view.snapshotDescendant(
            withAccessibilityIdentifier: "homeThemesCollectionView"
        ) as? UICollectionView else { return }

        collectionView.layoutIfNeeded()
        let maximumOffset = max(
            -collectionView.adjustedContentInset.top,
            collectionView.contentSize.height - collectionView.bounds.height + collectionView.adjustedContentInset.bottom
        )
        collectionView.contentOffset.y = maximumOffset
        collectionView.delegate?.scrollViewDidScroll?(collectionView)
    }
}
