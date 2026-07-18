import XCTest
@testable import Quizice

@MainActor
final class GameCenterAuthenticationServiceTests: XCTestCase {
    func testSuccessfulAuthenticationMergesGuestAttemptAndSynchronizesIt() async {
        let harness = makeHarness()
        harness.statistics.recordAttempt(correctAnswers: 4, totalQuestions: 5)
        harness.api.syncSummary = StatisticsSummary(
            playedQuizzes: 1,
            correctAnswers: 4,
            totalQuestions: 5,
            bestCorrectAnswers: 4,
            bestTotalQuestions: 5
        )

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil { harness.api.syncRequests.count == 1 }

        XCTAssertEqual(
            harness.service.state,
            .authenticated(userID: "user-1", teamPlayerID: "team-1")
        )
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 1)
        XCTAssertEqual(harness.api.syncRequests.first?.attempts.count, 1)
        XCTAssertEqual(harness.statistics.loadSummary(), harness.api.syncSummary)
    }

    func testUnavailableGameCenterEntersGuestMode() async {
        let harness = makeHarness()

        harness.service.start { _ in }
        harness.gameCenter.emit(.unavailable)

        await waitUntil { harness.service.state == .guest }
        XCTAssertTrue(harness.api.authenticatedIdentities.isEmpty)
    }

    func testValidCachedSessionIsUsedOnlyForMatchingPlayer() async {
        let cached = AuthSession(
            userID: "cached-user",
            accessToken: "cached-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let harness = makeHarness(storedSession: cached)

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil {
            harness.service.state == .authenticated(userID: "cached-user", teamPlayerID: "team-1")
        }
        XCTAssertTrue(harness.api.authenticatedIdentities.isEmpty)
    }

    func testCachedSessionForDifferentPlayerIsReplaced() async {
        let cached = AuthSession(
            userID: "old-user",
            accessToken: "old-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "old-team"
        )
        let harness = makeHarness(storedSession: cached)

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil { harness.api.authenticatedIdentities.count == 1 }
        XCTAssertEqual(harness.sessionStore.session?.teamPlayerID, "team-1")
        XCTAssertEqual(harness.sessionStore.session?.userID, "user-1")
    }

    func testUnauthorizedStatisticsRequestRefreshesAndRetriesOnlyOnce() async {
        let cached = AuthSession(
            userID: "user-1",
            accessToken: "expired-server-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let harness = makeHarness(storedSession: cached)
        harness.api.syncErrors = [.unauthorized(nil)]

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil { harness.api.syncRequests.count == 2 }
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 1)
        XCTAssertEqual(harness.api.syncAccessTokens, ["expired-server-token", "access-token"])
    }

    func testSecondUnauthorizedResponseStopsRetryAndEntersGuestMode() async {
        let cached = AuthSession(
            userID: "user-1",
            accessToken: "expired-server-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let harness = makeHarness(storedSession: cached)
        harness.api.syncErrors = [.unauthorized(nil), .unauthorized(nil)]

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil { harness.service.state == .guest }
        XCTAssertEqual(harness.api.syncRequests.count, 2)
        XCTAssertNil(harness.sessionStore.session)
    }

    func testRepeatedAuthenticatedCallbackDoesNotExchangeAgain() async {
        let harness = makeHarness()
        harness.service.start { _ in }

        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))
        await waitUntil { harness.api.authenticatedIdentities.count == 1 }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(harness.api.authenticatedIdentities.count, 1)
    }

    private func makeHarness(storedSession: AuthSession? = nil) -> (
        service: GameCenterAuthenticationService,
        gameCenter: FakeGameCenterClient,
        api: FakeAuthAPI,
        sessionStore: MemorySessionStore,
        statistics: StatisticsStore
    ) {
        let suiteName = "GameCenterAuthenticationServiceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let notificationCenter = NotificationCenter()
        let statistics = StatisticsStore(
            userDefaults: defaults,
            key: "attempts",
            notificationCenter: notificationCenter
        )
        let gameCenter = FakeGameCenterClient()
        let api = FakeAuthAPI()
        let sessionStore = MemorySessionStore(session: storedSession)
        let service = GameCenterAuthenticationService(
            gameCenter: gameCenter,
            api: api,
            sessionStore: sessionStore,
            statisticsStore: statistics,
            bundleIdentifier: "ru.avtabenskiy.Quizice",
            now: { Date(timeIntervalSince1970: 1_000) },
            notificationCenter: notificationCenter
        )
        return (service, gameCenter, api, sessionStore, statistics)
    }

    private func waitUntil(
        timeout: TimeInterval = 1,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ predicate: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while predicate() == false, Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(predicate(), "Condition was not met before timeout", file: file, line: line)
    }
}

