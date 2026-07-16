import Foundation

enum L10n {
    private static func localized(_ key: String, comment: String) -> String {
        AppLocalizationStore.shared.localizedBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    }

    private static func formatted(_ key: String, comment: String, _ arguments: CVarArg...) -> String {
        let format = localized(key, comment: comment)
        return String(format: format, locale: AppLocalizationStore.shared.resolvedLocale, arguments: arguments)
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
        static var aiQuestionCountFixed: String { L10n.localized("description.ai_question_count_fixed", comment: "Fixed AI question count picker hint") }
        static var defaultThemeDescription: String { L10n.localized("description.default_theme_description", comment: "Default theme description fallback") }
        static var defaultThemeName: String { L10n.localized("description.default_theme_name", comment: "Default theme name fallback") }
        static var questionCount: String { L10n.localized("description.question_count", comment: "Question count picker caption") }
    }

    enum Home {
        static var backgroundStyleSwitcher: String { L10n.localized("home.background_style.switcher", comment: "Experimental home background style switcher label") }
        static var chooseTheme: String { L10n.localized("home.choose_theme", comment: "Home screen theme selection title") }
        static var createWithAI: String { L10n.localized("home.create_with_ai", comment: "Create quiz theme with AI button title") }
        static var createWithAIAccessibilityHint: String { L10n.localized("home.create_with_ai.accessibility_hint", comment: "Create quiz theme with AI accessibility hint") }
        static var createWithAIBetaBadge: String { L10n.localized("home.create_with_ai.beta_badge", comment: "Create quiz theme with AI beta badge") }
        static var exitAlertMessage: String { L10n.localized("home.exit_alert.message", comment: "Exit confirmation message") }
        static var feelingLucky: String { L10n.localized("home.feeling_lucky", comment: "Feeling lucky random theme button title") }
        static var feelingLuckyAccessibilityHint: String { L10n.localized("home.feeling_lucky.accessibility_hint", comment: "Feeling lucky button accessibility hint") }
        static var statisticsAccessibilityHint: String { L10n.localized("home.statistics.accessibility_hint", comment: "Home statistics card accessibility hint") }
        static var statisticsAccessibilityLabel: String { L10n.localized("home.statistics.accessibility_label", comment: "Home statistics card accessibility label") }
        static var statisticsAccuracyShort: String { L10n.localized("home.statistics.accuracy_short", comment: "Home statistics card accuracy metric title") }
        static var statisticsDescription: String { L10n.localized("home.statistics.description", comment: "Home statistics card description") }
        static var statisticsPlayedShort: String { L10n.localized("home.statistics.played_short", comment: "Home statistics card played quizzes metric title") }
        static var themesCollectionAccessibilityLabel: String { L10n.localized("home.themes_collection.accessibility_label", comment: "Home themes collection accessibility label") }
        static var unavailableThemes: String { L10n.localized("home.unavailable_themes", comment: "Home screen empty themes title") }

        enum BackgroundStyle {
            static var original: String { L10n.localized("home.background_style.original", comment: "Original mesh gradient background option") }
            static var grid4x4: String { L10n.localized("home.background_style.grid_4x4", comment: "4 by 4 mesh gradient background option") }
            static var grid5x5: String { L10n.localized("home.background_style.grid_5x5", comment: "5 by 5 mesh gradient background option") }
        }

        static var motivationPrompts: [String] {
            [
                L10n.localized("home.motivation_prompt.1", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.2", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.3", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.4", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.5", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.6", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.7", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.8", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.9", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.10", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.11", comment: "Home screen random motivation prompt"),
                L10n.localized("home.motivation_prompt.12", comment: "Home screen random motivation prompt")
            ]
        }

        static func statisticsAccessibilityValue(playedQuizzes: Int, percentage: Int) -> String {
            L10n.formatted(
                "home.statistics.accessibility_value_format",
                comment: "Home statistics card accessibility value format",
                playedQuizzes,
                percentage
            )
        }
    }

    enum AITheme {
        enum Difficulty {
            static var easy: String { L10n.localized("ai_theme.difficulty.easy", comment: "Easy AI quiz difficulty") }
            static var medium: String { L10n.localized("ai_theme.difficulty.medium", comment: "Medium AI quiz difficulty") }
            static var hard: String { L10n.localized("ai_theme.difficulty.hard", comment: "Hard AI quiz difficulty") }
        }

        enum Progress {
            static var analyzing: String { L10n.localized("ai_theme.progress.analyzing", comment: "AI generation analyzing phase") }
            static var sending: String { L10n.localized("ai_theme.progress.sending", comment: "AI generation sending phase") }
            static var generating: String { L10n.localized("ai_theme.progress.generating", comment: "AI generation composing phase") }
            static var almostReady: String { L10n.localized("ai_theme.progress.almost_ready", comment: "AI generation almost ready phase") }
        }

