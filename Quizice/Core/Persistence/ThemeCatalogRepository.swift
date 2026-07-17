import CryptoKit
import Foundation
import SwiftData

final class ThemeCatalogRepository: ThemeRepository {
    enum Content {
        static let dataResourceName = "data"
        static let dataResourceExtension = "json"
        static let localizedDataHashKey = "quizice.localizedDataHashKey"
    }

    static let shared = ThemeCatalogRepository()

    private var localizationObserver: NSObjectProtocol?
    private var themeStore: SwiftDataThemeStore?
    private let themeDataLoader = LocalizedThemeDataLoader()

    var themes: [QuizTheme]?
    var onCatalogReplaced: (() -> Void)?

    private init() {
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
                return
            }

            AppLog.content.debug("Localized JSON decoded for language: \(loadedData.languageCode, privacy: .public)")
            themeStore?.replaceThemes(with: loadedData.themes)
            UserDefaults.standard.set(localizedHash, forKey: Content.localizedDataHashKey)
            themes = loadedData.themes
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

    func clearSwiftData(context: ModelContext) {
        SwiftDataThemeStore(context: context).clearThemes()
    }

    private func reloadDataForLocalizationChange() {
        guard themeStore != nil else { return }
        loadData(forceReload: true)
    }
}
