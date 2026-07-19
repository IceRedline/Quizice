import XCTest
@testable import Quizice

final class HomeAIThemeCardReducerTests: XCTestCase {
    private let firstRequestID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
    private let secondRequestID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
    private let firstDate = Date(timeIntervalSince1970: 1_700_000_000)
    private let secondDate = Date(timeIntervalSince1970: 1_700_000_100)
    private let locale = Locale(identifier: "ru_RU")

    func testDefaultsAndTrimmedPromptDriveFlipAvailabilityAtBoundaryChangesOnly() {
        var state = HomeAIThemeCardState()

        XCTAssertEqual(state.prompt, "")
        XCTAssertEqual(state.trimmedPrompt, "")
        XCTAssertEqual(state.selectedQuestionCount, 5)
        XCTAssertEqual(state.selectedDifficulty, .medium)
        XCTAssertFalse(state.canRevealConfiguration)
        XCTAssertFalse(state.isSubmitting)
        XCTAssertFalse(state.canSubmit)

        XCTAssertNil(reduce(&state, .promptChanged(" \n\t ")))
        XCTAssertFalse(state.canRevealConfiguration)
        XCTAssertEqual(
            reduce(&state, .promptChanged("  History of Moscow  \n")),
            .flipAvailabilityChanged(true)
        )
        XCTAssertEqual(state.trimmedPrompt, "History of Moscow")
        XCTAssertTrue(state.canRevealConfiguration)
        XCTAssertTrue(state.canSubmit)

        XCTAssertNil(reduce(&state, .promptChanged("Another valid topic")))
        XCTAssertEqual(
            reduce(&state, .promptChanged("   ")),
            .flipAvailabilityChanged(false)
        )
        XCTAssertFalse(state.canRevealConfiguration)
    }

    func testPromptLongerThanMaximumCannotRevealOrSubmit() {
        var state = HomeAIThemeCardState()
        let maximumPrompt = String(
            repeating: "A",
            count: AIQuizGenerationConfiguration.maximumThemeLength
        )
        let oversizedPrompt = maximumPrompt + "B"

        _ = reduce(&state, .promptChanged(maximumPrompt))
        XCTAssertFalse(state.isPromptTooLong)
        XCTAssertTrue(state.canRevealConfiguration)
        XCTAssertTrue(state.canSubmit)

        _ = reduce(&state, .promptChanged(oversizedPrompt))
        XCTAssertTrue(state.isPromptTooLong)
        XCTAssertFalse(state.canRevealConfiguration)
        XCTAssertFalse(state.canSubmit)
        XCTAssertNil(
            reduce(
                &state,
                .submitRequested(requestID: firstRequestID, locale: locale, now: firstDate)
            )
        )
    }

    func testSelectorsAcceptOnlySupportedCountsAndRemainEditableBeforeSubmission() {
        var state = validDraftState()

        XCTAssertNil(reduce(&state, .questionCountSelected(10)))
        XCTAssertEqual(state.selectedQuestionCount, 10)
        XCTAssertNil(reduce(&state, .questionCountSelected(7)))
        XCTAssertEqual(state.selectedQuestionCount, 10)

        XCTAssertNil(reduce(&state, .difficultySelected(.hard)))
        XCTAssertEqual(state.selectedDifficulty, .hard)
        XCTAssertTrue(state.canSubmit)
    }

    func testSubmitCapturesTrimmedImmutableConfigurationAndStartsAtAnalyzing() {
        var state = HomeAIThemeCardState()
        _ = reduce(&state, .promptChanged("  Space exploration \n"))
        _ = reduce(&state, .questionCountSelected(15))
        _ = reduce(&state, .difficultySelected(.hard))

        let expectedSubmission = HomeAIThemeCardSubmission(
            id: firstRequestID,
            configuration: AIQuizGenerationConfiguration(
                theme: "Space exploration",
                questionCount: 15,
                difficulty: .hard,
                locale: locale
            ),
            startedAt: firstDate
        )

        XCTAssertEqual(
            reduce(
                &state,
                .submitRequested(requestID: firstRequestID, locale: locale, now: firstDate)
            ),
            .submit(expectedSubmission)
        )
        XCTAssertEqual(state.activeSubmission, expectedSubmission)
        XCTAssertEqual(state.generationPhase, .analyzing)
        XCTAssertTrue(state.isSubmitting)
        XCTAssertFalse(state.canSubmit)
        XCTAssertNil(state.activeAlert)
    }

