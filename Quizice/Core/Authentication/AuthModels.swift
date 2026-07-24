import Foundation
import UIKit

extension Notification.Name {
    static let backendAuthenticationInvalidated = Notification.Name(
        "ru.avtabenskiy.Quizice.backendAuthenticationInvalidated"
    )
    static let backendAuthenticationEstablished = Notification.Name(
        "ru.avtabenskiy.Quizice.backendAuthenticationEstablished"
    )
}

enum AuthSessionState: Equatable {
    case initializing
    case guest
    case authenticating
    case authenticated(userID: String, teamPlayerID: String)
}

protocol AIQuizAccessProviding: AnyObject {
    var isAIQuizAvailable: Bool { get }
}

protocol AIQuizAccessUpdating: AIQuizAccessProviding {
    func update(isAuthenticated: Bool)
}

final class AIQuizAccessStore: AIQuizAccessUpdating, @unchecked Sendable {
    static let shared = AIQuizAccessStore()

    private let lock = NSLock()
    private var isAuthenticated = false

    var isAIQuizAvailable: Bool {
        lock.withLock { isAuthenticated }
    }

    func update(isAuthenticated: Bool) {
        lock.withLock {
            self.isAuthenticated = isAuthenticated
        }
    }
}

struct AuthSession: Codable, Equatable {
    let userID: String
    let accessToken: String
    let expiresAt: Date
    let teamPlayerID: String

    func isValid(for teamPlayerID: String, now: Date) -> Bool {
        self.teamPlayerID == teamPlayerID && expiresAt > now
    }
}

struct GameCenterIdentity: Codable, Equatable {
    let teamPlayerId: String
    let bundleId: String
    let publicKeyUrl: String
    let signature: String
    let salt: String
    let timestamp: String
}

struct BackendErrorEnvelope: Codable, Equatable {
    let code: String
    let message: String
    let requestId: String?

    init(code: String, message: String, requestId: String? = nil) {
        self.code = code
        self.message = message
        self.requestId = requestId
    }
}

enum BackendAPIError: Error, Equatable {
    case configurationMissing
    case invalidResponse
    case transport(URLError.Code)
    case unauthorized(BackendErrorEnvelope?)
    case httpStatus(Int, BackendErrorEnvelope?)
    case encoding
    case decoding
    case contractViolation
}

protocol AuthAPI {
    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession
    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse
}

protocol SessionStoring {
    func load() throws -> AuthSession?
    func save(_ session: AuthSession) throws
    func clear() throws
}

enum GameCenterPlayerState: Equatable {
    case authenticated(teamPlayerID: String)
    case unavailable
}

@MainActor
protocol GameCenterAuthenticating: AnyObject {
    func start(
        present: @escaping (UIViewController) -> Void,
        stateChanged: @escaping (GameCenterPlayerState) -> Void
    )
    func fetchIdentity(bundleIdentifier: String) async throws -> GameCenterIdentity
}
