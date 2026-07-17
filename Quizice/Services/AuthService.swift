//
//  AuthService.swift
//  Quizice
//

import Foundation
import GameKit
import Security
import UIKit

enum AuthSessionState: Equatable {
    case initializing
    case guest
    case authenticating
    case authenticated(userID: String, teamPlayerID: String)
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
}

enum BackendAPIError: Error, Equatable {
    case configurationMissing
    case invalidResponse
    case transport(URLError.Code)
    case unauthorized(BackendErrorEnvelope?)
    case httpStatus(Int, BackendErrorEnvelope?)
    case decoding
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

struct BackendConfiguration: Equatable {
    static let infoPlistKey = "BackendBaseURL"

    let baseURL: URL

    static func load(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) -> BackendConfiguration? {
#if DEBUG
        if userDefaults.bool(forKey: DebugBackendSettings.useLocalhostKey) {
            return BackendConfiguration(baseURL: DebugBackendSettings.localhostBaseURL)
        }
#endif
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String
        else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, value.contains("$(") == false, let url = URL(string: value) else {
            return nil
        }
        return BackendConfiguration(baseURL: url)
    }
}

#if DEBUG
enum DebugBackendSettings {
    static let useLocalhostKey = "quizice.debug.backend.use-localhost"
    static let localhostBaseURL = URL(string: "http://localhost:8000/api")!
}
#endif

final class HTTPAuthAPI: AuthAPI {
    // TODO(BACKEND_CONTRACT): replace provisional routes and DTOs when backend contract is finalized.
    private enum Endpoint {
        static let gameCenterAuth = "v1/auth/game-center"
        static let statisticsSync = "v1/me/statistics/sync"
    }

    private struct AuthResponse: Decodable {
        let userId: String
        let accessToken: String
        let expiresAt: Date
    }

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(configuration: BackendConfiguration, session: URLSession = .shared) {
        baseURL = configuration.baseURL
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        let response: AuthResponse = try await post(
            path: Endpoint.gameCenterAuth,
            body: identity,
            accessToken: nil
        )
        return AuthSession(
            userID: response.userId,
            accessToken: response.accessToken,
            expiresAt: response.expiresAt,
            teamPlayerID: identity.teamPlayerId
        )
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        try await post(
            path: Endpoint.statisticsSync,
            body: request,
            accessToken: accessToken
        )
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        accessToken: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw BackendAPIError.decoding
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw BackendAPIError.transport(error.code)
        } catch {
            throw BackendAPIError.transport(.unknown)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data)
            if httpResponse.statusCode == 401 {
                throw BackendAPIError.unauthorized(envelope)
            }
            throw BackendAPIError.httpStatus(httpResponse.statusCode, envelope)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw BackendAPIError.decoding
        }
    }
}

struct UnavailableAuthAPI: AuthAPI {
    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        throw BackendAPIError.configurationMissing
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        throw BackendAPIError.configurationMissing
    }
}

final class KeychainSessionStore: SessionStoring {
    private let service: String
    private let account = "game-center-session"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(service: String = "ru.avtabenskiy.Quizice.auth") {
        self.service = service
    }

