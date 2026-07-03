import XCTest
@testable import Quizice

@MainActor
final class CrossScreenVisualStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetQuestionFactoryState()
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        resetQuestionFactoryState()
        super.tearDown()
    }

    func testDescriptionScreenExposesPolishedLayoutAnchorsAndControls() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView"))
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
        XCTAssertEqual(startButton.title(for: .normal), "Начать")
        XCTAssertEqual(startButton.layer.cornerRadius, 22)
        XCTAssertGreaterThan(startButton.layer.shadowOpacity, 0)
        XCTAssertEqual(backButton.title(for: .normal), "Назад")
        XCTAssertEqual(backButton.layer.cornerRadius, 20)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
    }

    func testDescriptionScreenKeepsControlsReachableWithEmptyAndLongPresenterText() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "", themeDescription: String(repeating: "Очень длинное описание темы. ", count: 18))
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(themeLabel.text, "")
        XCTAssertFalse(descriptionLabel.text?.isEmpty ?? true)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertTrue(scrollView.alwaysBounceVertical)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
        XCTAssertFalse(pickerView.hasAmbiguousLayout)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
    }

    func testQuestionScreenExposesPolishedLayoutAnchorsAndAnswerControls() {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionThemeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNumberLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerContainerView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionAnswersStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionBackButton"))

        let answerButtons = questionAnswerButtons(in: viewController)
        XCTAssertEqual(answerButtons.count, 4)
        XCTAssertTrue(answerButtons.allSatisfy(\.isEnabled))
        XCTAssertTrue(answerButtons.allSatisfy { $0.layer.cornerRadius >= 16 })
        XCTAssertTrue(answerButtons.allSatisfy { $0.backgroundColor == .defaultButton })
    }

    func testQuestionScreenPreservesPresenterDrivenAnswerFeedbackState() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        let answerButtons = questionAnswerButtons(in: viewController)
        let correctButton = try XCTUnwrap(answerButtons.first { $0.title(for: .normal) == "Правильный ответ" })
        let wrongButtons = answerButtons.filter { $0 !== correctButton }

        correctButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(answerButtons.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(correctButton.backgroundColor, .correctAnswerButton)
        XCTAssertTrue(wrongButtons.allSatisfy { $0.backgroundColor == .wrongAnswerButton })

        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        XCTAssertTrue(nextButton.isEnabled)
    }

    func testQuestionScreenTimeExpiredStateDisablesAnswersAndKeepsNextActionAvailable() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        viewController.showTimeExpired()

        let answerButtons = questionAnswerButtons(in: viewController)
        XCTAssertTrue(answerButtons.allSatisfy { !$0.isEnabled })

        let correctButton = try XCTUnwrap(answerButtons.first { $0.title(for: .normal) == "Правильный ответ" })
        XCTAssertEqual(correctButton.backgroundColor, .correctAnswerButton)
        XCTAssertTrue(answerButtons.filter { $0 !== correctButton }.allSatisfy { $0.backgroundColor == .wrongAnswerButton })

        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        XCTAssertTrue(nextButton.isEnabled)
    }

    func testResultScreenExposesPolishedCurrentAttemptAnchorsAndPrimaryRestartControl() throws {
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
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let restartButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton") as? UIButton)

        XCTAssertEqual(resultLabel.text, "Ваш результат: 4/5")
        XCTAssertEqual(descriptionLabel.text, "Отличный текущий результат — можно начать новую попытку.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(resultLabel.numberOfLines, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(restartButton.title(for: .normal), "Начать заново")
        XCTAssertTrue(restartButton.isEnabled)
        XCTAssertEqual(restartButton.layer.cornerRadius, 22)
        XCTAssertEqual(restartButton.layer.borderWidth, 1)
        XCTAssertGreaterThan(restartButton.layer.shadowOpacity, 0)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testResultScreenLoadsWithoutStatisticsHistoryAndKeepsRestartActionSafelyInspectible() throws {
        resetQuestionFactoryState()

        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(resultText: "0/0", descriptionText: "Нет данных текущей попытки")

        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let restartButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton") as? UIButton)
        let registeredActions = restartButton.actions(forTarget: viewController, forControlEvent: .touchUpInside) ?? []

        XCTAssertEqual(resultLabel.text, "0/0")
        XCTAssertEqual(descriptionLabel.text, "Нет данных текущей попытки")
        XCTAssertTrue(QuizFactory.shared.themes?.isEmpty ?? true)
        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertTrue(registeredActions.contains("backButtonTapped"))
    }

    private func questionAnswerButtons(in viewController: QuizQuestionViewController) -> [UIButton] {
        (1...4).compactMap { index in
            viewController.view.descendant(withAccessibilityIdentifier: "questionAnswerButton\(index)") as? UIButton
        }
    }

    private func resetQuestionFactoryState() {
        QuizFactory.shared.themes = []
        QuizFactory.shared.chosenTheme = nil
        QuizFactory.shared.questionsCount = 0
    }

    private func makeQuestionTheme() -> ThemeModel {
        let question = QuizQuestion(
            question: "Какой ответ должен подсветиться как верный?",
            answers: ["Правильный ответ", "Ошибочный ответ 1", "Ошибочный ответ 2", "Ошибочный ответ 3"],
            correctAnswer: "Правильный ответ",
            explanation: "Проверяем визуальное состояние ответа."
        )

        return ThemeModel(
            quizTheme: QuizTheme(
                theme: "Визуальный тест",
                themeDescription: "Тема для проверки вопросного экрана",
                questions: [question]
            )
        )
    }
}

private extension UIView {
    func descendant(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier {
            return self
        }

        for subview in subviews {
            if let match = subview.descendant(withAccessibilityIdentifier: identifier) {
                return match
            }
        }

        return nil
    }
}
