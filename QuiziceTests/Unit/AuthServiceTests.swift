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
        XCTAssertTrue(harness.aiAccess.isAIQuizAvailable)
    }

    func testUnavailableGameCenterEntersGuestMode() async {
        let harness = makeHarness()

        harness.service.start { _ in }
        harness.gameCenter.emit(.unavailable)

        await waitUntil { harness.service.state == .guest }
        XCTAssertTrue(harness.api.authenticatedIdentities.isEmpty)
        XCTAssertFalse(harness.aiAccess.isAIQuizAvailable)
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
        XCTAssertFalse(harness.aiAccess.isAIQuizAvailable)
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

    func testBackendAuthenticationInvalidationCoalescesAndRefreshesSession() async {
        let harness = makeHarness()
        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))
        await waitUntil {
            harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }

        harness.sessionStore.session = nil
        harness.aiAccess.update(isAuthenticated: false)
        harness.notificationCenter.post(name: .backendAuthenticationInvalidated, object: nil)
        harness.notificationCenter.post(name: .backendAuthenticationInvalidated, object: nil)

        await waitUntil {
            harness.api.authenticatedIdentities.count == 2 &&
                harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 2)
        XCTAssertTrue(harness.aiAccess.isAIQuizAvailable)
        XCTAssertEqual(harness.sessionStore.session?.accessToken, "access-token")
    }

    func testBackendAuthenticationRefreshFailureEntersGuestMode() async {
        let harness = makeHarness()
        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))
        await waitUntil {
            harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }

        harness.api.authenticationErrors = [.transport(.notConnectedToInternet)]
        harness.sessionStore.session = nil
        harness.aiAccess.update(isAuthenticated: false)
        harness.notificationCenter.post(name: .backendAuthenticationInvalidated, object: nil)

        await waitUntil { harness.service.state == .guest }
        XCTAssertFalse(harness.aiAccess.isAIQuizAvailable)
        XCTAssertNil(harness.sessionStore.session)
    }

    func testTransientRefreshFailureRetriesOnceOnForegroundAndRestoresAuthenticatedAccess() async {
        let harness = makeHarness()
        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))
        await waitUntil {
            harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }

        harness.api.authenticationErrors = [.transport(.notConnectedToInternet)]
        harness.notificationCenter.post(name: .backendAuthenticationInvalidated, object: nil)

        await waitUntil { harness.service.state == .guest }
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 2)
        XCTAssertFalse(harness.aiAccess.isAIQuizAvailable)
        XCTAssertNil(harness.sessionStore.session)

        try? await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 2)

        harness.service.retrySynchronization()
        harness.service.retrySynchronization()

        await waitUntil {
            harness.api.authenticatedIdentities.count == 3 &&
                harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 3)
        XCTAssertTrue(harness.aiAccess.isAIQuizAvailable)
        XCTAssertEqual(harness.sessionStore.session?.teamPlayerID, "team-1")
    }

    func testSynchronizationDrainsOneHundredAndOneAttemptsInTwoBatches() async {
        let harness = makeHarness()
        for index in 0..<101 {
            harness.statistics.recordAttempt(
                correctAnswers: index % 5,
                totalQuestions: 5
            )
        }

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil(timeout: 2) {
            harness.api.syncRequests.count == 2 &&
                harness.statistics.hasPendingSync(for: "user-1") == false
        }

        XCTAssertEqual(harness.api.syncRequests.map(\.attempts.count), [100, 1])
        XCTAssertEqual(
            Set(harness.api.syncRequests.flatMap { $0.attempts.map(\.id) }).count,
            101
        )
    }

    private func makeHarness(storedSession: AuthSession? = nil) -> (
        service: GameCenterAuthenticationService,
        gameCenter: FakeGameCenterClient,
        api: FakeAuthAPI,
        sessionStore: MemorySessionStore,
        statistics: StatisticsStore,
        notificationCenter: NotificationCenter,
        aiAccess: AIQuizAccessStore
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
        let aiAccess = AIQuizAccessStore()
        let service = GameCenterAuthenticationService(
            gameCenter: gameCenter,
            api: api,
            sessionStore: sessionStore,
            statisticsStore: statistics,
            bundleIdentifier: "ru.avtabenskiy.Quizice",
            now: { Date(timeIntervalSince1970: 1_000) },
            notificationCenter: notificationCenter,
            aiQuizAccessStore: aiAccess
        )
        return (
            service,
            gameCenter,
            api,
            sessionStore,
            statistics,
            notificationCenter,
            aiAccess
        )
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
        AuthURLProtocol.hangingRequestHandler = nil
        AuthURLProtocol.stopHandler = nil
        super.tearDown()
    }

    func testLiveCamelCaseContractEncodesRequestsAndDecodesResponses() async throws {
        let metrics = AuthBackendMetricSpy()
        let api = makeAPI(metrics: metrics)
        var requestNumber = 0
        AuthURLProtocol.requestHandler = { request in
            requestNumber += 1
            if requestNumber == 1 {
                XCTAssertEqual(request.url?.path, "/api/v1/auth/game-center")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
                XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
                let body = try XCTUnwrap(Self.bodyData(from: request))
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
                XCTAssertEqual(
                    json,
                    [
                        "teamPlayerId": "team-1",
                        "bundleId": "ru.avtabenskiy.Quizice",
                        "publicKeyUrl": "https://apple.example/key",
                        "signature": "c2lnbmF0dXJl",
                        "salt": "c2FsdA==",
                        "timestamp": "123456"
                    ]
                )
                let data = Data(
                    #"{"userId":"018f4f5e-7b6a-7c8d-9e0f-123456789abc","accessToken":"token","expiresAt":"2030-01-01T00:00:00Z"}"#.utf8
                )
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }

            XCTAssertEqual(request.url?.path, "/api/v1/me/statistics/sync")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual(Set(json.keys), ["migrationId", "legacySummary", "attempts"])
            XCTAssertEqual(json["migrationId"] as? String, "migration-1")
            XCTAssertEqual(
                json["legacySummary"] as? [String: Int],
                [
                    "playedQuizzes": 1,
                    "correctAnswers": 4,
                    "totalQuestions": 5,
                    "bestCorrectAnswers": 4,
                    "bestTotalQuestions": 5
                ]
            )
            let attempts = try XCTUnwrap(json["attempts"] as? [[String: Any]])
            XCTAssertEqual(attempts.count, 1)
            XCTAssertEqual(Set(attempts[0].keys), ["id", "correctAnswers", "totalQuestions", "completedAt"])
            XCTAssertEqual(attempts[0]["id"] as? String, "attempt-1")
            XCTAssertEqual(attempts[0]["correctAnswers"] as? Int, 3)
            XCTAssertEqual(attempts[0]["totalQuestions"] as? Int, 5)
            XCTAssertEqual(attempts[0]["completedAt"] as? String, "1970-01-01T00:20:34Z")
            let data = Data(
                #"{"summary":{"playedQuizzes":2,"correctAnswers":7,"totalQuestions":10,"bestCorrectAnswers":4,"bestTotalQuestions":5},"acceptedAttemptIds":["attempt-1"],"legacySummaryAccepted":true}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        let authSession = try await api.authenticate(identity: Self.identity)
        XCTAssertEqual(authSession.teamPlayerID, "team-1")
        XCTAssertEqual(authSession.userID, "018f4f5e-7b6a-7c8d-9e0f-123456789abc")

        let response = try await api.syncStatistics(
            request: StatisticsStore.SyncRequest(
                migrationId: "migration-1",
                legacySummary: StatisticsSummary(
                    playedQuizzes: 1,
                    correctAnswers: 4,
                    totalQuestions: 5,
                    bestCorrectAnswers: 4,
                    bestTotalQuestions: 5
                ),
                attempts: [
                    StatisticsStore.PendingAttempt(
                        id: "attempt-1",
                        correctAnswers: 3,
                        totalQuestions: 5,
                        completedAt: Date(timeIntervalSince1970: 1_234)
                    )
                ]
            ),
            accessToken: authSession.accessToken
        )
        XCTAssertEqual(response.summary.playedQuizzes, 2)
        XCTAssertEqual(response.acceptedAttemptIds, ["attempt-1"])
        XCTAssertEqual(metrics.values.map(\.operation), [.authentication, .statisticsSync])
        XCTAssertEqual(metrics.values.map(\.result), [.success, .success])
        XCTAssertTrue(metrics.values.allSatisfy { $0.statusCode == 200 })
        XCTAssertTrue(metrics.values.allSatisfy { $0.durationMilliseconds >= 0 })
    }

    func testAuthenticationDecodesRFC3339ExpirationWithAndWithoutFractionalSeconds() async throws {
        let fixtures: [(value: String, expectedTimestamp: TimeInterval)] = [
            ("2030-01-01T00:00:00Z", 1_893_456_000),
            ("2030-01-01T00:00:00.123Z", 1_893_456_000.123)
        ]

        for fixture in fixtures {
            let api = makeAPI()
            AuthURLProtocol.requestHandler = { request in
                let data = Data(
                    #"{"userId":"user-1","accessToken":"token","expiresAt":"\#(fixture.value)"}"#.utf8
                )
                return (
                    HTTPURLResponse(
                        url: request.url!,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil
                    )!,
                    data
                )
            }

            let session = try await api.authenticate(identity: Self.identity)

            XCTAssertEqual(
                session.expiresAt.timeIntervalSince1970,
                fixture.expectedTimestamp,
                accuracy: 0.001
            )
        }
    }

    func testUnauthorizedResponseDecodesLiveErrorEnvelopeIncludingRequestID() async {
        let api = makeAPI()
        AuthURLProtocol.requestHandler = { request in
            let data = Data(
                #"{"requestId":"request-42","code":"unauthorized","message":"invalid token"}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, data)
        }

        do {
            _ = try await api.syncStatistics(request: Self.emptySyncRequest, accessToken: "expired")
            XCTFail("Expected unauthorized error")
        } catch let error as BackendAPIError {
            XCTAssertEqual(
                error,
                .unauthorized(
                    BackendErrorEnvelope(
                        code: "unauthorized",
                        message: "invalid token",
                        requestId: "request-42"
                    )
                )
            )
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testMalformedSuccessJSONThrowsDecodingError() async {
        let api = makeAPI()
        AuthURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"{"userId":"user-1"}"#.utf8)
            )
        }

        await assertError(.decoding) {
            try await api.authenticate(identity: Self.identity)
        }
    }

    func testNonHTTPResponseThrowsInvalidResponse() async {
        let api = makeAPI()
        AuthURLProtocol.requestHandler = { request in
            (
                URLResponse(
                    url: request.url!,
                    mimeType: "application/json",
                    expectedContentLength: 0,
                    textEncodingName: nil
                ),
                Data()
            )
        }

        await assertError(.invalidResponse) {
            try await api.authenticate(identity: Self.identity)
        }
    }

    func testTimeoutIsInjectedIntoRequestAndMappedToTransportError() async {
        let api = makeAPI(requestTimeout: 0.25)
        AuthURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.timeoutInterval, 0.25, accuracy: 0.001)
            throw URLError(.timedOut)
        }

        await assertError(.transport(.timedOut)) {
            try await api.authenticate(identity: Self.identity)
        }
    }

    func testCancellingRequestPropagatesCancellationError() async {
        let api = makeAPI()
        let requestStarted = expectation(description: "Request started")
        let requestStopped = expectation(description: "Request stopped")
        AuthURLProtocol.hangingRequestHandler = { _ in requestStarted.fulfill() }
        AuthURLProtocol.stopHandler = { requestStopped.fulfill() }

        let task = Task {
            try await api.authenticate(identity: Self.identity)
        }
        await fulfillment(of: [requestStarted], timeout: 1)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation is not converted into a recoverable transport error.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        await fulfillment(of: [requestStopped], timeout: 1)
    }

    func testInvalidAuthenticationSuccessValuesThrowContractViolation() async {
        let invalidFixtures = [
            #"{"userId":"","accessToken":"token","expiresAt":"2030-01-01T00:00:00Z"}"#,
            #"{"userId":"user-1","accessToken":"   ","expiresAt":"2030-01-01T00:00:00Z"}"#,
            #"{"userId":"user-1","accessToken":"token","expiresAt":"2020-01-01T00:00:00Z"}"#
        ]

        for fixture in invalidFixtures {
            let api = makeAPI()
            AuthURLProtocol.requestHandler = { request in
                (
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                    Data(fixture.utf8)
                )
            }

            await assertError(.contractViolation) {
                try await api.authenticate(identity: Self.identity)
            }
        }
    }

    func testInconsistentStatisticsSuccessThrowsContractViolation() async {
        let api = makeAPI()
        AuthURLProtocol.requestHandler = { request in
            let data = Data(
                #"{"summary":{"playedQuizzes":1,"correctAnswers":6,"totalQuestions":5,"bestCorrectAnswers":6,"bestTotalQuestions":5},"acceptedAttemptIds":[],"legacySummaryAccepted":true}"#.utf8
            )
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
        }

        await assertError(.contractViolation) {
            try await api.syncStatistics(request: Self.emptySyncRequest, accessToken: "token")
        }
    }

    func testStatisticsResponseMustAcknowledgeEveryAttemptInBatch() async {
        let api = makeAPI()
        AuthURLProtocol.requestHandler = { request in
            let data = Data(
                #"{"summary":{"playedQuizzes":1,"correctAnswers":3,"totalQuestions":5,"bestCorrectAnswers":3,"bestTotalQuestions":5},"acceptedAttemptIds":[],"legacySummaryAccepted":true}"#.utf8
            )
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                data
            )
        }
        let request = StatisticsStore.SyncRequest(
            migrationId: "migration-1",
            legacySummary: nil,
            attempts: [
                StatisticsStore.PendingAttempt(
                    id: "attempt-1",
                    correctAnswers: 3,
                    totalQuestions: 5,
                    completedAt: Date(timeIntervalSince1970: 1_234)
                )
            ]
        )

        await assertError(.contractViolation) {
            try await api.syncStatistics(request: request, accessToken: "token")
        }
    }

    private func makeAPI(
        requestTimeout: TimeInterval = 15,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder()
    ) -> HTTPAuthAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AuthURLProtocol.self]
        let session = URLSession(configuration: configuration)
        return HTTPAuthAPI(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://backend.example/api")!
            ),
            session: session,
            requestTimeout: requestTimeout,
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            metrics: metrics
        )
    }

    private func assertError<T>(
        _ expectedError: BackendAPIError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expectedError)", file: file, line: line)
        } catch let error as BackendAPIError {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private static let identity = GameCenterIdentity(
        teamPlayerId: "team-1",
        bundleId: "ru.avtabenskiy.Quizice",
        publicKeyUrl: "https://apple.example/key",
        signature: "c2lnbmF0dXJl",
        salt: "c2FsdA==",
        timestamp: "123456"
    )

    private static let emptySyncRequest = StatisticsStore.SyncRequest(
        migrationId: "migration-1",
        legacySummary: nil,
        attempts: []
    )

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

final class BackendConfigurationTests: XCTestCase {
    func testProductionEndpointIsAccepted() throws {
        let configuration = try XCTUnwrap(
            BackendConfiguration.configuration(
                from: "https://bbav8b1v6032q53l8360.containers.yandexcloud.net/api"
            )
        )

        XCTAssertEqual(
            configuration.baseURL.absoluteString,
            "https://bbav8b1v6032q53l8360.containers.yandexcloud.net/api"
        )
    }

    func testRelativeMissingHostAndInsecureRemoteURLsAreRejected() {
        XCTAssertNil(BackendConfiguration.configuration(from: "api/v1"))
        XCTAssertNil(BackendConfiguration.configuration(from: "https:///api"))
        XCTAssertNil(BackendConfiguration.configuration(from: "http://backend.example/api"))
        XCTAssertNil(BackendConfiguration.configuration(from: "$(BACKEND_BASE_URL)"))
    }

    #if DEBUG
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

    func testHTTPLocalhostIsAcceptedOnlyByDebugValidation() throws {
        let configuration = try XCTUnwrap(
            BackendConfiguration.configuration(from: "http://localhost:8000/api")
        )
        XCTAssertEqual(configuration.baseURL, DebugBackendSettings.localhostBaseURL)
    }
    #endif
}

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

private final class AuthBackendMetricSpy: BackendRequestMetricRecording {
    private(set) var values: [BackendRequestMetric] = []

    func record(_ metric: BackendRequestMetric) {
        values.append(metric)
    }
}