    func load() throws -> AuthSession? {
        var query = baseQuery
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainSessionStoreError.status(status)
        }
        do {
            return try decoder.decode(AuthSession.self, from: data)
        } catch {
            try? clear()
            throw KeychainSessionStoreError.invalidData
        }
    }

    func save(_ session: AuthSession) throws {
        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            throw KeychainSessionStoreError.invalidData
        }

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(baseQuery.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainSessionStoreError.status(status)
        }
    }

    func clear() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSessionStoreError.status(status)
        }
    }

    private var baseQuery: [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

enum KeychainSessionStoreError: Error, Equatable {
    case status(OSStatus)
    case invalidData
}

@MainActor
final class GameCenterClient: GameCenterAuthenticating {
    private let player: GKLocalPlayer
    private let notificationCenter: NotificationCenter
    private var authenticationObserver: NSObjectProtocol?
    private var stateChanged: ((GameCenterPlayerState) -> Void)?

    init(
        player: GKLocalPlayer = .local,
        notificationCenter: NotificationCenter = .default
    ) {
        self.player = player
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let authenticationObserver {
            notificationCenter.removeObserver(authenticationObserver)
        }
    }

    func start(
        present: @escaping (UIViewController) -> Void,
        stateChanged: @escaping (GameCenterPlayerState) -> Void
    ) {
        self.stateChanged = stateChanged
        if authenticationObserver == nil {
            authenticationObserver = notificationCenter.addObserver(
                forName: NSNotification.Name.GKPlayerAuthenticationDidChangeNotificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.publishCurrentState()
                }
            }
        }

        player.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let viewController {
                    present(viewController)
                    return
                }
                self.publishCurrentState()
            }
        }
    }

    func fetchIdentity(bundleIdentifier: String) async throws -> GameCenterIdentity {
        guard player.isAuthenticated, player.teamPlayerID.isEmpty == false else {
            throw GameCenterClientError.notAuthenticated
        }
        let (publicKeyURL, signature, salt, timestamp) = try await player.fetchItemsForIdentityVerificationSignature()
        return GameCenterIdentity(
            teamPlayerId: player.teamPlayerID,
            bundleId: bundleIdentifier,
            publicKeyUrl: publicKeyURL.absoluteString,
            signature: signature.base64EncodedString(),
            salt: salt.base64EncodedString(),
            timestamp: String(timestamp)
        )
    }

    private func publishCurrentState() {
        if player.isAuthenticated, player.teamPlayerID.isEmpty == false {
            stateChanged?(.authenticated(teamPlayerID: player.teamPlayerID))
        } else {
            stateChanged?(.unavailable)
        }
    }
}

enum GameCenterClientError: Error, Equatable {
    case notAuthenticated
}

@MainActor
final class GameCenterAuthenticationService {
    private(set) var state: AuthSessionState = .initializing

    private let gameCenter: GameCenterAuthenticating
    private let api: AuthAPI
    private let sessionStore: SessionStoring
    private let statisticsStore: StatisticsStore
    private let bundleIdentifier: String
    private let now: () -> Date
    private let notificationCenter: NotificationCenter

    private var authenticationTask: Task<Void, Never>?
    private var synchronizationTask: Task<Void, Never>?
    private var pendingSyncObserver: NSObjectProtocol?
    private var currentTeamPlayerID: String?
    private var started = false