        enum Error {
            enum Refusal {
                static var title: String { L10n.localized("ai_theme.error.refusal.title", comment: "AI refusal title") }
                static var message: String { L10n.localized("ai_theme.error.refusal.message", comment: "AI refusal message") }
            }

            enum Network {
                static var title: String { L10n.localized("ai_theme.error.network.title", comment: "AI network error title") }
                static var message: String { L10n.localized("ai_theme.error.network.message", comment: "AI network error message") }
            }

            enum Service {
                static var title: String { L10n.localized("ai_theme.error.service.title", comment: "AI service error title") }
                static var message: String { L10n.localized("ai_theme.error.service.message", comment: "AI service error message") }
            }

            enum InvalidQuiz {
                static var title: String { L10n.localized("ai_theme.error.invalid_quiz.title", comment: "Invalid generated quiz title") }
                static var message: String { L10n.localized("ai_theme.error.invalid_quiz.message", comment: "Invalid generated quiz message") }
            }

            enum Unavailable {
                static var title: String { L10n.localized("ai_theme.error.unavailable.title", comment: "AI unavailable title") }
                static var message: String { L10n.localized("ai_theme.error.unavailable.message", comment: "AI unavailable message") }
            }
        }

        static var difficulty: String { L10n.localized("ai_theme.difficulty", comment: "AI quiz difficulty selector title") }
        static var editTheme: String { L10n.localized("ai_theme.edit_theme", comment: "Edit AI quiz theme action") }
        static var errorMessage: String { L10n.localized("ai_theme.error_message", comment: "AI theme creation error message") }
        static var errorTitle: String { L10n.localized("ai_theme.error_title", comment: "AI theme creation error title") }
        static var generating: String { L10n.localized("ai_theme.generating", comment: "AI generation button title") }
        static var promptPlaceholder: String { L10n.localized("ai_theme.prompt_placeholder", comment: "AI theme prompt placeholder") }
        static var questionCount: String { L10n.localized("ai_theme.question_count", comment: "AI quiz question count selector title") }
        static var retry: String { L10n.localized("ai_theme.retry", comment: "Retry AI generation action") }
        static var submit: String { L10n.localized("ai_theme.submit", comment: "AI theme creation submit button title") }
        static var subtitle: String { L10n.localized("ai_theme.subtitle", comment: "AI theme creation subtitle") }
        static var title: String { L10n.localized("ai_theme.title", comment: "AI theme creation screen title") }

        static func questionCountAccessibility(count: Int) -> String {
            L10n.formatted(
                "ai_theme.question_count.accessibility_format",
                comment: "AI quiz question count accessibility label",
                count
            )
        }
    }

    enum Question {
        static var audioLoadFailure: String { L10n.localized("question.audio_load_failure", comment: "Console message when answer sounds fail to load") }
        static var exitAlertMessage: String { L10n.localized("question.exit_alert.message", comment: "Message shown before discarding current quiz progress") }
        static var exitAlertTitle: String { L10n.localized("question.exit_alert.title", comment: "Title shown before discarding current quiz progress") }
        static var fallbackTheme: String { L10n.localized("question.fallback_theme", comment: "Fallback quiz theme name") }
        static var timeRemaining: String { L10n.localized("question.time_remaining", comment: "Quiz timer accessibility label") }
        static var unavailableAnswer: String { L10n.localized("question.unavailable_answer", comment: "Unavailable answer placeholder") }
        static var unavailableMessage: String { L10n.localized("question.unavailable.message", comment: "Message when selected theme has no usable questions") }
        static var unavailableNumber: String { L10n.localized("question.unavailable_number", comment: "Unavailable question number label") }

        static func number(_ number: Int) -> String {
            L10n.formatted("question.number_format", comment: "Question number format", number)
        }
    }

    enum Result {
        static var fallbackDescription: String { L10n.localized("result.description.fallback", comment: "Fallback result description") }
        static var strongResultDescription: String { L10n.localized("result.description.high_score", comment: "Result description for strong results") }
        static var invalidScoreDescription: String { L10n.localized("result.description.invalid_score", comment: "Result description for invalid score state") }
        static var lowScoreDescription: String { L10n.localized("result.description.low_score", comment: "Result description for low scores") }
        static var mediumLowScoreDescription: String { L10n.localized("result.description.medium_low_score", comment: "Result description for medium-low scores") }
        static var mediumScoreDescription: String { L10n.localized("result.description.medium_score", comment: "Result description for medium scores") }
        static var noQuestionsDescription: String { L10n.localized("result.description.no_questions", comment: "Result description for attempts without questions") }
        static var perfectScoreDescription: String { L10n.localized("result.description.perfect_score", comment: "Result description for perfect scores") }
        static var playAgain: String { L10n.localized("result.play_again", comment: "Replay current quiz button title") }
        static var toThemes: String { L10n.localized("result.to_themes", comment: "Return to quiz themes button title") }
        static var veryLowScoreDescription: String { L10n.localized("result.description.very_low_score", comment: "Result description for very low scores") }

