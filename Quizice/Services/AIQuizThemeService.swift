import Foundation

protocol AIQuizThemeServiceProtocol: AnyObject {
    func generateQuizTheme(for prompt: String, locale: Locale) async throws -> QuizTheme
}

final class MockAIQuizThemeService: AIQuizThemeServiceProtocol {
    private(set) var generatedPrompts: [String] = []
    private(set) var generatedLocaleIdentifiers: [String] = []

    func generateQuizTheme(for prompt: String, locale: Locale) async throws -> QuizTheme {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        generatedPrompts.append(trimmedPrompt)
        generatedLocaleIdentifiers.append(locale.identifier)
        AppLog.quiz.debug("AI quiz theme prompt: \(trimmedPrompt, privacy: .public), locale: \(locale.identifier, privacy: .public)")
        return QuizTheme(
            id: trimmedPrompt.lowercased().replacingOccurrences(of: " ", with: "_"),
            theme: trimmedPrompt,
            themeDescription: "AI generated quiz placeholder",
            questions: []
        )
    }
}
