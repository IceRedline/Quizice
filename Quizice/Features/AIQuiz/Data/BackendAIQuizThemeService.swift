import Foundation

final class BackendAIQuizThemeService: AIQuizThemeServiceProtocol {
    private struct GenerationRequest: Encodable {
        let topic: String
        let count: Int
        let locale: String
        let difficulty: AIQuizDifficulty
    }

    private struct GenerationResponse: Decodable {
        enum Status: String, Decodable {
            case success
            case refused
        }

        struct Question: Decodable {
            let question: String
            let answers: [String]
            let correctAnswer: String
            let explanation: String
        }

        let locale: String
        let status: Status
        let message: String
        let theme: String
        let themeDescription: String
        let questions: [Question]
    }

    private let baseURL: URL
    private let session: URLSession
    private let sessionStore: SessionStoring
    private let now: () -> Date
    private let idGenerator: () -> String
    private let metrics: BackendRequestMetricRecording
    private let accessProvider: AIQuizAccessProviding
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let clock = ContinuousClock()
    private let requestTimeout: TimeInterval
    private let notificationCenter: NotificationCenter

    init(
        configuration: BackendConfiguration,
        session: URLSession = .shared,
        sessionStore: SessionStoring = KeychainSessionStore(),
        now: @escaping () -> Date = Date.init,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        requestTimeout: TimeInterval = 90,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder(),
        accessProvider: AIQuizAccessProviding = AIQuizAccessStore.shared,
        notificationCenter: NotificationCenter = .default
    ) {
        baseURL = configuration.baseURL
        self.session = session
        self.sessionStore = sessionStore
        self.now = now
        self.idGenerator = idGenerator
        self.requestTimeout = requestTimeout
        self.metrics = metrics
        self.accessProvider = accessProvider
        self.notificationCenter = notificationCenter
    }