    init(
        gameCenter: GameCenterAuthenticating,
        api: AuthAPI,
        sessionStore: SessionStoring,
        statisticsStore: StatisticsStore = StatisticsStore(),
        bundleIdentifier: String,
        now: @escaping () -> Date = Date.init,
        notificationCenter: NotificationCenter = .default
    ) {
        self.gameCenter = gameCenter
        self.api = api
        self.sessionStore = sessionStore
        self.statisticsStore = statisticsStore
        self.bundleIdentifier = bundleIdentifier
        self.now = now
        self.notificationCenter = notificationCenter
        pendingSyncObserver = notificationCenter.addObserver(
            forName: .statisticsPendingSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.synchronizeStatistics()
            }
        }
    }

    deinit {
        if let pendingSyncObserver {
            notificationCenter.removeObserver(pendingSyncObserver)
        }
    }

    static func live(bundle: Bundle = .main) -> GameCenterAuthenticationService {
        let api: AuthAPI
        if let configuration = BackendConfiguration.load(bundle: bundle) {
            api = HTTPAuthAPI(configuration: configuration)
        } else {
            api = UnavailableAuthAPI()
        }
        return GameCenterAuthenticationService(
            gameCenter: GameCenterClient(),
            api: api,
            sessionStore: KeychainSessionStore(),
            bundleIdentifier: bundle.bundleIdentifier ?? "ru.avtabenskiy.Quizice"
        )
    }

    func start(present: @escaping (UIViewController) -> Void) {
        guard started == false else { return }
        started = true
        state = .initializing
        gameCenter.start(present: present) { [weak self] playerState in
            self?.handle(playerState)
        }
    }

    func retrySynchronization() {
        synchronizeStatistics()
    }

    private func handle(_ playerState: GameCenterPlayerState) {
        switch playerState {
        case let .authenticated(teamPlayerID):
            guard teamPlayerID.isEmpty == false else {
                enterGuestMode()
                return
            }
            if currentTeamPlayerID == teamPlayerID,
               case .authenticated = state {
                synchronizeStatistics()
                return
            }
            authenticationTask?.cancel()
            currentTeamPlayerID = teamPlayerID
            state = .authenticating
            authenticationTask = Task { [weak self] in
                await self?.restoreOrExchangeSession(for: teamPlayerID)
            }
        case .unavailable:
            enterGuestMode()
        }
    }

    private func restoreOrExchangeSession(for teamPlayerID: String) async {
        do {
            if let cachedSession = try sessionStore.load(), cachedSession.isValid(for: teamPlayerID, now: now()) {
                completeAuthentication(with: cachedSession)
                return
            }
            try? sessionStore.clear()
            let session = try await exchangeSession(for: teamPlayerID)
            try Task.checkCancellation()
            completeAuthentication(with: session)
        } catch is CancellationError {
            return
        } catch {
            guard currentTeamPlayerID == teamPlayerID else { return }
            enterGuestMode()
        }
    }

    private func exchangeSession(for teamPlayerID: String) async throws -> AuthSession {
        let identity = try await gameCenter.fetchIdentity(bundleIdentifier: bundleIdentifier)
        guard identity.teamPlayerId == teamPlayerID else {
            throw GameCenterAuthenticationError.playerChanged
        }
        let session = try await api.authenticate(identity: identity)
        guard session.teamPlayerID == teamPlayerID else {
            throw GameCenterAuthenticationError.playerChanged
        }
        try sessionStore.save(session)
        return session
    }

    private func completeAuthentication(with session: AuthSession) {
        guard currentTeamPlayerID == session.teamPlayerID else { return }
        statisticsStore.activateAuthenticatedUser(session.userID)
        state = .authenticated(userID: session.userID, teamPlayerID: session.teamPlayerID)
        synchronizeStatistics(using: session)
    }

    private func enterGuestMode() {
        authenticationTask?.cancel()
        synchronizationTask?.cancel()
        currentTeamPlayerID = nil
        try? sessionStore.clear()
        statisticsStore.activateGuest()
        state = .guest
    }

    private func synchronizeStatistics(using knownSession: AuthSession? = nil) {
        guard synchronizationTask == nil else { return }
        let storedSession = knownSession ?? (try? sessionStore.load()) ?? nil
        guard
            let session = storedSession,
            case let .authenticated(userID, teamPlayerID) = state,
            userID == session.userID,
            teamPlayerID == session.teamPlayerID
        else {
            return
        }

        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            let didSync = await self.performStatisticsSync(session: session, mayRefreshToken: true)
            self.synchronizationTask = nil
            if didSync, self.statisticsStore.hasPendingSync(for: session.userID) {
                self.synchronizeStatistics()
            }
        }
    }

    private func performStatisticsSync(session: AuthSession, mayRefreshToken: Bool) async -> Bool {
        let request = statisticsStore.makeSyncRequest(for: session.userID)
        do {
            let response = try await api.syncStatistics(
                request: request,
                accessToken: session.accessToken
            )
            statisticsStore.applySyncResponse(response, for: session.userID)
            return true
        } catch BackendAPIError.unauthorized where mayRefreshToken {
            do {
                let refreshed = try await exchangeSession(for: session.teamPlayerID)
                guard currentTeamPlayerID == refreshed.teamPlayerID else { return false }
                state = .authenticated(userID: refreshed.userID, teamPlayerID: refreshed.teamPlayerID)
                return await performStatisticsSync(session: refreshed, mayRefreshToken: false)
            } catch {
                enterGuestMode()
                return false
            }
        } catch BackendAPIError.unauthorized {
            enterGuestMode()
            return false
        } catch {
            // Keep the local outbox intact. Foregrounding or the next completed quiz retries it.
            return false
        }
    }
}

enum GameCenterAuthenticationError: Error, Equatable {
    case playerChanged
}
