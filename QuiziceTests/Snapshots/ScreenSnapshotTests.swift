import UIKit
import XCTest
import SnapshotTesting
@testable import Quizice

@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let portraitSize = CGSize(width: 390, height: 844)
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

    func testDescriptionScreenSnapshot() {
        SnapshotSupport.assertScreen(makeDescriptionViewController(), named: "clean-description", size: portraitSize)
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

    func testStatisticsScreenSnapshot() {
        let suiteName = "ScreenSnapshotTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StatisticsStore(userDefaults: defaults, key: "attempts")
        store.recordAttempt(correctAnswers: 4, totalQuestions: 5)
        store.recordAttempt(correctAnswers: 8, totalQuestions: 10)
        let viewController = StatisticsViewController(statisticsStore: store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)

        SnapshotSupport.assertScreen(viewController, named: "clean-statistics", size: portraitSize)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testRadarStatisticsLargeHistorySnapshot() {
        SnapshotSupport.setUp(designStyle: .radar)

        SnapshotSupport.assertScreen(
            makeLargeHistoryStatisticsViewController(),
            named: "radar-statistics-large-history-iphone-17-pro",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testDescriptionAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeDescriptionViewController, screenName: "description")
    }

    func testQuestionAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: { self.makeQuestionViewController() }, screenName: "question")
    }

    func testResultAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeResultViewController, screenName: "result")
    }

    func testStatisticsAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeStatisticsViewController, screenName: "statistics")
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

    private func makeDescriptionViewController() -> QuizDescriptionViewController {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )
        return viewController
    }

    private func makeHomeViewController() -> QuizViewController {
        let suiteName = "ScreenSnapshotTests.home.\(UUID().uuidString)"
        defaultsSuiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        QuizFactory.shared.themes = [
            SnapshotSupport.makeTheme(id: "music", name: "Музыка"),
            SnapshotSupport.makeTheme(id: "technology", name: "Технологии"),
            SnapshotSupport.makeTheme(id: "history_culture", name: "История и культура"),
            SnapshotSupport.makeTheme(id: "politics_business", name: "Политика и бизнес")
        ]
        QuizFactory.shared.startup1st = false
        return QuizViewController(
            statisticsStore: StatisticsStore(userDefaults: defaults, key: "attempts"),
            motivationPromptProvider: { _ in "Время\nпроверить факты" }
        )
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

    private func makeStatisticsViewController() -> StatisticsViewController {
        let suiteName = "ScreenSnapshotTests.adaptive.\(UUID().uuidString)"
        defaultsSuiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StatisticsStore(userDefaults: defaults, key: "attempts")
        store.recordAttempt(correctAnswers: 4, totalQuestions: 5)
        store.recordAttempt(correctAnswers: 8, totalQuestions: 10)
        let viewController = StatisticsViewController(statisticsStore: store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)
        return viewController
    }

    private func makeLargeHistoryStatisticsViewController() -> StatisticsViewController {
        let suiteName = "ScreenSnapshotTests.large-statistics.\(UUID().uuidString)"
        defaultsSuiteNames.append(suiteName)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = StatisticsStore(userDefaults: defaults, key: "attempts")
        for _ in 0..<10 {
            store.recordAttempt(correctAnswers: 5, totalQuestions: 5)
        }
        for _ in 0..<24 {
            store.recordAttempt(correctAnswers: 1, totalQuestions: 5)
        }
        for _ in 0..<19 {
            store.recordAttempt(correctAnswers: 0, totalQuestions: 5)
        }
        let viewController = StatisticsViewController(statisticsStore: store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)
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
