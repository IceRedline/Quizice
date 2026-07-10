import UIKit
import XCTest
@testable import Quizice

@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let portraitSize = CGSize(width: 390, height: 844)
    private let landscapeSize = CGSize(width: 844, height: 390)
    private let compactPortraitSize = CGSize(width: 375, height: 667)
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
        let suiteName = "ScreenSnapshotTests.home.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let statisticsStore = StatisticsStore(userDefaults: defaults, key: "attempts")
        QuizFactory.shared.themes = [
            SnapshotSupport.makeTheme(id: "music", name: "Музыка"),
            SnapshotSupport.makeTheme(id: "technology", name: "Технологии"),
            SnapshotSupport.makeTheme(id: "history_culture", name: "История и культура"),
            SnapshotSupport.makeTheme(id: "politics_business", name: "Политика и бизнес")
        ]
        QuizFactory.shared.startup1st = false

        let viewController = QuizViewController(
            statisticsStore: statisticsStore,
            motivationPromptProvider: { _ in "Время\nпроверить факты" }
        )

        SnapshotSupport.assertScreen(viewController, named: "clean-home", size: portraitSize)

        defaults.removePersistentDomain(forName: suiteName)
    }

    func testDescriptionScreenSnapshot() {
        SnapshotSupport.assertScreen(makeDescriptionViewController(), named: "clean-description", size: portraitSize)
    }

    func testQuestionScreenSnapshot() {
        SnapshotSupport.assertScreen(makeQuestionViewController(), named: "clean-question", size: portraitSize)
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

    func testDescriptionAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeDescriptionViewController, screenName: "description")
    }

    func testQuestionAdaptiveCanvasSnapshots() {
        assertAdaptiveSnapshots(makeViewController: makeQuestionViewController, screenName: "question")
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
            size: compactPortraitSize
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

    private func makeQuestionViewController() -> QuizQuestionViewController {
        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Музыка",
                questionText: "Какой инструмент обычно ассоциируется с рок-группой?",
                questionNumberText: L10n.Question.number(1),
                answers: [
                    QuizAnswerOption(id: "0", title: "Гитара"),
                    QuizAnswerOption(id: "1", title: "Скрипка"),
                    QuizAnswerOption(id: "2", title: "Флейта"),
                    QuizAnswerOption(id: "3", title: "Арфа")
                ]
            )
        )
        viewController.updateProgress(0.62)
        return viewController
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
}
