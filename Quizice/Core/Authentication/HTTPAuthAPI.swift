import Foundation

final class HTTPAuthAPI: AuthAPI {
    private enum Endpoint {
        static let gameCenterAuth = "v1/auth/game-center"
        static let statisticsSync = "v1/me/statistics/sync"
    }

    private struct AuthResponse: Decodable {
        let userId: String
        let accessToken: String
        let expiresAt: Date
    }

    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let requestTimeout: TimeInterval
    private let now: () -> Date
    private let metrics: BackendRequestMetricRecording
    private let clock = ContinuousClock()

    init(
        configuration: BackendConfiguration,
        session: URLSession = .shared,
        requestTimeout: TimeInterval = 15,
        now: @escaping () -> Date = Date.init,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder()
    ) {
        baseURL = configuration.baseURL
        self.session = session
        self.requestTimeout = requestTimeout
        self.now = now
        self.metrics = metrics
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            try Self.decodeISO8601Date(from: decoder)
        }
    }

    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        try await post(
            path: Endpoint.gameCenterAuth,
            body: identity,
            accessToken: nil,
            operation: .authentication
        ) { [now] (response: AuthResponse) in
            guard
                response.userId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                response.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
                response.expiresAt > now()
            else {
                throw BackendAPIError.contractViolation
            }
            return AuthSession(
                userID: response.userId,
                accessToken: response.accessToken,
                expiresAt: response.expiresAt,
                teamPlayerID: identity.teamPlayerId
            )
        }
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        try await post(
            path: Endpoint.statisticsSync,
            body: request,
            accessToken: accessToken,
            operation: .statisticsSync
        ) { (response: StatisticsStore.SyncResponse) in
            guard Self.isValid(response: response, for: request) else {
                throw BackendAPIError.contractViolation
            }
            return response
        }
    }

    private func post<Body: Encodable, Response: Decodable, Output>(
        path: String,
        body: Body,
        accessToken: String?,
        operation: BackendOperation,
        transform: (Response) throws -> Output
    ) async throws -> Output {
        try Task.checkCancellation()
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.timeoutInterval = requestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw BackendAPIError.encoding
        }

        let startedAt = clock.now
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            record(operation, result: .cancelled, startedAt: startedAt)
            throw CancellationError()
        } catch let error as URLError {
            if Task.isCancelled || error.code == .cancelled {
                record(operation, result: .cancelled, startedAt: startedAt)
                throw CancellationError()
            }
            record(operation, result: .transportError, startedAt: startedAt)
            throw BackendAPIError.transport(error.code)
        } catch {
            if Task.isCancelled {
                record(operation, result: .cancelled, startedAt: startedAt)
                throw CancellationError()
            }
            record(operation, result: .transportError, startedAt: startedAt)
            throw BackendAPIError.transport(.unknown)
        }
        do {
            try Task.checkCancellation()
        } catch {
            record(
                operation,
                result: .cancelled,
                startedAt: startedAt,
                responseBytes: data.count
            )
            throw CancellationError()
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            record(
                operation,
                result: .transportError,
                startedAt: startedAt,
                responseBytes: data.count
            )
            throw BackendAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data)
            record(
                operation,
                result: .httpError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            if httpResponse.statusCode == 401 {
                throw BackendAPIError.unauthorized(envelope)
            }
            throw BackendAPIError.httpStatus(httpResponse.statusCode, envelope)
        }
        let decoded: Response
        do {
            decoded = try decoder.decode(Response.self, from: data)
        } catch {
            record(
                operation,
                result: .decodingError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw BackendAPIError.decoding
        }
        do {
            let output = try transform(decoded)
            record(
                operation,
                result: .success,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            return output
        } catch is CancellationError {
            record(
                operation,
                result: .cancelled,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw CancellationError()
        } catch {
            record(
                operation,
                result: .contractError,
                startedAt: startedAt,
                statusCode: httpResponse.statusCode,
                responseBytes: data.count
            )
            throw error
        }
    }

    private func record(
        _ operation: BackendOperation,
        result: BackendRequestResult,
        startedAt: ContinuousClock.Instant,
        statusCode: Int? = nil,
        responseBytes: Int = 0
    ) {
        let components = (clock.now - startedAt).components
        metrics.record(
            BackendRequestMetric(
                operation: operation,
                result: result,
                durationMilliseconds: max(
                    Int(
                        components.seconds * 1_000
                            + components.attoseconds / 1_000_000_000_000_000
                    ),
                    0
                ),
                statusCode: statusCode,
                responseBytes: responseBytes
            )
        )
    }

    private static func decodeISO8601Date(from decoder: Decoder) throws -> Date {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)
        let formatter = ISO8601DateFormatter()

        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: value) {
            return date
        }

        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Expected an RFC3339/ISO-8601 date."
        )
    }

    private static func isValid(
        response: StatisticsStore.SyncResponse,
        for request: StatisticsStore.SyncRequest
    ) -> Bool {
        let summary = response.summary
        let values = [
            summary.playedQuizzes,
            summary.correctAnswers,
            summary.totalQuestions,
            summary.bestCorrectAnswers,
            summary.bestTotalQuestions
        ]
        guard
            values.allSatisfy({ $0 >= 0 }),
            summary.correctAnswers <= summary.totalQuestions,
            summary.bestCorrectAnswers <= summary.bestTotalQuestions,
            summary.bestCorrectAnswers <= summary.correctAnswers,
            summary.bestTotalQuestions <= summary.totalQuestions
        else {
            return false
        }

        if summary.playedQuizzes == 0 {
            guard values.allSatisfy({ $0 == 0 }) else { return false }
        } else {
            guard summary.totalQuestions > 0, summary.bestTotalQuestions > 0 else { return false }
        }

        let acceptedIDs = response.acceptedAttemptIds
        let requestIDs = Set(request.attempts.map(\.id))
        return
            Set(acceptedIDs).count == acceptedIDs.count &&
            acceptedIDs.allSatisfy { $0.isEmpty == false } &&
            Set(acceptedIDs) == requestIDs
    }
}

struct UnavailableAuthAPI: AuthAPI {
    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        throw BackendAPIError.configurationMissing
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        throw BackendAPIError.configurationMissing
    }
}
