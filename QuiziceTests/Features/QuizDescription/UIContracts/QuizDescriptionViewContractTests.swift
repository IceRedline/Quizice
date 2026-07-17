import XCTest
@testable import Quizice

@MainActor
final class QuizDescriptionViewContractTests: CrossScreenVisualTestCase {
    func testDescriptionScreenExposesPolishedLayoutAnchorsAndControls() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(themeLabel.text, "Музыка")
        XCTAssertEqual(descriptionLabel.text, "Проверьте знания о любимых исполнителях и песнях.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(pickerView.layer.cornerRadius, 22)
        XCTAssertEqual(startButton.title(for: .normal), L10n.Common.start)
        XCTAssertEqual(startButton.layer.cornerRadius, 24)
        XCTAssertGreaterThan(startButton.layer.shadowOpacity, 0)
        XCTAssertNotNil(backButton.image(for: .normal))
        XCTAssertEqual(backButton.accessibilityLabel, L10n.Common.back)
        XCTAssertGreaterThanOrEqual(backButton.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(backButton.bounds.height, 44)
        XCTAssertEqual(backButton.layer.cornerRadius, 22)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
        XCTAssertFalse(startButton.isDescendant(of: cardView))
        XCTAssertFalse(backButton.isDescendant(of: cardView))
    }

    func testDescriptionScreenKeepsControlsReachableWithEmptyAndLongPresenterText() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "", themeDescription: String(repeating: "Очень длинное описание темы. ", count: 18))
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)

        XCTAssertEqual(themeLabel.text, "")
        XCTAssertFalse(descriptionLabel.text?.isEmpty ?? true)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertFalse(startButton.isDescendant(of: cardView))
        XCTAssertFalse(startButton.isDescendant(of: scrollView))
        XCTAssertFalse(backButton.isDescendant(of: cardView))
        XCTAssertEqual(
            cardView.bounds.maxY - pickerView.convert(pickerView.bounds, to: cardView).maxY,
            26,
            accuracy: 1
        )
        XCTAssertLessThanOrEqual(scrollView.frame.maxY, startButton.frame.minY)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
        XCTAssertFalse(pickerView.hasAmbiguousLayout)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
    }

    func testDescriptionCardKeepsStableSizeAcrossThemeDescriptions() throws {
        let musicCardHeight = try descriptionCardHeight(
            themeName: "Музыка",
            themeDescription: "В данной викторине вам предстоит угадывать исполнителей и названия песен. Проверьте свои музыкальные знания, вспомните хиты разных эпох и получите удовольствие от путешествия по миру музыки."
        )
        let technologyCardHeight = try descriptionCardHeight(
            themeName: "Технологии",
            themeDescription: "Проверьте знания о гаджетах, языках программирования, компьютерной истории и цифровой культуре."
        )

        XCTAssertEqual(musicCardHeight, technologyCardHeight, accuracy: 0.5)
        XCTAssertEqual(musicCardHeight, 510, accuracy: 0.5)
    }

    func testDescriptionTextIsCenteredBetweenThemeNameAndQuestionCountLabel() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel"))
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel"))
        let questionCountLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionPickerCaptionLabel"))
        let themeFrame = themeLabel.convert(themeLabel.bounds, to: cardView)
        let descriptionFrame = descriptionLabel.convert(descriptionLabel.bounds, to: cardView)
        let questionCountFrame = questionCountLabel.convert(questionCountLabel.bounds, to: cardView)
        let availableGapMidY = (themeFrame.maxY + questionCountFrame.minY) / 2

        XCTAssertEqual(descriptionFrame.midY, availableGapMidY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(descriptionFrame.minY - themeFrame.maxY, 32)
        XCTAssertGreaterThanOrEqual(questionCountFrame.minY - descriptionFrame.maxY, 32)
    }

    func testDescriptionStartButtonStaysPinnedWhenCardContentGrows() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "Музыка", themeDescription: "Короткое описание.")
        viewController.view.layoutIfNeeded()

        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)
        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let pinnedButtonY = startButton.frame.minY
        let stableCardHeight = cardView.frame.height

        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: String(repeating: "Очень длинное описание темы должно прокручиваться независимо от кнопки запуска. ", count: 18)
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertEqual(startButton.frame.minY, pinnedButtonY, accuracy: 0.5)
        XCTAssertGreaterThan(cardView.frame.height, stableCardHeight)
        XCTAssertFalse(startButton.isDescendant(of: scrollView))
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
    }

    func testDescriptionStartFadesActionButtonsAndRoutesToQuestion() throws {
        let viewController = QuizDescriptionViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()

        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(startButton.alpha, 1)
        XCTAssertEqual(backButton.alpha, 1)

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(startButton.alpha, 0)
        XCTAssertEqual(backButton.alpha, 0)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }
}
