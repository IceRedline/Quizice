import Foundation

protocol AIQuizThemeServiceProtocol: AnyObject {
    func generateQuizTheme(configuration: AIQuizGenerationConfiguration) async throws -> QuizTheme
}

enum YandexAIQuizContractViolation: Equatable {
    case promptTooLong(maximum: Int, actual: Int)
    case localeMismatch(expected: String, actual: String)
    case invalidSuccessMessage
    case invalidRefusal
    case emptyTheme
    case emptyThemeDescription
    case invalidQuestionCount(expected: Int, actual: Int)
    case emptyQuestion(index: Int)
    case questionTooLong(index: Int)
    case duplicateQuestions
    case invalidAnswerCount(questionIndex: Int, actual: Int)
    case emptyAnswer(questionIndex: Int, answerIndex: Int)
    case answerTooLong(questionIndex: Int, answerIndex: Int)
    case duplicateAnswers(questionIndex: Int)
    case invalidCorrectAnswer(questionIndex: Int)
    case invalidExplanation(questionIndex: Int)
}

enum YandexAIQuizThemeServiceError: Error, Equatable {
    case unavailableInRelease
    case authenticationRequired
    case missingAPIKey
    case unauthorized
    case emptyPrompt
    case requestEncodingFailed
    case network(URLError.Code)
    case invalidHTTPResponse
    case httpStatus(Int)
    case generationStatus(String)
    case refused
    case invalidResponseJSON
    case missingOutputText
    case invalidQuizJSON
    case invalidContract(YandexAIQuizContractViolation)
}

extension YandexAIQuizThemeServiceError {
    var analyticsCode: String {
        switch self {
        case .unavailableInRelease: return "unavailable_in_release"
        case .authenticationRequired: return "authentication_required"
        case .missingAPIKey: return "missing_api_key"
        case .unauthorized: return "unauthorized"
        case .emptyPrompt: return "empty_prompt"
        case .requestEncodingFailed: return "request_encoding_failed"
        case .network: return "network"
        case .invalidHTTPResponse: return "invalid_http_response"
        case .httpStatus: return "http_status"
        case .generationStatus: return "generation_status"
        case .refused: return "refused"
        case .invalidResponseJSON: return "invalid_response_json"
        case .missingOutputText: return "missing_output_text"
        case .invalidQuizJSON: return "invalid_quiz_json"
        case .invalidContract: return "invalid_contract"
        }
    }
}

private extension YandexAIQuizContractViolation {
    var diagnosticDescription: String {
        switch self {
        case let .promptTooLong(maximum, actual):
            return "prompt_too_long maximum=\(maximum) actual=\(actual)"
        case let .localeMismatch(expected, actual):
            return "locale_mismatch expected=\(expected) actual=\(actual)"
        case .invalidSuccessMessage:
            return "invalid_success_message"
        case .invalidRefusal:
            return "invalid_refusal"
        case .emptyTheme:
            return "empty_theme"
        case .emptyThemeDescription:
            return "empty_theme_description"
        case let .invalidQuestionCount(expected, actual):
            return "invalid_question_count expected=\(expected) actual=\(actual)"
        case let .emptyQuestion(index):
            return "empty_question index=\(index)"
        case let .questionTooLong(index):
            return "question_too_long index=\(index)"
        case .duplicateQuestions:
            return "duplicate_questions"
        case let .invalidAnswerCount(questionIndex, actual):
            return "invalid_answer_count question_index=\(questionIndex) actual=\(actual)"
        case let .emptyAnswer(questionIndex, answerIndex):
            return "empty_answer question_index=\(questionIndex) answer_index=\(answerIndex)"
        case let .answerTooLong(questionIndex, answerIndex):
            return "answer_too_long question_index=\(questionIndex) answer_index=\(answerIndex)"
        case let .duplicateAnswers(questionIndex):
            return "duplicate_answers question_index=\(questionIndex)"
        case let .invalidCorrectAnswer(questionIndex):
            return "invalid_correct_answer question_index=\(questionIndex)"
        case let .invalidExplanation(questionIndex):
            return "invalid_explanation question_index=\(questionIndex)"
        }
    }
}