    func generateQuizTheme(configuration: AIQuizGenerationConfiguration) async throws -> QuizTheme {
        try Task.checkCancellation()
        guard accessProvider.isAIQuizAvailable else {
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }
        let topic = configuration.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !topic.isEmpty else {
            throw YandexAIQuizThemeServiceError.emptyPrompt
        }
        guard topic.count <= AIQuizGenerationConfiguration.maximumThemeLength else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .promptTooLong(
                    maximum: AIQuizGenerationConfiguration.maximumThemeLength,
                    actual: topic.count
                )
            )
        }
        guard AIQuizGenerationConfiguration.supportedQuestionCounts.contains(configuration.questionCount) else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidQuestionCount(expected: configuration.questionCount, actual: 0)
            )
        }

        let locale = Self.languageCode(for: configuration.locale)
        let authSession: AuthSession
        do {
            guard
                let storedSession = try sessionStore.load(),
                storedSession.expiresAt > now().addingTimeInterval(30),
                !storedSession.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                invalidateBackendAuthentication()
                throw YandexAIQuizThemeServiceError.authenticationRequired
            }
            authSession = storedSession
        } catch let error as YandexAIQuizThemeServiceError {
            throw error
        } catch {
            invalidateBackendAuthentication()
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }

        let requestBody: Data
        do {
            requestBody = try encoder.encode(
                GenerationRequest(
                    topic: topic,
                    count: configuration.questionCount,
                    locale: locale,
                    difficulty: configuration.difficulty
                )
            )
        } catch {
            throw YandexAIQuizThemeServiceError.requestEncodingFailed
        }

        var request = URLRequest(
            url: baseURL
                .appendingPathComponent("v1")
                .appendingPathComponent("quizzes")
                .appendingPathComponent("generate"),
            timeoutInterval: requestTimeout
        )
        request.httpMethod = "POST"
        request.httpBody = requestBody
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(authSession.accessToken)", forHTTPHeaderField: "Authorization")

        let startedAt = clock.now
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            record(.cancelled, startedAt: startedAt)
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            record(.cancelled, startedAt: startedAt)
            throw CancellationError()
        } catch let error as URLError {
            record(.transportError, startedAt: startedAt)
            throw YandexAIQuizThemeServiceError.network(error.code)
        } catch {
            record(.transportError, startedAt: startedAt)
            throw YandexAIQuizThemeServiceError.network(.unknown)
        }

        if Task.isCancelled {
            record(.cancelled, startedAt: startedAt, responseBytes: data.count)
            throw CancellationError()
        }
        guard isCurrentAuthSession(authSession) else {
            record(.cancelled, startedAt: startedAt, responseBytes: data.count)
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }
        guard accessProvider.isAIQuizAvailable else {
            record(.cancelled, startedAt: startedAt, responseBytes: data.count)
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            record(.transportError, startedAt: startedAt, responseBytes: data.count)
            throw YandexAIQuizThemeServiceError.invalidHTTPResponse
        }
        if httpResponse.statusCode == 401 {
            guard isCurrentAuthSession(authSession) else {
                record(.cancelled, startedAt: startedAt, responseBytes: data.count)
                throw YandexAIQuizThemeServiceError.authenticationRequired
            }
            invalidateBackendAuthentication()
            record(
                .httpError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }
        if httpResponse.statusCode == 403 {
            guard isCurrentAuthSession(authSession) else {
                record(.cancelled, startedAt: startedAt, responseBytes: data.count)
                throw YandexAIQuizThemeServiceError.authenticationRequired
            }
            disableAIQuizAccess()
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            record(
                .httpError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.httpStatus(httpResponse.statusCode)
        }

        let payload: GenerationResponse
        do {
            payload = try decoder.decode(GenerationResponse.self, from: data)
        } catch {
            record(
                .decodingError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.invalidResponseJSON
        }
        guard payload.locale == locale else {
            record(
                .contractError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.invalidContract(
                .localeMismatch(expected: locale, actual: payload.locale)
            )
        }
        if payload.status == .refused {
            let message = payload.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                !message.isEmpty,
                message.count <= 500,
                payload.theme.isEmpty,
                payload.themeDescription.isEmpty,
                payload.questions.isEmpty
            else {
                record(
                    .contractError,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                throw YandexAIQuizThemeServiceError.invalidContract(.invalidRefusal)
            }
            guard
                isCurrentAuthSession(authSession),
                accessProvider.isAIQuizAvailable
            else {
                record(
                    .cancelled,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                throw YandexAIQuizThemeServiceError.authenticationRequired
            }
            record(
                .success,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.refused
        }
        guard payload.message.isEmpty else {
            record(
                .contractError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.invalidContract(.invalidSuccessMessage)
        }

        let theme: QuizTheme
        do {
            theme = try makeQuizTheme(
                payload,
                expectedQuestionCount: configuration.questionCount
            )
        } catch {
            record(
                .contractError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw error
        }
        theme.aiGenerationConfiguration = configuration
        guard
            isCurrentAuthSession(authSession),
            accessProvider.isAIQuizAvailable
        else {
            record(
                .cancelled,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw YandexAIQuizThemeServiceError.authenticationRequired
        }
        record(
            .success,
            startedAt: startedAt,
            statusCode: httpResponse.statusCode,
            responseBytes: data.count
        )
        return theme
    }

    private func makeQuizTheme(
        _ payload: GenerationResponse,
        expectedQuestionCount: Int
    ) throws -> QuizTheme {
        let theme = payload.theme.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !theme.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyTheme)
        }
        let description = payload.themeDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !description.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyThemeDescription)
        }
        guard payload.questions.count == expectedQuestionCount else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidQuestionCount(
                    expected: expectedQuestionCount,
                    actual: payload.questions.count
                )
            )
        }

        let questions = try payload.questions.enumerated().map { index, payload in
            try makeQuestion(payload, index: index)
        }
        guard Set(questions.map(\.question)).count == questions.count else {
            throw YandexAIQuizThemeServiceError.invalidContract(.duplicateQuestions)
        }
        return QuizTheme(
            id: "ai-\(idGenerator())",
            theme: theme,
            themeDescription: description,
            questions: questions,
            source: .ai,
            questionOrigin: .backend
        )
    }

    private func makeQuestion(
        _ payload: GenerationResponse.Question,
        index: Int
    ) throws -> QuizQuestion {
        let question = payload.question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(.emptyQuestion(index: index))
        }
        guard question.count <= 500 else {
            throw YandexAIQuizThemeServiceError.invalidContract(.questionTooLong(index: index))
        }
        guard payload.answers.count == 4 else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidAnswerCount(questionIndex: index, actual: payload.answers.count)
            )
        }
        let answers = try payload.answers.enumerated().map { answerIndex, answer in
            let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else {
                throw YandexAIQuizThemeServiceError.invalidContract(
                    .emptyAnswer(questionIndex: index, answerIndex: answerIndex)
                )
            }
            guard normalized.count <= 300 else {
                throw YandexAIQuizThemeServiceError.invalidContract(
                    .answerTooLong(questionIndex: index, answerIndex: answerIndex)
                )
            }
            return normalized
        }
        guard Set(answers).count == answers.count else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .duplicateAnswers(questionIndex: index)
            )
        }
        let correctAnswer = payload.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard answers.filter({ $0 == correctAnswer }).count == 1 else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidCorrectAnswer(questionIndex: index)
            )
        }
        guard payload.explanation.isEmpty else {
            throw YandexAIQuizThemeServiceError.invalidContract(
                .invalidExplanation(questionIndex: index)
            )
        }
        return QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer,
            explanation: payload.explanation
        )
    }

    private func record(
        _ result: BackendRequestResult,
        startedAt: ContinuousClock.Instant,
        statusCode: Int? = nil,
        responseBytes: Int = 0
    ) {
        let components = (clock.now - startedAt).components
        let durationMilliseconds = max(
            Int(components.seconds * 1_000 + components.attoseconds / 1_000_000_000_000_000),
            0
        )
        metrics.record(
            BackendRequestMetric(
                operation: .aiGeneration,
                result: result,
                durationMilliseconds: durationMilliseconds,
                statusCode: statusCode,
                responseBytes: responseBytes
            )
        )
    }

    private func invalidateBackendAuthentication() {
        disableAIQuizAccess()
        try? sessionStore.clear()
        notificationCenter.post(name: .backendAuthenticationInvalidated, object: nil)
    }

    private func isCurrentAuthSession(_ expectedSession: AuthSession) -> Bool {
        do {
            return try sessionStore.load() == expectedSession
        } catch {
            return false
        }
    }

    private func disableAIQuizAccess() {
        (accessProvider as? AIQuizAccessUpdating)?.update(isAuthenticated: false)
    }

    private static func languageCode(for locale: Locale) -> String {
        let code = locale.language.languageCode?.identifier.lowercased()
        guard let code, AppLanguagePreference.explicitPreference(for: code) != nil else {
            return AppLanguagePreference.fallbackLanguageCode
        }
        return code
    }
}
