//
//  QuizFactory.swift
//  My First App
//
//  Created by Артем Табенский on 01.01.2025.
//

import UIKit
import SwiftData
import CryptoKit

final class QuizFactory {
    private enum Content {
        static let dataResourceName = "data"
        static let dataResourceExtension = "json"
        static let localizedDataHashKey = "quizice.localizedDataHashKey"
    }
    
    static let shared = QuizFactory()
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    private var localizationObserver: NSObjectProtocol?
    
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
    }
    
    @discardableResult
    func loadTheme(themeID: String) -> Bool {
        guard
            let loadedThemes = themes,
            let chosenTheme = loadedThemes.first(where: { $0.stableID == themeID })
        else {
            print("Failed to resolve selected theme id: \(themeID)")
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
            print("Failed to resolve selected theme: \(themeName)")
            return false
        }
        self.chosenTheme = ThemeModel(quizTheme: chosenTheme)
        return true
    }

    func loadData(forceReload: Bool = false) {
        let existingThemes = fetchQuizThemes()
        let languageCode = AppLocalizationStore.shared.resolvedLanguageCode
        
        if let url = localizedDataURL(),
           let data = try? Data(contentsOf: url) {
            
            let newHash = sha256Hash(for: data)
            let localizedHash = "\(languageCode):\(newHash)"
            let savedHash = UserDefaults.standard.string(forKey: Content.localizedDataHashKey)
            
            if !forceReload, localizedHash == savedHash, !existingThemes.isEmpty {
                print("JSON is unchanged. Loading themes from SwiftData: \(existingThemes.count)")
                themes = existingThemes
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([QuizTheme].self, from: data)
                print("Localized JSON decoded for language: \(languageCode)")
                
                clearSwiftData(context: modelContext)
                
                for theme in decodedData {
                    modelContext.insert(theme)
                }
                try? modelContext.save()
                print("Localized JSON loaded and saved to SwiftData")
                
                UserDefaults.standard.set(localizedHash, forKey: Content.localizedDataHashKey)
                
                themes = decodedData
                chosenTheme = nil
            } catch {
                print("JSON decoding error: \(error)")
            }
        } else {
            print("Error: localized JSON not found")
        }
    }
    
    func sha256Hash(for data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    func fetchQuizThemes() -> [QuizTheme] {
        let descriptor = FetchDescriptor<QuizTheme>(sortBy: [SortDescriptor(\.theme)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func clearSwiftData(context: ModelContext) {
        do {
            let themes = try context.fetch(FetchDescriptor<QuizTheme>())
            for theme in themes {
                context.delete(theme)
            }
            try context.save()
            print("SwiftData cleared")
        } catch {
            print("Database clearing error: \(error)")
        }
    }

    private func localizedDataURL() -> URL? {
        AppLocalizationStore.shared.localizedBundle.url(
            forResource: Content.dataResourceName,
            withExtension: Content.dataResourceExtension
        ) ?? Bundle.main.url(
            forResource: Content.dataResourceName,
            withExtension: Content.dataResourceExtension
        )
    }

    private func reloadDataForLocalizationChange() {
        guard modelContext != nil else { return }
        loadData(forceReload: true)
    }
}
