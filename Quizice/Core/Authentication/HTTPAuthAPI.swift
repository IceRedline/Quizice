import Foundation

final class HTTPAuthAPI: AuthAPI {
    // TODO(BACKEND_CONTRACT): replace provisional routes and DTOs when backend contract is finalized.
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

    init(configuration: BackendConfiguration, session: URLSession = .shared) {
        baseURL = configuration.baseURL
        self.session = session
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func authenticate(identity: GameCenterIdentity) async throws -> AuthSession {
        let response: AuthResponse = try await post(
            path: Endpoint.gameCenterAuth,
            body: identity,
            accessToken: nil
        )
        return AuthSession(
            userID: response.userId,
            accessToken: response.accessToken,
            expiresAt: response.expiresAt,
            teamPlayerID: identity.teamPlayerId
        )
    }

    func syncStatistics(
        request: StatisticsStore.SyncRequest,
        accessToken: String
    ) async throws -> StatisticsStore.SyncResponse {
        try await post(
            path: Endpoint.statisticsSync,
            body: request,
            accessToken: accessToken
        )
    }

    private func post<Body: Encodable, Response: Decodable>(
        path: String,
        body: Body,
        accessToken: String?
    ) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw BackendAPIError.decoding
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError {
            throw BackendAPIError.transport(error.code)
        } catch {
            throw BackendAPIError.transport(.unknown)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let envelope = try? decoder.decode(BackendErrorEnvelope.self, from: data)
            if httpResponse.statusCode == 401 {
                throw BackendAPIError.unauthorized(envelope)
            }
            throw BackendAPIError.httpStatus(httpResponse.statusCode, envelope)
        }
        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw BackendAPIError.decoding
        }
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
