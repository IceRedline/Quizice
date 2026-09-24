import XCTest
@testable import Quizice

final class ResultMessagesTests: XCTestCase {
    private var directory: URL!
    private let clock = ResultMessagesTestClock()

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        BackendTestURLProtocol.requestHandler = nil
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
    }

    func testFirstLaunchOfflineHasNoRemoteText() async {
        let api = ResultMessagesAPIStub { _, _ in throw URLError(.notConnectedToInternet) }
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "ru")
        XCTAssertNil(repository.message(for: .perfectScore, locale: "ru"))
    }

    func testPersistsCatalogAndSkipsFreshRequestsAcrossLaunches() async {
        let api = ResultMessagesAPIStub { locale, _ in Self.catalog(locale: locale) }
        await makeRepository(api).refreshIfNeeded(locale: "ru-RU")
        let restored = makeRepository(api)
        XCTAssertEqual(restored.message(for: .perfectScore, locale: "ru"), "ru perfect")
        await restored.refreshIfNeeded(locale: "ru")
        let requests = await api.requests
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.locale, "ru")
    }

    func testExpiredCacheUsesETagAnd304RenewsPersistedFreshness() async {
        let api = ResultMessagesAPIStub { locale, etag in
            etag == nil ? Self.catalog(locale: locale) : .notModified(etag: nil)
        }
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "en-US")
        clock.date.addTimeInterval(86_400)
        await repository.refreshIfNeeded(locale: "en")
        clock.date.addTimeInterval(86_399)
        let restored = makeRepository(api)
        await restored.refreshIfNeeded(locale: "en")
        XCTAssertEqual(restored.message(for: .perfectScore, locale: "en"), "en perfect")
        let requests = await api.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.last?.etag, "v1")
    }

    func test304WithoutBodyRetriesUnconditionally() async {
        let api = ResultMessagesAPIStub { locale, _ in Self.catalog(locale: locale) }
        await api.returnNotModifiedOnce()
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "ru")
        let requests = await api.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertTrue(requests.allSatisfy { $0.etag == nil })
        XCTAssertEqual(repository.message(for: .perfectScore, locale: "ru"), "ru perfect")
    }

    func testRepeated304WithoutBodyStopsAfterOneRetry() async {
        let api = ResultMessagesAPIStub { _, _ in .notModified(etag: "orphan") }
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "ru")
        let requests = await api.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertNil(repository.message(for: .perfectScore, locale: "ru"))
    }

    func testFailureKeepsExpiredSameLanguageCache() async {
        await makeRepository(ResultMessagesAPIStub { locale, _ in Self.catalog(locale: locale) })
            .refreshIfNeeded(locale: "ru")
        clock.date.addTimeInterval(90_000)
        let repository = makeRepository(ResultMessagesAPIStub { _, _ in throw URLError(.timedOut) })
        await repository.refreshIfNeeded(locale: "ru")
        XCTAssertEqual(repository.message(for: .perfectScore, locale: "ru"), "ru perfect")
        XCTAssertNil(repository.message(for: .perfectScore, locale: "fr"))
    }

    func testNew200ReplacesCatalogAndETag() async {
        await makeRepository(ResultMessagesAPIStub { locale, _ in Self.catalog(locale: locale) })
            .refreshIfNeeded(locale: "ru")
        clock.date.addTimeInterval(90_000)
        let api = ResultMessagesAPIStub { locale, _ in
            .modified(.init(locale: locale, messages: ["low_score": ["new"]]), etag: "v2")
        }
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "ru")
        XCTAssertEqual(repository.message(for: .lowScore, locale: "ru"), "new")
        XCTAssertNil(repository.message(for: .perfectScore, locale: "ru"))
        clock.date.addTimeInterval(90_000)
        await repository.refreshIfNeeded(locale: "ru")
        let requests = await api.requests
        XCTAssertEqual(requests.map(\.etag), ["v1", "v2"])
    }

    func testSanitizesUnknownEmptyAndDuplicatePhrasesAndAvoidsRepeats() async {
        let api = ResultMessagesAPIStub { locale, _ in
            .modified(.init(locale: locale, messages: [
                "perfect_score": [" A ", "A", "B", "  "],
                "low_score": [], "high_score": ["\n"], "future_category": ["unknown"]
            ]), etag: nil)
        }
        let repository = makeRepository(api)
        await repository.refreshIfNeeded(locale: "ru")
        var previous: String?
        for _ in 0..<20 {
            let phrase = repository.message(for: .perfectScore, locale: "ru")
            XCTAssertTrue(["A", "B"].contains(phrase ?? ""))
            XCTAssertNotEqual(phrase, previous)
            previous = phrase
        }
        XCTAssertNil(repository.message(for: .lowScore, locale: "ru"))
        XCTAssertNil(repository.message(for: .strongResult, locale: "ru"))
    }

    func testWrongLocaleAndUnusableResponsesDoNotReplaceLastGoodCatalog() async {
        await makeRepository(ResultMessagesAPIStub { locale, _ in Self.catalog(locale: locale) })
            .refreshIfNeeded(locale: "ru")
        clock.date.addTimeInterval(90_000)
        for catalog in [
            BackendResultMessagesResponse(locale: "de", messages: ["perfect_score": ["wrong language"]]),
            BackendResultMessagesResponse(locale: "ru", messages: ["unknown": ["text"], "perfect_score": []])
        ] {
            let repository = makeRepository(ResultMessagesAPIStub { _, _ in .modified(catalog, etag: "bad") })
            await repository.refreshIfNeeded(locale: "ru")
            XCTAssertEqual(repository.message(for: .perfectScore, locale: "ru"), "ru perfect")
        }
    }

    func testConcurrentRequestsCoalesceAndLocalesRemainIsolated() async {
        let gate = ResultMessagesGate()
        let api = ResultMessagesAPIStub { locale, _ in
            if locale == "ru" { await gate.wait() }
            return Self.catalog(locale: locale)
        }
        let repository = makeRepository(api)
        let first = Task { await repository.refreshIfNeeded(locale: "ru") }
        await gate.waitUntilStarted()
        let second = Task { await repository.refreshIfNeeded(locale: "ru-RU") }
        await repository.refreshIfNeeded(locale: "en")
        XCTAssertEqual(repository.message(for: .perfectScore, locale: "en"), "en perfect")
        XCTAssertNil(repository.message(for: .perfectScore, locale: "ru"))
        await gate.release()
        await first.value
        await second.value
        let requests = await api.requests
        XCTAssertEqual(requests.filter { $0.locale == "ru" }.count, 1)
        XCTAssertEqual(repository.message(for: .perfectScore, locale: "en"), "en perfect")
        XCTAssertEqual(repository.message(for: .perfectScore, locale: "ru"), "ru perfect")
    }

    func testAllCategoriesAndBoundaryScores() {
        let cases: [(Int, Int, ResultMessageCategory)] = [
            (0, 100, .veryLowScore), (14, 100, .veryLowScore), (15, 100, .lowScore),
            (29, 100, .lowScore), (30, 100, .mediumLowScore), (49, 100, .mediumLowScore),
            (50, 100, .mediumScore), (74, 100, .mediumScore), (75, 100, .strongResult),
            (99, 100, .strongResult), (100, 100, .perfectScore), (0, 0, .noQuestions),
            (-1, 5, .invalidScore), (6, 5, .invalidScore), (0, -1, .invalidScore), (1, 0, .invalidScore)
        ]
        for (correct, total, category) in cases {
            XCTAssertEqual(ResultMessageCategory.resolve(correctAnswers: correct, totalQuestions: total), category)
        }
    }

    func testPresenterSelectsOnceAndUsesFallbackWhenCategoryMissing() {
        let provider = ResultMessageProviderSpy()
        let presenter = QuizResultPresenter(
            result: .init(correctAnswers: 5, totalQuestions: 5), session: QuizSessionStore(themes: { nil }),
            messages: provider, locale: "ru"
        )
        provider.text = "changed after creation"
        let view = ResultMessagesViewSpy()
        presenter.view = view
        presenter.viewDidLoad()
        presenter.viewDidLoad()
        XCTAssertEqual(view.descriptionTexts, ["remote", "remote"])
        XCTAssertEqual(provider.calls, 1)
        provider.text = nil
        let fallback = QuizResultPresenter(
            result: .init(correctAnswers: 3, totalQuestions: 5), session: QuizSessionStore(themes: { nil }),
            messages: provider, locale: "ru"
        )
        fallback.view = view
        fallback.viewDidLoad()
        XCTAssertEqual(view.descriptionTexts.last, L10n.Result.mediumScoreDescription)
    }

    func testHTTPPublicRequestAnd200304Contract() async throws {
        let api = try makeHTTPAPI()
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/result-messages")
            XCTAssertEqual(request.url?.query, "locale=ru")
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertEqual(request.value(forHTTPHeaderField: "If-None-Match"), "v1")
            return (try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: 304,
                                                 httpVersion: nil, headerFields: ["ETag": "v1"])), Data())
        }
        guard case .notModified(etag: "v1") = try await api.fetchResultMessages(locale: "ru", etag: "v1") else {
            return XCTFail("Expected 304")
        }
        BackendTestURLProtocol.requestHandler = { request in
            XCTAssertNil(request.value(forHTTPHeaderField: "If-None-Match"))
            return (try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: 200,
                                                 httpVersion: nil, headerFields: ["ETag": "v2"])),
                    Data(#"{"locale":"ru","messages":{"perfect_score":["Great"]}}"#.utf8))
        }
        guard case let .modified(catalog, etag) = try await api.fetchResultMessages(locale: "ru", etag: nil) else {
            return XCTFail("Expected catalog")
        }
        XCTAssertEqual(catalog.messages["perfect_score"], ["Great"])
        XCTAssertEqual(etag, "v2")
    }

    func testHTTPRejectsInvalidBodiesAndOldServer() async throws {
        let api = try makeHTTPAPI()
        for (status, body) in [
            (200, #"{"locale":"en","messages":{"perfect_score":["Wrong"]}}"#),
            (200, #"{"locale":"ru","messages":{"perfect_score":[" "]}}"#),
            (200, "invalid json"), (404, "")
        ] {
            BackendTestURLProtocol.requestHandler = { request in
                (try XCTUnwrap(HTTPURLResponse(url: request.url!, statusCode: status,
                                              httpVersion: nil, headerFields: nil)), Data(body.utf8))
            }
            do {
                _ = try await api.fetchResultMessages(locale: "ru", etag: nil)
                XCTFail("Expected rejection")
            } catch { XCTAssertTrue(error is BackendContentError) }
        }
    }

    private func makeRepository(_ api: ResultMessagesAPI) -> ResultMessagesRepository {
        ResultMessagesRepository(api: api, directory: directory, now: { self.clock.date })
    }

    private func makeHTTPAPI() throws -> HTTPResultMessagesAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendTestURLProtocol.self]
        return HTTPResultMessagesAPI(
            configuration: BackendConfiguration(baseURL: try XCTUnwrap(URL(string: "https://example.com/api"))),
            session: URLSession(configuration: configuration)
        )
    }

    private static func catalog(locale: String) -> ResultMessagesFetchResult {
        .modified(.init(locale: locale, messages: ["perfect_score": ["\(locale) perfect"]]), etag: "v1")
    }
}

