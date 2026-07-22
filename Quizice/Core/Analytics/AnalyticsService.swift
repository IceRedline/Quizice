import Foundation
import AppMetricaCore
import AppMetricaCrashes

protocol AnalyticsTracking: AnyObject {
    func track(_ event: AnalyticsEvent)
    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext)
}

enum AnalyticsScreen: String {
    case home
    case themeCardDescription = "quiz_description"
    case quizQuestion = "quiz_question"
    case quizResult = "quiz_result"
    case statistics
    case aiThemeCreation = "ai_theme_creation"
    case settings
}

enum AnalyticsSelectionMethod: String {
    case manual
    case random
    case ai
}

enum AnalyticsAnswerOutcome: String {
    case correct
    case incorrect
    case timeout
}

enum AnalyticsResultAction: String {
    case replay
    case themes
}

enum AnalyticsThemeCardFace: String {
    case front
    case back
}

enum AnalyticsSetting: String {
    case design
    case language
    case theme
    case icon
}

enum AnalyticsSettingsAction: String {
    case profile
    case feedback
}

enum AnalyticsTheme: Equatable {
    case catalog(id: String)
    case ai
    case unknown
}

extension ThemeModel {
    var analyticsTheme: AnalyticsTheme {
        isAIGenerated ? .ai : .catalog(id: themeID)
    }
}

struct AnalyticsQuizProgress: Equatable {
    let theme: AnalyticsTheme
    let answeredQuestions: Int
    let totalQuestions: Int
    let correctAnswers: Int
}

enum AnalyticsEvent {
    case screenView(screen: AnalyticsScreen, theme: AnalyticsTheme = .unknown)
    case themeSelected(theme: AnalyticsTheme, method: AnalyticsSelectionMethod)
    case themeCardFlipped(theme: AnalyticsTheme, visibleFace: AnalyticsThemeCardFace)
    case quizSetupCancelled(theme: AnalyticsTheme)
    case quizStarted(theme: AnalyticsTheme, questionCount: Int)
    case quizAnswered(theme: AnalyticsTheme, questionIndex: Int, totalQuestions: Int, outcome: AnalyticsAnswerOutcome)
    case quizExitRequested(AnalyticsQuizProgress)
    case quizExitCancelled(AnalyticsQuizProgress)
    case quizAbandoned(AnalyticsQuizProgress)
    case quizCompleted(theme: AnalyticsTheme, correctAnswers: Int, totalQuestions: Int)
    case quizResultAction(theme: AnalyticsTheme, action: AnalyticsResultAction)
    case statisticsViewed(attemptsCount: Int, totalQuestions: Int, accuracyPercent: Int)
    case aiGenerationStarted(locale: String, promptLength: Int, questionCount: Int, difficulty: AIQuizDifficulty)
    case aiGenerationSucceeded(locale: String, questionCount: Int, difficulty: AIQuizDifficulty, durationMilliseconds: Int)
    case aiGenerationFailed(locale: String, errorCode: String, durationMilliseconds: Int)
    case aiGenerationCancelled(locale: String, durationMilliseconds: Int)
    case backendRequestCompleted(BackendRequestMetric)
    case settingChanged(setting: AnalyticsSetting, oldValue: String, newValue: String)
    case settingsAction(AnalyticsSettingsAction)

    var name: String {
        switch self {
        case .screenView: return "screen_view"
        case .themeSelected: return "theme_selected"
        case .themeCardFlipped: return "theme_card_flipped"
        case .quizSetupCancelled: return "quiz_setup_cancelled"
        case .quizStarted: return "quiz_started"
        case .quizAnswered: return "quiz_answered"
        case .quizExitRequested: return "quiz_exit_requested"
        case .quizExitCancelled: return "quiz_exit_cancelled"
        case .quizAbandoned: return "quiz_abandoned"
        case .quizCompleted: return "quiz_completed"
        case .quizResultAction: return "quiz_result_action"
        case .statisticsViewed: return "statistics_viewed"
        case .aiGenerationStarted: return "ai_generation_started"
        case .aiGenerationSucceeded: return "ai_generation_succeeded"
        case .aiGenerationFailed: return "ai_generation_failed"
        case .aiGenerationCancelled: return "ai_generation_cancelled"
        case .backendRequestCompleted: return "backend_request_completed"
        case .settingChanged: return "setting_changed"
        case .settingsAction: return "settings_action"
        }
    }

