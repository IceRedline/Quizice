//
//  ThemeModel.swift
//  My First App
//
//  Created by Артем Табенский on 31.12.2024.
//

import Foundation

struct ThemeModel {
    let quizTheme: QuizTheme
    
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
