//
//  QuizFactory.swift
//  My First App
//
//  Created by Артем Табенский on 01.01.2025.
//

import UIKit
import SwiftData
import CryptoKit

class QuizFactory {
    
    static let shared = QuizFactory()
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
    var questionsCount: Int = 5
    var startup1st: Bool = true
    
    private init() {}
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func loadTheme(button: UIButton) {
        guard
            let loadedThemes = themes,
            let chosenTheme = loadedThemes.first(where: { $0.theme == button.accessibilityIdentifier})
        else {
            print("не удалось определить выбранную тему, текущий текст кнопки: \(String(describing: button.currentTitle))")
            return
        }
        self.chosenTheme = ThemeModel(quizTheme: chosenTheme)
    }
    
    func loadData() {
        let existingThemes = fetchQuizThemes()
        let jsonHashKey = "jsonHashKey"
        
        if let url = Bundle.main.url(forResource: "data", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            
            let newHash = sha256Hash(for: data)
            let savedHash = UserDefaults.standard.string(forKey: jsonHashKey)
            
            if newHash == savedHash, !existingThemes.isEmpty {
                print("JSON не изменился. Загружаем темы из SwiftData: \(existingThemes.count) штуки")
                themes = existingThemes
                return
            }
            
            do {
                let decodedData = try JSONDecoder().decode([QuizTheme].self, from: data)
                print("JSON декодирован")
                
                clearSwiftData(context: modelContext)
                
                for theme in decodedData {
                    modelContext.insert(theme)
                }
                try? modelContext.save()
                print("JSON загружен и темы сохранены в SwiftData")
                
                UserDefaults.standard.set(newHash, forKey: jsonHashKey)
                
                themes = decodedData
            } catch {
                print("Ошибка декодирования JSON: \(error)")
            }
        } else {
            print("Ошибка: JSON не найден")
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
            print("SwiftData очищена!")
        } catch {
            print("Ошибка при очистке базы: \(error)")
        }
    }
}
