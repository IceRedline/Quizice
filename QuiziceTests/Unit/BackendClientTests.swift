import XCTest
@testable import Quizice

final class BackendClientTests: XCTestCase {
    override func tearDown() {
        BackendTestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testThemeCatalogUsesLocaleEnvelopeAndRecordsDecodedLatency() async throws {
        let metrics = BackendMetricSpy()
        let api = makeContentAPI(metrics: metrics)
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/themes")
            XCTAssertEqual(request.url?.query, "locale=ru")
#if DEBUG
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
#endif
            let body = Data(
                #"{"locale":"ru","themes":[{"id":"music","name":"Музыка","description":"Описание"}]}"#.utf8
            )
            return Self.response(for: request, data: body)
        }

        let response = try await api.fetchThemes(locale: "ru")

        XCTAssertEqual(response.locale, "ru")
        XCTAssertEqual(response.themes.map(\.id), ["music"])
        XCTAssertEqual(metrics.values.count, 1)
        XCTAssertEqual(metrics.values.first?.operation, .themes)
        XCTAssertEqual(metrics.values.first?.result, .success)
        XCTAssertEqual(metrics.values.first?.statusCode, 200)
        XCTAssertGreaterThanOrEqual(metrics.values.first?.durationMilliseconds ?? -1, 0)
    }

    func testQuestionBatchSendsCountLocaleAndSeedAndValidatesQuestions() async throws {
        let api = makeContentAPI()
        let seed = "550e8400-e29b-41d4-a716-446655440000"
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/themes/history_culture/questions")
            let query = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
            XCTAssertEqual(
                Dictionary(uniqueKeysWithValues: query.compactMap { item in
                    item.value.map { (item.name, $0) }
                }),
                ["count": "5", "locale": "fr", "seed": seed]
            )
            let questions = (0..<5).map(Self.questionJSON)
            let body = try JSONSerialization.data(withJSONObject: [
                "locale": "fr",
                "seed": seed,
                "questions": questions
            ])
            return Self.response(for: request, data: body)
        }

        let response = try await api.fetchQuestions(
            themeID: "history_culture",
            count: 5,
            locale: "fr",
            seed: seed
        )

