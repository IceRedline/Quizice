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
                metrics: AppMetricaAnalyticsTracker.shared,
                accessTokenProvider: StoredBackendAccessTokenProvider()
            )
        }
        return ThemeCatalogRepository(backendContentAPI: api)
    }()

    private var localizationObserver: NSObjectProtocol?
    private var themeStore: SwiftDataThemeStore?
    private let themeDataLoader = LocalizedThemeDataLoader()
    private let backendContentAPI: BackendContentAPI?
    private let preferenceStore: OnboardingProgressStoring
    private let seedGenerator: () -> String
    private let remoteQuestionTimeoutNanoseconds: UInt64

    var themes: [QuizTheme]?
    private(set) var catalogOrigin: QuizCatalogOrigin = .bundled
    var onCatalogReplaced: (() -> Void)?

    init(
        backendContentAPI: BackendContentAPI? = nil,
        preferenceStore: OnboardingProgressStoring = OnboardingProgressStore.shared,
        seedGenerator: @escaping () -> String = { UUID().uuidString.lowercased() },
        remoteQuestionTimeoutNanoseconds: UInt64 = 3_000_000_000
    ) {
        self.backendContentAPI = backendContentAPI
        self.preferenceStore = preferenceStore
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
                    sfSymbolName: remoteTheme.sfSymbol,
                    emoji: remoteTheme.emoji,
                    colorHex: remoteTheme.colorHex,
                    isFavorite: remoteTheme.isFavorite,
                    source: .catalog,
                    questionOrigin: localTheme?.questionOrigin ?? .backend
                )
            }
            let remoteFavoriteIDs = response.themes.filter(\.isFavorite).map(\.id)
            if !remoteFavoriteIDs.isEmpty, !preferenceStore.hasPendingThemePreferences(locale: locale) {
                preferenceStore.applyRemotePreferredThemeIDs(remoteFavoriteIDs, locale: locale)
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
            handleAuthenticationFailureIfNeeded(error)
            AppLog.content.error(
                "Backend theme catalog rejected; current catalog remains active: origin=\(self.catalogOrigin.rawValue, privacy: .public) error=\(String(describing: error), privacy: .public)"
            )
            return false
        }
    }

    @discardableResult
    func synchronizeThemePreferences(locale: String) async -> Bool {
        guard let backendContentAPI else { return false }
        let storedIDs = preferenceStore.orderedPreferredThemeIDs(locale: locale)
        let favoriteThemeIDs: [String]
        if catalogOrigin == .backend {
            let availableIDs = Set((themes ?? []).map(\.stableID))
            favoriteThemeIDs = storedIDs.filter(availableIDs.contains)
        } else {
            favoriteThemeIDs = storedIDs
        }

        do {
            let response: BackendThemePreferencesResponse
            if preferenceStore.hasPendingThemePreferences(locale: locale) {
                response = try await backendContentAPI.replaceThemePreferences(
                    locale: locale,
                    favoriteThemeIDs: favoriteThemeIDs
                )
            } else {
                response = try await backendContentAPI.fetchThemePreferences(locale: locale)
            }
            try Task.checkCancellation()
            guard AppLocalizationStore.shared.resolvedLanguageCode == locale else { return false }

            preferenceStore.applyRemotePreferredThemeIDs(
                response.favoriteThemeIds,
                locale: locale
            )
            applyFavoriteOrder(response.favoriteThemeIds)
            onCatalogReplaced?()
            AppLog.content.info(
                "Theme preferences synchronized: locale=\(locale, privacy: .public) favorites=\(response.favoriteThemeIds.count, privacy: .public)"
            )
            return true
        } catch is CancellationError {
            return false
        } catch BackendContentError.unauthenticated {
            return false
        } catch {
            handleAuthenticationFailureIfNeeded(error)
            AppLog.content.error(
                "Theme preferences sync deferred: locale=\(locale, privacy: .public) error=\(String(describing: error), privacy: .public)"
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
                sfSymbolName: metadata.sfSymbolName,
                emoji: metadata.emoji,
                colorHex: metadata.colorHex,
                isFavorite: metadata.isFavorite,
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
                sfSymbolName: localFallback.sfSymbolName,
                emoji: localFallback.emoji,
                colorHex: localFallback.colorHex,
                isFavorite: localFallback.isFavorite,
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
            sfSymbolName: theme.sfSymbolName,
            emoji: theme.emoji,
            colorHex: theme.colorHex,
            isFavorite: theme.isFavorite,
            source: theme.source,
            questionOrigin: .bundled
        )
    }

    private func reloadDataForLocalizationChange() {
        guard themeStore != nil else { return }
        loadData(forceReload: true)
    }

    private func applyFavoriteOrder(_ favoriteThemeIDs: [String]) {
        guard let currentThemes = themes else { return }
        let rankByID = Dictionary(
            uniqueKeysWithValues: favoriteThemeIDs.enumerated().map { ($0.element, $0.offset) }
        )
        currentThemes.forEach {
            $0.isFavorite = rankByID[$0.stableID] != nil
        }
        themes = currentThemes.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = rankByID[lhs.element.stableID]
                let rhsRank = rankByID[rhs.element.stableID]
                switch (lhsRank, rhsRank) {
                case let (.some(lhsRank), .some(rhsRank)):
                    return lhsRank < rhsRank
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.offset < rhs.offset
                }
            }
            .map(\.element)
    }

    private func handleAuthenticationFailureIfNeeded(_ error: Error) {
        guard case BackendContentError.httpStatus(401, _) = error else { return }
        NotificationCenter.default.post(name: .backendAuthenticationInvalidated, object: nil)
    }

    private static func durationMilliseconds(since startDate: Date) -> Int {
        max(Int(Date().timeIntervalSince(startDate) * 1_000), 0)
    }
}