    func testSubmissionIsSingleFlightAndDraftCannotMutateWhileRequestIsActive() {
        var state = startedState()
        let capturedState = state

        XCTAssertNil(reduce(&state, .promptChanged("A different prompt")))
        XCTAssertNil(reduce(&state, .questionCountSelected(15)))
        XCTAssertNil(reduce(&state, .difficultySelected(.easy)))
        XCTAssertNil(
            reduce(
                &state,
                .submitRequested(requestID: secondRequestID, locale: locale, now: secondDate)
            )
        )
        XCTAssertEqual(state, capturedState)
    }

    func testProgressRequiresActiveRequestAndOnlyMovesForward() {
        var state = startedState()

        XCTAssertNil(
            reduce(
                &state,
                .progressAdvanced(requestID: secondRequestID, phase: .sending)
            )
        )
        XCTAssertEqual(state.generationPhase, .analyzing)
        XCTAssertNil(
            reduce(
                &state,
                .progressAdvanced(requestID: firstRequestID, phase: .generating)
            )
        )
        XCTAssertEqual(state.generationPhase, .generating)
        XCTAssertNil(
            reduce(
                &state,
                .progressAdvanced(requestID: firstRequestID, phase: .sending)
            )
        )
        XCTAssertEqual(state.generationPhase, .generating)
        XCTAssertNil(
            reduce(
                &state,
                .progressAdvanced(requestID: firstRequestID, phase: .almostReady)
            )
        )
        XCTAssertEqual(state.generationPhase, .almostReady)
    }

    func testMatchingSuccessCompletesOnceAndStaleResultsAreIgnored() {
        var state = startedState()

        XCTAssertNil(reduce(&state, .submissionSucceeded(requestID: secondRequestID)))
        XCTAssertTrue(state.isSubmitting)
        XCTAssertEqual(
            reduce(&state, .submissionSucceeded(requestID: firstRequestID)),
            .submissionCompleted(requestID: firstRequestID)
        )
        XCTAssertFalse(state.isSubmitting)
        XCTAssertNil(state.generationPhase)
        XCTAssertEqual(state.trimmedPrompt, "Ocean life")
        XCTAssertEqual(state.selectedQuestionCount, 10)
        XCTAssertEqual(state.selectedDifficulty, .hard)
        XCTAssertNil(reduce(&state, .submissionSucceeded(requestID: firstRequestID)))
    }

    func testFailurePreservesDraftAndRetryCreatesAnIndependentNewSubmission() {
        var state = startedState()
        let retryLocale = Locale(identifier: "en_US")
        let alert = AIQuizGenerationAlert(
            error: YandexAIQuizThemeServiceError.network(.timedOut)
        )

        XCTAssertNil(
            reduce(
                &state,
                .submissionFailed(requestID: secondRequestID, alert: alert)
            )
        )
        XCTAssertTrue(state.isSubmitting)
        XCTAssertEqual(
            reduce(
                &state,
                .submissionFailed(requestID: firstRequestID, alert: alert)
            ),
            .presentAlert(alert)
        )
        XCTAssertFalse(state.isSubmitting)
        XCTAssertNil(state.generationPhase)
        XCTAssertEqual(state.activeAlert, alert)
        XCTAssertEqual(state.trimmedPrompt, "Ocean life")
        XCTAssertEqual(state.selectedQuestionCount, 10)
        XCTAssertEqual(state.selectedDifficulty, .hard)

        guard case let .submit(retrySubmission)? = reduce(
            &state,
            .submitRequested(
                requestID: secondRequestID,
                locale: retryLocale,
                now: secondDate
            )
        ) else {
            return XCTFail("Expected a retry submission")
        }
        XCTAssertEqual(retrySubmission.id, secondRequestID)
        XCTAssertEqual(retrySubmission.startedAt, secondDate)
        XCTAssertEqual(retrySubmission.configuration.theme, "Ocean life")
        XCTAssertEqual(retrySubmission.configuration.questionCount, 10)
        XCTAssertEqual(retrySubmission.configuration.difficulty, .hard)
        XCTAssertEqual(retrySubmission.configuration.locale, retryLocale)
        XCTAssertNil(state.activeAlert)
        XCTAssertNil(reduce(&state, .submissionSucceeded(requestID: firstRequestID)))
        XCTAssertEqual(state.activeSubmission?.id, secondRequestID)
    }