        XCTAssertEqual(response.questions.count, 5)
        XCTAssertEqual(response.questions.first?.correctAnswer, "B0")
    }

    func testOldBareArrayContractFailsClosed() async {
        let api = makeContentAPI()
        BackendTestURLProtocol.requestHandler = { request in
            let body = Data(
                #"[{"id":"music","name":"Music","description":"Description"}]"#.utf8
            )
            return Self.response(for: request, data: body)
        }

        await assertBackendContentError(.decoding) {
            try await api.fetchThemes(locale: "en")
        }
    }

    func testMismatchedQuestionLocaleOrSeedIsRejected() async {
        let metrics = BackendMetricSpy()
        let api = makeContentAPI(metrics: metrics)
        let requestedSeed = "550e8400-e29b-41d4-a716-446655440000"
        BackendTestURLProtocol.requestHandler = { request in
            let body = try JSONSerialization.data(withJSONObject: [
                "locale": "en",
                "seed": "550e8400-e29b-41d4-a716-446655440001",
                "questions": (0..<5).map(Self.questionJSON)
            ])
            return Self.response(for: request, data: body)
        }

        await assertBackendContentError(.contractViolation) {
            try await api.fetchQuestions(
                themeID: "music",
                count: 5,
                locale: "ru",
                seed: requestedSeed
            )
        }
        XCTAssertEqual(metrics.values.count, 1)
        XCTAssertEqual(metrics.values.first?.result, .contractError)
    }

    func testThemeRepositoryFallsBackToBundledQuestionsAfterInteractiveTimeout() async throws {
        let repository = ThemeCatalogRepository(
            backendContentAPI: SlowBackendContentAPI(),
            seedGenerator: { "seed-1" },
            remoteQuestionTimeoutNanoseconds: 1_000_000
        )
        repository.themes = [Self.localTheme(questionCount: 15)]

        let prepared = try await repository.prepareQuiz(
            themeID: "music",
            questionCount: 5,
            locale: "en"
        )

        XCTAssertEqual(prepared.stableID, "music")
        XCTAssertEqual(prepared.questions.count, 5)
        XCTAssertTrue(prepared.questions.allSatisfy { $0.question.hasPrefix("Local") })
        XCTAssertEqual(prepared.questionOrigin, .bundled)
    }

    func testEachQuizPreparationUsesANewLowercaseUUIDSeed() async throws {
        let backend = RecordingBackendContentAPI()
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        let prepared = try await repository.prepareQuiz(themeID: "music", questionCount: 5, locale: locale)
        _ = try await repository.prepareQuiz(themeID: "music", questionCount: 5, locale: locale)

        XCTAssertEqual(prepared.questionOrigin, .backend)
        XCTAssertEqual(backend.seeds.count, 2)
        XCTAssertNotEqual(backend.seeds[0], backend.seeds[1])
        XCTAssertTrue(backend.seeds.allSatisfy { UUID(uuidString: $0) != nil })
        XCTAssertTrue(backend.seeds.allSatisfy { $0 == $0.lowercased() })
    }

    func testCatalogOriginRemainsBackendWhenSubsequentRefreshFails() async {
        let backend = SequencedCatalogBackendContentAPI()
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        let firstRefreshSucceeded = await repository.refreshBackendCatalog(locale: locale)
        let secondRefreshSucceeded = await repository.refreshBackendCatalog(locale: locale)

        XCTAssertTrue(firstRefreshSucceeded)
        XCTAssertFalse(secondRefreshSucceeded)
        XCTAssertEqual(repository.catalogOrigin, .backend)
        XCTAssertEqual(repository.themes?.first?.theme, "Remote Music")
    }

    func testBackendCatalogPublishesNewThemesAndPreparesTheirQuestionsRemotely() async throws {
        let backend = RecordingBackendContentAPI(
            catalogThemes: [
                BackendThemeDTO(id: "music", name: "Remote Music", description: "Known theme"),
                BackendThemeDTO(id: "space", name: "Space", description: "Backend-only theme")
            ]
        )
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        let didRefresh = await repository.refreshBackendCatalog(locale: locale)
        let themes = try XCTUnwrap(repository.themes)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(themes.map(\.stableID), ["music", "space"])
        XCTAssertEqual(themes[0].questions.count, 15)
        XCTAssertTrue(themes[1].questions.isEmpty)
        XCTAssertEqual(themes[1].questionOrigin, .backend)

        let prepared = try await repository.prepareQuiz(
            themeID: "space",
            questionCount: 5,
            locale: locale
        )

        XCTAssertEqual(prepared.stableID, "space")
        XCTAssertEqual(prepared.questions.count, 5)
        XCTAssertEqual(prepared.questionOrigin, .backend)
    }

    func testBackendAIRejectsGuestBeforeCreatingNetworkRequest() async {
        let session = makeSession()
        let staleSession = AuthSession(
            userID: "previous-user",
            accessToken: "still-valid-stale-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "previous-team"
        )
        let api = BackendAIQuizThemeService(
            configuration: Self.configuration,
            session: session,
            sessionStore: BackendMemorySessionStore(session: staleSession),
            accessProvider: BackendAIQuizAccessStub(isAvailable: false)
        )
        BackendTestURLProtocol.requestHandler = { request in
            XCTFail("Guest must not call the AI endpoint: \(request)")
            throw URLError(.cancelled)
        }

        do {
            _ = try await api.generateQuizTheme(configuration: Self.aiConfiguration)
            XCTFail("Expected authenticationRequired")
        } catch let error as YandexAIQuizThemeServiceError {
            XCTAssertEqual(error, .authenticationRequired)
            XCTAssertEqual(AIQuizGenerationAlert(error: error).kind, .authentication)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testBackendAIExpiredSessionInvalidatesAuthenticationWithoutNetworkRequest() async {
        let session = makeSession()
        let store = BackendMemorySessionStore(
            session: AuthSession(
                userID: "user-1",
                accessToken: "expiring-token",
                expiresAt: Date(timeIntervalSince1970: 1_020),
                teamPlayerID: "team-1"
            )
        )
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
            XCTFail("An expiring session must be refreshed before AI networking: \(request)")
            throw URLError(.cancelled)
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertNil(store.session)
        XCTAssertFalse(access.isAIQuizAvailable)
        XCTAssertEqual(invalidationCount, 1)
    }

    func testBackendAIUnauthorizedResponseInvalidatesAuthenticationOnce() async {
        let session = makeSession()
        let storedSession = AuthSession(
            userID: "user-1",
            accessToken: "expired-server-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let store = BackendMemorySessionStore(session: storedSession)
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
        var requestCount = 0
        BackendTestURLProtocol.requestHandler = { request in
            requestCount += 1
            return Self.response(
                for: request,
                statusCode: 401,
                data: Data(#"{"requestId":"request-1","code":"unauthorized","message":"expired"}"#.utf8)
            )
        }

        await assertAIError(.authenticationRequired) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(requestCount, 1)
        XCTAssertNil(store.session)
        XCTAssertFalse(access.isAIQuizAvailable)
        XCTAssertEqual(invalidationCount, 1)
    }

    func testBackendAIForbiddenResponseDisablesAIWithoutClearingAuthentication() async {
        let session = makeSession()
        let storedSession = AuthSession(
            userID: "user-1",
            accessToken: "valid-token",
            expiresAt: Date(timeIntervalSince1970: 4_000_000_000),
            teamPlayerID: "team-1"
        )
        let store = BackendMemorySessionStore(session: storedSession)
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
            Self.response(
                for: request,
                statusCode: 403,
                data: Data(#"{"requestId":"request-2","code":"forbidden","message":"forbidden"}"#.utf8)
            )
        }

        await assertAIError(.httpStatus(403)) {
            try await api.generateQuizTheme(configuration: Self.aiConfiguration)
        }

        XCTAssertEqual(store.session, storedSession)
        XCTAssertFalse(access.isAIQuizAvailable)
        XCTAssertEqual(invalidationCount, 0)
    }

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
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
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
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer original-token"
            )
            try store.save(refreshedSession)
            return Self.response(
                for: request,
                statusCode: 401,
                data: Data(#"{"requestId":"request-3","code":"unauthorized","message":"expired"}"#.utf8)
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
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer original-token"
            )
            try store.save(replacementSession)
            return Self.response(
                for: request,
                statusCode: 403,
                data: Data(#"{"requestId":"request-4","code":"forbidden","message":"forbidden"}"#.utf8)
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
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
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

    private func makeContentAPI(
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder()
    ) -> HTTPBackendContentAPI {
        HTTPBackendContentAPI(
            configuration: Self.configuration,
            session: makeSession(),
            metrics: metrics
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendTestURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private func assertBackendContentError<T>(
        _ expected: BackendContentError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as BackendContentError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private func assertAIError<T>(
        _ expected: YandexAIQuizThemeServiceError,
        file: StaticString = #filePath,
        line: UInt = #line,
        operation: () async throws -> T
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch let error as YandexAIQuizThemeServiceError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    private static func response(
        for request: URLRequest,
        statusCode: Int = 200,
        data: Data
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!,
            data
        )
    }

    private static func questionJSON(index: Int) -> [String: Any] {
        [
            "question": "Question \(index)",
            "answers": ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
            "correctAnswer": "B\(index)",
            "explanation": ""
        ]
    }

    private static func successfulAIResponseData() throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "locale": "ru",
            "status": "success",
            "message": "",
            "theme": "Космос",
            "themeDescription": "Описание",
            "questions": (0..<5).map(Self.questionJSON)
        ])
    }

    private static func localTheme(questionCount: Int) -> QuizTheme {
        QuizTheme(
            id: "music",
            theme: "Music",
            themeDescription: "Description",
            questions: (0..<questionCount).map { index in
                QuizQuestion(
                    question: "Local \(index)",
                    answers: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                    correctAnswer: "B\(index)"
                )
            }
        )
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

    private static let configuration = BackendConfiguration(
        baseURL: URL(string: "https://backend.example/api")!
    )

    private static let aiConfiguration = AIQuizGenerationConfiguration(
        theme: " Space ",
        questionCount: 5,
        difficulty: .hard,
        locale: Locale(identifier: "ru")
    )
}
