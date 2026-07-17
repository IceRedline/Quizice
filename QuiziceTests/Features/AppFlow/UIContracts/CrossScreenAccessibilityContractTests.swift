import XCTest
@testable import Quizice

@MainActor
final class CrossScreenAccessibilityContractTests: CrossScreenVisualTestCase {
    func testQuizFlowScreensExposeCoreAnchorsAndControlSurfaces() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1
        let questionViewController = QuizQuestionViewController()
        questionViewController.loadViewIfNeeded()

        let resultViewController = QuizResultViewController()
        resultViewController.loadViewIfNeeded()
        resultViewController.updateResultLabels(resultText: "Ваш результат: 1/1", descriptionText: "Готово")

        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton"))
    }

    func testCompactNavigationControlsExposeAtLeastFortyFourPointHitAreas() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let controllers: [(UIViewController, String)] = [
            (QuizQuestionViewController(), "questionCloseButton"),
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
