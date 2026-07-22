import Foundation
import XCTest
@testable import Quizice

final class BackendTestURLProtocol: URLProtocol {
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

final class BackendMetricSpy: BackendRequestMetricRecording {
    private(set) var values: [BackendRequestMetric] = []
    func record(_ metric: BackendRequestMetric) { values.append(metric) }
}

final class BackendMemorySessionStore: SessionStoring {
    var session: AuthSession?

    init(session: AuthSession? = nil) {
        self.session = session
    }

    func load() throws -> AuthSession? { session }
    func save(_ session: AuthSession) throws { self.session = session }
    func clear() throws { session = nil }
}

final class BackendScriptedSessionStore: SessionStoring {
    private var loadResults: [AuthSession?]
    private(set) var loadCount = 0

    init(loadResults: [AuthSession?]) {
        self.loadResults = loadResults
    }

    func load() throws -> AuthSession? {
        let index = min(loadCount, loadResults.count - 1)
        loadCount += 1
        return loadResults[index]
    }

    func save(_ session: AuthSession) throws {
        loadResults = [session]
        loadCount = 0
    }

    func clear() throws {
        loadResults = [nil]
        loadCount = 0
    }
}

final class BackendAIQuizAccessStub: AIQuizAccessUpdating {
    private(set) var isAIQuizAvailable: Bool

    init(isAvailable: Bool) {
        isAIQuizAvailable = isAvailable
    }

    func update(isAuthenticated: Bool) {
        isAIQuizAvailable = isAuthenticated
    }
}

struct SlowBackendContentAPI: BackendContentAPI {
    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw URLError(.timedOut)
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw URLError(.timedOut)
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        try await Task.sleep(nanoseconds: 1_000_000_000)
        throw URLError(.timedOut)
    }
}

final class RecordingBackendContentAPI: BackendContentAPI {
    private(set) var seeds: [String] = []
    private(set) var randomSelectionModes: [CrossThemeQuestionSelectionMode] = []
    private let catalogThemes: [BackendThemeDTO]

    init(catalogThemes: [BackendThemeDTO] = []) {
        self.catalogThemes = catalogThemes
    }

    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse {
        BackendThemeCatalogResponse(locale: locale, themes: catalogThemes)
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        seeds.append(seed)
        return BackendQuestionBatchResponse(
            locale: locale,
            seed: seed,
            questions: (0..<count).map { index in
                BackendQuestionDTO(
                    question: "Remote \(seed) \(index)",
                    answers: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                    correctAnswer: "B\(index)",
                    explanation: "Explanation"
                )
            }
        )
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        randomSelectionModes.append(selectionMode)
        return try await fetchQuestions(
            themeID: RandomQuizSelection.themeID,
            count: count,
            locale: locale,
            seed: seed
        )
    }
}

final class SequencedCatalogBackendContentAPI: BackendContentAPI {
    private var fetchCount = 0

    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse {
        defer { fetchCount += 1 }
        guard fetchCount == 0 else { throw URLError(.timedOut) }
        return BackendThemeCatalogResponse(
            locale: locale,
            themes: [
                BackendThemeDTO(
                    id: "music",
                    name: "Remote Music",
                    description: "Remote Description",
                    sfSymbol: "music.note.list",
                    emoji: "🎵",
                    colorHex: "#FF8252"
                )
            ]
        )
    }

    func fetchQuestions(
        themeID: String,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        throw URLError(.unsupportedURL)
    }

    func fetchRandomQuestions(
        selectionMode: CrossThemeQuestionSelectionMode,
        count: Int,
        locale: String,
        seed: String
    ) async throws -> BackendQuestionBatchResponse {
        throw URLError(.unsupportedURL)
    }
}

final class BackendRandomQuestionTests: XCTestCase {
    override func tearDown() {
        BackendTestURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testCrossThemeQuestionModesUseDocumentedEndpointsAndContract() async throws {
        let api = makeContentAPI()
        let seed = "550e8400-e29b-41d4-a716-446655440000"

        for selectionMode in CrossThemeQuestionSelectionMode.allCases {
            BackendTestURLProtocol.requestHandler = { request in
                XCTAssertEqual(request.url?.path, "/api/v1/questions/\(selectionMode.rawValue)")
                let query = try XCTUnwrap(
                    URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems
                )
                XCTAssertEqual(
                    Dictionary(uniqueKeysWithValues: query.compactMap { item in
                        item.value.map { (item.name, $0) }
                    }),
                    ["count": "5", "locale": "ru", "seed": seed]
                )
                let body = try JSONSerialization.data(withJSONObject: [
                    "locale": "ru",
                    "seed": seed,
                    "questions": (0..<5).map(Self.questionJSON)
                ])
                return Self.response(for: request, data: body)
            }

            let response = try await api.fetchRandomQuestions(
                selectionMode: selectionMode,
                count: 5,
                locale: "ru",
                seed: seed
            )
            XCTAssertEqual(response.questions.count, 5)
        }
    }

    func testRandomQuizPreparationForwardsBothSelectionModesToBackend() async throws {
        let backend = RecordingBackendContentAPI()
        let repository = ThemeCatalogRepository(backendContentAPI: backend)
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let localFallback = QuizTheme(
            id: RandomQuizSelection.themeID,
            theme: L10n.Home.randomSelection,
            themeDescription: L10n.Home.feelingLucky,
            questions: Self.localQuestions(count: 5)
        )

        for selectionMode in CrossThemeQuestionSelectionMode.allCases {
            let prepared = try await repository.prepareRandomQuiz(
                selectionMode: selectionMode,
                localFallback: localFallback,
                questionCount: 5,
                locale: locale
            )
            XCTAssertEqual(prepared.stableID, RandomQuizSelection.themeID)
            XCTAssertEqual(prepared.questionOrigin, .backend)
            XCTAssertEqual(prepared.questions.count, 5)
            XCTAssertTrue(prepared.questions.allSatisfy { $0.explanation == "Explanation" })
        }

        XCTAssertEqual(backend.randomSelectionModes, [.random, .randomBalanced])
        XCTAssertEqual(backend.seeds.count, 2)
        XCTAssertNotEqual(backend.seeds[0], backend.seeds[1])
    }

    private func makeContentAPI() -> HTTPBackendContentAPI {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [BackendTestURLProtocol.self]
        return HTTPBackendContentAPI(
            configuration: BackendConfiguration(
                baseURL: URL(string: "https://backend.example/api")!
            ),
            session: URLSession(configuration: configuration)
        )
    }

    private static func response(
        for request: URLRequest,
        data: Data
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
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

    private static func localQuestions(count: Int) -> [QuizQuestion] {
        (0..<count).map { index in
            QuizQuestion(
                question: "Local \(index)",
                answers: ["A\(index)", "B\(index)", "C\(index)", "D\(index)"],
                correctAnswer: "B\(index)"
            )
        }
    }
}
