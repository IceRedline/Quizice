import XCTest
@testable import Quizice

extension BackendClientTests {
    func testBackendAIRejectsSuccessfulResponseWhenUserChangesWhileRequestIsInFlight() async {
        let session = makeSession()
        let originalSession = AuthSession(
            userID: "user-1",
            accessToken: "original-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let replacementSession = AuthSession(
            userID: "user-2",
            accessToken: "replacement-token",
            expiresAt: Date(timeIntervalSince1970: 4_100_000_000),
            teamPlayerID: "team-2"
        )
        let store = BackendMemorySessionStore(session: originalSession)
        let access = BackendAIQuizAccessStub(isAvailable: true)
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1_000) },
            accessProvider: access
        )
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Quizice-Authorization"),
                "Bearer original-token"
            )
            try store.save(replacementSession)
            return Self.response(
                for: request,
                data: try Self.successfulAIResponseData()
            )
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(store.session, replacementSession)
        XCTAssertTrue(access.isAIQuizAvailable)
    }

    func testBackendAIRechecksSessionAfterValidatingSuccessfulPayload() async {
        let session = makeSession()
        let originalSession = AuthSession(
            userID: "user-1",
            accessToken: "original-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let replacementSession = AuthSession(
            userID: "user-2",
            accessToken: "replacement-token",
            expiresAt: Date(timeIntervalSince1970: 4_100_000_000),
            teamPlayerID: "team-2"
        )
        let store = BackendScriptedSessionStore(
            loadResults: [originalSession, originalSession, replacementSession]
        )
        let access = BackendAIQuizAccessStub(isAvailable: true)
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1_000) },
            accessProvider: access
        )
        BackendTestURLProtocol.requestHandler = { request in
            Self.response(for: request, data: try Self.successfulAIResponseData())
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(store.loadCount, 3)
        XCTAssertTrue(access.isAIQuizAvailable)
    }

    func testBackendAIStaleUnauthorizedResponseDoesNotInvalidateReplacementSession() async {
        let session = makeSession()
        let originalSession = AuthSession(
            userID: "user-1",
            accessToken: "original-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let refreshedSession = AuthSession(
            userID: "user-1",
            accessToken: "refreshed-token",
            expiresAt: Date(timeIntervalSince1970: 4_100_000_000),
            teamPlayerID: "team-1"
        )
        let store = BackendMemorySessionStore(session: originalSession)
        let access = BackendAIQuizAccessStub(isAvailable: true)
        let notificationCenter = NotificationCenter()
        var invalidationCount = 0
        let observer = notificationCenter.addObserver(
            forName: .backendAuthenticationInvalidated,
            object: nil,
            queue: nil
        ) { _ in
            invalidationCount += 1
        }
        defer { notificationCenter.removeObserver(observer) }
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1_000) },
            accessProvider: access,
            notificationCenter: notificationCenter
        )
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Quizice-Authorization"),
                "Bearer original-token"
            )
            try store.save(refreshedSession)
            return Self.response(
                for: request,
                statusCode: 401,
                data: Data(
                    #"{"requestId":"request-3","code":"unauthorized","message":"expired"}"#.utf8
                )
            )
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(store.session, refreshedSession)
        XCTAssertTrue(access.isAIQuizAvailable)
        XCTAssertEqual(invalidationCount, 0)
    }

    func testBackendAIStaleForbiddenResponseDoesNotDisableReplacementUser() async {
        let session = makeSession()
        let originalSession = AuthSession(
            userID: "user-1",
            accessToken: "original-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let replacementSession = AuthSession(
            userID: "user-2",
            accessToken: "replacement-token",
            expiresAt: Date(timeIntervalSince1970: 4_100_000_000),
            teamPlayerID: "team-2"
        )
        let store = BackendMemorySessionStore(session: originalSession)
        let access = BackendAIQuizAccessStub(isAvailable: true)
        let notificationCenter = NotificationCenter()
        var invalidationCount = 0
        let observer = notificationCenter.addObserver(
            forName: .backendAuthenticationInvalidated,
            object: nil,
            queue: nil
        ) { _ in
            invalidationCount += 1
        }
        defer { notificationCenter.removeObserver(observer) }
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1_000) },
            accessProvider: access,
            notificationCenter: notificationCenter
        )
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Quizice-Authorization"),
                "Bearer original-token"
            )
            try store.save(replacementSession)
            return Self.response(
                for: request,
                statusCode: 403,
                data: Data(
                    #"{"requestId":"request-4","code":"forbidden","message":"forbidden"}"#.utf8
                )
            )
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(store.session, replacementSession)
        XCTAssertTrue(access.isAIQuizAvailable)
        XCTAssertEqual(invalidationCount, 0)
    }

    func testBackendAISendsBearerAndCompleteProductContract() async throws {
        let session = makeSession()
        let store = BackendMemorySessionStore(
            session: AuthSession(
                userID: "user-1",
                accessToken: "access-token",
                expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
                teamPlayerID: "team-1"
            )
        )
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: store,
            now: { Date(timeIntervalSince1970: 1_000) },
            idGenerator: { "generated-id" },
            accessProvider: BackendAIQuizAccessStub(isAvailable: true)
        )
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/quizzes/generate")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Quizice-Authorization"),
                "Bearer access-token"
            )
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["topic"] as? String, "Space")
            XCTAssertEqual(json["count"] as? Int, 5)
            XCTAssertEqual(json["locale"] as? String, "ru")
            XCTAssertEqual(json["difficulty"] as? String, "hard")

            let responseBody = try JSONSerialization.data(withJSONObject: [
                "locale": "ru",
                "status": "success",
                "message": "",
                "theme": "Космос",
                "themeDescription": "Описание",
                "questions": (0..<5).map(Self.questionJSON)
            ])
            return Self.response(for: request, data: responseBody)
        }

        let theme = try await api.generateQuizTheme(configuration: Self.aiConfiguration)

        XCTAssertEqual(theme.id, "ai-generated-id")
        XCTAssertEqual(theme.questions.count, 5)
        XCTAssertEqual(theme.aiGenerationConfiguration, Self.aiConfiguration)
        XCTAssertEqual(theme.questionOrigin, .backend)
    }
}

