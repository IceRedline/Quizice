import Foundation

struct HomeAIThemeCardSubmission: Equatable {
    let id: UUID
    let configuration: AIQuizGenerationConfiguration
    let startedAt: Date
}

struct HomeAIThemeCardState: Equatable {
    fileprivate(set) var prompt = ""
    fileprivate(set) var selectedQuestionCount =
        AIQuizGenerationConfiguration.supportedQuestionCounts[0]
    fileprivate(set) var selectedDifficulty: AIQuizDifficulty = .medium
    fileprivate(set) var activeSubmission: HomeAIThemeCardSubmission?
    fileprivate(set) var generationPhase: AIQuizGenerationPhase?
    fileprivate(set) var activeAlert: AIQuizGenerationAlert?

    var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isPromptTooLong: Bool {
        trimmedPrompt.count > AIQuizGenerationConfiguration.maximumThemeLength
    }

    var canRevealConfiguration: Bool {
        !trimmedPrompt.isEmpty && !isPromptTooLong
    }

    var isSubmitting: Bool {
        activeSubmission != nil
    }

    var canSubmit: Bool {
        canRevealConfiguration &&
        !isSubmitting &&
        AIQuizGenerationConfiguration.supportedQuestionCounts.contains(selectedQuestionCount)
    }

    init() {}
}

enum HomeAIThemeCardAction: Equatable {
    case promptChanged(String)
    case questionCountSelected(Int)
    case difficultySelected(AIQuizDifficulty)
    case submitRequested(requestID: UUID, locale: Locale, now: Date)
    case progressAdvanced(requestID: UUID, phase: AIQuizGenerationPhase)
    case submissionSucceeded(requestID: UUID)
    case submissionFailed(requestID: UUID, alert: AIQuizGenerationAlert)
    case cancelRequested
    case alertDismissed
    case reset
}

enum HomeAIThemeCardEffect: Equatable {
    case flipAvailabilityChanged(Bool)
    case submit(HomeAIThemeCardSubmission)
    case cancelSubmission(HomeAIThemeCardSubmission)
    case submissionCompleted(requestID: UUID)
    case presentAlert(AIQuizGenerationAlert)
    case focusPrompt
}

enum HomeAIThemeCardReducer {
    @discardableResult
    static func reduce(
        state: inout HomeAIThemeCardState,
        action: HomeAIThemeCardAction
    ) -> HomeAIThemeCardEffect? {
        switch action {
        case let .promptChanged(prompt):
            guard !state.isSubmitting else { return nil }
            let wasAvailable = state.canRevealConfiguration
            state.prompt = prompt
            let isAvailable = state.canRevealConfiguration
            guard wasAvailable != isAvailable else { return nil }
            return .flipAvailabilityChanged(isAvailable)

        case let .questionCountSelected(questionCount):
            guard
                !state.isSubmitting,
                AIQuizGenerationConfiguration.supportedQuestionCounts.contains(questionCount)
            else {
                return nil
            }
            state.selectedQuestionCount = questionCount
            return nil

        case let .difficultySelected(difficulty):
            guard !state.isSubmitting else { return nil }
            state.selectedDifficulty = difficulty
            return nil

        case let .submitRequested(requestID, locale, now):
            guard state.canSubmit else { return nil }
            let submission = HomeAIThemeCardSubmission(
                id: requestID,
                configuration: AIQuizGenerationConfiguration(
                    theme: state.trimmedPrompt,
                    questionCount: state.selectedQuestionCount,
                    difficulty: state.selectedDifficulty,
                    locale: locale
                ),
                startedAt: now
            )
            state.activeSubmission = submission
            state.generationPhase = .analyzing
            state.activeAlert = nil
            return .submit(submission)

        case let .progressAdvanced(requestID, phase):
            guard
                state.activeSubmission?.id == requestID,
                let currentPhase = state.generationPhase,
                phase.rawValue > currentPhase.rawValue
            else {
                return nil
            }
            state.generationPhase = phase
            return nil

        case let .submissionSucceeded(requestID):
            guard state.activeSubmission?.id == requestID else { return nil }
            state.activeSubmission = nil
            state.generationPhase = nil
            state.activeAlert = nil
            return .submissionCompleted(requestID: requestID)

        case let .submissionFailed(requestID, alert):
            guard state.activeSubmission?.id == requestID else { return nil }
            state.activeSubmission = nil
            state.generationPhase = nil
            state.activeAlert = alert
            return .presentAlert(alert)

        case .cancelRequested:
            guard let submission = state.activeSubmission else { return nil }
            state.activeSubmission = nil
            state.generationPhase = nil
            return .cancelSubmission(submission)

        case .alertDismissed:
            guard let alert = state.activeAlert else { return nil }
            state.activeAlert = nil
            return alert.shouldFocusPromptOnDismiss ? .focusPrompt : nil

        case .reset:
            let submission = state.activeSubmission
            state = HomeAIThemeCardState()
            return submission.map(HomeAIThemeCardEffect.cancelSubmission)
        }
    }
}