final class HTTPAuthAPITests: XCTestCase {
    override func tearDown() {
        AuthURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testProvisionalContractEncodesIdentityAndBearerHeader() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let api = HTTPAuthAPI(
            configuration: BackendConfiguration(baseURL: URL(string: "https://backend.example")!),
            session: session
        )
        var requestNumber = 0
        AuthURLProtocol.requestHandler = { request in
            requestNumber += 1
            if requestNumber == 1 {
                XCTAssertEqual(request.url?.path, "/v1/auth/game-center")
                let body = try XCTUnwrap(Self.bodyData(from: request))
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(json["teamPlayerId"], "team-1")
                XCTAssertEqual(json["signature"], Data("signature".utf8).base64EncodedString())
                XCTAssertEqual(json["timestamp"], "123456")
                let data = Data(
                    #"{"userId":"user-1","accessToken":"token","expiresAt":"2999-01-01T00:00:00Z"}"#.utf8
                )
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }

            XCTAssertEqual(request.url?.path, "/v1/me/statistics/sync")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            let data = Data(
                #"{"summary":{"playedQuizzes":0,"correctAnswers":0,"totalQuestions":0,"bestCorrectAnswers":0,"bestTotalQuestions":0},"acceptedAttemptIds":[],"legacySummaryAccepted":true}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let identity = GameCenterIdentity(
            teamPlayerId: "team-1",
            bundleId: "ru.avtabenskiy.Quizice",
            publicKeyUrl: "https://apple.example/key",
            signature: Data("signature".utf8).base64EncodedString(),
            salt: Data("salt".utf8).base64EncodedString(),
            timestamp: "123456"
        )
        let authSession = try await api.authenticate(identity: identity)
        XCTAssertEqual(authSession.teamPlayerID, "team-1")

        let response = try await api.syncStatistics(
            request: StatisticsStore.SyncRequest(
                migrationId: "migration",
                legacySummary: nil,
                attempts: []
            ),
            accessToken: authSession.accessToken
        )
        XCTAssertEqual(response.summary, .empty)
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else { return nil }
            if count == 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

#if DEBUG
final class BackendConfigurationTests: XCTestCase {
    func testLocalhostOverrideWinsWhenEnabled() throws {
        let suiteName = "BackendConfigurationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(true, forKey: DebugBackendSettings.useLocalhostKey)

        let configuration = try XCTUnwrap(
            BackendConfiguration.load(bundle: .main, userDefaults: defaults)
        )

        XCTAssertEqual(configuration.baseURL, URL(string: "http://localhost:8000/api"))
    }
}
#endif

final class KeychainSessionStoreTests: XCTestCase {
    func testRoundTripAndClear() throws {
        let client = InMemoryKeychainClient()
        let store = KeychainSessionStore(
            service: "QuiziceTests.Auth.\(UUID().uuidString)",
            client: client
        )
        let session = AuthSession(
            userID: "user-1",
            accessToken: "secret",
            expiresAt: Date(timeIntervalSince1970: 2_000),
            teamPlayerID: "team-1"
        )
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
        try store.clear()
        XCTAssertNil(try store.load())
    }
}

private final class InMemoryKeychainClient: KeychainClient {
    private var data: Data?

    func loadData(service: String, account: String) throws -> Data? {
        data
    }

    func saveData(_ data: Data, service: String, account: String) throws {
        self.data = data
    }

    func deleteData(service: String, account: String) throws {
        data = nil
    }
}

@MainActor
private final class FakeGameCenterClient: GameCenterAuthenticating {
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

private final class FakeAuthAPI: AuthAPI {
    var authenticatedIdentities: [GameCenterIdentity] = []
    var syncRequests: [StatisticsStore.SyncRequest] = []
    var syncAccessTokens: [String] = []
    var syncErrors: [BackendAPIError] = []
    var syncSummary: StatisticsSummary = .empty

    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        authenticatedIdentities.append(identity)
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

private final class MemorySessionStore: SessionStoring {
    var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() throws { session = nil }
}

private final class AuthURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
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

    override func stopLoading() {}
}
