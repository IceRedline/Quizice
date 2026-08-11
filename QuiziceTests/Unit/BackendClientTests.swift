import XCTest
@testable import Quizice

final class BackendClientTests: XCTestCase {
    override func tearDown() {
        BackendTestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testThemeCatalogUsesLocaleEnvelopeAndRecordsDecodedLatency() async throws {
        let metrics = BackendMetricSpy()
        let api = makeContentAPI(metrics: metrics, accessToken: "catalog-token")
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/themes")
            XCTAssertEqual(request.url?.query, "locale=ru")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer catalog-token"
            )
#if DEBUG
            XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
#endif
            let body = Data(
                ##"{"locale":"ru","themes":[{"id":"music","name":"Музыка","description":"Описание","sfSymbol":"music.note.list","emoji":"🎵","colorHex":"#FF8252","isFavorite":true}]}"##.utf8
            )
            return Self.response(for: request, data: body)
        }

        let response = try await api.fetchThemes(locale: "ru")

        XCTAssertEqual(response.locale, "ru")
        XCTAssertEqual(response.themes.map(\.id), ["music"])
        XCTAssertEqual(response.themes.map(\.sfSymbol), ["music.note.list"])
        XCTAssertEqual(response.themes.map(\.emoji), ["🎵"])
        XCTAssertEqual(response.themes.map(\.colorHex), ["#FF8252"])
        XCTAssertEqual(response.themes.map(\.isFavorite), [true])
        XCTAssertEqual(metrics.values.count, 1)
        XCTAssertEqual(metrics.values.first?.operation, .themes)
        XCTAssertEqual(metrics.values.first?.result, .success)
        XCTAssertEqual(metrics.values.first?.statusCode, 200)
        XCTAssertGreaterThanOrEqual(metrics.values.first?.durationMilliseconds ?? -1, 0)
    }

    func testThemePreferencesGETUsesBearerAndPreservesServerOrder() async throws {
        let api = makeContentAPI(accessToken: "preferences-token")
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.path, "/api/v1/me/theme-preferences")
            XCTAssertEqual(request.url?.query, "locale=ru")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer preferences-token"
            )
            let body = Data(
                ##"{"locale":"ru","favoriteThemeIds":["space","music","cinema"]}"##.utf8
            )
            return Self.response(for: request, data: body)
        }

        let response = try await api.fetchThemePreferences(locale: "ru")

        XCTAssertEqual(response.favoriteThemeIds, ["space", "music", "cinema"])
    }

    func testThemePreferencesPUTReplacesOrderedSelection() async throws {
        let api = makeContentAPI(accessToken: "preferences-token")
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "PUT")
            XCTAssertEqual(request.url?.path, "/api/v1/me/theme-preferences")
            XCTAssertNil(request.url?.query)
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer preferences-token"
            )
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let payload = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(payload["locale"] as? String, "ru")
            XCTAssertEqual(
                payload["favoriteThemeIds"] as? [String],
                ["space", "music", "cinema"]
            )
            return Self.response(for: request, data: body)
        }

        let response = try await api.replaceThemePreferences(
            locale: "ru",
            favoriteThemeIDs: ["space", "music", "cinema"]
        )

        XCTAssertEqual(response.favoriteThemeIds, ["space", "music", "cinema"])
    }

    func testThemePreferencesFailBeforeNetworkWithoutValidSession() async {
        let api = makeContentAPI()

        await assertBackendContentError(.unauthenticated) {
            try await api.fetchThemePreferences(locale: "ru")
        }
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
        XCTAssertEqual(response.questions.first?.questionId, "question-0")
        XCTAssertEqual(response.questions.first?.questionVersion, 1)
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

    func testBundledCatalogUsesBundledQuestionsWithoutCallingBackend() async throws {
        let backend = RecordingBackendContentAPI()
        let repository = ThemeCatalogRepository(
            backendContentAPI: backend,
            seedGenerator: { "seed-1" }
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
        XCTAssertEqual(backend.themeRequestCount, 0)
        XCTAssertTrue(backend.seeds.isEmpty)
    }

    func testBackendCatalogReplacesTheEntireBundledCatalogInBackendOrder() async {
        let remoteThemes = (0..<14).map { index in
            BackendThemeDTO(
                id: "remote-\(index)",
                name: "Remote \(index)",
                description: "Description \(index)",
                sfSymbol: "star.fill",
                emoji: "⭐️",
                colorHex: "#4F46E5",
                isFavorite: index < 2
            )
        }
        let backend = RecordingBackendContentAPI(catalogThemes: remoteThemes)
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = (0..<4).map { index in
            QuizTheme(
                id: "local-\(index)",
                theme: "Local \(index)",
                themeDescription: "Local Description",
                questions: []
            )
        }
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        let didRefresh = await repository.refreshBackendCatalog(locale: locale)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(repository.catalogOrigin, .backend)
        XCTAssertEqual(repository.themes?.map(\.stableID), remoteThemes.map(\.id))
        XCTAssertEqual(repository.themes?.map(\.theme), remoteThemes.map(\.name))
        XCTAssertEqual(repository.themes?.count, 14)
        XCTAssertTrue(repository.themes?.allSatisfy(\.questions.isEmpty) == true)
        XCTAssertTrue(repository.themes?.allSatisfy { $0.questionOrigin == .backend } == true)
        XCTAssertTrue(repository.themes?.allSatisfy { $0.sfSymbolName == "star.fill" } == true)
    }

    func testBackendCatalogQuestionFailureDoesNotReturnBundledQuestions() async {
        let backend = RecordingBackendContentAPI(
            questionError: URLError(.timedOut)
        )
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let didRefresh = await repository.refreshBackendCatalog(locale: locale)
        XCTAssertTrue(didRefresh)

        do {
            _ = try await repository.prepareQuiz(
                themeID: "music",
                questionCount: 5,
                locale: locale
            )
            XCTFail("Backend catalog mode must not fall back to bundled questions")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(backend.seeds.count, 1)
    }

    func testEachQuizPreparationUsesANewLowercaseUUIDSeed() async throws {
        let backend = RecordingBackendContentAPI()
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let didRefresh = await repository.refreshBackendCatalog(locale: locale)
        XCTAssertTrue(didRefresh)

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
                BackendThemeDTO(
                    id: "music",
                    name: "Remote Music",
                    description: "Known theme",
                    sfSymbol: "music.note.list",
                    emoji: "🎵",
                    colorHex: "#FF8252",
                    isFavorite: true
                ),
                BackendThemeDTO(
                    id: "space",
                    name: "Space",
                    description: "Backend-only theme",
                    sfSymbol: "globe",
                    emoji: "🚀",
                    colorHex: "#4F46E5",
                    isFavorite: false
                )
            ]
        )
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        repository.themes = [Self.localTheme(questionCount: 15)]
        let locale = AppLocalizationStore.shared.resolvedLanguageCode

        let didRefresh = await repository.refreshBackendCatalog(locale: locale)
        let themes = try XCTUnwrap(repository.themes)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(themes.map(\.stableID), ["music", "space"])
        XCTAssertTrue(themes[0].questions.isEmpty)
        XCTAssertEqual(themes[0].questionOrigin, .backend)
        XCTAssertTrue(themes[1].questions.isEmpty)
        XCTAssertEqual(themes[1].questionOrigin, .backend)
        XCTAssertEqual(themes[1].sfSymbolName, "globe")
        XCTAssertEqual(themes[1].emoji, "🚀")
        XCTAssertEqual(themes[1].colorHex, "#4F46E5")
        XCTAssertTrue(themes[0].isFavorite)
        XCTAssertFalse(themes[1].isFavorite)

        let prepared = try await repository.prepareQuiz(
            themeID: "space",
            questionCount: 5,
            locale: locale
        )

        XCTAssertEqual(prepared.stableID, "space")
        XCTAssertEqual(prepared.questions.count, 5)
        XCTAssertEqual(prepared.questionOrigin, .backend)
    }

    func testPendingLocalThemePreferencesArePUTInTheirSavedOrder() async {
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let (store, defaults, suiteName) = makePreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.complete(preferredThemeIDs: ["space", "music"], locale: locale)
        let backend = ThemePreferencesBackendContentAPI(
            catalogThemes: Self.preferenceCatalog
        )
        let repository = ThemeCatalogRepository(
            backendContentAPI: backend,
            preferenceStore: store
        )

        _ = await repository.refreshBackendCatalog(locale: locale)
        let didSynchronize = await repository.synchronizeThemePreferences(locale: locale)

        XCTAssertTrue(didSynchronize)
        XCTAssertEqual(backend.fetchedPreferenceLocales, [])
        XCTAssertEqual(backend.replacedPreferences.count, 1)
        XCTAssertEqual(backend.replacedPreferences.first?.locale, locale)
        XCTAssertEqual(backend.replacedPreferences.first?.themeIDs, ["space", "music"])
        XCTAssertEqual(
            store.orderedPreferredThemeIDs(locale: locale),
            ["space", "music"]
        )
        XCTAssertFalse(store.hasPendingThemePreferences(locale: locale))
        XCTAssertEqual(repository.themes?.map(\.stableID), ["space", "music", "cinema"])
        XCTAssertEqual(repository.themes?.map(\.isFavorite), [true, true, false])
    }

    func testRemoteThemePreferencesBecomeLocalSourceOfTruthWhenNothingIsPending() async {
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let (store, defaults, suiteName) = makePreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let backend = ThemePreferencesBackendContentAPI(
            catalogThemes: Self.preferenceCatalog,
            remoteFavoriteThemeIDs: ["cinema", "music"]
        )
        let repository = ThemeCatalogRepository(
            backendContentAPI: backend,
            preferenceStore: store
        )

        _ = await repository.refreshBackendCatalog(locale: locale)
        let didSynchronize = await repository.synchronizeThemePreferences(locale: locale)

        XCTAssertTrue(didSynchronize)
        XCTAssertEqual(backend.fetchedPreferenceLocales, [locale])
        XCTAssertTrue(backend.replacedPreferences.isEmpty)
        XCTAssertEqual(
            store.orderedPreferredThemeIDs(locale: locale),
            ["cinema", "music"]
        )
        XCTAssertEqual(repository.themes?.map(\.stableID), ["cinema", "music", "space"])
        XCTAssertEqual(repository.themes?.map(\.isFavorite), [true, true, false])
    }

    func testOfflinePreferenceSyncKeepsPendingLocalSelectionForRetry() async {
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let (store, defaults, suiteName) = makePreferenceStore()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        store.complete(preferredThemeIDs: ["space"], locale: locale)
        let backend = ThemePreferencesBackendContentAPI(
            catalogThemes: Self.preferenceCatalog
        )
        backend.preferencesError = BackendContentError.transport(.notConnectedToInternet)
        let repository = ThemeCatalogRepository(
            backendContentAPI: backend,
            preferenceStore: store
        )

        _ = await repository.refreshBackendCatalog(locale: locale)
        let didSynchronize = await repository.synchronizeThemePreferences(locale: locale)

        XCTAssertFalse(didSynchronize)
        XCTAssertEqual(backend.replacedPreferences.first?.themeIDs, ["space"])
        XCTAssertEqual(store.orderedPreferredThemeIDs(locale: locale), ["space"])
        XCTAssertTrue(store.hasPendingThemePreferences(locale: locale))
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

    func testPersonalizedQuestionStrategiesMapToProgressModeAndBearer() async throws {
        let seed = "550e8400-e29b-41d4-a716-446655440000"
        for (strategy, expectedMode) in [
            (QuestionRepeatStrategy.hideAnswered, "all_answered"),
            (.retryIncorrect, "correct_only")
        ] {
            let api = makeContentAPI(accessToken: "progress-token")
            BackendTestURLProtocol.requestHandler = { request in
                let items = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
                XCTAssertEqual(items?.first(where: { $0.name == "progressMode" })?.value, expectedMode)
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer progress-token")
                let body = try JSONSerialization.data(withJSONObject: [
                    "locale": "ru",
                    "seed": seed,
                    "progressMode": expectedMode,
                    "availableCount": 1,
                    "questions": [Self.questionJSON(index: 0)]
                ])
                return Self.response(for: request, data: body)
            }
            let response = try await api.fetchQuestions(
                themeID: "music",
                count: 5,
                locale: "ru",
                difficulty: .medium,
                seed: seed,
                strategy: strategy
            )
            XCTAssertEqual(response.questions.count, 1)
            XCTAssertEqual(response.availableCount, 1)
        }
    }

    func testGuestRepeatStrategyAlwaysFallsBackToShowAll() {
        XCTAssertEqual(
            QuestionRepeatStrategy.hideAnswered.effective(hasValidBackendSession: false),
            .showAll
        )
        XCTAssertEqual(
            QuestionRepeatStrategy.retryIncorrect.effective(hasValidBackendSession: false),
            .showAll
        )
        XCTAssertEqual(
            QuestionRepeatStrategy.hideAnswered.effective(hasValidBackendSession: true),
            .hideAnswered
        )
    }

    func testShowAllOmitsProgressModeAndAllowsEmptyGuestBatch() async throws {
        let seed = "550e8400-e29b-41d4-a716-446655440000"
        let api = makeContentAPI()
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertFalse(request.url?.query?.contains("progressMode") ?? false)
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            let body = Data(
                "{\"locale\":\"ru\",\"seed\":\"\(seed)\",\"availableCount\":0,\"questions\":[]}".utf8
            )
            return Self.response(for: request, data: body)
        }
        let response = try await api.fetchQuestions(
            themeID: "music",
            count: 5,
            locale: "ru",
            difficulty: .medium,
            seed: seed,
            strategy: .showAll
        )
        XCTAssertTrue(response.questions.isEmpty)
    }

    func testQuestionAnswerBatchUsesBearerAndEncodesTimeoutAsNull() async throws {
        let eventID = UUID()
        let api = makeContentAPI(accessToken: "answer-token")
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/me/question-answers")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer answer-token")
            let body = try XCTUnwrap(Self.bodyData(from: request))
            let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
            let events = try XCTUnwrap(json["events"] as? [[String: Any]])
            XCTAssertTrue(events[0]["answer"] is NSNull)
            return Self.response(
                for: request,
                data: Data("{\"processedEventIds\":[\"\(eventID.uuidString)\"]}".utf8)
            )
        }
        let response = try await api.submitQuestionAnswers([
            QuestionAnswerEvent(
                eventId: eventID,
                questionId: "music:0001",
                questionVersion: 1,
                locale: "ru",
                answer: nil,
                answeredAt: Date(timeIntervalSince1970: 1_000)
            )
        ])
        XCTAssertEqual(response.processedEventIds, [eventID])
    }

    func testProtectedRequestReauthenticatesAndRetriesExactlyOnceAfter401() async throws {
        let recoverer = BackendAuthenticationRecovererSpy(refreshedToken: "fresh-token")
        let api = makeContentAPI(
            accessToken: "rejected-token",
            authenticationRecoverer: recoverer
        )
        var authorizationHeaders: [String?] = []
        BackendTestURLProtocol.requestHandler = { request in
            authorizationHeaders.append(request.value(forHTTPHeaderField: "Authorization"))
            if authorizationHeaders.count == 1 {
                return Self.response(
                    for: request,
                    statusCode: 401,
                    data: Data(#"{"code":"unauthorized"}"#.utf8)
                )
            }
            return Self.response(
                for: request,
                data: Data(#"{"locale":"ru","favoriteThemeIds":["music"]}"#.utf8)
            )
        }

        let response = try await api.fetchThemePreferences(locale: "ru")

        XCTAssertEqual(response.favoriteThemeIds, ["music"])
        XCTAssertEqual(authorizationHeaders, ["Bearer rejected-token", "Bearer fresh-token"])
        XCTAssertEqual(recoverer.rejectedTokens, ["rejected-token"])
    }

    func testSecond401DoesNotStartAnotherAuthenticationCycle() async {
        let recoverer = BackendAuthenticationRecovererSpy(refreshedToken: "fresh-token")
        let api = makeContentAPI(
            accessToken: "rejected-token",
            authenticationRecoverer: recoverer
        )
        var requestCount = 0
        BackendTestURLProtocol.requestHandler = { request in
            requestCount += 1
            return Self.response(
                for: request,
                statusCode: 401,
                data: Data(#"{"code":"unauthorized"}"#.utf8)
            )
        }

        await assertBackendContentError(.httpStatus(401, nil)) {
            try await api.fetchThemePreferences(locale: "ru")
        }

        XCTAssertEqual(requestCount, 2)
        XCTAssertEqual(recoverer.rejectedTokens, ["rejected-token"])
    }

    func testAnswerOutboxRetriesTheSameEventIDAndDeletesOnlyProcessedEvents() async {
        let processedID = UUID()
        let pendingID = UUID()
        let api = QuestionAnswerBackendContentAPI(submitResults: [
            .failure(BackendContentError.transport(.notConnectedToInternet)),
            .success(QuestionAnswerBatchResponse(processedEventIds: [processedID])),
            .success(QuestionAnswerBatchResponse(processedEventIds: []))
        ])
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("QuiziceTests-(UUID().uuidString)")
            .appendingPathComponent("outbox.json")
        let outbox = PersistentQuestionAnswerOutbox(
            api: api,
            fileURL: fileURL,
            automaticallySynchronizesOnEnqueue: false
        )
        let processedEvent = QuestionAnswerEvent(
            eventId: processedID,
            questionId: "music:1",
            questionVersion: 1,
            locale: "ru",
            answer: "A",
            answeredAt: Date(timeIntervalSince1970: 1_000)
        )
        let pendingEvent = QuestionAnswerEvent(
            eventId: pendingID,
            questionId: "music:2",
            questionVersion: 1,
            locale: "ru",
            answer: "B",
            answeredAt: Date(timeIntervalSince1970: 2_000)
        )
        outbox.enqueue(processedEvent)
        outbox.enqueue(pendingEvent)

        await outbox.synchronize()
        await outbox.synchronize()

        XCTAssertEqual(api.submittedBatches.count, 3)
        XCTAssertEqual(api.submittedBatches[0].map(\.eventId), [processedID, pendingID])
        XCTAssertEqual(api.submittedBatches[1].map(\.eventId), [processedID, pendingID])
        XCTAssertEqual(api.submittedBatches[2].map(\.eventId), [pendingID])
        XCTAssertEqual(outbox.pendingEvents().map(\.eventId), [pendingID])
    }

}
