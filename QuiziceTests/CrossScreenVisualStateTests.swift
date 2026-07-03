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
