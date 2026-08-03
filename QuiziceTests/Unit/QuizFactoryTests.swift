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
        culture.isFavorite = true
        store.replaceThemes(with: [culture])

        let fetchedThemes = store.fetchThemes()
        XCTAssertEqual(fetchedThemes.map(\.stableID), ["culture"])
        XCTAssertEqual(fetchedThemes.first?.questions.first?.explanation, "Stored explanation")
        XCTAssertEqual(fetchedThemes.first?.sfSymbolName, "building.columns")
        XCTAssertEqual(fetchedThemes.first?.emoji, "🏛️")
        XCTAssertEqual(fetchedThemes.first?.colorHex, "#8B5CF6")
        XCTAssertTrue(fetchedThemes.first?.isFavorite == true)

        store.clearThemes()

        XCTAssertTrue(store.fetchThemes().isEmpty)
    }

    func testLoadDataFromRealBundledJSONProducesThemesWithEnoughUsableQuestions() throws {
        let container = try ModelContainer(
            for: SwiftDataThemeStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let repository = ThemeCatalogRepository(backendContentAPI: nil)
        repository.setModelContext(container.mainContext)

        repository.loadData(forceReload: true)

        let themes = try XCTUnwrap(repository.themes)
        XCTAssertFalse(themes.isEmpty)
        XCTAssertEqual(repository.catalogOrigin, .bundled)
        for theme in themes {
            let usableCount = QuizQuestionCountPolicy.usableQuestionCount(
                in: theme.questions.map(QuestionModel.init(quizQuestion:))
            )
            XCTAssertGreaterThanOrEqual(
                usableCount,
                QuizQuestionCountPolicy.supportedCounts.min() ?? 0,
                "Theme '\(theme.theme)' has too few usable questions for the Start button to ever be enabled"
            )
        }
    }

    func testLoadDataSelfHealsWhenCachedBundledCatalogHasNoUsableQuestions() throws {
        let container = try ModelContainer(
            for: SwiftDataThemeStore.schema,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let store = SwiftDataThemeStore(context: context)

        // Simulate a stale/corrupted cache left over from an older build:
        // themes persisted under the bundled origin but with no questions,
        // paired with a hash that matches the current JSON so a naive
        // hash-only check would wrongly trust it.
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        let loader = LocalizedThemeDataLoader()
        let loadedData = try loader.load()
        let corruptedThemes = loadedData.themes.map { theme in
            QuizTheme(
                id: theme.id,
                theme: theme.theme,
                themeDescription: theme.themeDescription,
                questions: [],
                sfSymbolName: theme.sfSymbolName,
                emoji: theme.emoji,
                colorHex: theme.colorHex,
                isFavorite: theme.isFavorite,
                source: theme.source,
                questionOrigin: theme.questionOrigin
            )
        }
        store.replaceThemes(with: corruptedThemes, locale: loadedData.languageCode, catalogOrigin: .bundled)
        UserDefaults.standard.set(
            "\(loadedData.languageCode):\(loadedData.hash)",
            forKey: ThemeCatalogRepository.Content.localizedDataHashKey
        )

        let repository = ThemeCatalogRepository(backendContentAPI: nil)
        repository.setModelContext(context)
        repository.loadData(forceReload: false)

        let themes = try XCTUnwrap(repository.themes)
        XCTAssertEqual(repository.catalogOrigin, .bundled)
        XCTAssertTrue(
            themes.contains { theme in
                QuizQuestionCountPolicy.usableQuestionCount(
                    in: theme.questions.map(QuestionModel.init(quizQuestion:))
                ) >= (QuizQuestionCountPolicy.supportedCounts.min() ?? 0)
            },
            "Stale cache with no usable questions should have triggered a fresh reload from JSON, locale=\(locale)"
        )
    }
}