extension BackendClientTests {
    func testBackendAIAcceptsExplanationsAllowedByServerContract() async throws {
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration, session: makeSession(),
            sessionStore: BackendMemorySessionStore(session: ProgressSessionProvider.session("A")),
            accessProvider: BackendAIQuizAccessStub(isAvailable: true)
        )
        BackendTestURLProtocol.requestHandler = { request in
            var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: Self.successfulAIResponseData()) as? [String: Any])
            var questions = try XCTUnwrap(payload["questions"] as? [[String: Any]])
            questions[0]["explanation"] = String(repeating: "a", count: 2_000)
            payload["questions"] = questions
            return Self.response(for: request, data: try JSONSerialization.data(withJSONObject: payload))
        }
        let theme = try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        XCTAssertEqual(theme.questions.first?.explanation?.count, 2_000)
    }

    func testBackendAIDistinguishesMonthlyQuotaFromTransientRateLimit() async throws {
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration, session: makeSession(),
            sessionStore: BackendMemorySessionStore(session: ProgressSessionProvider.session("A")),
            accessProvider: BackendAIQuizAccessStub(isAvailable: true)
        )
        for (code, expected) in [("ai_quota_exceeded", YandexAIQuizThemeServiceError.quotaExceeded),
                                 ("rate_limited", .httpStatus(429))] {
            BackendTestURLProtocol.requestHandler = { request in
                Self.response(for: request, statusCode: 429, data: Data("{\"requestId\":\"test\",\"code\":\"\(code)\",\"message\":\"limit\"}".utf8))
            }
            await assertAIError(expected) { try await api.generateQuizTheme(configuration: Self.aiConfiguration) }
        }
        let alert = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.quotaExceeded)
        XCTAssertEqual(alert.kind, .quota)
        XCTAssertFalse(alert.canRetry)
        XCTAssertFalse(alert.offersEditAction)
        XCTAssertNotEqual(alert.message, AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(429)).message)
    }
}
