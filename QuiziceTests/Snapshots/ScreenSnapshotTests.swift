import UIKit
import XCTest
@testable import Quizice

@MainActor
final class ScreenSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .light)
    }

    override func tearDown() {
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testHomeScreenSnapshot() {
        QuizFactory.shared.themes = [
            SnapshotSupport.makeTheme(id: "music", name: "Музыка"),
            SnapshotSupport.makeTheme(id: "technology", name: "Технологии"),
            SnapshotSupport.makeTheme(id: "history_culture", name: "История и культура"),
            SnapshotSupport.makeTheme(id: "politics_business", name: "Политика и бизнес")
        ]
        QuizFactory.shared.startup1st = false

        SnapshotSupport.assertScreen(QuizViewController(), named: "clean-home")
    }

    func testDescriptionScreenSnapshot() {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )

        SnapshotSupport.assertScreen(viewController, named: "clean-description")
    }

    func testQuestionScreenSnapshot() {
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

        SnapshotSupport.assertScreen(viewController, named: "clean-question")
    }

    func testResultScreenSnapshot() {
        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(
            resultText: "Ваш результат: 4/5",
            descriptionText: "Отличный результат. Можно закрепить успех новой попыткой."
        )

        SnapshotSupport.assertScreen(viewController, named: "clean-result")
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

        SnapshotSupport.assertScreen(viewController, named: "clean-statistics")

        defaults.removePersistentDomain(forName: suiteName)
    }
}
