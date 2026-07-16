import Foundation

enum QuizQuestionCountPolicy {
    static let supportedCounts = [5, 10, 15]

    static func isUsable(_ question: QuestionModel) -> Bool {
        !question.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        question.answers.count >= 4 &&
        !question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        question.answers.filter { $0 == question.correctAnswer }.count == 1
    }

    static func usableQuestionCount(in questions: [QuestionModel]) -> Int {
        questions.filter(isUsable).count
    }

    static func availableCounts(for questions: [QuestionModel]) -> [Int] {
        availableCounts(usableQuestionCount: usableQuestionCount(in: questions))
    }

    static func availableCounts(usableQuestionCount: Int) -> [Int] {
        supportedCounts.filter { $0 <= usableQuestionCount }
    }

    static func initialSelection(preferred: Int?, available: [Int]) -> Int? {
        let normalizedAvailableCounts = supportedCounts.filter(available.contains)

        if let preferred, normalizedAvailableCounts.contains(preferred) {
            return preferred
        }

        return normalizedAvailableCounts.first
    }
}