private extension YandexAIQuizThemeServiceError {
    var diagnosticDescription: String {
        switch self {
        case .unavailableInRelease:
            return "unavailable_in_release"
        case .authenticationRequired:
            return "authentication_required"
        case .missingAPIKey:
            return "missing_api_key environment_variable=YANDEX_AI_API_KEY"
        case .unauthorized:
            return "unauthorized status_code=401 environment_variable=YANDEX_AI_API_KEY"
        case .emptyPrompt:
            return "empty_prompt"
        case .requestEncodingFailed:
            return "request_encoding_failed"
        case let .network(code):
            return "network_error url_error_code=\(code.rawValue)"
        case .invalidHTTPResponse:
            return "invalid_http_response"
        case let .httpStatus(statusCode):
            return "http_status status_code=\(statusCode)"
        case let .generationStatus(status):
            return "generation_status status=\(status)"
        case .refused:
            return "refused"
        case .invalidResponseJSON:
            return "invalid_response_json"
        case .missingOutputText:
            return "missing_output_text"
        case .invalidQuizJSON:
            return "invalid_quiz_json"
        case let .invalidContract(violation):
            return "invalid_contract \(violation.diagnosticDescription)"
        }
    }
}

extension YandexAIQuizThemeServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unavailableInRelease:
            return "AI quiz generation is unavailable in this build."
        case .authenticationRequired:
            return "Game Center authentication is required for AI quiz generation."
        case .missingAPIKey:
            return "Yandex AI API key is not configured."
        case .unauthorized:
            return "Yandex AI API key was rejected."
        case .emptyPrompt:
            return "Enter a quiz theme."
        case .requestEncodingFailed:
            return "The AI quiz request could not be prepared."
        case let .network(code):
            return "The AI service request failed: \(code.rawValue)."
        case .invalidHTTPResponse:
            return "The AI service returned an invalid response."
        case let .httpStatus(statusCode):
            return "The AI service returned HTTP \(statusCode)."
        case let .generationStatus(status):
            return "The AI service did not complete generation (\(status))."
        case .refused:
            return "The AI service refused to generate a quiz for this topic."
        case .invalidResponseJSON:
            return "The AI service response could not be read."
        case .missingOutputText:
            return "The AI service response did not contain generated text."
        case .invalidQuizJSON:
            return "The AI service returned an invalid quiz document."
        case .invalidContract:
            return "The generated quiz does not match the required format."
        }
    }
}

final class YandexAIQuizThemeService: AIQuizThemeServiceProtocol {
    static let endpoint = URL(string: "https://ai.api.cloud.yandex.net/v1/responses")!
    static let projectID = "b1g37dgcjvpr020nel5a"
    static let promptID = "fvto67v1ev0p2b7r4v5i"

    private static let supportedLanguageCodes: Set<String> = ["ru", "en", "es", "de", "it", "fr"]
    private static let contentFilterReason = "content_filter"
    private static let plainTextRefusals: Set<String> = [
        "Я не могу обсуждать эту тему. Давайте поговорим о чём-нибудь ещё."
    ]

    private let apiKey: String?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let idGenerator: () -> String
    private let onUnauthorized: () -> Void

