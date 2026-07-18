import Foundation
import XCTest
@testable import Quizice

@MainActor
class YandexAIQuizThemeServiceTestCase: XCTestCase {
    var session: URLSession!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [YandexAIURLProtocolStub.self]
        session = URLSession(configuration: configuration)
        YandexAIURLProtocolStub.requestHandler = nil
    }

    override func tearDown() {
        session.invalidateAndCancel()
        session = nil
        YandexAIURLProtocolStub.requestHandler = nil
        super.tearDown()
    }

    func makeService(apiKey: String? = "test-api-key") -> YandexAIQuizThemeService {
        YandexAIQuizThemeService(apiKey: apiKey, session: session)
    }

    func generate() async throws -> QuizTheme {
        try await makeService().generateQuizTheme(configuration: configuration())
    }

    func configuration(
        theme: String = "Ocean",
        locale: Locale = Locale(identifier: "en"),
        questionCount: Int = 5,
        difficulty: AIQuizDifficulty = .medium
    ) -> AIQuizGenerationConfiguration {
        AIQuizGenerationConfiguration(
            theme: theme,
            questionCount: questionCount,
            difficulty: difficulty,
            locale: locale
        )
    }

    func assertServiceError(
        _ expectedError: YandexAIQuizThemeServiceError,
        operation: () async throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            try await operation()
            XCTFail("Expected \(expectedError)", file: file, line: line)
        } catch let error as YandexAIQuizThemeServiceError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected YandexAIQuizThemeServiceError, got \(error)", file: file, line: line)
        }
    }

    func assertContractError(
        _ violation: YandexAIQuizContractViolation,
        responseData: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        YandexAIURLProtocolStub.requestHandler = { request in
            (Self.httpResponse(for: request), responseData)
        }
        await assertServiceError(.invalidContract(violation), operation: {
            _ = try await self.generate()
        }, file: file, line: line)
    }

    func makeCompletedResponse(quiz: [String: Any]? = nil) throws -> Data {
        let quiz = quiz ?? makeQuizPayload()
        let quizData = try JSONSerialization.data(withJSONObject: quiz)
        let outputText = try XCTUnwrap(String(data: quizData, encoding: .utf8))
        return try makeEnvelope(outputText: outputText)
    }

    func makeEnvelope(outputText: String, status: String = "completed") throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "status": status,
            "output": [
                [
                    "type": "tool_call",
                    "content": []
                ],
                [
                    "type": "message",
                    "content": [
                        ["type": "input_text", "text": "ignored"],
                        ["type": "output_text", "text": outputText]
                    ]
                ]
            ]
        ])
    }

    func makeQuizPayload() -> [String: Any] {
        makeQuizPayload(questionCount: 5)
    }

    func makeQuizPayload(questionCount: Int) -> [String: Any] {
        [
            "status": "success",
            "message": "",
            "theme": "Море",
            "themeDescription": "Описание морской викторины",
            "questions": makeQuestionPayloads(count: questionCount)
        ]
    }

    func makeQuestionPayloads() -> [[String: Any]] {
        makeQuestionPayloads(count: 5)
    }

    func makeQuestionPayloads(count: Int) -> [[String: Any]] {
        (1...count).map { index in
            [
                "question": "Вопрос \(index)?",
                "answers": ["Ответ \(index)A", "Ответ \(index)B", "Ответ \(index)C", "Ответ \(index)D"],
                "correctAnswer": "Ответ \(index)A",
                "explanation": "This field is decoded but intentionally not persisted."
            ]
        }
    }

    nonisolated static func httpResponse(
        for request: URLRequest,
        statusCode: Int = 200
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
    }

    nonisolated static func bodyData(for request: URLRequest) throws -> Data {
        if let body = request.httpBody {
            return body
        }

        guard let stream = request.httpBodyStream else {
            throw URLError(.cannotDecodeContentData)
        }

        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while true {
            let count = stream.read(buffer, maxLength: bufferSize)
            if count < 0 {
                throw stream.streamError ?? URLError(.cannotDecodeContentData)
            }
            if count == 0 {
                break
            }
            data.append(buffer, count: count)
        }

        return data
    }
}

final class YandexAIURLProtocolStub: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let requestHandler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try requestHandler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
