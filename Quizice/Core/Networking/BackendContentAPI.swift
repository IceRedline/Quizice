import Foundation
import Network

protocol BackendContentAPI {
    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse
    func fetchThemePreferences(locale: String) async throws -> BackendThemePreferencesResponse
    func replaceThemePreferences(
        locale: String,
        favoriteThemeIDs: [String]
    ) async throws -> BackendThemePreferencesResponse
    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
    func submitQuestionAnswers(_ events: [QuestionAnswerEvent], session: AuthSession) async throws -> QuestionAnswerBatchResponse
    func submitQuestionAnswers(_ events: [QuestionAnswerEvent]) async throws -> QuestionAnswerBatchResponse
    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse
    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse
}

extension BackendContentAPI {
    func submitQuestionAnswers(_ events: [QuestionAnswerEvent], session: AuthSession) async throws -> QuestionAnswerBatchResponse {
        try await submitQuestionAnswers(events)
    }
    func submitQuestionAnswers(_ events: [QuestionAnswerEvent]) async throws -> QuestionAnswerBatchResponse {
        throw BackendContentError.unauthenticated
    }
    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchQuestions(
            themeID: themeID,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchRandomQuestions(
            selectionMode: selectionMode,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed
        )
    }
    func fetchThemePreferences(locale: String) async throws -> BackendThemePreferencesResponse {
        throw BackendContentError.unauthenticated
    }

    func replaceThemePreferences(
        locale: String,
        favoriteThemeIDs: [String]
    ) async throws -> BackendThemePreferencesResponse {
        throw BackendContentError.unauthenticated
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchQuestions(
            themeID: themeID,
            count: count,
            locale: locale,
            seed: seed
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchRandomQuestions(
            selectionMode: selectionMode,
            count: count,
            locale: locale,
            seed: seed
        )
    }
}

final class HTTPBackendContentAPI: BackendContentAPI {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let requestTimeout: TimeInterval
    private let metrics: BackendRequestMetricRecording
    private let accessTokenProvider: BackendAccessTokenProviding
    private let authenticationRecoverer: BackendAuthenticationRecovering?
    private let clock = ContinuousClock()

    // Content responses (themes, preferences, question batches) are a few
    // kilobytes at most. Anything larger indicates a misbehaving upstream or
    // an active attack; refuse the body before JSON decoding balloons memory.
    private static let maxResponseBytes = 10 * 1024 * 1024