    init(
        apiKey: String?,
        session: URLSession = .shared,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        onUnauthorized: @escaping () -> Void = {}
    ) {
        self.apiKey = apiKey
        self.session = session
        self.idGenerator = idGenerator
        self.onUnauthorized = onUnauthorized
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func generateQuizTheme(configuration: AIQuizGenerationConfiguration) async throws -> QuizTheme {
#if !DEBUG
        let error = YandexAIQuizThemeServiceError.unavailableInRelease
        AppLog.quiz.error("AI quiz generation failed: \(error.diagnosticDescription, privacy: .public)")
        throw error
#else
        do {
            try Task.checkCancellation()

            let trimmedPrompt = configuration.theme.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedPrompt.isEmpty else {
                throw YandexAIQuizThemeServiceError.emptyPrompt
            }
            guard AIQuizGenerationConfiguration.supportedQuestionCounts.contains(configuration.questionCount) else {
                throw YandexAIQuizThemeServiceError.invalidContract(
                    .invalidQuestionCount(expected: configuration.questionCount, actual: 0)
                )
            }

            let trimmedAPIKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !trimmedAPIKey.isEmpty else {
                throw YandexAIQuizThemeServiceError.missingAPIKey
            }

            let languageCode = Self.languageCode(for: configuration.locale)
            let request = try makeRequest(
                prompt: trimmedPrompt,
                questionCount: configuration.questionCount,
                difficulty: configuration.difficulty,
                languageCode: languageCode,
                apiKey: trimmedAPIKey
            )

            AppLog.quiz.info(
                "AI quiz request prepared: locale=\(languageCode, privacy: .public) prompt_length=\(trimmedPrompt.count, privacy: .public) endpoint=\(Self.endpoint.absoluteString, privacy: .public)"
            )

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError where error.code == .cancelled {
                throw CancellationError()
            } catch let error as URLError {
                throw YandexAIQuizThemeServiceError.network(error.code)
            } catch {
                throw YandexAIQuizThemeServiceError.network(.unknown)
            }

            try Task.checkCancellation()

            guard let httpResponse = response as? HTTPURLResponse else {
                throw YandexAIQuizThemeServiceError.invalidHTTPResponse
            }
            AppLog.quiz.info(
                "AI quiz response received: status_code=\(httpResponse.statusCode, privacy: .public) body_bytes=\(data.count, privacy: .public)"
            )
            if httpResponse.statusCode == 401 {
                onUnauthorized()
                throw YandexAIQuizThemeServiceError.unauthorized
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                throw YandexAIQuizThemeServiceError.httpStatus(httpResponse.statusCode)
            }

            let envelope: ResponsesEnvelope
            do {
                envelope = try decoder.decode(ResponsesEnvelope.self, from: data)
            } catch {
                AppLog.quiz.error(
                    "AI quiz response envelope decoding failed: \(Self.decodingFailureSummary(error), privacy: .public)"
                )
                throw YandexAIQuizThemeServiceError.invalidResponseJSON
            }

            let incompleteReason = envelope.incompleteDetails?.reason
            let incompleteReasonForLog = incompleteReason ?? "none"
            AppLog.quiz.debug(
                "AI quiz generation status received: status=\(envelope.status, privacy: .public) incomplete_reason=\(incompleteReasonForLog, privacy: .public)"
            )

            let outputContent = envelope.output.flatMap(\.content)
            let outputText = outputContent
                .filter { $0.type == "output_text" }
                .compactMap(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if Self.isContentFilterReason(incompleteReason)
                || outputContent.contains(where: { $0.type == "refusal" })
                || Self.plainTextRefusals.contains(outputText) {
                throw YandexAIQuizThemeServiceError.refused
            }
            guard envelope.status == "completed" else {
                throw YandexAIQuizThemeServiceError.generationStatus(envelope.status)
            }
            guard !outputText.isEmpty else {
                throw YandexAIQuizThemeServiceError.missingOutputText
            }

            let payload: GeneratedQuizPayload
            do {
                payload = try decoder.decode(GeneratedQuizPayload.self, from: Data(outputText.utf8))
            } catch {
                AppLog.quiz.error(
                    "AI quiz payload decoding failed: \(Self.decodingFailureSummary(error), privacy: .public)"
                )
                throw YandexAIQuizThemeServiceError.invalidQuizJSON
            }

            guard payload.status == .success else {
                throw YandexAIQuizThemeServiceError.refused
            }

            let theme = try makeQuizTheme(from: payload, expectedQuestionCount: configuration.questionCount)
            theme.aiGenerationConfiguration = AIQuizGenerationConfiguration(
                theme: trimmedPrompt,
                questionCount: configuration.questionCount,
                difficulty: configuration.difficulty,
                locale: configuration.locale
            )
            AppLog.quiz.info(
                "AI quiz generation completed: locale=\(languageCode, privacy: .public) questions=\(theme.questions.count, privacy: .public)"
            )
            return theme
        } catch is CancellationError {
            AppLog.quiz.debug("AI quiz generation cancelled")
            throw CancellationError()
        } catch let error as YandexAIQuizThemeServiceError {
            AppLog.quiz.error("AI quiz generation failed: \(error.diagnosticDescription, privacy: .public)")
            throw error
        } catch {
            let errorType = String(describing: type(of: error))
            AppLog.quiz.error("AI quiz generation failed with unexpected error type: \(errorType, privacy: .public)")
            throw error
        }
#endif
    }

    private static func decodingFailureSummary(_ error: Error) -> String {
        guard let decodingError = error as? DecodingError else {
            return String(describing: type(of: error))
        }

        let codingPath: [CodingKey]
        let category: String
        switch decodingError {
        case let .typeMismatch(_, context):
            category = "type_mismatch"
            codingPath = context.codingPath
        case let .valueNotFound(_, context):
            category = "value_not_found"
            codingPath = context.codingPath
        case let .keyNotFound(key, context):
            category = "key_not_found key=\(key.stringValue)"
            codingPath = context.codingPath
        case let .dataCorrupted(context):
            category = "data_corrupted"
            codingPath = context.codingPath
        @unknown default:
            category = "unknown_decoding_error"
            codingPath = []
        }

        let path = codingPath.map(\.stringValue).joined(separator: ".")
        return path.isEmpty ? category : "\(category) coding_path=\(path)"
    }

    private func makeRequest(
        prompt: String,
        questionCount: Int,
        difficulty: AIQuizDifficulty,
        languageCode: String,
        apiKey: String
    ) throws -> URLRequest {
        let inputData: Data
        let requestData: Data

        do {
            inputData = try encoder.encode(
                GenerationInput(
                    theme: prompt,
                    locale: languageCode,
                    questionCount: questionCount,
                    difficulty: difficulty
                )
            )
            guard let input = String(data: inputData, encoding: .utf8) else {
                throw YandexAIQuizThemeServiceError.requestEncodingFailed
            }
            requestData = try encoder.encode(
                ResponsesRequest(
                    prompt: .init(id: Self.promptID),
                    input: input,
                    store: false
                )
            )
        } catch let error as YandexAIQuizThemeServiceError {
            throw error
        } catch {
            throw YandexAIQuizThemeServiceError.requestEncodingFailed
        }

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("Api-Key \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(Self.projectID, forHTTPHeaderField: "OpenAI-Project")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("false", forHTTPHeaderField: "x-data-logging-enabled")
        return request
    }

    private func makeQuizTheme(
        from payload: GeneratedQuizPayload,
        expectedQuestionCount: Int
    ) throws -> QuizTheme {
        let themeName = payload.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !themeName.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyTheme)
        }

        let themeDescription = payload.themeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !themeDescription.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyThemeDescription)
        }

