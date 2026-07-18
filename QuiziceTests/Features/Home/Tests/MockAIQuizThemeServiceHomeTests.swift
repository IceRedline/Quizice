import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class MockAIQuizThemeServiceHomeTests: HomeScreenVisualStateTestCase {
    func testMockAIQuizThemeServiceTrimsPromptAndReturnsEmptyQuestions() async throws {
        let service = MockAIQuizThemeService()
        let locale = Locale(identifier: "ru")

        let theme = try await service.generateQuizTheme(
            configuration: AIQuizGenerationConfiguration(
                theme: "  Космос  \n",
                questionCount: 10,
                difficulty: .hard,
                locale: locale
            )
        )

        XCTAssertEqual(service.generatedConfigurations.map(\.theme), ["Космос"])
        XCTAssertEqual(service.generatedConfigurations.map(\.questionCount), [10])
        XCTAssertEqual(service.generatedConfigurations.map(\.difficulty), [.hard])
        XCTAssertEqual(service.generatedConfigurations.map(\.locale.identifier), ["ru"])
        XCTAssertEqual(theme.theme, "Космос")
        XCTAssertEqual(theme.themeDescription, "AI generated quiz placeholder")
        XCTAssertTrue(theme.questions.isEmpty)
    }

}