    init(
        configuration: BackendConfiguration,
        session: URLSession = .shared,
        requestTimeout: TimeInterval = 15,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder(),
        accessTokenProvider: BackendAccessTokenProviding = NoopBackendAccessTokenProvider(),
        authenticationRecoverer: BackendAuthenticationRecovering? = nil
    ) {
        baseURL = configuration.baseURL
        self.session = session
        self.requestTimeout = requestTimeout
        self.metrics = metrics
        self.accessTokenProvider = accessTokenProvider
        self.authenticationRecoverer = authenticationRecoverer
        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse {
        guard Self.isSupported(locale: locale) else {
            throw BackendContentError.invalidRequest
        }
        let url = try makeURL(
            pathComponents: ["v1", "themes"],
            queryItems: [URLQueryItem(name: "locale", value: locale)]
        )
        return try await get(
            url: url,
            operation: .themes,
            accessToken: accessTokenProvider.validAccessToken(),
            validate: { Self.isValid($0, requestedLocale: locale) }
        )
    }

    func fetchThemePreferences(locale: String) async throws -> BackendThemePreferencesResponse {
        guard Self.isSupported(locale: locale) else {
            throw BackendContentError.invalidRequest
        }
        guard let accessToken = accessTokenProvider.validAccessToken() else {
            throw BackendContentError.unauthenticated
        }
        let url = try makeURL(
            pathComponents: ["v1", "me", "theme-preferences"],
            queryItems: [URLQueryItem(name: "locale", value: locale)]
        )
        return try await get(
            url: url,
            operation: .themePreferences,
            accessToken: accessToken,
            validate: { Self.isValid($0, requestedLocale: locale) }
        )
    }

    func replaceThemePreferences(
        locale: String,
        favoriteThemeIDs: [String]
    ) async throws -> BackendThemePreferencesResponse {
        guard Self.isSupported(locale: locale) else {
            throw BackendContentError.invalidRequest
        }
        guard let accessToken = accessTokenProvider.validAccessToken() else {
            throw BackendContentError.unauthenticated
        }
        let normalizedIDs = Self.normalizedThemeIDs(favoriteThemeIDs)
        guard normalizedIDs.count == favoriteThemeIDs.count else {
            throw BackendContentError.invalidRequest
        }
        let url = try makeURL(
            pathComponents: ["v1", "me", "theme-preferences"],
            queryItems: []
        )
        return try await put(
            url: url,
            operation: .themePreferences,
            accessToken: accessToken,
            body: BackendThemePreferencesUpdate(
                locale: locale,
                favoriteThemeIds: normalizedIDs
            ),
            validate: { Self.isValid($0, requestedLocale: locale) }
        )
    }

    func submitQuestionAnswers(_ events: [QuestionAnswerEvent], session: AuthSession) async throws -> QuestionAnswerBatchResponse {
        guard !events.isEmpty, events.count <= 100 else { throw BackendContentError.invalidRequest }
        guard accessTokenProvider.currentSession()?.userID == session.userID else {
            throw BackendContentError.unauthenticated
        }
        let url = try makeURL(pathComponents: ["v1", "me", "question-answers"], queryItems: [])
        return try await post(
            url: url, operation: .questionAnswers, accessToken: session.accessToken,
            body: QuestionAnswerBatchRequest(events: events),
            expectedUserID: session.userID,
            validate: { Set($0.processedEventIds).isSubset(of: Set(events.map(\.eventId))) }
        )
    }

    func submitQuestionAnswers(_ events: [QuestionAnswerEvent]) async throws -> QuestionAnswerBatchResponse {
        guard !events.isEmpty, events.count <= 100 else { throw BackendContentError.invalidRequest }
        guard let accessToken = accessTokenProvider.validAccessToken() else {
            throw BackendContentError.unauthenticated
        }
        let url = try makeURL(
            pathComponents: ["v1", "me", "question-answers"],
            queryItems: []
        )
        return try await post(
            url: url,
            operation: .questionAnswers,
            accessToken: accessToken,
            body: QuestionAnswerBatchRequest(events: events),
            validate: { response in
                let requested = Set(events.map(\.eventId))
                return Set(response.processedEventIds).isSubset(of: requested)
            }
        )
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchQuestionBatch(
            themeID: themeID,
            count: count,
            locale: locale,
            difficulty: nil,
            seed: seed,
            strategy: .showAll
        )
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchQuestionBatch(
            themeID: themeID,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed,
            strategy: .showAll
        )
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchQuestionBatch(
            themeID: themeID,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed,
            strategy: strategy
        )
    }

    private func fetchQuestionBatch(
        themeID: String,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty?,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        let normalizedThemeID = themeID.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !normalizedThemeID.isEmpty,
            UUID(uuidString: normalizedSeed)?.uuidString.lowercased() == normalizedSeed,
            QuizQuestionCountPolicy.supportedCounts.contains(count),
            Self.isSupported(locale: locale)
        else {
            throw BackendContentError.invalidRequest
        }

        var queryItems = [
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "locale", value: locale)
        ]
        if let difficulty {
            queryItems.append(
                URLQueryItem(name: "difficulty", value: difficulty.rawValue)
            )
        }
        queryItems.append(URLQueryItem(name: "seed", value: normalizedSeed))
        if let progressMode = strategy.progressMode {
            queryItems.append(URLQueryItem(name: "progressMode", value: progressMode.rawValue))
        }
        let url = try makeURL(
            pathComponents: ["v1", "themes", normalizedThemeID, "questions"],
            queryItems: queryItems
        )
        let accessToken = accessTokenProvider.validAccessToken()
        if strategy.progressMode != nil, accessToken == nil {
            throw BackendContentError.unauthenticated
        }
        return try await get(
            url: url,
            operation: .questions,
            accessToken: accessToken,
            validate: {
                Self.isValid(
                    $0,
                    requestedCount: count,
                    requestedLocale: locale,
                    requestedSeed: normalizedSeed
                )
            }
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchRandomQuestionBatch(
            selectionMode: selectionMode,
            count: count,
            locale: locale,
            difficulty: nil,
            seed: seed,
            strategy: .showAll
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchRandomQuestionBatch(
            selectionMode: selectionMode,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed,
            strategy: .showAll
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        try await fetchRandomQuestionBatch(
            selectionMode: selectionMode,
            count: count,
            locale: locale,
            difficulty: difficulty,
            seed: seed,
            strategy: strategy
        )
    }

    private func fetchRandomQuestionBatch(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        difficulty: AIQuizDifficulty?,
        seed: String,
        strategy: QuestionRepeatStrategy
    ) async throws -> BackendQuestionBatchResponse {
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            UUID(uuidString: normalizedSeed)?.uuidString.lowercased() == normalizedSeed,
            QuizQuestionCountPolicy.supportedCounts.contains(count),
            Self.isSupported(locale: locale)
        else {
            throw BackendContentError.invalidRequest
        }

        var queryItems = [
            URLQueryItem(name: "count", value: String(count)),
            URLQueryItem(name: "locale", value: locale)
        ]
        if let difficulty {
            queryItems.append(
                URLQueryItem(name: "difficulty", value: difficulty.rawValue)
            )
        }
        queryItems.append(URLQueryItem(name: "seed", value: normalizedSeed))
        if let progressMode = strategy.progressMode {
            queryItems.append(URLQueryItem(name: "progressMode", value: progressMode.rawValue))
        }
        let url = try makeURL(
            pathComponents: ["v1", "questions", selectionMode.rawValue],
            queryItems: queryItems
        )
        let accessToken = accessTokenProvider.validAccessToken()
        if strategy.progressMode != nil, accessToken == nil {
            throw BackendContentError.unauthenticated
        }
        return try await get(
            url: url,
            operation: .questions,
            accessToken: accessToken,
            validate: {
                Self.isValid(
                    $0,
                    requestedCount: count,
                    requestedLocale: locale,
                    requestedSeed: normalizedSeed
                )
            }
        )
    }

    private func get<Response: Decodable>(
        url: URL,
        operation: BackendOperation,
        accessToken: String? = nil,
        validate: @escaping (Response) -> Bool
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return try await perform(
            request: request,
            operation: operation,
            validate: validate
        )
    }

    private func put<Response: Decodable, Body: Encodable>(
        url: URL,
        operation: BackendOperation,
        accessToken: String,
        body: Body,
        validate: @escaping (Response) -> Bool
    ) async throws -> Response {
        let bodyData: Data
        do {
            bodyData = try encoder.encode(body)
        } catch {
            throw BackendContentError.encoding
        }

        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpMethod = "PUT"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(
            request: request,
            operation: operation,
            validate: validate
        )
    }

    private func post<Response: Decodable, Body: Encodable>(
        url: URL,
        operation: BackendOperation,
        accessToken: String,
        body: Body,
        expectedUserID: String? = nil,
        validate: @escaping (Response) -> Bool
    ) async throws -> Response {
        let bodyData: Data
        do {
            encoder.dateEncodingStrategy = .iso8601
            bodyData = try encoder.encode(body)
        } catch {
            throw BackendContentError.encoding
        }
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
        request.httpMethod = "POST"
        request.httpBody = bodyData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request: request, operation: operation, validate: validate, expectedUserID: expectedUserID)
    }

    private func perform<Response: Decodable>(
        request: URLRequest,
        operation: BackendOperation,
        validate: @escaping (Response) -> Bool,
        expectedUserID: String? = nil,
        allowsAuthenticationRetry: Bool = true
    ) async throws -> Response {
        let startedAt = clock.now
        do {
            let (data, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                record(
                    operation: operation,
                    result: .transportError,
                    startedAt: startedAt,
                    statusCode: nil,
                    responseBytes: data.count
                )
                throw BackendContentError.invalidResponse
            }
            guard data.count <= Self.maxResponseBytes else {
                record(
                    operation: operation,
                    result: .contractError,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                throw BackendContentError.contractViolation
            }
            // If a WAF or captive portal intercepts the request it typically
            // returns HTML with a 200 code. Refuse anything that is not JSON
            // before feeding it to the decoder.
            if (200..<300).contains(httpResponse.statusCode) {
                let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")?.lowercased()
                if let contentType, !contentType.contains("application/json") {
                    record(
                        operation: operation,
                        result: .contractError,
                        startedAt: startedAt,
                        statusCode: httpResponse.statusCode,
                        responseBytes: data.count
                    )
                    throw BackendContentError.contractViolation
                }
            }
            guard (200..<300).contains(httpResponse.statusCode) else {
                let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data)
                record(
                    operation: operation,
                    result: .httpError,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                if httpResponse.statusCode == 401,
                   allowsAuthenticationRetry,
                   let authenticationRecoverer,
                   let authorization = request.value(forHTTPHeaderField: "Authorization"),
                   authorization.hasPrefix("Bearer ") {
                    if let expectedUserID,
                       accessTokenProvider.currentSession()?.userID != expectedUserID {
                        throw BackendContentError.unauthenticated
                    }
                    let rejectedToken = String(authorization.dropFirst("Bearer ".count))
                    let refreshedToken = try await authenticationRecoverer.reauthenticate(
                        afterRejectedAccessToken: rejectedToken
                    )
                    if let expectedUserID,
                       accessTokenProvider.currentSession()?.userID != expectedUserID {
                        throw BackendContentError.unauthenticated
                    }
                    var retryRequest = request
                    retryRequest.setValue(
                        "Bearer \(refreshedToken)",
                        forHTTPHeaderField: "Authorization"
                    )
                    return try await perform(
                        request: retryRequest,
                        operation: operation,
                        validate: validate,
                        expectedUserID: expectedUserID,
                        allowsAuthenticationRetry: false
                    )
                }
                throw BackendContentError.httpStatus(httpResponse.statusCode, envelope)
            }
            do {
                let decoded = try decoder.decode(Response.self, from: data)
                guard validate(decoded) else {
                    record(
                        operation: operation,
                        result: .contractError,
                        startedAt: startedAt,
                        statusCode: httpResponse.statusCode,
                        responseBytes: data.count
                    )
                    throw BackendContentError.contractViolation
                }
                record(
                    operation: operation,
                    result: .success,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                return decoded
            } catch let error as BackendContentError {
                throw error
            } catch {
                record(
                    operation: operation,
                    result: .decodingError,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
                throw BackendContentError.decoding
            }
        } catch is CancellationError {
            record(
                operation: operation,
                result: .cancelled,
                startedAt: startedAt,
                statusCode: nil,
                responseBytes: 0
            )
            throw CancellationError()
        } catch let error as BackendContentError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            record(
                operation: operation,
                result: .cancelled,
                startedAt: startedAt,
                statusCode: nil,
                responseBytes: 0
            )
            throw CancellationError()
        } catch let error as URLError {
            record(
                operation: operation,
                result: .transportError,
                startedAt: startedAt,
                statusCode: nil,
                responseBytes: 0
            )
            throw BackendContentError.transport(error.code)
        } catch {
            record(
                operation: operation,
                result: .transportError,
                startedAt: startedAt,
                statusCode: nil,
                responseBytes: 0
            )
            throw BackendContentError.transport(.unknown)
        }
    }

    private func makeURL(
        pathComponents: [String],
        queryItems: [URLQueryItem]
    ) throws -> URL {
        let url = pathComponents.reduce(baseURL) { partialURL, component in
            partialURL.appendingPathComponent(component)
        }
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw BackendContentError.invalidRequest
        }
        components.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let result = components.url else {
            throw BackendContentError.invalidRequest
        }
        return result
    }

    private func record(
        operation: BackendOperation,
        result: BackendRequestResult,
        startedAt: ContinuousClock.Instant,
        statusCode: Int?,
        responseBytes: Int
    ) {
        metrics.record(
            BackendRequestMetric(
                operation: operation,
                result: result,
                durationMilliseconds: Self.milliseconds(clock.now - startedAt),
                statusCode: statusCode,
                responseBytes: responseBytes
            )
        )
    }

    private static func isSupported(locale: String) -> Bool {
        AppLanguagePreference.explicitPreference(for: locale) != nil
    }

    private static func isValid(
        _ response: BackendThemeCatalogResponse,
        requestedLocale: String
    ) -> Bool {
        guard response.locale == requestedLocale, !response.themes.isEmpty else { return false }
        var identifiers = Set<String>()
        return response.themes.allSatisfy { theme in
            let id = theme.id.trimmingCharacters(in: .whitespacesAndNewlines)
            let name = theme.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = theme.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let sfSymbol = theme.sfSymbol.trimmingCharacters(in: .whitespacesAndNewlines)
            let emoji = theme.emoji.trimmingCharacters(in: .whitespacesAndNewlines)
            let colorHex = QuizThemeColor.normalizedHex(theme.colorHex)
            return !id.isEmpty
                && !name.isEmpty
                && !description.isEmpty
                && !sfSymbol.isEmpty
                && !emoji.isEmpty
                && colorHex == theme.colorHex
                && identifiers.insert(id).inserted
        }
    }

    private static func isValid(
        _ response: BackendThemePreferencesResponse,
        requestedLocale: String
    ) -> Bool {
        response.locale == requestedLocale
            && normalizedThemeIDs(response.favoriteThemeIds) == response.favoriteThemeIds
    }

    private static func normalizedThemeIDs(_ themeIDs: [String]) -> [String] {
        var identifiers = Set<String>()
        return themeIDs.compactMap { themeID in
            let normalizedID = themeID.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedID.isEmpty, identifiers.insert(normalizedID).inserted else { return nil }
            return normalizedID
        }
    }

    private static func isValid(
        _ response: BackendQuestionBatchResponse,
        requestedCount: Int,
        requestedLocale: String,
        requestedSeed: String
    ) -> Bool {
        guard
            response.locale == requestedLocale,
            response.seed == requestedSeed,
            response.questions.count <= requestedCount,
            response.availableCount >= response.questions.count
        else { return false }

        var prompts = Set<String>()
        var questionIDs = Set<String>()
        return response.questions.allSatisfy { question in
            let questionID = question.questionId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let prompt = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let answers = question.answers.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let correctAnswer = question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            return !questionID.isEmpty
                && questionIDs.insert(questionID).inserted
                && (question.questionVersion ?? 0) > 0
                && !prompt.isEmpty
                && prompt.count <= 500
                && prompts.insert(prompt).inserted
                && answers.count == 4
                && answers.allSatisfy { !$0.isEmpty }
                && answers.allSatisfy { $0.count <= 300 }
                && Set(answers).count == answers.count
                && answers.filter { $0 == correctAnswer }.count == 1
        }
    }

    private static func milliseconds(_ duration: Duration) -> Int {
        let components = duration.components
        let seconds = components.seconds * 1_000
        let milliseconds = components.attoseconds / 1_000_000_000_000_000
        return max(Int(seconds + milliseconds), 0)
    }
}

protocol QuestionAnswerOutboxing {
    var currentUserID: String? { get }
    func enqueue(_ event: QuestionAnswerEvent)
    func enqueue(_ event: QuestionAnswerEvent, for userID: String?)
    func synchronize() async
    func synchronizeBeforeFetchingQuestions(for userID: String) async throws
}

extension QuestionAnswerOutboxing {
    var currentUserID: String? { nil }
    func enqueue(_ event: QuestionAnswerEvent, for userID: String?) { enqueue(event) }
    func synchronizeBeforeFetchingQuestions(for userID: String) async throws { await synchronize() }
}

struct NoopQuestionAnswerOutbox: QuestionAnswerOutboxing {
    func enqueue(_ event: QuestionAnswerEvent) {}
    func synchronize() async {}
}

enum QuestionAnswerSyncError: Error {
    case accountChanged
    case unacknowledgedEvents
}

final class PersistentQuestionAnswerOutbox: QuestionAnswerOutboxing, @unchecked Sendable {
    static let shared = PersistentQuestionAnswerOutbox.live()

    struct OwnedEvent: Codable {
        let userID: String?
        let event: QuestionAnswerEvent
    }

    struct RejectedEvent: Codable {
        let ownedEvent: OwnedEvent
        let status: Int
        let code: String?
    }

    private struct State: Codable {
        var pending: [OwnedEvent] = []
        var rejected: [RejectedEvent] = []
    }

    private struct Flight {
        let id: UUID
        let userID: String
        let task: Task<Void, Error>
    }

    private let api: BackendContentAPI?
    private let fileURL: URL
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let sessionProvider: () -> AuthSession?
    private let retryDelay: UInt64
    private var flight: Flight?
    private var networkMonitor: NWPathMonitor?
    private var authenticationObserver: NSObjectProtocol?
    private let automaticallySynchronizesOnEnqueue: Bool

    var currentUserID: String? { sessionProvider()?.userID }

    init(
        api: BackendContentAPI?,
        fileURL: URL,
        automaticallySynchronizesOnEnqueue: Bool = true,
        sessionProvider: @escaping () -> AuthSession? = { StoredBackendAccessTokenProvider().currentSession() },
        retryDelay: UInt64 = BackendRetry.defaultBaseDelay
    ) {
        self.api = api
        self.fileURL = fileURL
        self.automaticallySynchronizesOnEnqueue = automaticallySynchronizesOnEnqueue
        self.sessionProvider = sessionProvider
        self.retryDelay = retryDelay
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    deinit {
        networkMonitor?.cancel()
        if let authenticationObserver { NotificationCenter.default.removeObserver(authenticationObserver) }
    }

    static func live(bundle: Bundle = .main) -> PersistentQuestionAnswerOutbox {
        let directory = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        let fileURL = directory.appendingPathComponent("Quizice", isDirectory: true)
            .appendingPathComponent("question-answer-outbox.json")
        let api = BackendConfiguration.load(bundle: bundle).map {
            HTTPBackendContentAPI(
                configuration: $0,
                metrics: AppMetricaAnalyticsTracker.shared,
                accessTokenProvider: StoredBackendAccessTokenProvider(),
                authenticationRecoverer: NotificationBackendAuthenticationRecoverer()
            )
        }
        let outbox = PersistentQuestionAnswerOutbox(api: api, fileURL: fileURL)
        if api != nil { outbox.startMonitoring() }
        return outbox
    }

    func enqueue(_ event: QuestionAnswerEvent) { enqueue(event, for: currentUserID) }

    func enqueue(_ event: QuestionAnswerEvent, for userID: String?) {
        do {
            try lock.withLock {
                var state = try loadLocked()
                guard !state.pending.contains(where: { $0.event.eventId == event.eventId }),
                      !state.rejected.contains(where: { $0.ownedEvent.event.eventId == event.eventId }) else { return }
                state.pending.append(OwnedEvent(userID: userID, event: event))
                try saveLocked(state)
            }
            if automaticallySynchronizesOnEnqueue { Task { await synchronize() } }
        } catch {
            AppLog.persistence.error("Question answer outbox persistence failed")
        }
    }

    func synchronize() async {
        guard let userID = currentUserID else { return }
        do { try await synchronizeBeforeFetchingQuestions(for: userID) }
        catch { AppLog.persistence.notice("Question answer synchronization deferred") }
    }

    /// Shares in-flight uploads with automatic synchronization. A failed upload must
    /// prevent a personalized fetch from racing ahead of unconfirmed progress.
    func synchronizeBeforeFetchingQuestions(for userID: String) async throws {
        while true {
            try Task.checkCancellation()
            guard currentUserID == userID else { throw QuestionAnswerSyncError.accountChanged }
            let active = lock.withLock { () -> Flight in
                if let flight { return flight }
                let created = Flight(id: UUID(), userID: userID, task: Task {
                    try await self.drain(for: userID)
                })
                flight = created
                return created
            }
            let result = await active.task.result
            lock.withLock { if flight?.id == active.id { flight = nil } }
            try Task.checkCancellation()
            guard currentUserID == userID else { throw QuestionAnswerSyncError.accountChanged }
            if active.userID != userID { continue }
            try result.get()
            // Include answers enqueued while a previous upload was completing.
            let hasPending = try lock.withLock { try loadLocked().pending.contains { $0.userID == userID } }
            if !hasPending { return }
        }
    }

    private func drain(for userID: String) async throws {
        guard let api else { throw BackendContentError.unauthenticated }
        while true {
            guard currentUserID == userID else { throw QuestionAnswerSyncError.accountChanged }
            let batch = try lock.withLock {
                Array(try loadLocked().pending.filter { $0.userID == userID }.prefix(100).map(\.event))
            }
            guard !batch.isEmpty else { return }
            try await upload(batch, for: userID, api: api)
        }
    }

    private func upload(_ batch: [QuestionAnswerEvent], for userID: String, api: BackendContentAPI) async throws {
        do {
            let response = try await BackendRetry.withExponentialBackoff(baseDelay: retryDelay, isRetryable: Self.isRetryable) {
                guard let session = self.sessionProvider(), session.userID == userID else {
                    throw QuestionAnswerSyncError.accountChanged
                }
                return try await api.submitQuestionAnswers(batch, session: session)
            }
            let processed = Set(response.processedEventIds)
            guard !processed.isEmpty, processed.isSubset(of: Set(batch.map(\.eventId))) else {
                throw QuestionAnswerSyncError.unacknowledgedEvents
            }
            try lock.withLock {
                var state = try loadLocked()
                state.pending.removeAll { $0.userID == userID && processed.contains($0.event.eventId) }
                try saveLocked(state)
            }
        } catch BackendContentError.httpStatus(let status, let envelope) where status == 409 || status == 422 {
            // The server rejects the whole batch. Split it to isolate invalid events;
            // valid neighbours are retried with their original IDs and payloads.
            guard currentUserID == userID else { throw QuestionAnswerSyncError.accountChanged }
            if batch.count > 1 {
                let middle = batch.count / 2
                try await upload(Array(batch.prefix(middle)), for: userID, api: api)
                try await upload(Array(batch.dropFirst(middle)), for: userID, api: api)
            } else if let event = batch.first {
                try lock.withLock {
                    var state = try loadLocked()
                    if let index = state.pending.firstIndex(where: { $0.userID == userID && $0.event.eventId == event.eventId }) {
                        let owned = state.pending.remove(at: index)
                        state.rejected.append(RejectedEvent(ownedEvent: owned, status: status, code: envelope?.code))
                        try saveLocked(state)
                    }
                }
                AppLog.persistence.error("Question answer quarantined: status=\(status) code=\(envelope?.code ?? "unknown", privacy: .public)")
            }
        }
    }

    private static func isRetryable(_ error: Error) -> Bool {
        switch error {
        case BackendContentError.transport(let code): return code != .cancelled
        case BackendContentError.timedOut: return true
        case BackendContentError.httpStatus(let status, _): return status == 429 || (500...599).contains(status)
        default: return false
        }
    }

    private func loadLocked() throws -> State {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return State() }
        let data = try Data(contentsOf: fileURL)
        if let state = try? decoder.decode(State.self, from: data) { return state }
        // The old format has no owner. Preserve it without assigning another user's
        // history to whoever happens to sign in after upgrading.
        let legacy = try decoder.decode([QuestionAnswerEvent].self, from: data)
        return State(pending: legacy.map { OwnedEvent(userID: nil, event: $0) })
    }

    func pendingEvents() -> [QuestionAnswerEvent] {
        lock.withLock { (try? loadLocked().pending.map(\.event)) ?? [] }
    }

    func rejectedEvents() -> [RejectedEvent] {
        lock.withLock { (try? loadLocked().rejected) ?? [] }
    }

    private func saveLocked(_ state: State) throws {
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(state).write(to: fileURL, options: .atomic)
    }

    private func startMonitoring() {
        authenticationObserver = NotificationCenter.default.addObserver(
            forName: .backendAuthenticationEstablished, object: nil, queue: nil
        ) { [weak self] _ in Task { await self?.synchronize() } }
        let monitor = NWPathMonitor()
        networkMonitor = monitor
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { await self?.synchronize() }
        }
        monitor.start(queue: DispatchQueue(label: "ru.avtabenskiy.Quizice.answer-outbox-network"))
    }
}
