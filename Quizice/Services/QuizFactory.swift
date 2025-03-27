//
//  QuizFactory.swift
//  My First App
//
//  Created by Артем Табенский on 01.01.2025.
//

import UIKit
import SwiftData

class QuizFactory {
    
    static let shared = QuizFactory()
    
    private var modelContainer: ModelContainer!
    private var modelContext: ModelContext!
    
    var themes: [QuizTheme]?
    var chosenTheme: ThemeModel?
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
        //clearSwiftData(context: modelContext)
        let existingThemes = fetchQuizThemes()
        
        if !existingThemes.isEmpty {
            print("Загружены темы из SwiftData: \(existingThemes.count) штуки")
            themes = existingThemes
            return
        }
        
        if let url = Bundle.main.url(forResource: "data", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            do {
                let decodedData = try JSONDecoder().decode([QuizTheme].self, from: data)
                print("JSON декодирован")
                
                for theme in decodedData {
                    modelContext.insert(theme)
                }
                try? modelContext.save()
                print("JSON загружен и темы сохранены в SwiftData")
                
                themes = decodedData
            } catch {
                print("Ошибка декодирования JSON: \(error)")
            }
        } else {
            print("Ошибка: JSON не найден")
        }
    }
    
    func fetchQuizThemes() -> [QuizTheme] {
        let descriptor = FetchDescriptor<QuizTheme>(sortBy: [SortDescriptor(\.theme)])
        return (try? modelContext.fetch(descriptor)) ?? []
    }
    
    func clearSwiftData(context: ModelContext) { // на случай, если что-то пойдет не так
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
