import Foundation

enum L10n {
    private static func localized(_ key: String, comment: String) -> String {
        NSLocalizedString(key, comment: comment)
    }

    private static func formatted(_ key: String, comment: String, _ arguments: CVarArg...) -> String {
        let format = localized(key, comment: comment)
        return String(format: format, locale: Locale.current, arguments: arguments)
    }

    enum Common {
        static var back: String { L10n.localized("common.back", comment: "Back button title") }
        static var exit: String { L10n.localized("common.exit", comment: "Exit button title") }
        static var next: String { L10n.localized("common.next", comment: "Next button title") }
        static var no: String { L10n.localized("common.no", comment: "Negative alert action title") }
        static var start: String { L10n.localized("common.start", comment: "Start button title") }
        static var yes: String { L10n.localized("common.yes", comment: "Positive alert action title") }
    }

    enum Description {
        static var defaultThemeDescription: String { L10n.localized("description.default_theme_description", comment: "Default theme description fallback") }
        static var defaultThemeName: String { L10n.localized("description.default_theme_name", comment: "Default theme name fallback") }
        static var questionCount: String { L10n.localized("description.question_count", comment: "Question count picker caption") }
    }

    enum Home {
        static var chooseTheme: String { L10n.localized("home.choose_theme", comment: "Home screen theme selection title") }
        static var exitAlertMessage: String { L10n.localized("home.exit_alert.message", comment: "Exit confirmation message") }
        static var feelingLucky: String { L10n.localized("home.feeling_lucky", comment: "Feeling lucky random theme button title") }
        static var feelingLuckyAccessibilityHint: String { L10n.localized("home.feeling_lucky.accessibility_hint", comment: "Feeling lucky button accessibility hint") }
        static var statisticsAccessibilityHint: String { L10n.localized("home.statistics.accessibility_hint", comment: "Home statistics card accessibility hint") }
        static var statisticsAccessibilityLabel: String { L10n.localized("home.statistics.accessibility_label", comment: "Home statistics card accessibility label") }
        static var statisticsDescription: String { L10n.localized("home.statistics.description", comment: "Home statistics card description") }
        static var themesCollectionAccessibilityLabel: String { L10n.localized("home.themes_collection.accessibility_label", comment: "Home themes collection accessibility label") }
        static var unavailableThemes: String { L10n.localized("home.unavailable_themes", comment: "Home screen empty themes title") }
        static var welcome: String { L10n.localized("home.welcome", comment: "Home screen welcome text") }
    }

    enum Question {
        static var audioLoadFailure: String { L10n.localized("question.audio_load_failure", comment: "Console message when answer sounds fail to load") }
        static var fallbackTheme: String { L10n.localized("question.fallback_theme", comment: "Fallback quiz theme name") }
        static var unavailableAnswer: String { L10n.localized("question.unavailable_answer", comment: "Unavailable answer placeholder") }
        static var unavailableMessage: String { L10n.localized("question.unavailable.message", comment: "Message when selected theme has no usable questions") }
        static var unavailableNumber: String { L10n.localized("question.unavailable_number", comment: "Unavailable question number label") }

        static func number(_ number: Int) -> String {
            L10n.formatted("question.number_format", comment: "Question number format", number)
        }
    }

    enum Result {
        static var fallbackDescription: String { L10n.localized("result.description.fallback", comment: "Fallback result description") }
        static var highScoreDescription: String { L10n.localized("result.description.high_score", comment: "Result description for high scores") }
        static var invalidScoreDescription: String { L10n.localized("result.description.invalid_score", comment: "Result description for invalid score state") }
        static var lowScoreDescription: String { L10n.localized("result.description.low_score", comment: "Result description for low scores") }
        static var mediumLowScoreDescription: String { L10n.localized("result.description.medium_low_score", comment: "Result description for medium-low scores") }
        static var mediumScoreDescription: String { L10n.localized("result.description.medium_score", comment: "Result description for medium scores") }
        static var noQuestionsDescription: String { L10n.localized("result.description.no_questions", comment: "Result description for attempts without questions") }
        static var perfectScoreDescription: String { L10n.localized("result.description.perfect_score", comment: "Result description for perfect scores") }
        static var restart: String { L10n.localized("result.restart", comment: "Restart quiz button title") }
        static var veryLowScoreDescription: String { L10n.localized("result.description.very_low_score", comment: "Result description for very low scores") }

        static func text(correctAnswers: Int, totalQuestions: Int) -> String {
            L10n.formatted("result.text_format", comment: "Quiz result title format", correctAnswers, totalQuestions)
        }
    }

    enum Statistics {
        static var accessibilityLabel: String { L10n.localized("statistics.accessibility_label", comment: "Statistics screen accessibility label") }
        static var bestResult: String { L10n.localized("statistics.best_result", comment: "Best result row title") }
        static var correctAnswers: String { L10n.localized("statistics.correct_answers", comment: "Correct answers row title") }
        static var emptyStateAccessibilityLabel: String { L10n.localized("statistics.empty_state.accessibility_label", comment: "Statistics empty state accessibility label") }
        static var emptyStateText: String { L10n.localized("statistics.empty_state.text", comment: "Statistics empty state text") }
        static var percentage: String { L10n.localized("statistics.percentage", comment: "Correct answers percentage row title") }
        static var playedQuizzes: String { L10n.localized("statistics.played_quizzes", comment: "Played quizzes row title") }
        static var subtitleEmpty: String { L10n.localized("statistics.subtitle.empty", comment: "Statistics subtitle when there are no attempts") }
        static var subtitleWithStats: String { L10n.localized("statistics.subtitle.with_stats", comment: "Statistics subtitle when attempts exist") }
        static var title: String { L10n.localized("statistics.title", comment: "Statistics screen title") }
    }

    enum ThemeCard {
        static var accessibilityHint: String { L10n.localized("theme.card.accessibility_hint", comment: "Theme card accessibility hint") }

        static func accessibilityLabel(themeName: String) -> String {
            L10n.formatted("theme.card.accessibility_label_format", comment: "Theme card accessibility label format", themeName)
        }
    }
}
