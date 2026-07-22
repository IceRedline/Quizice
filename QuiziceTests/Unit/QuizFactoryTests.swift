import CryptoKit
import SwiftData
import XCTest
@testable import Quizice

@MainActor
final class QuizFactoryTests: XCTestCase {
    override func tearDown() {
        resetSharedQuizFactoryForTests()
        UserDefaults.standard.removeObject(forKey: QuizFactory.Content.localizedDataHashKey)
        super.tearDown()
    }

    func testLoadThemeByIDAndNameMutatesChosenThemeOnlyWhenFound() {
        let music = SnapshotSupport.makeTheme(id: "music", name: "Music")
        let tech = SnapshotSupport.makeTheme(id: "technology", name: "Technology")
        QuizFactory.shared.themes = [music, tech]

        XCTAssertTrue(QuizFactory.shared.loadTheme(themeID: "music"))
        XCTAssertEqual(QuizFactory.shared.chosenTheme?.themeID, "music")

        XCTAssertTrue(QuizFactory.shared.loadTheme(themeName: "Technology"))
        XCTAssertEqual(QuizFactory.shared.chosenTheme?.themeID, "technology")

        XCTAssertFalse(QuizFactory.shared.loadTheme(themeID: "missing"))
        XCTAssertEqual(QuizFactory.shared.chosenTheme?.themeID, "technology")
    }

    func testSha256HashMatchesCryptoKitReference() {
        let data = Data("quizice".utf8)
        let expected = SHA256.hash(data: data)
            .compactMap { String(format: "%02x", $0) }
            .joined()

        XCTAssertEqual(QuizFactory.shared.sha256Hash(for: data), expected)
    }

    func testSwiftDataThemeStoreReplacesFetchesAndClearsThemes() throws {
        let container = try ModelContainer(
            for: SwiftDataThemeStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let store = SwiftDataThemeStore(context: context)

        store.replaceThemes(with: [
            SnapshotSupport.makeTheme(id: "music", name: "Music"),
            SnapshotSupport.makeTheme(id: "technology", name: "Technology")
        ])

        XCTAssertEqual(store.fetchThemes().map(\.stableID).sorted(), ["music", "technology"])

        let culture = SnapshotSupport.makeTheme(id: "culture", name: "Culture")
        culture.questions.first?.explanation = "Stored explanation"
        culture.sfSymbolName = "building.columns"
        culture.emoji = "🏛️"
        culture.colorHex = "#8B5CF6"
        store.replaceThemes(with: [culture])

        let fetchedThemes = store.fetchThemes()
        XCTAssertEqual(fetchedThemes.map(\.stableID), ["culture"])
        XCTAssertEqual(fetchedThemes.first?.questions.first?.explanation, "Stored explanation")
        XCTAssertEqual(fetchedThemes.first?.sfSymbolName, "building.columns")
        XCTAssertEqual(fetchedThemes.first?.emoji, "🏛️")
        XCTAssertEqual(fetchedThemes.first?.colorHex, "#8B5CF6")

        store.clearThemes()

        XCTAssertTrue(store.fetchThemes().isEmpty)
    }
}
