import Foundation

struct AIQuizRuntimeDependencies {
    let accessProvider: AIQuizAccessProviding
    let themeService: AIQuizThemeServiceProtocol

    static func live(
        backendConfiguration: BackendConfiguration? = BackendConfiguration.load(),
        backendAccessProvider: AIQuizAccessProviding = AIQuizAccessStore.shared,
        metrics: BackendRequestMetricRecording = AppMetricaAnalyticsTracker.shared
    ) -> AIQuizRuntimeDependencies {
#if DEBUG && targetEnvironment(simulator)
        resolve(
            isDebugSimulator: true,
            backendConfiguration: backendConfiguration,
            backendAccessProvider: backendAccessProvider,
            simulatorAPIKeyProvider: DebugYandexAIAPIKeyStore.resolveAPIKey,
            simulatorUnauthorizedHandler: DebugYandexAIAPIKeyStore.removeRejectedAPIKey,
            metrics: metrics
        )
#else
        resolve(
            isDebugSimulator: false,
            backendConfiguration: backendConfiguration,
            backendAccessProvider: backendAccessProvider,
            simulatorAPIKeyProvider: { nil },
            simulatorUnauthorizedHandler: {},
            metrics: metrics
        )
#endif
    }

    static func resolve(
        isDebugSimulator: Bool,
        backendConfiguration: BackendConfiguration?,
        backendAccessProvider: AIQuizAccessProviding,
        simulatorAPIKeyProvider: () -> String?,
        simulatorUnauthorizedHandler: @escaping () -> Void,
        metrics: BackendRequestMetricRecording = NoopBackendRequestMetricRecorder()
    ) -> AIQuizRuntimeDependencies {
        if isDebugSimulator {
            AppLog.quiz.notice("🧪 AI SIMULATOR FALLBACK: direct Yandex service selected")
            return AIQuizRuntimeDependencies(
                accessProvider: AlwaysAvailableAIQuizAccessProvider(),
                themeService: YandexAIQuizThemeService(
                    apiKey: simulatorAPIKeyProvider(),
                    onUnauthorized: simulatorUnauthorizedHandler
                )
            )
        }

        guard let backendConfiguration else {
            return AIQuizRuntimeDependencies(
                accessProvider: backendAccessProvider,
                themeService: UnavailableAIQuizThemeService()
            )
        }

        return AIQuizRuntimeDependencies(
            accessProvider: backendAccessProvider,
            themeService: BackendAIQuizThemeService(
                configuration: backendConfiguration,
                metrics: metrics,
                accessProvider: backendAccessProvider
            )
        )
    }
}

private final class AlwaysAvailableAIQuizAccessProvider: AIQuizAccessProviding {
    let isAIQuizAvailable = true
}

private final class UnavailableAIQuizThemeService: AIQuizThemeServiceProtocol {
    func generateQuizTheme(
        configuration: AIQuizGenerationConfiguration
    ) async throws -> QuizTheme {
        throw YandexAIQuizThemeServiceError.authenticationRequired
    }
}
