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
        return configuration(from: bundle.object(forInfoDictionaryKey: infoPlistKey))
    }

    static func configuration(from rawValue: Any?) -> BackendConfiguration? {
        guard let rawValue = rawValue as? String else { return nil }
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false, value.contains("$(") == false, let url = URL(string: value) else {
            return nil
        }
        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let scheme = components.scheme?.lowercased(),
            let host = components.host?.lowercased(),
            host.isEmpty == false
        else {
            return nil
        }

        #if DEBUG
        let isAllowedLocalhost = scheme == "http" && host == "localhost"
        #else
        let isAllowedLocalhost = false
        #endif
        guard scheme == "https" || isAllowedLocalhost else { return nil }

        return BackendConfiguration(baseURL: url)
    }
}

#if DEBUG
enum DebugBackendSettings {
    static let useLocalhostKey = "quizice.debug.backend.use-localhost"
    static let localhostBaseURL = URL(string: "http://localhost:8000/api")!

    static var shouldShowSourceIndicators: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["XCTestConfigurationFilePath"] == nil
            && environment["QUIZICE_XCTEST_SMOKE_HOST"] != "1"
            && NSClassFromString("XCTestCase") == nil
    }
}
#endif
