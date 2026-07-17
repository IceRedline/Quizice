import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizContractValidationTests: YandexAIQuizThemeServiceTestCase {
    func testMalformedGeneratedQuizJSONIsRejected() async throws {
        let responseData = try makeEnvelope(outputText: "not-json")
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.invalidQuizJSON) {
            _ = try await self.generate()
        }
    }

    func testQuizMustContainExactlyFiveQuestions() async throws {
        var quiz = makeQuizPayload()
        quiz["questions"] = Array(makeQuestionPayloads().prefix(4))

        await assertContractError(
            .invalidQuestionCount(expected: 5, actual: 4),
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }

    func testResponseMustContainTheRequestedQuestionCount() async throws {
        let responseData = try makeCompletedResponse(quiz: makeQuizPayload(questionCount: 10))
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        let theme = try await makeService().generateQuizTheme(
            configuration: configuration(questionCount: 10, difficulty: .easy)
        )

        XCTAssertEqual(theme.questions.count, 10)
    }

    func testQuestionMustContainExactlyFourAnswers() async throws {
        var quiz = makeQuizPayload()
        var questions = makeQuestionPayloads()
        questions[0]["answers"] = ["A", "B", "C"]
        questions[0]["correctAnswer"] = "A"
        quiz["questions"] = questions

        await assertContractError(
            .invalidAnswerCount(questionIndex: 0, actual: 3),
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }

    func testAnswersMustBeNonEmptyAndUniqueAfterTrimming() async throws {
        var quiz = makeQuizPayload()
        var questions = makeQuestionPayloads()
        questions[0]["answers"] = ["A", "  ", "C", "D"]
        questions[0]["correctAnswer"] = "A"
        quiz["questions"] = questions

        await assertContractError(
            .emptyAnswer(questionIndex: 0, answerIndex: 1),
            responseData: try makeCompletedResponse(quiz: quiz)
        )

        questions = makeQuestionPayloads()
        questions[0]["answers"] = ["A", " A ", "C", "D"]
        questions[0]["correctAnswer"] = "A"
        quiz["questions"] = questions

        await assertContractError(
            .duplicateAnswers(questionIndex: 0),
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }

    func testCorrectAnswerMustMatchExactlyOneTrimmedAnswer() async throws {
        var quiz = makeQuizPayload()
        var questions = makeQuestionPayloads()
        questions[0]["correctAnswer"] = "Missing"
        quiz["questions"] = questions

        await assertContractError(
            .invalidCorrectAnswer(questionIndex: 0),
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }

    func testWhitespaceIsTrimmedBeforeBuildingQuizModels() async throws {
        var quiz = makeQuizPayload()
        quiz["theme"] = "  Sea  "
        quiz["themeDescription"] = "  Description  "
        var questions = makeQuestionPayloads()
        questions[0]["question"] = "  Question?  "
        questions[0]["answers"] = ["  A  ", " B ", "C", "D"]
        questions[0]["correctAnswer"] = " A "
        quiz["questions"] = questions
        let responseData = try makeCompletedResponse(quiz: quiz)
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        let theme = try await generate()

        XCTAssertEqual(theme.theme, "Sea")
        XCTAssertEqual(theme.themeDescription, "Description")
        XCTAssertEqual(theme.questions[0].question, "Question?")
        XCTAssertEqual(theme.questions[0].answers, ["A", "B", "C", "D"])
        XCTAssertEqual(theme.questions[0].correctAnswer, "A")
    }

    func testThemeDescriptionAndQuestionMustBeNonEmpty() async throws {
        var quiz = makeQuizPayload()
        quiz["themeDescription"] = " \n"
        await assertContractError(
            .emptyThemeDescription,
            responseData: try makeCompletedResponse(quiz: quiz)
        )

        quiz = makeQuizPayload()
        var questions = makeQuestionPayloads()
        questions[2]["question"] = "  "
        quiz["questions"] = questions
        await assertContractError(
            .emptyQuestion(index: 2),
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }

    func testThemeMustBeNonEmpty() async throws {
        var quiz = makeQuizPayload()
        quiz["theme"] = " \n"

        await assertContractError(
            .emptyTheme,
            responseData: try makeCompletedResponse(quiz: quiz)
        )
    }
}