        static func text(correctAnswers: Int, totalQuestions: Int) -> String {
            L10n.formatted("result.text_format", comment: "Quiz result title format", correctAnswers, totalQuestions)
        }
    }

    enum Settings {
        static var alertAction: String { L10n.localized("settings.alert.action", comment: "Default settings alert action title") }
        static var appearanceSectionTitle: String { L10n.localized("settings.section.appearance", comment: "Settings appearance section title") }
        static var close: String { L10n.localized("settings.close", comment: "Settings close button title") }
        static var feedback: String { L10n.localized("settings.feedback", comment: "Settings feedback row title") }
        static var feedbackSubtitle: String { L10n.localized("settings.feedback.subtitle", comment: "Settings feedback row subtitle") }
        static var feedbackUnavailableMessage: String { L10n.localized("settings.feedback.unavailable_message", comment: "Settings feedback unavailable alert message") }
        static var done: String { L10n.localized("settings.done", comment: "Settings done button title") }
        static var icon: String { L10n.localized("settings.icon", comment: "Settings app icon row title") }
        static var iconSubtitle: String { L10n.localized("settings.icon.subtitle", comment: "Settings app icon row subtitle") }
        static var language: String { L10n.localized("settings.language", comment: "Settings app language row title") }
        static var languageSubtitle: String { L10n.localized("settings.language.subtitle", comment: "Settings app language row subtitle") }
        static var profile: String { L10n.localized("settings.profile", comment: "Settings profile row title") }
        static var profileSectionTitle: String { L10n.localized("settings.section.profile", comment: "Settings profile section title") }
        static var profileSubtitle: String { L10n.localized("settings.profile.subtitle", comment: "Settings profile row subtitle") }
        static var profileUnavailableMessage: String { L10n.localized("settings.profile.unavailable_message", comment: "Settings profile unavailable alert message") }
        static var restartRequiredTitle: String { L10n.localized("settings.restart_required.title", comment: "Settings restart required alert title") }
        static var supportSectionTitle: String { L10n.localized("settings.section.support", comment: "Settings support section title") }
        static var design: String { L10n.localized("settings.design", comment: "Settings design row title") }
        static var designSubtitle: String { L10n.localized("settings.design.subtitle", comment: "Settings design row subtitle") }
        static var cleanThemeMode: String { L10n.localized("settings.clean_theme_mode", comment: "Settings clean theme mode row title") }
        static var cleanThemeModeSubtitle: String { L10n.localized("settings.clean_theme_mode.subtitle", comment: "Settings clean theme mode row subtitle") }
        static var theme: String { L10n.localized("settings.theme", comment: "Settings theme row title") }
        static var themeSubtitle: String { L10n.localized("settings.theme.subtitle", comment: "Settings theme row subtitle") }
        static var title: String { L10n.localized("settings.title", comment: "Settings screen title") }

        static func restartRequiredMessage(selection: String) -> String {
            L10n.formatted("settings.restart_required.message_format", comment: "Settings restart required alert message format", selection)
        }

        enum Icon {
            static var classic: String { L10n.localized("settings.icon.classic", comment: "Classic app icon option title") }
            static var dark: String { L10n.localized("settings.icon.dark", comment: "Dark app icon option title") }
            static var ice: String { L10n.localized("settings.icon.ice", comment: "Ice app icon option title") }
        }

        enum Theme {
            static var dark: String { L10n.localized("settings.theme.dark", comment: "Dark app theme option title") }
            static var light: String { L10n.localized("settings.theme.light", comment: "Light app theme option title") }
            static var system: String { L10n.localized("settings.theme.system", comment: "System app theme option title") }
        }

        enum Language {
            static var system: String { L10n.localized("settings.language.system", comment: "System app language option title") }
        }

        enum Design {
            static var classic: String { L10n.localized("settings.design.classic", comment: "Classic design option title") }
            static var clean: String { L10n.localized("settings.design.clean", comment: "Clean design option title") }
            static var radar: String { L10n.localized("settings.design.radar", comment: "Radar design option title") }
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
        static var closeAccessibilityLabel: String { L10n.localized("theme.card.close_accessibility_label", comment: "Expanded theme card close button accessibility label") }
        static var showDescriptionAccessibilityLabel: String { L10n.localized("theme.card.show_description_accessibility_label", comment: "Expanded theme card show-description accessibility label") }
        static var showFrontAccessibilityLabel: String { L10n.localized("theme.card.show_front_accessibility_label", comment: "Expanded theme card return-to-front accessibility label") }

        static func accessibilityLabel(themeName: String) -> String {
            L10n.formatted("theme.card.accessibility_label_format", comment: "Theme card accessibility label format", themeName)
        }
    }
}
