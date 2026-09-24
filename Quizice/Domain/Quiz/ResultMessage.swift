import Foundation

enum ResultMessageCategory: String, CaseIterable {
    case veryLowScore = "very_low_score"
    case lowScore = "low_score"
    case mediumLowScore = "medium_low_score"
    case mediumScore = "medium_score"
    case highScore = "high_score"
    case perfectScore = "perfect_score"
    case noQuestions = "no_questions"
    case invalidScore = "invalid_score"

    static func resolve(correctAnswers: Int, totalQuestions: Int) -> Self {
        guard totalQuestions >= 0, correctAnswers >= 0, correctAnswers <= totalQuestions else {
            return .invalidScore
        }
        guard totalQuestions > 0 else { return .noQuestions }
        switch Float(correctAnswers) / Float(totalQuestions) {
        case ..<0.15: return .veryLowScore
        case ..<0.3: return .lowScore
        case ..<0.5: return .mediumLowScore
        case ..<0.75: return .mediumScore
        case ..<1: return .highScore
        default: return .perfectScore
        }
    }
}

protocol ResultMessageProviding {
    func message(for category: ResultMessageCategory, locale: String) -> String?
}
