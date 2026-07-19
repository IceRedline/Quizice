import XCTest
@testable import Quizice

final class LiveBackendContractTests: XCTestCase {
    private let productionOrigin = URL(
        string: "https://bbav8b1v6032q53l8360.containers.yandexcloud.net"
    )!

    func testHealthReadinessAndReportLatency() async throws {
        try requireLiveTests()
        let session = makeSession()
        let healthURL = productionOrigin.appendingPathComponent("health")
        let readinessURL = productionOrigin.appendingPathComponent("readiness")
        try await assertStatusJSON(
            url: healthURL,
            expected: ["status": "alive"],
            session: session
        )
        try await assertStatusJSON(
            url: readinessURL,
            expected: ["status": "ready"],
            session: session
        )

        let backendURL = liveBackendURL
        let themesURL = try XCTUnwrap(
            URL(string: backendURL.appendingPathComponent("v1/themes").absoluteString + "?locale=en")
        )
        let questionsURL = try XCTUnwrap(
            URL(
                string: backendURL.appendingPathComponent("v1/themes/music/questions").absoluteString
                    + "?count=5&locale=en&seed=550e8400-e29b-41d4-a716-446655440000"
            )
        )

        try await reportLatency(operation: "health", url: healthURL, session: session)
        try await reportLatency(operation: "themes", url: themesURL, session: session)
        try await reportLatency(operation: "questions", url: questionsURL, session: session)
    }

    func testFuturePublicContentContract() async throws {
        try requireLiveTests()
        let contentAPI = HTTPBackendContentAPI(
            configuration: BackendConfiguration(baseURL: liveBackendURL),
            session: makeSession()
        )
        let themes = try await contentAPI.fetchThemes(locale: "en")
        XCTAssertFalse(themes.themes.isEmpty)
        let firstTheme = try XCTUnwrap(themes.themes.first)
        let seed = "550e8400-e29b-41d4-a716-446655440000"
        let questions = try await contentAPI.fetchQuestions(
            themeID: firstTheme.id,
            count: 5,
            locale: "en",
            seed: seed
        )
        XCTAssertEqual(questions.questions.count, 5)
    }

    func testFutureAIContractRejectsGuestBeforeGeneration() async throws {
        try requireLiveTests()
        let session = makeSession()
        let url = liveBackendURL
            .appendingPathComponent("v1")
            .appendingPathComponent("quizzes")
            .appendingPathComponent("generate")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "topic": "European geography",
            "count": 5,
            "locale": "en",
            "difficulty": "medium"
        ])

        let (data, response) = try await session.data(for: request)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        guard httpResponse.statusCode == 401 else {
            XCTFail("Guest AI generation must return 401, got \(httpResponse.statusCode)")
            return
        }

        let envelope = try JSONDecoder().decode(BackendErrorEnvelope.self, from: data)
        XCTAssertEqual(envelope.code, "unauthorized")
        XCTAssertFalse(envelope.message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        let requestID = try XCTUnwrap(envelope.requestId)
        XCTAssertNotNil(UUID(uuidString: requestID))
        XCTAssertEqual(httpResponse.value(forHTTPHeaderField: "X-Request-Id"), requestID)
    }

    private var liveBackendURL: URL {
        ProcessInfo.processInfo.environment["QUIZICE_LIVE_BACKEND_URL"]
            .flatMap(URL.init(string:))
            ?? productionOrigin.appendingPathComponent("api")
    }

    private func requireLiveTests() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["QUIZICE_RUN_LIVE_BACKEND_TESTS"] == "1",
            "Set QUIZICE_RUN_LIVE_BACKEND_TESTS=1 to probe the deployed backend."
        )
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        return URLSession(configuration: configuration)
    }

    private func reportLatency(
        operation: String,
        url: URL,
        session: URLSession
    ) async throws {
        // This production smoke is deliberately report-only: stable latency gates
        // belong to the production-like backend load suite documented in the handoff.
        let firstSample = try await timedGET(url: url, session: session)
        var samples: [Double] = []
        for _ in 0..<10 {
            samples.append(try await timedGET(url: url, session: session))
        }
        let sorted = samples.sorted()
        let median = percentile(0.5, sortedSamples: sorted)
        let p95 = percentile(0.95, sortedSamples: sorted)
        print(
            "LIVE_BACKEND_LATENCY operation=\(operation) samples=10 "
                + "first_ms=\(String(format: "%.1f", firstSample)) "
                + "median_ms=\(String(format: "%.1f", median)) "
                + "p95_ms=\(String(format: "%.1f", p95)) "
                + "max_ms=\(String(format: "%.1f", sorted.last ?? 0))"
        )
    }

    private func assertStatusJSON(
        url: URL,
        expected: [String: String],
        session: URLSession
    ) async throws {
        let (data, response) = try await session.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: String])
        XCTAssertEqual(json, expected)
    }

    private func timedGET(url: URL, session: URLSession) async throws -> Double {
        let clock = ContinuousClock()
        let startedAt = clock.now
        let (_, response) = try await session.data(from: url)
        let httpResponse = try XCTUnwrap(response as? HTTPURLResponse)
        XCTAssertEqual(httpResponse.statusCode, 200)
        let components = (clock.now - startedAt).components
        return Double(components.seconds) * 1_000
            + Double(components.attoseconds) / 1_000_000_000_000_000
    }

    private func percentile(_ percentile: Double, sortedSamples: [Double]) -> Double {
        guard !sortedSamples.isEmpty else { return 0 }
        let index = Int(
            (Double(sortedSamples.count - 1) * min(max(percentile, 0), 1)).rounded(.up)
        )
        return sortedSamples[index]
    }
}
