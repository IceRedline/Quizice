import XCTest
@testable import Quizice

final class LocalizationTests: XCTestCase {
    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: AppLocalizationStore.Keys.language)
        super.tearDown()
    }

    func testLanguageStoreUsesExplicitLanguagePreference() {
        let suiteName = "LocalizationTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let store = AppLocalizationStore(
            userDefaults: defaults,
            preferredLanguagesProvider: { ["de-DE"] }
        )

        store.languagePreference = .spanish

        XCTAssertEqual(store.resolvedLanguageCode, "es")
    }

    func testSystemLanguageResolvesSupportedRegionCode() {
        XCTAssertEqual(
            AppLocalizationStore.resolveSystemLanguageCode(preferredLanguages: ["es-MX", "en-US"]),
            "es"
        )
    }

    func testSystemLanguageFallsBackToEnglishWhenUnsupported() {
        XCTAssertEqual(
            AppLocalizationStore.resolveSystemLanguageCode(preferredLanguages: ["pt-BR", "ja-JP"]),
            "en"
        )
    }

    func testL10nReadsSelectedLanguageBundle() {
        AppLocalizationStore.shared.languagePreference = .english
        XCTAssertEqual(L10n.Common.next, "Next")

        AppLocalizationStore.shared.languagePreference = .russian
        XCTAssertEqual(L10n.Common.next, "Далее")

        AppLocalizationStore.shared.languagePreference = .french
        XCTAssertEqual(L10n.Settings.language, "Langue")
    }

    func testDesignPolishCopyExistsInEverySupportedLocalization() throws {
        let root = localizedDataRoot()
        let languages = ["ru", "en", "es", "de", "it", "fr"]
        let requiredKeys = [
            "home.background_style.switcher",
            "home.background_style.original",
            "home.background_style.grid_4x4",
            "home.background_style.grid_5x5",
            "home.feeling_lucky.loading",
            "home.feeling_lucky.random_selection",
            "debug_menu.title",
            "debug_menu.hide_interface",
            "debug_menu.pulse",
            "debug_menu.pulse.subtitle",
            "ai_theme.prompt_too_long",
            "question.exit_alert.title",
            "question.exit_alert.message",
            "question.show_explanation",
            "question.show_question",
            "question.time_remaining",
            "result.play_again",
            "result.to_themes",
            "onboarding.action.skip",
            "onboarding.action.get_started",
            "onboarding.help.accessibility_label",
            "onboarding.help.accessibility_hint",
            "onboarding.progress_format",
            "onboarding.welcome.kicker",
            "onboarding.welcome.title",
            "onboarding.welcome.subtitle",
            "onboarding.topics.title",
            "onboarding.topics.subtitle",
            "onboarding.topics.selection_hint",
            "onboarding.topics.selected",
            "onboarding.topic.music",
            "onboarding.topic.technology",
            "onboarding.topic.history_culture",
            "onboarding.topic.politics_business",
            "onboarding.tutorial.title",
            "onboarding.tutorial.subtitle",
            "onboarding.tutorial.themes.title",
            "onboarding.tutorial.themes.detail",
            "onboarding.tutorial.ai.title",
            "onboarding.tutorial.ai.detail",
            "onboarding.tutorial.statistics.title",
            "onboarding.tutorial.statistics.detail"
        ]

        for language in languages {
            let url = root.appendingPathComponent("\(language).lproj/Localizable.strings")
            let data = try Data(contentsOf: url)
            var format = PropertyListSerialization.PropertyListFormat.openStep
            let strings = try XCTUnwrap(
                PropertyListSerialization.propertyList(from: data, options: [], format: &format) as? [String: String]
            )

            for key in requiredKeys {
                let value = try XCTUnwrap(strings[key], "Missing \(key) in \(language)")
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(key) in \(language)")
            }
        }
    }

    func testLocalizedDataFilesKeepStableThemeShapeAndValidAnswers() throws {
        let root = localizedDataRoot()
        let languages = ["ru", "en", "es", "de", "it", "fr"]
        var expectedThemeIDs: [String]?
        var expectedQuestionCounts: [Int]?

        for language in languages {
            let url = root.appendingPathComponent("\(language).lproj/data.json")
            let data = try Data(contentsOf: url)
            let themes = try JSONDecoder().decode([QuizThemePayload].self, from: data)

            let themeIDs = themes.map(\.id)
            let questionCounts = themes.map { $0.questions.count }
            if expectedThemeIDs == nil {
                expectedThemeIDs = themeIDs
                expectedQuestionCounts = questionCounts
            }

            XCTAssertEqual(themeIDs, expectedThemeIDs, "Theme IDs must match in \(language)")
            XCTAssertEqual(questionCounts, expectedQuestionCounts, "Question counts must match in \(language)")

            for theme in themes {
                XCTAssertFalse(theme.theme.isEmpty, "Theme title must not be empty in \(language)")
                XCTAssertFalse(theme.themeDescription.isEmpty, "Theme description must not be empty in \(language)")
                for question in theme.questions {
                    XCTAssertFalse(question.question.isEmpty, "Question text must not be empty in \(language)")
                    XCTAssertTrue(
                        question.answers.contains(question.correctAnswer),
                        "Correct answer must be one of answers in \(language): \(question.question)"
                    )
                }
            }
        }
    }

    func testNonRussianDataFilesDoNotContainCyrillicQuestionContent() throws {
        let root = localizedDataRoot()
        let nonRussianLanguages = ["en", "es", "de", "it", "fr"]
        let cyrillicRange = try NSRegularExpression(pattern: #"[А-Яа-яЁё]"#)

        for language in nonRussianLanguages {
            let url = root.appendingPathComponent("\(language).lproj/data.json")
            let data = try Data(contentsOf: url)
            let themes = try JSONDecoder().decode([QuizThemePayload].self, from: data)

            for theme in themes {
                for question in theme.questions {
                    let values = [question.question, question.correctAnswer] + question.answers
                    for value in values {
                        let range = NSRange(value.startIndex..<value.endIndex, in: value)
                        XCTAssertNil(
                            cyrillicRange.firstMatch(in: value, range: range),
                            "\(language) contains Cyrillic quiz content: \(value)"
                        )
                    }
                }
            }
        }
    }

    func testNonRussianDataFilesDoNotContainTransliteratedRussianQuestionFragments() throws {
        let root = localizedDataRoot()
        let nonRussianLanguages = ["en", "es", "de", "it", "fr"]
        let badFragments = [
            "V kakom",
            "Kak nazyvaetsya",
            "krupneyshaya",
            "provela",
            "sovet direktorov",
            "tekhnologiyu",
            "zamorazhivaniya",
            "gosdolga",
            "denezhnoy massy",
            "Bozhestvennoy",
            "imperatorom Kitaya",
            "besprovodnoy svyazi",
        ]

        for language in nonRussianLanguages {
            let url = root.appendingPathComponent("\(language).lproj/data.json")
            let data = try Data(contentsOf: url)
            let themes = try JSONDecoder().decode([QuizThemePayload].self, from: data)

            for theme in themes {
                for question in theme.questions {
                    for fragment in badFragments {
                        XCTAssertFalse(
                            question.question.localizedCaseInsensitiveContains(fragment),
                            "\(language) contains a transliterated Russian fragment '\(fragment)': \(question.question)"
                        )
                    }
                }
            }
        }
    }

    private func localizedDataRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Quizice")
    }
}

private struct QuizThemePayload: Decodable {
    let id: String
    let theme: String
    let themeDescription: String
    let questions: [QuizQuestionPayload]
}

private struct QuizQuestionPayload: Decodable {
    let question: String
    let answers: [String]
    let correctAnswer: String
}