        guard payload.questions.count == expectedQuestionCount else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidQuestionCount(expected: expectedQuestionCount, actual: payload.questions.count)
            )
        }

        let questions = try payload.questions.enumerated().map { index, payload in
            try makeQuestion(from: payload, index: index)
        }

        return QuizTheme(
            id: "ai-\(idGenerator())",
            theme: themeName,
            themeDescription: themeDescription,
            questions: questions,
            source: .ai,
            questionOrigin: .directAI
        )
    }

    private func makeQuestion(from payload: GeneratedQuestionPayload, index: Int) throws -> QuizQuestion {
        let question = payload.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyQuestion(index: index))
        }

        guard payload.answers.count == 4 else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidAnswerCount(questionIndex: index, actual: payload.answers.count)
            )
        }

        let answers = try payload.answers.enumerated().map { answerIndex, answer -> String in
            let trimmedAnswer = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedAnswer.isEmpty else {
                throw YandexAIQuizThemeServiceError.invalidContract(
                    .emptyAnswer(questionIndex: index, answerIndex: answerIndex)
                )
            }
            return trimmedAnswer
        }

        guard Set(answers).count == answers.count else {
            throw YandexAIQuizThemeServiceError.invalidContract(.duplicateAnswers(questionIndex: index))
        }

        let correctAnswer = payload.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        let exactCorrectAnswerMatches = answers.filter { $0 == correctAnswer }.count
        guard exactCorrectAnswerMatches == 1 else {
            throw YandexAIQuizThemeServiceError.invalidContract(.invalidCorrectAnswer(questionIndex: index))
        }

        return QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer,
            explanation: payload.explanation
        )
    }

    private static func languageCode(for locale: Locale) -> String {
        let languageCode = locale.language.languageCode?.identifier.lowercased()
        guard let languageCode, supportedLanguageCodes.contains(languageCode) else {
            return "en"
        }
        return languageCode
    }

    private static func isContentFilterReason(_ reason: String?) -> Bool {
        reason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == contentFilterReason
    }
}