    var parameters: [String: Any] {
        switch self {
        case let .screenView(screen, theme):
            return ["screen": screen.rawValue].merging(themeParameters(theme)) { current, _ in current }
        case let .themeSelected(theme, method):
            return ["selection_method": method.rawValue].merging(themeParameters(theme)) { current, _ in current }
        case let .themeCardFlipped(theme, visibleFace):
            return ["visible_face": visibleFace.rawValue].merging(themeParameters(theme)) { current, _ in current }
        case let .quizSetupCancelled(theme):
            return themeParameters(theme)
        case let .quizStarted(theme, questionCount):
            return ["question_count": questionCount].merging(themeParameters(theme)) { current, _ in current }
        case let .quizAnswered(theme, questionIndex, totalQuestions, outcome):
            return [
                "question_index": questionIndex,
                "total_questions": totalQuestions,
                "outcome": outcome.rawValue
            ].merging(themeParameters(theme)) { current, _ in current }
        case let .quizExitRequested(progress), let .quizExitCancelled(progress), let .quizAbandoned(progress):
            return progressParameters(progress)
        case let .quizCompleted(theme, correctAnswers, totalQuestions):
            return [
                "correct_answers": max(correctAnswers, 0),
                "total_questions": max(totalQuestions, 0),
                "score_percent": Self.percentage(correct: correctAnswers, total: totalQuestions)
            ].merging(themeParameters(theme)) { current, _ in current }
        case let .quizResultAction(theme, action):
            return ["action": action.rawValue].merging(themeParameters(theme)) { current, _ in current }
        case let .statisticsViewed(attemptsCount, totalQuestions, accuracyPercent):
            return [
                "attempts_count": max(attemptsCount, 0),
                "total_questions": max(totalQuestions, 0),
                "accuracy_percent": min(max(accuracyPercent, 0), 100)
            ]
        case let .aiGenerationStarted(locale, promptLength, questionCount, difficulty):
            return [
                "locale": locale,
                "prompt_length": max(promptLength, 0),
                "question_count": max(questionCount, 0),
                "difficulty": difficulty.rawValue
            ]
        case let .aiGenerationSucceeded(locale, questionCount, difficulty, durationMilliseconds):
            return [
                "locale": locale,
                "question_count": max(questionCount, 0),
                "difficulty": difficulty.rawValue,
                "duration_ms": max(durationMilliseconds, 0)
            ]
        case let .aiGenerationFailed(locale, errorCode, durationMilliseconds):
            return [
                "locale": locale,
                "error_code": errorCode,
                "duration_ms": max(durationMilliseconds, 0)
            ]
        case let .aiGenerationCancelled(locale, durationMilliseconds):
            return ["locale": locale, "duration_ms": max(durationMilliseconds, 0)]
        case let .backendRequestCompleted(metric):
            var parameters: [String: Any] = [
                "operation": metric.operation.rawValue,
                "result": metric.result.rawValue,
                "duration_ms": max(metric.durationMilliseconds, 0),
                "response_bytes": max(metric.responseBytes, 0)
            ]
            if let statusCode = metric.statusCode {
                parameters["status_class"] = "\(statusCode / 100)xx"
            }
            return parameters
        case let .settingChanged(setting, oldValue, newValue):
            return ["setting": setting.rawValue, "old_value": oldValue, "new_value": newValue]
        case let .settingsAction(action):
            return ["action": action.rawValue]
        }
    }

    private func progressParameters(_ progress: AnalyticsQuizProgress) -> [String: Any] {
        [
            "answered_questions": max(progress.answeredQuestions, 0),
            "total_questions": max(progress.totalQuestions, 0),
            "correct_answers": max(progress.correctAnswers, 0)
        ].merging(themeParameters(progress.theme)) { current, _ in current }
    }

    private func themeParameters(_ theme: AnalyticsTheme) -> [String: Any] {
        switch theme {
        case let .catalog(id) where !id.isEmpty:
            return ["theme_source": "catalog", "theme_id": id]
        case .catalog, .unknown:
            return ["theme_source": "unknown"]
        case .ai:
            return ["theme_source": "ai"]
        }
    }

    private static func percentage(correct: Int, total: Int) -> Int {
        guard total > 0 else { return 0 }
        return min(max(Int((Double(max(correct, 0)) / Double(total) * 100).rounded()), 0), 100)
    }
}

enum AnalyticsErrorContext {
    case persistentStore
    case inMemoryStore
    case contentLoad
    case themeResolution
    case aiGeneration(code: String)

    fileprivate var code: Int {
        switch self {
        case .persistentStore: return 1001
        case .inMemoryStore: return 1002
        case .contentLoad: return 2001
        case .themeResolution: return 2002
        case .aiGeneration: return 3001
        }
    }

