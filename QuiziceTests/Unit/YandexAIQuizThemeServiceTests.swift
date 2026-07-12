import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizThemeServiceTests: XCTestCase {
    private var session: URLSession!

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
    }

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

    func testURLCancellationIsPropagatedAsCancellationError() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            throw URLError(.cancelled)
        }

        do {
            _ = try await generate()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation remains distinguishable from user-facing failures.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testNetworkFailureIsTyped() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        await assertServiceError(.network(.timedOut)) {
            _ = try await self.generate()
        }
    }

    func testUserFacingErrorsAreClassifiedWithoutServiceText() {
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.refused).kind, .refusal)
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.network(.notConnectedToInternet)).kind,
            .network
        )
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(429)).kind, .service)
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(503)).kind, .service)
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.invalidQuizJSON).kind, .invalidQuiz)
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.missingAPIKey).kind, .unavailable)
        XCTAssertFalse(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.refused).message.contains("Yandex"))
    }

    private func makeService(apiKey: String? = "test-api-key") -> YandexAIQuizThemeService {
        YandexAIQuizThemeService(apiKey: apiKey, session: session)
    }

    private func generate() async throws -> QuizTheme {
        try await makeService().generateQuizTheme(configuration: configuration())
    }

    private func configuration(
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

    private func assertServiceError(
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

    private func assertContractError(
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

    private func makeCompletedResponse(quiz: [String: Any]? = nil) throws -> Data {
        let quiz = quiz ?? makeQuizPayload()
        let quizData = try JSONSerialization.data(withJSONObject: quiz)
        let outputText = try XCTUnwrap(String(data: quizData, encoding: .utf8))
        return try makeEnvelope(outputText: outputText)
    }

    private func makeEnvelope(outputText: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "status": "completed",
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

    private func makeQuizPayload() -> [String: Any] {
        makeQuizPayload(questionCount: 5)
    }

    private func makeQuizPayload(questionCount: Int) -> [String: Any] {
        [
            "status": "success",
            "message": "",
            "theme": "Море",
            "themeDescription": "Описание морской викторины",
            "questions": makeQuestionPayloads(count: questionCount)
        ]
    }

    private func makeQuestionPayloads() -> [[String: Any]] {
        makeQuestionPayloads(count: 5)
    }

    private func makeQuestionPayloads(count: Int) -> [[String: Any]] {
        (1...count).map { index in
            [
                "question": "Вопрос \(index)?",
                "answers": ["Ответ \(index)A", "Ответ \(index)B", "Ответ \(index)C", "Ответ \(index)D"],
                "correctAnswer": "Ответ \(index)A",
                "explanation": "This field is decoded but intentionally not persisted."
            ]
        }
    }

    nonisolated private static func httpResponse(
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

    nonisolated private static func bodyData(for request: URLRequest) throws -> Data {
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

private final class YandexAIURLProtocolStub: URLProtocol {
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
