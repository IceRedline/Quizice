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

    var isAIGenerated: Bool {
        themeID.hasPrefix("ai-")
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
        id
    }
}
