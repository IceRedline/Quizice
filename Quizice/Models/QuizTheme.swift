//
//  ThemeData.swift
//  Quizice
//
//  Created by Артем Табенский on 22.03.2025.
//

import Foundation
import SwiftData

@Model
class QuizTheme {
    @Attribute(.unique) var id: String
    var theme: String
    var themeDescription: String
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]
    
    init(id: String, theme: String, themeDescription: String, questions: [QuizQuestion]) {
        self.id = id
        self.theme = theme
        self.themeDescription = themeDescription
        self.questions = questions
    }
}

struct QuizThemeDTO: Decodable {
    let id: String
    let theme: String
    let themeDescription: String
    let questions: [QuizQuestionDTO]

    func makeModel() -> QuizTheme {
        QuizTheme(
            id: id,
            theme: theme,
            themeDescription: themeDescription,
            questions: questions.map { $0.makeModel() }
        )
    }
}
