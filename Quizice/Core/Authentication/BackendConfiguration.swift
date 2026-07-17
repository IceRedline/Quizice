import Foundation

struct BackendConfiguration: Equatable {
    static let infoPlistKey = "BackendBaseURL"

    let baseURL: URL

    static func load(
        bundle: Bundle = .main,
        userDefaults: UserDefaults = .standard
    ) -> BackendConfiguration? {
        #if DEBUG
        if userDefaults.bool(forKey: DebugBackendSettings.useLocalhostKey) {
            return BackendConfiguration(baseURL: DebugBackendSettings.localhostBaseURL)
        }
        #endif
        guard
            let rawValue = bundle.object(forInfoDictionaryKey: infoPlistKey) as? String
        else {
            return nil
        }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, value.contains("$(") == false, let url = URL(string: value) else {
            return nil
        }
        return BackendConfiguration(baseURL: url)
    }
}

#if DEBUG
enum DebugBackendSettings {
    static let useLocalhostKey = "quizice.debug.backend.use-localhost"
    static let localhostBaseURL = URL(string: "http://localhost:8000/api")!
}
#endif
