import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizThemeRequestTests: YandexAIQuizThemeServiceTestCase {
    func testRequestUsesResponsesAPIHeadersPromptAndJSONEncodedInput() async throws {
        let responseData = try makeCompletedResponse()
        let expectedTheme = "Море \"шторм\"\nи волны"

        YandexAIURLProtocolStub.requestHandler = { request in
            XCTAssertEqual(request.url, YandexAIQuizThemeService.endpoint)
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Api-Key test-api-key")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "OpenAI-Project"),
                YandexAIQuizThemeService.projectID
            )
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertEqual(request.value(forHTTPHeaderField: "x-data-logging-enabled"), "false")

            let bodyData = try Self.bodyData(for: request)
            let body = try XCTUnwrap(
                JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
            )
            let prompt = try XCTUnwrap(body["prompt"] as? [String: Any])
            XCTAssertEqual(prompt["id"] as? String, YandexAIQuizThemeService.promptID)
            XCTAssertEqual(body["store"] as? Bool, false)

            let inputString = try XCTUnwrap(body["input"] as? String)
            let inputData = try XCTUnwrap(inputString.data(using: .utf8))
            let input = try XCTUnwrap(
                JSONSerialization.jsonObject(with: inputData) as? [String: Any]
            )
            XCTAssertEqual(input["theme"] as? String, expectedTheme)
            XCTAssertEqual(input["locale"] as? String, "ru")
            XCTAssertEqual(input["questionCount"] as? Int, 5)
            XCTAssertEqual(input["difficulty"] as? String, "hard")

            return (Self.httpResponse(for: request), responseData)
        }

        let service = YandexAIQuizThemeService(apiKey: "  test-api-key\n", session: session)
        let theme = try await service.generateQuizTheme(configuration: configuration(
            theme: "  \(expectedTheme)  ",
            locale: Locale(identifier: "ru_RU"),
            difficulty: .hard
        ))

        XCTAssertTrue(theme.id.hasPrefix("ai-"))
        XCTAssertEqual(theme.source, .ai)
        XCTAssertNotNil(UUID(uuidString: String(theme.id.dropFirst(3))))
        XCTAssertEqual(theme.theme, "Море")
        XCTAssertEqual(theme.themeDescription, "Описание морской викторины")
        XCTAssertEqual(theme.questions.count, 5)
        XCTAssertEqual(theme.questions[0].question, "Вопрос 1?")
        XCTAssertEqual(theme.questions[0].answers, ["Ответ 1A", "Ответ 1B", "Ответ 1C", "Ответ 1D"])
        XCTAssertEqual(theme.questions[0].correctAnswer, "Ответ 1A")
    }

    func testUnsupportedLocaleFallsBackToEnglish() async throws {
        let responseData = try makeCompletedResponse()
        YandexAIURLProtocolStub.requestHandler = { request in
            let bodyData = try Self.bodyData(for: request)
            let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
            let inputString = try XCTUnwrap(body["input"] as? String)
            let inputData = try XCTUnwrap(inputString.data(using: .utf8))
            let input = try XCTUnwrap(JSONSerialization.jsonObject(with: inputData) as? [String: Any])
            XCTAssertEqual(input["locale"] as? String, "en")
            return (Self.httpResponse(for: request), responseData)
        }

        let service = makeService()
        _ = try await service.generateQuizTheme(configuration: configuration(locale: Locale(identifier: "ja_JP")))
    }

    func testSupportedRegionalLocalesUseTheirTwoLetterLanguageCode() async throws {
        for localeIdentifier in ["en_US", "es_ES", "de_DE", "it_IT", "fr_FR"] {
            let expectedLanguageCode = String(localeIdentifier.prefix(2))
            let responseData = try makeCompletedResponse()
            YandexAIURLProtocolStub.requestHandler = { request in
                let bodyData = try Self.bodyData(for: request)
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
                let inputString = try XCTUnwrap(body["input"] as? String)
                let inputData = try XCTUnwrap(inputString.data(using: .utf8))
                let input = try XCTUnwrap(JSONSerialization.jsonObject(with: inputData) as? [String: Any])
                XCTAssertEqual(input["locale"] as? String, expectedLanguageCode)
                return (Self.httpResponse(for: request), responseData)
            }

            _ = try await makeService().generateQuizTheme(
                configuration: configuration(locale: Locale(identifier: localeIdentifier))
            )
        }
    }

    func testAllSupportedCountsAndDifficultiesUseTheWireContract() async throws {
        let cases: [(Int, AIQuizDifficulty)] = [(5, .easy), (10, .medium), (15, .hard)]

        for (questionCount, difficulty) in cases {
            let responseData = try makeCompletedResponse(
                quiz: makeQuizPayload(questionCount: questionCount)
            )
            YandexAIURLProtocolStub.requestHandler = { request in
                let bodyData = try Self.bodyData(for: request)
                let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
                let inputString = try XCTUnwrap(body["input"] as? String)
                let inputData = try XCTUnwrap(inputString.data(using: .utf8))
                let input = try XCTUnwrap(JSONSerialization.jsonObject(with: inputData) as? [String: Any])
                XCTAssertEqual(input["questionCount"] as? Int, questionCount)
                XCTAssertEqual(input["difficulty"] as? String, difficulty.rawValue)
                return (Self.httpResponse(for: request), responseData)
            }

            let theme = try await makeService().generateQuizTheme(
                configuration: configuration(questionCount: questionCount, difficulty: difficulty)
            )

            XCTAssertEqual(theme.questions.count, questionCount)
        }
    }
}
