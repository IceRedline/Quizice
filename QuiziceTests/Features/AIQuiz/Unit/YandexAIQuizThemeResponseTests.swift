import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizThemeResponseTests: YandexAIQuizThemeServiceTestCase {
    func testMalformedResponsesEnvelopeIsRejected() async {
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), Data("{not-json".utf8))
        }

        await assertServiceError(.invalidResponseJSON) {
            _ = try await self.generate()
        }
    }

    func testPlatformRefusalIsReportedWithoutExposingItsText() async throws {
        let responseData = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "output": [[
                "type": "message",
                "content": [["type": "refusal", "text": "No"]]
            ]]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }
    }

    func testStructuredRefusalIsReported() async throws {
        let responseData = try makeCompletedResponse(quiz: [
            "status": "refused",
            "message": "Sensitive model detail",
            "theme": "",
            "themeDescription": "",
            "questions": []
        ])

        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }
    }

    func testPlainTextRefusalIsReported() async throws {
        let responseData = try makeEnvelope(
            outputText: "  Я не могу обсуждать эту тему. Давайте поговорим о чём-нибудь ещё.\n"
        )
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }

        let incompleteResponseData = try makeEnvelope(
            outputText: "Я не могу обсуждать эту тему. Давайте поговорим о чём-нибудь ещё.",
            status: "incomplete"
        )
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), incompleteResponseData)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }
    }

    func testMissingOutputTextIsRejected() async throws {
        let responseData = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "output": [["type": "message", "content": []]]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.missingOutputText) {
            _ = try await self.generate()
        }
    }

    func testOutputTextFragmentsAreJoinedInWireOrder() async throws {
        let quizData = try JSONSerialization.data(withJSONObject: makeQuizPayload())
        let quizJSON = try XCTUnwrap(String(data: quizData, encoding: .utf8))
        let splitIndex = quizJSON.index(quizJSON.startIndex, offsetBy: quizJSON.count / 2)
        let responseData = try JSONSerialization.data(withJSONObject: [
            "status": "completed",
            "output": [
                [
                    "type": "message",
                    "content": [[
                        "type": "output_text",
                        "text": String(quizJSON[..<splitIndex])
                    ]]
                ],
                [
                    "type": "message",
                    "content": [[
                        "type": "output_text",
                        "text": String(quizJSON[splitIndex...])
                    ]]
                ]
            ]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        let theme = try await generate()

        XCTAssertEqual(theme.theme, "Море")
        XCTAssertEqual(theme.questions.count, 5)
    }
}