    func testCancellationIsIdempotentAndKeepsDraftAvailableForRetry() {
        var state = startedState()
        let submission = state.activeSubmission

        XCTAssertEqual(
            reduce(&state, .cancelRequested),
            submission.map(HomeAIThemeCardEffect.cancelSubmission)
        )
        XCTAssertFalse(state.isSubmitting)
        XCTAssertNil(state.generationPhase)
        XCTAssertEqual(state.trimmedPrompt, "Ocean life")
        XCTAssertTrue(state.canSubmit)
        XCTAssertNil(reduce(&state, .cancelRequested))

        XCTAssertNotNil(
            reduce(
                &state,
                .submitRequested(requestID: secondRequestID, locale: locale, now: secondDate)
            )
        )
        XCTAssertEqual(state.activeSubmission?.id, secondRequestID)
    }

    func testResetCancelsActiveSubmissionOnceAndClearsEveryDraftField() {
        var state = startedState()
        let submission = state.activeSubmission

        XCTAssertEqual(
            reduce(&state, .reset),
            submission.map(HomeAIThemeCardEffect.cancelSubmission)
        )
        XCTAssertEqual(state, HomeAIThemeCardState())
        XCTAssertNil(reduce(&state, .reset))
        XCTAssertEqual(state, HomeAIThemeCardState())
    }

    func testAlertDismissalFocusesPromptOnlyForEditableFailures() {
        var state = startedState()
        let refusal = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.refused)
        _ = reduce(
            &state,
            .submissionFailed(requestID: firstRequestID, alert: refusal)
        )

        XCTAssertEqual(reduce(&state, .alertDismissed), .focusPrompt)
        XCTAssertNil(state.activeAlert)
        XCTAssertNil(reduce(&state, .alertDismissed))

        _ = reduce(
            &state,
            .submitRequested(requestID: secondRequestID, locale: locale, now: secondDate)
        )
        let network = AIQuizGenerationAlert(
            error: YandexAIQuizThemeServiceError.network(.timedOut)
        )
        _ = reduce(
            &state,
            .submissionFailed(requestID: secondRequestID, alert: network)
        )
        XCTAssertNil(reduce(&state, .alertDismissed))
        XCTAssertNil(state.activeAlert)
    }

    func testWhitespaceOnlyPromptCannotSubmit() {
        var state = HomeAIThemeCardState()
        _ = reduce(&state, .promptChanged(" \n "))

        XCTAssertNil(
            reduce(
                &state,
                .submitRequested(requestID: firstRequestID, locale: locale, now: firstDate)
            )
        )
        XCTAssertNil(state.activeSubmission)
        XCTAssertNil(state.generationPhase)
    }

    private func validDraftState() -> HomeAIThemeCardState {
        var state = HomeAIThemeCardState()
        _ = reduce(&state, .promptChanged("Ocean life"))
        return state
    }

    private func startedState() -> HomeAIThemeCardState {
        var state = validDraftState()
        _ = reduce(&state, .questionCountSelected(10))
        _ = reduce(&state, .difficultySelected(.hard))
        _ = reduce(
            &state,
            .submitRequested(requestID: firstRequestID, locale: locale, now: firstDate)
        )
        return state
    }

    @discardableResult
    private func reduce(
        _ state: inout HomeAIThemeCardState,
        _ action: HomeAIThemeCardAction
    ) -> HomeAIThemeCardEffect? {
        HomeAIThemeCardReducer.reduce(state: &state, action: action)
    }
}
