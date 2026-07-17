import Foundation
import Security

protocol KeychainClient {
    func loadData(service: String, account: String) throws -> Data?
    func saveData(_ data: Data, service: String, account: String) throws
    func deleteData(service: String, account: String) throws
}

enum KeychainClientError: Error, Equatable {
    case status(OSStatus)
}

struct SecurityKeychainClient: KeychainClient {
    func loadData(service: String, account: String) throws -> Data? {
        var query = baseQuery(service: service, account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainClientError.status(status)
        }
        return data
    }

    func saveData(_ data: Data, service: String, account: String) throws {
        let query = baseQuery(service: service, account: account)
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else {
            throw KeychainClientError.status(status)
        }
    }

    func deleteData(service: String, account: String) throws {
        let status = SecItemDelete(baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainClientError.status(status)
        }
    }

    private func baseQuery(service: String, account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

final class KeychainSessionStore: SessionStoring {
    private let service: String
    private let account = "game-center-session"
    private let client: KeychainClient
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        service: String = "ru.avtabenskiy.Quizice.auth",
        client: KeychainClient = SecurityKeychainClient()
    ) {
        self.service = service
        self.client = client
    }

    func load() throws -> AuthSession? {
        let data: Data?
        do {
            data = try client.loadData(service: service, account: account)
        } catch {
            throw mapClientError(error)
        }
        guard let data else { return nil }

        do {
            return try decoder.decode(AuthSession.self, from: data)
        } catch {
            try? clear()
            throw KeychainSessionStoreError.invalidData
        }
    }

    func save(_ session: AuthSession) throws {
        let data: Data
        do {
            data = try encoder.encode(session)
        } catch {
            throw KeychainSessionStoreError.invalidData
        }

        do {
            try client.saveData(data, service: service, account: account)
        } catch {
            throw mapClientError(error)
        }
    }

    func clear() throws {
        do {
            try client.deleteData(service: service, account: account)
        } catch {
            throw mapClientError(error)
        }
    }

    private func mapClientError(_ error: Error) -> Error {
        guard case let KeychainClientError.status(status) = error else { return error }
        return KeychainSessionStoreError.status(status)
    }
}

enum KeychainSessionStoreError: Error, Equatable {
    case status(OSStatus)
    case invalidData
}
