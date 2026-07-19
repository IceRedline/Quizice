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
}

final class RecordingBackendContentAPI: BackendContentAPI {
    private(set) var seeds: [String] = []

    func fetchThemes(locale: String) async throws -> BackendThemeCatalogResponse {
        BackendThemeCatalogResponse(locale: locale, themes: [])
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
                    description: "Remote Description"
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
}
