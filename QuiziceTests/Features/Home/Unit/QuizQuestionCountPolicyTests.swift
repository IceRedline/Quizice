import XCTest
@testable import Quizice

final class QuizQuestionCountPolicyTests: XCTestCase {
    func testAvailableCountsUseOnlyUsableQuestionsAtSupportedBoundaries() {
        let questions = makeUsableQuestions(count: 15) + [
            makeQuestion(text: "   "),
            makeQuestion(answers: ["A", "B", "C"]),
            makeQuestion(correctAnswer: "   "),
            makeQuestion(answers: ["A", "A", "B", "C"])
        ]

        XCTAssertEqual(QuizQuestionCountPolicy.supportedCounts, [5, 10, 15])
        XCTAssertEqual(QuizQuestionCountPolicy.usableQuestionCount(in: questions), 15)
        XCTAssertEqual(QuizQuestionCountPolicy.availableCounts(for: questions), [5, 10, 15])
        XCTAssertEqual(
            QuizQuestionCountPolicy.availableCounts(for: Array(questions.prefix(9))),
            [5]
        )
        XCTAssertEqual(
            QuizQuestionCountPolicy.availableCounts(for: Array(questions.prefix(4))),
            []
        )
    }

    func testQuestionMustHaveTextFourAnswersAndOneExactNonblankCorrectAnswer() {
        XCTAssertTrue(QuizQuestionCountPolicy.isUsable(makeQuestion()))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(text: "\n\t")))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(answers: ["A", "B", "C"])))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(correctAnswer: " ")))
        XCTAssertFalse(
            QuizQuestionCountPolicy.isUsable(
                makeQuestion(answers: ["A", "A", "B", "C"], correctAnswer: "A")
            )
        )
        XCTAssertFalse(
            QuizQuestionCountPolicy.isUsable(
                makeQuestion(answers: ["A", "B", "C", "D"], correctAnswer: "E")
            )
        )
    }

    func testInitialSelectionKeepsAvailablePreferenceOrUsesMinimum() {
        XCTAssertEqual(
            QuizQuestionCountPolicy.initialSelection(preferred: 10, available: [5, 10, 15]),
            10
        )
        XCTAssertEqual(
            QuizQuestionCountPolicy.initialSelection(preferred: 15, available: [10, 5, 99]),
            5
        )
        XCTAssertNil(QuizQuestionCountPolicy.initialSelection(preferred: 5, available: []))
    }

    private func makeUsableQuestions(count: Int) -> [QuestionModel] {
        (0..<count).map { makeQuestion(text: "Question \($0)?") }
    }

    private func makeQuestion(
        text: String = "Question?",
        answers: [String] = ["A", "B", "C", "D"],
        correctAnswer: String = "A"
    ) -> QuestionModel {
        QuestionModel(
            quizQuestion: QuizQuestion(
                question: text,
                answers: answers,
                correctAnswer: correctAnswer
            )
        )
    }
}
