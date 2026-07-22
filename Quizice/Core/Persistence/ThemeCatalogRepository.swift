import CryptoKit
import Foundation
import SwiftData

final class ThemeCatalogRepository: ThemeRepository {
    enum Content {
        static let dataResourceName = "data"
        static let dataResourceExtension = "json"
        static let localizedDataHashKey = "quizice.localizedDataHashKey"
    }

    static let shared: ThemeCatalogRepository = {
        let environment = ProcessInfo.processInfo.environment
        let isRunningTests = environment["XCTestConfigurationFilePath"] != nil
            || environment["QUIZICE_XCTEST_SMOKE_HOST"] == "1"
            || NSClassFromString("XCTestCase") != nil
        let api = isRunningTests ? nil : BackendConfiguration.load().map {
            HTTPBackendContentAPI(
                configuration: $0,
                metrics: AppMetricaAnalyticsTracker.shared
            )
        }
        return ThemeCatalogRepository(backendContentAPI: api)
    }()

    private var localizationObserver: NSObjectProtocol?
    private var themeStore: SwiftDataThemeStore?
    private let themeDataLoader = LocalizedThemeDataLoader()
    private let backendContentAPI: BackendContentAPI?
    private let seedGenerator: () -> String
    private let remoteQuestionTimeoutNanoseconds: UInt64

    var themes: [QuizTheme]?
    private(set) var catalogOrigin: QuizCatalogOrigin = .bundled
    var onCatalogReplaced: (() -> Void)?

    init(
        backendContentAPI: BackendContentAPI? = nil,
        seedGenerator: @escaping () -> String = { UUID().uuidString.lowercased() },
        remoteQuestionTimeoutNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.backendContentAPI = backendContentAPI
        self.seedGenerator = seedGenerator
        self.remoteQuestionTimeoutNanoseconds = remoteQuestionTimeoutNanoseconds
        localizationObserver = NotificationCenter.default.addObserver(
            forName: .appLocalizationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reloadDataForLocalizationChange()
        }
    }

    func setModelContext(_ context: ModelContext) {
        themeStore = SwiftDataThemeStore(context: context)
    }

