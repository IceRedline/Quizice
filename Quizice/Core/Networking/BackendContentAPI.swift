import Foundation

enum BackendOperation: String, Equatable {
    case authentication
    case statisticsSync = "statistics_sync"
    case themes
    case questions
    case aiGeneration = "ai_generation"
}

enum BackendRequestResult: String, Equatable {
    case success
    case cancelled
    case transportError = "transport_error"
    case httpError = "http_error"
    case decodingError = "decoding_error"
    case contractError = "contract_error"
}

struct BackendRequestMetric: Equatable {
    let operation: BackendOperation
    let result: BackendRequestResult
    let durationMilliseconds: Int
    let statusCode: Int?
    let responseBytes: Int
}

protocol BackendRequestMetricRecording {
    func record(_ metric: BackendRequestMetric)
}

struct NoopBackendRequestMetricRecorder: BackendRequestMetricRecording {
    func record(_ metric: BackendRequestMetric) {}
}

enum BackendContentError: Error, Equatable {
    case invalidRequest
    case invalidResponse
    case transport(URLError.Code)
    case httpStatus(Int, BackendErrorEnvelope?)
    case decoding
    case contractViolation
    case timedOut
}

struct BackendThemeDTO: Decodable, Equatable {
    let id: String
    let name: String
    let description: String
    let sfSymbol: String
}

struct BackendThemeCatalogResponse: Decodable, Equatable {
    let locale: String
    let themes: [BackendThemeDTO]
}

struct BackendQuestionDTO: Decodable, Equatable {
    let question: String
    let answers: [String]
    let correctAnswer: String
    let explanation: String?

    func makeModel() -> QuizQuestion {
        QuizQuestion(
            question: question,
            answers: answers,
            correctAnswer: correctAnswer,
            explanation: explanation
        )
    }
}

struct BackendQuestionBatchResponse: Decodable, Equatable {
    let locale: String
    let seed: String
    let questions: [BackendQuestionDTO]
}

protocol BackendContentAPI {
    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse
    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse
}

final class HTTPBackendContentAPI: BackendContentAPI {
    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let requestTimeout: TimeInterval
    private let metrics: BackendRequestMetricRecording
    private let clock = ContinuousClock()

    init(
        configuration: BackendConfiguration,
        session: URLSession = .shared,
        requestTimeout: TimeInterval = 15,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder()
    ) {
        baseURL = configuration.baseURL
        self.session = session
        self.requestTimeout = requestTimeout
        self.metrics = metrics
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
            validate: { Self.isValid($0, requestedLocale: locale) }
        )
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
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

        let url = try makeURL(
            pathComponents: ["v1", "themes", normalizedThemeID, "questions"],
            queryItems: [
                URLQueryItem(name: "count", value: String(count)),
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "seed", value: normalizedSeed)
            ]
        )
        return try await get(
            url: url,
            operation: .questions,
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
        let normalizedSeed = seed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            UUID(uuidString: normalizedSeed)?.uuidString.lowercased() == normalizedSeed,
            QuizQuestionCountPolicy.supportedCounts.contains(count),
            Self.isSupported(locale: locale)
        else {
            throw BackendContentError.invalidRequest
        }

        let url = try makeURL(
            pathComponents: ["v1", "questions", selectionMode.rawValue],
            queryItems: [
                URLQueryItem(name: "count", value: String(count)),
                URLQueryItem(name: "locale", value: locale),
                URLQueryItem(name: "seed", value: normalizedSeed)
            ]
        )
        return try await get(
            url: url,
            operation: .questions,
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
        validate: (Response) -> Bool
    ) async throws -> Response {
        var request = URLRequest(url: url, timeoutInterval: requestTimeout)
#if DEBUG
        request.cachePolicy = .reloadIgnoringLocalCacheData
#endif
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

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
            guard (200..<300).contains(httpResponse.statusCode) else {
                let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data)
                record(
                    operation: operation,
                    result: .httpError,
                    startedAt: startedAt,
                    statusCode: httpResponse.statusCode,
                    responseBytes: data.count
                )
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
        components.queryItems = queryItems
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
            return !id.isEmpty
                && !name.isEmpty
                && !description.isEmpty
                && !sfSymbol.isEmpty
                && identifiers.insert(id).inserted
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
            response.questions.count == requestedCount
        else { return false }

        var prompts = Set<String>()
        return response.questions.allSatisfy { question in
            let prompt = question.question.trimmingCharacters(in: .whitespacesAndNewlines)
            let answers = question.answers.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let correctAnswer = question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
            return !prompt.isEmpty
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

func withBackendTimeout<Value>(
    nanoseconds: UInt64,
    operation: @escaping () async throws -> Value
) async throws -> Value {
    try await withThrowingTaskGroup(of: Value.self) { group in
        group.addTask {
            try await operation()
        }
        group.addTask {
            try await Task.sleep(nanoseconds: nanoseconds)
            throw BackendContentError.timedOut
        }
        guard let result = try await group.next() else {
            throw BackendContentError.timedOut
        }
        group.cancelAll()
        return result
    }
}
