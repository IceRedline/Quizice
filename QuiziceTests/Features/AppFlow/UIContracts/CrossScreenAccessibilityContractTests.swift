import XCTest
@testable import Quizice

@MainActor
final class CrossScreenAccessibilityContractTests: CrossScreenVisualTestCase {
    func testAllPolishedS03ScreensExposeCoreAnchorsAndControlSurfaces() throws {
        let descriptionViewController = QuizDescriptionViewController()
        descriptionViewController.loadViewIfNeeded()
        descriptionViewController.updateLabels(themeName: "Музыка", themeDescription: "Описание")

        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1
        let questionViewController = QuizQuestionViewController()
        questionViewController.loadViewIfNeeded()

        let resultViewController = QuizResultViewController()
        resultViewController.loadViewIfNeeded()
        resultViewController.updateResultLabels(resultText: "Ваш результат: 1/1", descriptionText: "Готово")

        let statisticsHarness = makeStatisticsHarness()
        let statisticsViewController = StatisticsViewController(statisticsStore: statisticsHarness.store)
        statisticsViewController.loadViewIfNeeded()
        statisticsViewController.viewWillAppear(false)

        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton"))
        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton"))
    }

    func testCompactNavigationControlsExposeAtLeastFortyFourPointHitAreas() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let controllers: [(UIViewController, String)] = [
            (QuizDescriptionViewController(), "descriptionBackButton"),
            (QuizQuestionViewController(), "questionCloseButton"),
            (StatisticsViewController(statisticsStore: makeStatisticsHarness().store), "statisticsBackButton"),
            (QuizViewController(), "homeSettingsButton")
        ]

        for (viewController, identifier) in controllers {
            viewController.loadViewIfNeeded()
            viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()
            let control = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: identifier), identifier)
            XCTAssertGreaterThanOrEqual(control.bounds.width, 44, identifier)
            XCTAssertGreaterThanOrEqual(control.bounds.height, 44, identifier)
        }
    }
}
