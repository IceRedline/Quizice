//
//  ThemeData.swift
//  Quizice
//
//  Created by Артем Табенский on 22.03.2025.
//

import Foundation
import SwiftData

@Model
class QuizTheme: Decodable {
    var id: String?
    @Attribute(.unique) var theme: String
    var themeDescription: String
    @Relationship(deleteRule: .cascade) var questions: [QuizQuestion]
    
    init(id: String? = nil, theme: String, themeDescription: String, questions: [QuizQuestion]) {
        self.id = id
        self.theme = theme
        self.themeDescription = themeDescription
        self.questions = questions
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case theme
        case themeDescription
        case questions
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id)
        self.theme = try container.decode(String.self, forKey: .theme)
        self.themeDescription = try container.decode(String.self, forKey: .themeDescription)
        self.questions = try container.decode([QuizQuestion].self, forKey: .questions)
    }
}
