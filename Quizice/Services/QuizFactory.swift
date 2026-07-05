//
//  QuizFactory.swift
//  My First App
//
//  Created by Артем Табенский on 01.01.2025.
//

import UIKit
import SwiftData
import CryptoKit

protocol ThemeRepository: AnyObject {
    var themes: [QuizTheme]? { get set }
    func loadData(forceReload: Bool)
    func fetchQuizThemes() -> [QuizTheme]
}

protocol QuizSessionManaging: AnyObject {
    var chosenTheme: ThemeModel? { get set }
    var questionsCount: Int { get set }
    var startup1st: Bool { get set }

    @discardableResult
    func loadTheme(themeID: String) -> Bool
}

struct LocalizedThemeDataLoader {
    struct LoadedData {
        let languageCode: String
        let hash: String
        let themes: [QuizTheme]
    }

    func load() throws -> LoadedData {
        guard let url = localizedDataURL() else {
            throw ThemeDataError.localizedJSONNotFound
        }
        let data = try Data(contentsOf: url)
        let decodedData = try JSONDecoder().decode([QuizThemeDTO].self, from: data)
        return LoadedData(
            languageCode: AppLocalizationStore.shared.resolvedLanguageCode,
            hash: sha256Hash(for: data),
            themes: decodedData.map { $0.makeModel() }
        )
    }

    private func localizedDataURL() -> URL? {
        AppLocalizationStore.shared.localizedBundle.url(
            forResource: QuizFactory.Content.dataResourceName,
            withExtension: QuizFactory.Content.dataResourceExtension
        ) ?? Bundle.main.url(
            forResource: QuizFactory.Content.dataResourceName,
            withExtension: QuizFactory.Content.dataResourceExtension
        )
    }

    private func sha256Hash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

enum ThemeDataError: Error {
    case localizedJSONNotFound
}

final class SwiftDataThemeStore {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func fetchThemes() -> [QuizTheme] {
        let descriptor = FetchDescriptor<QuizTheme>(sortBy: [SortDescriptor(\.theme)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func replaceThemes(with themes: [QuizTheme]) {
        clearThemes()
        for theme in themes {
            context.insert(theme)
        }
        do {
            try context.save()
        } catch {
            AppLog.persistence.error("Failed to save themes: \(String(describing: error), privacy: .public)")
        }
    }

    func clearThemes() {
        do {
            let themes = try context.fetch(FetchDescriptor<QuizTheme>())
            for theme in themes {
                context.delete(theme)
            }
            try context.save()
            AppLog.persistence.debug("SwiftData cleared")
        } catch {
            AppLog.persistence.error("Database clearing error: \(String(describing: error), privacy: .public)")
        }
    }
}

final class QuizFactory: ThemeRepository, QuizSessionManaging {
    enum Content {
        static let dataResourceName = "data"
        static let dataResourceExtension = "json"
        static let localizedDataHashKey = "quizice.localizedDataHashKey"
    }
    
    static let shared = QuizFactory()
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var localizationObserver: NSObjectProtocol?
    private var themeStore: SwiftDataThemeStore?
    private let themeDataLoader = LocalizedThemeDataLoader()
    
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount: Int = 5
    var startup1st: Bool = true
    
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
        self.modelContext = context
        self.themeStore = SwiftDataThemeStore(context: context)
    }
    
    @discardableResult
    func loadTheme(themeID: String) -> Bool {
        guard
            let loadedThemes = themes,
            let chosenTheme = loadedThemes.first(where: { $0.stableID == themeID })
        else {
            AppLog.content.error("Failed to resolve selected theme id: \(themeID, privacy: .public)")
            return false
        }
        self.chosenTheme = ThemeModel(quizTheme: chosenTheme)
        return true
    }
    
    @discardableResult
    func loadTheme(themeName: String) -> Bool {
        guard
            let loadedThemes = themes,
            let chosenTheme = loadedThemes.first(where: { $0.theme == themeName || $0.stableID == themeName })
        else {
            AppLog.content.error("Failed to resolve selected theme: \(themeName, privacy: .public)")
            return false
        }
        self.chosenTheme = ThemeModel(quizTheme: chosenTheme)
        return true
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
            chosenTheme = nil
        } catch {
            AppLog.content.error("Localized data loading error: \(String(describing: error), privacy: .public)")
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
        guard modelContext != nil else { return }
        loadData(forceReload: true)
    }
}
