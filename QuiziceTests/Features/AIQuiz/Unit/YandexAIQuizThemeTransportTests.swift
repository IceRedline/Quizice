import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizThemeTransportTests: YandexAIQuizThemeServiceTestCase {
    func testMissingAPIKeyFailsBeforeStartingNetworkRequest() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            XCTFail("A request must not start without an API key")
            throw URLError(.badServerResponse)
        }

        await assertServiceError(.missingAPIKey) {
            _ = try await YandexAIQuizThemeService(apiKey: " \n", session: self.session)
                .generateQuizTheme(configuration: self.configuration())
        }
    }

    func testEmptyPromptFailsBeforeStartingNetworkRequest() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            XCTFail("A request must not start for an empty prompt")
            throw URLError(.badServerResponse)
        }

        await assertServiceError(.emptyPrompt) {
            _ = try await self.makeService()
                .generateQuizTheme(configuration: self.configuration(theme: " \n"))
        }
    }

    func testNonHTTPResponseIsRejected() async throws {
        let responseData = try makeCompletedResponse()
        YandexAIURLProtocolStub.requestHandler = { request in
            let response = URLResponse(
                url: try XCTUnwrap(request.url),
                mimeType: "application/json",
                expectedContentLength: responseData.count,
                textEncodingName: "utf-8"
            )
            return (response, responseData)
        }

        await assertServiceError(.invalidHTTPResponse) {
            _ = try await self.generate()
        }
    }

    func testHTTPFailureIsReportedWithoutDecodingOrExposingBody() async {
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request, statusCode: 401), Data("secret response".utf8))
        }

        await assertServiceError(.httpStatus(401)) {
            _ = try await self.generate()
        }
    }

    func testFailedAndIncompleteGenerationStatusesAreRejected() async throws {
        for status in ["failed", "incomplete"] {
            let responseData = try JSONSerialization.data(withJSONObject: [
                "status": status,
                "output": []
            ])
            YandexAIURLProtocolStub.requestHandler = { request in
                (Self.httpResponse(for: request), responseData)
            }

            await assertServiceError(.generationStatus(status)) {
                _ = try await self.generate()
            }
        }

        let maxOutputTokensResponse = try JSONSerialization.data(withJSONObject: [
            "status": "incomplete",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": []
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), maxOutputTokensResponse)
        }

        await assertServiceError(.generationStatus("incomplete")) {
            _ = try await self.generate()
        }

        let partialOutputResponse = try JSONSerialization.data(withJSONObject: [
            "status": "incomplete",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": [[
                "type": "message",
                "content": [[
                    "type": "output_text",
                    "text": "{\"theme\":"
                ]]
            ]]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), partialOutputResponse)
        }

        await assertServiceError(.generationStatus("incomplete")) {
            _ = try await self.generate()
        }

        let missingReasonResponse = try JSONSerialization.data(withJSONObject: [
            "status": "incomplete",
            "incomplete_details": ["valid": true],
            "output": []
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), missingReasonResponse)
        }

        await assertServiceError(.generationStatus("incomplete")) {
            _ = try await self.generate()
        }
    }

    func testContentFilterIncompleteStatusIsReportedAsRefusal() async throws {
        let responseData = try JSONSerialization.data(withJSONObject: [
            "id": "a2a373ec-b45d-469d-9d7d-c09ec4501e0e",
            "created_at": 1_783_963_783.0,
            "error": NSNull(),
            "incomplete_details": [
                "reason": "content_filter",
                "valid": true
            ],
            "status": "incomplete",
            "output": []
        ] as [String: Any])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }

        let competingIncompleteReasonResponse = try JSONSerialization.data(withJSONObject: [
            "status": "incomplete",
            "incomplete_details": ["reason": "max_output_tokens"],
            "output": [[
                "type": "message",
                "content": [[
                    "type": "refusal",
                    "refusal": "Policy refusal"
                ]]
            ]]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), competingIncompleteReasonResponse)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }

        let unexpectedStatusResponse = try JSONSerialization.data(withJSONObject: [
            "status": "failed",
            "incomplete_details": ["reason": " Content_Filter\n"],
            "output": []
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), unexpectedStatusResponse)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }

        let outputRefusalResponse = try JSONSerialization.data(withJSONObject: [
            "status": "incomplete",
            "incomplete_details": NSNull(),
            "output": [[
                "type": "message",
                "content": [[
                    "type": "refusal",
                    "refusal": "Policy refusal"
                ]]
            ]]
        ])
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), outputRefusalResponse)
        }

        await assertServiceError(.refused) {
            _ = try await self.generate()
        }
    }
}
