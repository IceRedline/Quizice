import Foundation

enum BackendOperation: String, Equatable {
    case authentication
    case statisticsSync = "statistics_sync"
    case themes
    case themePreferences = "theme_preferences"
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
    case unauthenticated
    case transport(URLError.Code)
    case httpStatus(Int, BackendErrorEnvelope?)
    case encoding
    case decoding
    case contractViolation
    case timedOut
}

struct BackendThemeDTO: Decodable, Equatable {
    let id: String
    let name: String
    let description: String
    let sfSymbol: String
    let emoji: String
    let colorHex: String
    let isFavorite: Bool
}

struct BackendThemeCatalogResponse: Decodable, Equatable {
    let locale: String
    let themes: [BackendThemeDTO]
}

struct BackendThemePreferencesUpdate: Encodable, Equatable {
    let locale: String
    let favoriteThemeIds: [String]
}

struct BackendThemePreferencesResponse: Decodable, Equatable {
    let locale: String
    let favoriteThemeIds: [String]
}

protocol BackendAccessTokenProviding {
    func validAccessToken() -> String?
}

struct NoopBackendAccessTokenProvider: BackendAccessTokenProviding {
    func validAccessToken() -> String? { nil }
}

struct StoredBackendAccessTokenProvider: BackendAccessTokenProviding {
    private let sessionStore: SessionStoring
    private let now: () -> Date

    init(
        sessionStore: SessionStoring = KeychainSessionStore(),
        now: @escaping () -> Date = Date.init
    ) {
        self.sessionStore = sessionStore
        self.now = now
    }

    func validAccessToken() -> String? {
        do {
            guard
                let session = try sessionStore.load(),
                session.expiresAt > now()
            else { return nil }
            let token = session.accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        } catch {
            return nil
        }
    }
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