    func loadData(forceReload: Bool = false) {
        let existingThemes = fetchQuizThemes()
        do {
            let loadedData = try themeDataLoader.load()
            let localizedHash = "\(loadedData.languageCode):\(loadedData.hash)"
            let savedHash = UserDefaults.standard.string(forKey: Content.localizedDataHashKey)

            if !forceReload, localizedHash == savedHash, !existingThemes.isEmpty {
                AppLog.content.debug("JSON unchanged, loading \(existingThemes.count) themes from SwiftData")
                themes = existingThemes
                catalogOrigin = .bundled
                return
            }

            AppLog.content.debug("Localized JSON decoded for language: \(loadedData.languageCode, privacy: .public)")
            themeStore?.replaceThemes(with: loadedData.themes)
            UserDefaults.standard.set(localizedHash, forKey: Content.localizedDataHashKey)
            themes = loadedData.themes
            catalogOrigin = .bundled
            onCatalogReplaced?()
        } catch {
            AppLog.content.error("Localized data loading error: \(String(describing: error), privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .contentLoad)
        }
    }

    func sha256Hash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    func fetchQuizThemes() -> [QuizTheme] {
        themeStore?.fetchThemes() ?? []
    }

    @discardableResult
    func refreshBackendCatalog(locale: String) async -> Bool {
        guard let backendContentAPI else { return false }
        do {
            let response = try await backendContentAPI.fetchThemes(locale: locale)
            try Task.checkCancellation()
            guard AppLocalizationStore.shared.resolvedLanguageCode == locale else { return false }

            let localThemes = themes ?? fetchQuizThemes()
            guard !response.themes.isEmpty else {
                throw BackendContentError.contractViolation
            }

            let localByID = Dictionary(uniqueKeysWithValues: localThemes.map { ($0.stableID, $0) })
            themes = response.themes.map { remoteTheme in
                let localTheme = localByID[remoteTheme.id]
                return QuizTheme(
                    id: remoteTheme.id,
                    theme: remoteTheme.name,
                    themeDescription: remoteTheme.description,
                    questions: localTheme?.questions ?? [],
                    source: .catalog,
                    questionOrigin: localTheme?.questionOrigin ?? .backend
                )
            }
            catalogOrigin = .backend
            onCatalogReplaced?()
            AppLog.content.info(
                "Backend theme catalog accepted: locale=\(locale, privacy: .public) themes=\(response.themes.count, privacy: .public)"
            )
            return true
        } catch is CancellationError {
            return false
        } catch {
            AppLog.content.error(
                "Backend theme catalog rejected; current catalog remains active: origin=\(self.catalogOrigin.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    func prepareQuiz(
        themeID: String,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        let localFallback = try? makeLocalQuiz(themeID: themeID, questionCount: questionCount)
        guard let backendContentAPI else {
            guard let localFallback else { throw QuizPreparationError.unavailable }
            AppLog.content.notice(
                "📦 LOCAL QUESTIONS: backend disabled, using bundled content theme=\(themeID, privacy: .public) locale=\(locale, privacy: .public) count=\(questionCount, privacy: .public)"
            )
            return localFallback
        }

        let seed = seedGenerator()
        let startedAt = Date()
        do {
            let response = try await withBackendTimeout(
                nanoseconds: remoteQuestionTimeoutNanoseconds
            ) {
                try await backendContentAPI.fetchQuestions(
                    themeID: themeID,
                    count: questionCount,
                    locale: locale,
                    seed: seed
                )
            }
            try Task.checkCancellation()
            guard AppLocalizationStore.shared.resolvedLanguageCode == locale else {
                throw CancellationError()
            }

            let metadata = (themes ?? fetchQuizThemes()).first {
                $0.stableID == themeID
            } ?? localFallback
            guard let metadata else { throw QuizPreparationError.unavailable }
            let questions = response.questions.map { $0.makeModel() }
            AppLog.content.notice(
                "✅ BACKEND QUESTIONS: received theme=\(themeID, privacy: .public) locale=\(locale, privacy: .public) requested=\(questionCount, privacy: .public) received=\(questions.count, privacy: .public) seed=\(seed, privacy: .public) duration_ms=\(Self.durationMilliseconds(since: startedAt), privacy: .public)"
            )
            return QuizTheme(
                id: metadata.id,
                theme: metadata.theme,
                themeDescription: metadata.themeDescription,
                questions: questions,
                source: .catalog,
                questionOrigin: .backend
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard let localFallback else { throw QuizPreparationError.unavailable }
            AppLog.content.error(
                "⚠️ BACKEND QUESTIONS: failed, using bundled fallback theme=\(themeID, privacy: .public) locale=\(locale, privacy: .public) count=\(questionCount, privacy: .public) seed=\(seed, privacy: .public) duration_ms=\(Self.durationMilliseconds(since: startedAt), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return localFallback
        }
    }

    func prepareRandomQuiz(
        selectionMode: CrossThemeQuestionSelectionMode,
        localFallback: QuizTheme,
        questionCount: Int,
        locale: String
    ) async throws -> QuizTheme {
        guard let backendContentAPI else {
            AppLog.content.notice(
                "📦 LOCAL RANDOM QUESTIONS: backend disabled, using bundled content mode=\(selectionMode.rawValue, privacy: .public) locale=\(locale, privacy: .public) count=\(questionCount, privacy: .public)"
            )
            return localFallback
        }

        let seed = seedGenerator()
        let startedAt = Date()
        do {
            let response = try await withBackendTimeout(
                nanoseconds: remoteQuestionTimeoutNanoseconds
            ) {
                try await backendContentAPI.fetchRandomQuestions(
                    selectionMode: selectionMode,
                    count: questionCount,
                    locale: locale,
                    seed: seed
                )
            }
            try Task.checkCancellation()
            guard AppLocalizationStore.shared.resolvedLanguageCode == locale else {
                throw CancellationError()
            }

            let questions = response.questions.map { $0.makeModel() }
            AppLog.content.notice(
                "✅ BACKEND RANDOM QUESTIONS: received mode=\(selectionMode.rawValue, privacy: .public) locale=\(locale, privacy: .public) requested=\(questionCount, privacy: .public) received=\(questions.count, privacy: .public) seed=\(seed, privacy: .public) duration_ms=\(Self.durationMilliseconds(since: startedAt), privacy: .public)"
            )
            return QuizTheme(
                id: RandomQuizSelection.themeID,
                theme: localFallback.theme,
                themeDescription: localFallback.themeDescription,
                questions: questions,
                source: .catalog,
                questionOrigin: .backend
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            AppLog.content.error(
                "⚠️ BACKEND RANDOM QUESTIONS: failed, using bundled fallback mode=\(selectionMode.rawValue, privacy: .public) locale=\(locale, privacy: .public) count=\(questionCount, privacy: .public) seed=\(seed, privacy: .public) duration_ms=\(Self.durationMilliseconds(since: startedAt), privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return localFallback
        }
    }

    func clearSwiftData(context: ModelContext) {
        SwiftDataThemeStore(context: context).clearThemes()
    }

    private func makeLocalQuiz(themeID: String, questionCount: Int) throws -> QuizTheme {
        let catalog = themes ?? fetchQuizThemes()
        guard
            QuizQuestionCountPolicy.supportedCounts.contains(questionCount),
            let theme = catalog.first(where: { $0.stableID == themeID })
        else {
            throw QuizPreparationError.unavailable
        }

        let usableQuestions = theme.questions.filter {
            QuizQuestionCountPolicy.isUsable(QuestionModel(quizQuestion: $0))
        }
        guard usableQuestions.count >= questionCount else {
            throw QuizPreparationError.unavailable
        }
        return QuizTheme(
            id: theme.id,
            theme: theme.theme,
            themeDescription: theme.themeDescription,
            questions: Array(usableQuestions.shuffled().prefix(questionCount)),
            source: theme.source,
            questionOrigin: .bundled
        )
    }

    private func reloadDataForLocalizationChange() {
        guard themeStore != nil else { return }
        loadData(forceReload: true)
    }

    private static func durationMilliseconds(since startDate: Date) -> Int {
        max(Int(Date().timeIntervalSince(startDate) * 1_000), 0)
    }
}
