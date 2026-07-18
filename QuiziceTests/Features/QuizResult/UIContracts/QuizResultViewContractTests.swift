import XCTest
@testable import Quizice

@MainActor
final class QuizResultViewContractTests: CrossScreenVisualTestCase {
    func testResultScreenExposesDistinctReplayAndThemeActions() throws {
        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(
            resultText: "Ваш результат: 4/5",
            descriptionText: "Отличный текущий результат — можно начать новую попытку."
        )
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultScrollView") as? UIScrollView)

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let replayButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton") as? UIButton)
        let themesButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton") as? UIButton)

        XCTAssertEqual(resultLabel.text, "Ваш результат: 4/5")
        XCTAssertEqual(descriptionLabel.text, "Отличный текущий результат — можно начать новую попытку.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(resultLabel.numberOfLines, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(replayButton.title(for: .normal), L10n.Result.playAgain)
        XCTAssertEqual(themesButton.title(for: .normal), L10n.Result.toThemes)
        XCTAssertTrue(replayButton.isEnabled)
        XCTAssertTrue(themesButton.isEnabled)
        XCTAssertEqual(replayButton.layer.borderWidth, 1)
        XCTAssertGreaterThan(replayButton.layer.shadowOpacity, 0)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testResultActionsInvokeTheirDistinctRoutes() throws {
        resetQuestionFactoryState()

        let viewController = QuizResultViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(resultText: "0/0", descriptionText: "Нет данных текущей попытки")

        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let replayButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton") as? UIButton)
        let themesButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton") as? UIButton)

        replayButton.sendActions(for: .touchUpInside)
        themesButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(resultLabel.text, "0/0")
        XCTAssertEqual(descriptionLabel.text, "Нет данных текущей попытки")
        XCTAssertTrue(QuizFactory.shared.themes?.isEmpty ?? true)
        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(router.replayQuizCallCount, 1)
        XCTAssertEqual(router.returnToThemesCallCount, 1)
    }

    func testResultReplayShowsSameAIProgressPhasesAsCreationCard() throws {
        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()

        let replayButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayButton"
            ) as? UIButton
        )
        let activityIndicator = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayActivityIndicator"
            ) as? UIActivityIndicatorView
        )
        let progressLabel = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayProgressStatus"
            ) as? UILabel
        )
        let loadingContent = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "resultReplayLoadingContent"
            )
        )

        for phase in AIQuizGenerationPhase.allCases {
            viewController.setReplayGenerationPhase(phase)

            XCTAssertFalse(replayButton.isEnabled)
            XCTAssertNil(replayButton.title(for: .normal))
            XCTAssertFalse(loadingContent.isHidden)
            XCTAssertTrue(activityIndicator.isAnimating)
            XCTAssertFalse(progressLabel.isHidden)
            XCTAssertEqual(progressLabel.text, phase.title)
        }

        viewController.setReplayGenerationPhase(nil)

        XCTAssertTrue(replayButton.isEnabled)
        XCTAssertEqual(replayButton.title(for: .normal), L10n.Result.playAgain)
        XCTAssertTrue(loadingContent.isHidden)
        XCTAssertFalse(activityIndicator.isAnimating)
        XCTAssertTrue(progressLabel.isHidden)
    }
}
