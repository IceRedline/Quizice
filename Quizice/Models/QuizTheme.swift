//
//  ThemeData.swift
//  Quizice
//
//  Created by Артем Табенский on 22.03.2025.
//

import Foundation
import SwiftData

enum QuizThemeSource: String, Codable {
    case catalog
    case ai
}

@Model
class QuizTheme {
    @Attribute(.unique) var id: String
    var theme: String
    var themeDescription: String
    var sourceRawValue: String?
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]
    
    init(
        id: String,
        theme: String,
        themeDescription: String,
        questions: [QuizQuestion],
        source: QuizThemeSource = .catalog
    ) {
        self.id = id
        self.theme = theme
        self.themeDescription = themeDescription
        self.sourceRawValue = source.rawValue
        self.questions = questions
    }

    var source: QuizThemeSource {
        QuizThemeSource(rawValue: sourceRawValue ?? "") ?? .catalog
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