private extension YandexAIQuizThemeService {
    struct GenerationInput: Encodable {
        let theme: String
        let locale: String
        let questionCount: Int
        let difficulty: AIQuizDifficulty
    }

    struct ResponsesRequest: Encodable {
        struct Prompt: Encodable {
            let id: String
        }

        let prompt: Prompt
        let input: String
        let store: Bool
    }

    struct ResponsesEnvelope: Decodable {
        struct IncompleteDetails: Decodable {
            let reason: String?
        }

        struct Output: Decodable {
            let content: [Content]

            enum CodingKeys: CodingKey {
                case content
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                content = try container.decodeIfPresent([Content].self, forKey: .content) ?? []
            }
        }

        struct Content: Decodable {
            let type: String
            let text: String?
        }

        let status: String
        let incompleteDetails: IncompleteDetails?
        let output: [Output]

        enum CodingKeys: String, CodingKey {
            case status
            case incompleteDetails = "incomplete_details"
            case output
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            status = try container.decode(String.self, forKey: .status)
            incompleteDetails = try container.decodeIfPresent(IncompleteDetails.self, forKey: .incompleteDetails)
            output = try container.decodeIfPresent([Output].self, forKey: .output) ?? []
        }
    }

    struct GeneratedQuizPayload: Decodable {
        enum Status: String, Decodable {
            case success
            case refused
        }

        let status: Status
        let message: String
        let theme: String
        let themeDescription: String
        let questions: [GeneratedQuestionPayload]
    }

    struct GeneratedQuestionPayload: Decodable {
        let question: String
        let answers: [String]
        let correctAnswer: String
        let explanation: String
    }
}

final class MockAIQuizThemeService: AIQuizThemeServiceProtocol {
    private(set) var generatedConfigurations: [AIQuizGenerationConfiguration] = []

    func generateQuizTheme(configuration: AIQuizGenerationConfiguration) async throws -> QuizTheme {
        let trimmedPrompt = configuration.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedConfiguration = AIQuizGenerationConfiguration(
            theme: trimmedPrompt,
            questionCount: configuration.questionCount,
            difficulty: configuration.difficulty,
            locale: configuration.locale
        )
        generatedConfigurations.append(normalizedConfiguration)
        AppLog.quiz.debug("Generated mock AI quiz request for locale: \(configuration.locale.identifier, privacy: .public)")
        return QuizTheme(
            id: trimmedPrompt.lowercased().replacingOccurrences(of: " ", with: "_"),
            theme: trimmedPrompt,
            themeDescription: "AI generated quiz placeholder",
            questions: [],
            source: .ai,
            questionOrigin: .mock
        )
    }
}
