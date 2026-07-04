import Foundation

protocol AIQuizThemeServiceProtocol: AnyObject {
    func generateQuizTheme(for prompt: String) async throws -> QuizTheme
}

final class MockAIQuizThemeService: AIQuizThemeServiceProtocol {
    private(set) var generatedPrompts: [String] = []

    func generateQuizTheme(for prompt: String) async throws -> QuizTheme {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        generatedPrompts.append(trimmedPrompt)
        print("AI quiz theme prompt: \(trimmedPrompt)")
        return QuizTheme(
            theme: trimmedPrompt,
            themeDescription: "AI generated quiz placeholder",
            questions: []
        )
    }
}
