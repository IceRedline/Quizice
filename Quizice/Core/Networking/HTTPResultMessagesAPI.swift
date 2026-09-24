import Foundation

struct BackendResultMessagesResponse: Codable, Equatable {
    let locale: String
    let messages: [String: [String]]

    var usableMessages: [String: [String]] {
        messages.reduce(into: [:]) { result, entry in
            guard ResultMessageCategory(rawValue: entry.key) != nil else { return }
            let phrases = entry.value.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            if !phrases.isEmpty {
                result[entry.key] = Array(Set(phrases)).sorted()
            }
        }
    }
}

enum ResultMessagesFetchResult {
    case modified(BackendResultMessagesResponse, etag: String?)
    case notModified(etag: String?)
}

protocol ResultMessagesAPI {
    func fetchResultMessages(locale: String, etag: String?) async throws -> ResultMessagesFetchResult
}

final class HTTPResultMessagesAPI: ResultMessagesAPI {
    private let baseURL: URL
    private let session: URLSession

    init(configuration: BackendConfiguration, session: URLSession = .shared) {
        baseURL = configuration.baseURL
        self.session = session
    }

    func fetchResultMessages(locale: String, etag: String?) async throws -> ResultMessagesFetchResult {
        guard AppLanguagePreference.explicitPreference(for: locale) != nil,
              var components = URLComponents(
                url: baseURL.appendingPathComponent("v1/result-messages"),
                resolvingAgainstBaseURL: false
              ) else { throw BackendContentError.invalidRequest }
        components.queryItems = [URLQueryItem(name: "locale", value: locale)]
        guard let url = components.url else { throw BackendContentError.invalidRequest }
        // The repository owns freshness and keeps the last usable body for offline use.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(etag, forHTTPHeaderField: "If-None-Match")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw BackendContentError.invalidResponse }
        let responseETag = response.value(forHTTPHeaderField: "ETag")
        if response.statusCode == 304 { return .notModified(etag: responseETag) }
        guard response.statusCode == 200 else {
            throw BackendContentError.httpStatus(response.statusCode, nil)
        }
        guard data.count <= 10 * 1024 * 1024 else { throw BackendContentError.contractViolation }
        let catalog: BackendResultMessagesResponse
        do {
            catalog = try JSONDecoder().decode(BackendResultMessagesResponse.self, from: data)
        } catch {
            throw BackendContentError.decoding
        }
        guard catalog.locale == locale, !catalog.usableMessages.isEmpty else {
            throw BackendContentError.contractViolation
        }
        return .modified(catalog, etag: responseETag)
    }
}
