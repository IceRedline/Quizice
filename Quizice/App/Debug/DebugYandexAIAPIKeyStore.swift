#if DEBUG
import Foundation
import Security

enum DebugYandexAIAPIKeyStore {
    private static let environmentKey = "YANDEX_AI_API_KEY"
    private static let service = "ru.avtabenskiy.Quizice.debug-yandex-ai"
    private static let account = environmentKey

    static func cacheEnvironmentAPIKeyIfPresent() {
        guard let environmentValue = environmentAPIKey() else { return }
        save(environmentValue)
        AppLog.quiz.info("Yandex AI API key cached from Xcode environment")
    }

    static func resolveAPIKey() -> String? {
        if let environmentValue = environmentAPIKey() {
            save(environmentValue)
            AppLog.quiz.info("Yandex AI API key loaded from Xcode environment")
            return environmentValue
        }

        guard let storedValue = load() else {
            AppLog.quiz.error("Yandex AI API key is missing from both environment and Debug Keychain")
            return nil
        }

        AppLog.quiz.info("Yandex AI API key loaded from Debug Keychain")
        return storedValue
    }

    private static func environmentAPIKey() -> String? {
        guard
            let value = ProcessInfo.processInfo.environment[environmentKey]?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            return nil
        }
        return value
    }

    static func removeRejectedAPIKey() {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status != errSecSuccess, status != errSecItemNotFound else {
            AppLog.quiz.info("Rejected Yandex AI API key removed from Debug Keychain")
            return
        }
        AppLog.quiz.error("Failed to remove rejected Yandex AI API key from Debug Keychain: status=\(status, privacy: .public)")
    }

    private static func save(_ value: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: Data(value.utf8),
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]

        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }

        if status != errSecSuccess {
            AppLog.quiz.error("Failed to save Yandex AI API key to Debug Keychain: status=\(status, privacy: .public)")
        }
    }

    private static func load() -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            AppLog.quiz.error("Failed to load Yandex AI API key from Debug Keychain: status=\(status, privacy: .public)")
            return nil
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else {
            AppLog.quiz.error("Yandex AI API key in Debug Keychain has invalid data")
            return nil
        }
        return value
    }
}
#endif
