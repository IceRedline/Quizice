import Foundation
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class FakeGameCenterClient: GameCenterAuthenticating {
    private var stateChanged: ((GameCenterPlayerState) -> Void)?
    var identity = GameCenterIdentity(
        teamPlayerId: "team-1",
        bundleId: "ru.avtabenskiy.Quizice",
        publicKeyUrl: "https://apple.example/key",
        signature: "signature",
        salt: "salt",
        timestamp: "123"
    )

    func start(
        present: @escaping (UIViewController) -> Void,
        stateChanged: @escaping (GameCenterPlayerState) -> Void
    ) {
        self.stateChanged = stateChanged
    }

    func fetchIdentity(bundleIdentifier: String) async throws -> GameCenterIdentity {
        identity
    }

    func emit(_ state: GameCenterPlayerState) {
        stateChanged?(state)
    }
}

final class FakeAuthAPI: AuthAPI {
    var authenticatedIdentities: [GameCenterIdentity] = []
    var authenticationErrors: [BackendAPIError] = []
    var syncRequests: [StatisticsStore.SyncRequest] = []
    var syncAccessTokens: [String] = []
    var syncErrors: [BackendAPIError] = []
    var syncSummary: StatisticsSummary = .empty

    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        authenticatedIdentities.append(identity)
        if authenticationErrors.isEmpty == false {
            throw authenticationErrors.removeFirst()
        }
        return AuthSession(
            userID: "user-1",
            accessToken: "access-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: identity.teamPlayerId
        )
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        syncRequests.append(request)
        syncAccessTokens.append(accessToken)
        if syncErrors.isEmpty == false {
            throw syncErrors.removeFirst()
        }
        return StatisticsStore.SyncResponse(
            summary: syncSummary,
            acceptedAttemptIds: request.attempts.map(\.id),
            legacySummaryAccepted: true
        )
    }
}

final class MemorySessionStore: SessionStoring {
    var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() throws { session = nil }
}

final class AuthURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (URLResponse, Data))?
    static var hangingRequestHandler: ((URLRequest) -> Void)?
    static var stopHandler: (() -> Void)?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        if let hangingRequestHandler = Self.hangingRequestHandler {
            hangingRequestHandler(request)
            return
        }
        do {
            let handler = try XCTUnwrap(Self.requestHandler)
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        Self.stopHandler?()
    }
}

final class AuthBackendMetricSpy: BackendRequestMetricRecording {
    private(set) var values: [BackendRequestMetric] = []

    func record(_ metric: BackendRequestMetric) {
        values.append(metric)
    }
}