private final class ResultMessagesTestClock {
    var date = Date(timeIntervalSince1970: 1_000_000)
}

private actor ResultMessagesAPIStub: ResultMessagesAPI {
    struct Request { let locale: String; let etag: String? }
    private(set) var requests: [Request] = []
    private var notModifiedOnce = false
    private let handler: (String, String?) async throws -> ResultMessagesFetchResult

    init(handler: @escaping (String, String?) async throws -> ResultMessagesFetchResult) { self.handler = handler }
    func returnNotModifiedOnce() { notModifiedOnce = true }

    func fetchResultMessages(locale: String, etag: String?) async throws -> ResultMessagesFetchResult {
        requests.append(Request(locale: locale, etag: etag))
        if notModifiedOnce {
            notModifiedOnce = false
            return .notModified(etag: "v1")
        }
        return try await handler(locale, etag)
    }
}

private actor ResultMessagesGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private var started = false
    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            started = true
        }
    }
    func waitUntilStarted() async {
        while !started { await Task.yield() }
    }
    func release() { continuation?.resume(); continuation = nil }
}

private final class ResultMessageProviderSpy: ResultMessageProviding {
    var text: String? = "remote"
    var calls = 0
    func message(for category: ResultMessageCategory, locale: String) -> String? {
        calls += 1
        return text
    }
}

private final class ResultMessagesViewSpy: QuizResultViewControllerProtocol {
    var presenter: QuizResultPresenterProtocol?
    var descriptionTexts: [String] = []
    func updateResultLabels(resultText: String, descriptionText: String) {
        descriptionTexts.append(descriptionText)
    }
}