    fileprivate var identifier: String {
        switch self {
        case .persistentStore: return "persistent_store"
        case .inMemoryStore: return "in_memory_store"
        case .contentLoad: return "content_load"
        case .themeResolution: return "theme_resolution"
        case let .aiGeneration(code): return "ai_generation.\(code)"
        }
    }
}

enum AnalyticsOperationalIssue: Error {
    case themeResolution
}

final class AppMetricaAnalyticsTracker: AnalyticsTracking {
    static let shared = AppMetricaAnalyticsTracker()
    static let apiKeyInfoPlistKey = "AppMetricaAPIKey"
    static let apiKeyPlaceholder = "YOUR_APPMETRICA_API_KEY"
    static let verboseLogsEnvironmentKey = "QUIZICE_APPMETRICA_VERBOSE_LOGS"

    private(set) var isActivated = false

    private init() {}

    func activate(
        rawAPIKey: String? = Bundle.main.object(forInfoDictionaryKey: apiKeyInfoPlistKey) as? String,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isXCTestRuntime: Bool = NSClassFromString("XCTestCase") != nil
    ) {
        guard !Self.shouldSkipActivation(environment: environment, isXCTestRuntime: isXCTestRuntime) else {
            AppLog.analytics.debug("AppMetrica activation skipped for tests or previews")
            return
        }
        guard let apiKey = Self.validAPIKey(from: rawAPIKey) else {
            AppLog.analytics.error("AppMetrica API key is missing or still contains the placeholder")
            return
        }
        guard !isActivated else { return }

        let crashesConfiguration = AppMetricaCrashesConfiguration()
        crashesConfiguration.autoCrashTracking = true
        AppMetricaCrashes.crashes().setConfiguration(crashesConfiguration)

        guard let configuration = AppMetricaConfiguration(apiKey: apiKey) else {
            AppLog.analytics.error("AppMetrica configuration could not be created")
            return
        }
        if let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
           !appVersion.isEmpty {
            configuration.appVersion = appVersion
        }
        if let appBuildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
           let numericBuildNumber = UInt32(appBuildNumber),
           numericBuildNumber > 0 {
            configuration.appBuildNumber = appBuildNumber
        }
        configuration.locationTracking = false
        configuration.revenueAutoTrackingEnabled = false
        configuration.advertisingIdentifierTrackingEnabled = false
        configuration.areLogsEnabled = Self.shouldEnableVerboseSDKLogs(environment: environment)

        AppMetrica.activate(with: configuration)
        isActivated = true
    }

    func track(_ event: AnalyticsEvent) {
        guard isActivated else { return }
        #if DEBUG
        AppLog.analytics.debug("Event → \(event.name, privacy: .public)")
        #endif
        AppMetrica.reportEvent(name: event.name, parameters: event.parameters) { error in
            AppLog.analytics.error(
                "AppMetrica event failed: event=\(event.name, privacy: .public) error_type=\(String(describing: type(of: error)), privacy: .public)"
            )
        }
    }

    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {
        guard isActivated else { return }
        let report = NSError(
            domain: "ru.avtabenskiy.Quizice.operational",
            code: context.code,
            userInfo: [
                "context": context.identifier,
                "error_type": String(describing: type(of: error))
            ]
        )
        AppMetricaCrashes.crashes().report(nserror: report) { failure in
            AppLog.analytics.error(
                "AppMetrica operational error report failed: context=\(context.identifier, privacy: .public) error_type=\(String(describing: type(of: failure)), privacy: .public)"
            )
        }
    }

    static func validAPIKey(from rawValue: String?) -> String? {
        let value = rawValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty, value != apiKeyPlaceholder, !value.contains("$(APPMETRICA_API_KEY)") else {
            return nil
        }
        return value
    }

    static func shouldSkipActivation(environment: [String: String], isXCTestRuntime: Bool) -> Bool {
        isXCTestRuntime ||
        environment["XCTestConfigurationFilePath"] != nil ||
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ||
        environment["QUIZICE_XCTEST_SMOKE_HOST"] == "1"
    }

    static func shouldEnableVerboseSDKLogs(environment: [String: String]) -> Bool {
        #if DEBUG
        environment[verboseLogsEnvironmentKey] == "1"
        #else
        false
        #endif
    }
}

extension AppMetricaAnalyticsTracker: BackendRequestMetricRecording {
    func record(_ metric: BackendRequestMetric) {
        track(.backendRequestCompleted(metric))
    }
}

final class NoopAnalyticsTracker: AnalyticsTracking {
    static let shared = NoopAnalyticsTracker()
    private init() {}

    func track(_ event: AnalyticsEvent) {}
    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {}
}
