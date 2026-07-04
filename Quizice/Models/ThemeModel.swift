//
//  ThemeModel.swift
//  My First App
//
//  Created by Артем Табенский on 31.12.2024.
//

import Foundation

struct ThemeModel {
    let quizTheme: QuizTheme

    var themeID: String {
        quizTheme.stableID
    }
    
    var themeName: String {
        quizTheme.theme
    }
    
    var description: String {
        quizTheme.themeDescription
    }
    
    var questionsAndAnswers: [QuestionModel] {
        quizTheme.questions.map { QuestionModel(quizQuestion: $0) }
    }
}

extension QuizTheme {
    var stableID: String {
        if let id, !id.isEmpty {
            return id
        }

        switch theme {
        case "Музыка", "Music", "Música", "Musik", "Musica", "Musique":
            return "music"
        case "Технологии", "Technology", "Tecnología", "Tecnologia", "Technologie":
            return "technology"
        case "История", "История и культура", "Культура и история", "History and Culture", "Historia y cultura", "Geschichte und Kultur", "Storia e cultura", "Histoire et culture":
            return "history_culture"
        case "Политика", "Политика и бизнес", "Politics and Business", "Política y negocios", "Politik und Wirtschaft", "Politica e affari", "Politique et affaires":
            return "politics_business"
        default:
            return theme
        }
    }
}
