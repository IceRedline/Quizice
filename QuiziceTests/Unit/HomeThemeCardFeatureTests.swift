import XCTest
@testable import Quizice

final class QuizQuestionCountPolicyTests: XCTestCase {
    func testAvailableCountsUseOnlyUsableQuestionsAtSupportedBoundaries() {
        let questions = makeUsableQuestions(count: 15) + [
            makeQuestion(text: "   "),
            makeQuestion(answers: ["A", "B", "C"]),
            makeQuestion(correctAnswer: "   "),
            makeQuestion(answers: ["A", "A", "B", "C"])
        ]

        XCTAssertEqual(QuizQuestionCountPolicy.supportedCounts, [5, 10, 15])
        XCTAssertEqual(QuizQuestionCountPolicy.usableQuestionCount(in: questions), 15)
        XCTAssertEqual(QuizQuestionCountPolicy.availableCounts(for: questions), [5, 10, 15])
        XCTAssertEqual(
            QuizQuestionCountPolicy.availableCounts(for: Array(questions.prefix(9))),
            [5]
        )
        XCTAssertEqual(
            QuizQuestionCountPolicy.availableCounts(for: Array(questions.prefix(4))),
            []
        )
    }

    func testQuestionMustHaveTextFourAnswersAndOneExactNonblankCorrectAnswer() {
        XCTAssertTrue(QuizQuestionCountPolicy.isUsable(makeQuestion()))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(text: "\n\t")))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(answers: ["A", "B", "C"])))
        XCTAssertFalse(QuizQuestionCountPolicy.isUsable(makeQuestion(correctAnswer: " ")))
        XCTAssertFalse(
            QuizQuestionCountPolicy.isUsable(
                makeQuestion(answers: ["A", "A", "B", "C"], correctAnswer: "A")
            )
        )
        XCTAssertFalse(
            QuizQuestionCountPolicy.isUsable(
                makeQuestion(answers: ["A", "B", "C", "D"], correctAnswer: "E")
            )
        )
    }

    func testInitialSelectionKeepsAvailablePreferenceOrUsesMinimum() {
        XCTAssertEqual(
            QuizQuestionCountPolicy.initialSelection(preferred: 10, available: [5, 10, 15]),
            10
        )
        XCTAssertEqual(
            QuizQuestionCountPolicy.initialSelection(preferred: 15, available: [10, 5, 99]),
            5
        )
        XCTAssertNil(QuizQuestionCountPolicy.initialSelection(preferred: 5, available: []))
    }

    private func makeUsableQuestions(count: Int) -> [QuestionModel] {
        (0..<count).map { makeQuestion(text: "Question \($0)?") }
    }

    private func makeQuestion(
        text: String = "Question?",
        answers: [String] = ["A", "B", "C", "D"],
        correctAnswer: String = "A"
    ) -> QuestionModel {
        QuestionModel(
            quizQuestion: QuizQuestion(
                question: text,
                answers: answers,
                correctAnswer: correctAnswer
            )
        )
    }
}

final class HomeThemeCardTransitionGeometryTests: XCTestCase {
    func testExpandedCardKeepsItsNaturalSizeAndRootPositionThroughoutReveal() {
        let sourceFrame = CGRect(x: 24, y: 496, width: 163, height: 163)
        let targetFrame = CGRect(x: 20, y: 126, width: 350, height: 518)

        for progress in [CGFloat.zero, 0.25, 0.5, 0.75, 1] {
            let containerFrame = CGRect(
                x: interpolate(sourceFrame.minX, targetFrame.minX, progress: progress),
                y: interpolate(sourceFrame.minY, targetFrame.minY, progress: progress),
                width: interpolate(sourceFrame.width, targetFrame.width, progress: progress),
                height: interpolate(sourceFrame.height, targetFrame.height, progress: progress)
            )
            let geometry = HomeThemeCardTransitionGeometry(
                containerFrame: containerFrame,
                targetFrame: targetFrame
            )

            XCTAssertEqual(geometry.cardFrameInContainer.size, targetFrame.size)
            XCTAssertEqual(geometry.cardFrameInRoot.minX, targetFrame.minX, accuracy: 0.000_001)
            XCTAssertEqual(geometry.cardFrameInRoot.minY, targetFrame.minY, accuracy: 0.000_001)
            XCTAssertEqual(geometry.cardFrameInRoot.width, targetFrame.width, accuracy: 0.000_001)
            XCTAssertEqual(geometry.cardFrameInRoot.height, targetFrame.height, accuracy: 0.000_001)
        }
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

final class HomeThemeCardReducerTests: XCTestCase {
    func testPresentationNormalizesCountsAndKeepsAvailablePreference() {
        var state = HomeThemeCardState()

        let effect = reduce(
            &state,
            .present(
                themeID: "music",
                availableQuestionCounts: [15, 10, 10, 99, 5],
                preferredQuestionCount: 10
            )
        )

        XCTAssertEqual(effect, .expand(themeID: "music"))
        XCTAssertEqual(state.phase, .expanding)
        XCTAssertEqual(state.presentedThemeID, "music")
        XCTAssertEqual(state.availableQuestionCounts, [5, 10, 15])
        XCTAssertEqual(state.selectedQuestionCount, 10)
        XCTAssertFalse(state.canStart)

        XCTAssertNil(
            reduce(
                &state,
                .present(
                    themeID: "sports",
                    availableQuestionCounts: [5],
                    preferredQuestionCount: nil
                )
            )
        )
        XCTAssertEqual(state.themeID, "music")
    }

    func testFrontBackSelectionAndStartLifecycleLaunchesOnlyOnce() {
        var state = presentedState()

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(state.phase, .expandedFront)
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
        XCTAssertEqual(state.phase, .flippingToBack)
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertEqual(state.phase, .expandedBack)

        XCTAssertNil(reduce(&state, .questionCountSelected(15)))
        XCTAssertEqual(state.selectedQuestionCount, 15)
        XCTAssertTrue(state.canStart)
        XCTAssertEqual(
            reduce(&state, .startRequested),
            .launch(themeID: "music", questionCount: 15)
        )
        XCTAssertEqual(state.phase, .launching)
        XCTAssertNil(reduce(&state, .startRequested))
    }

    func testBackCanFlipToFrontAndCollapseToCleanGridState() {
        var state = expandedBackState()

        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.front))
        XCTAssertEqual(state.phase, .flippingToFront)
        XCTAssertNil(reduce(&state, .flipCompleted(.front)))
        XCTAssertEqual(state.phase, .expandedFront)
        XCTAssertEqual(reduce(&state, .closeRequested), .collapse(themeID: "music"))
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertNil(reduce(&state, .collapseCompleted))
        XCTAssertEqual(state, HomeThemeCardState())
        XCTAssertNil(state.presentedThemeID)
    }

    func testUnavailableCountCannotBeSelectedOrLaunched() {
        var state = expandedBackState(availableQuestionCounts: [])

        XCTAssertNil(reduce(&state, .questionCountSelected(5)))
        XCTAssertNil(state.selectedQuestionCount)
        XCTAssertFalse(state.canStart)
        XCTAssertNil(reduce(&state, .startRequested))
        XCTAssertEqual(state.phase, .expandedBack)
    }

    func testResetAlwaysClearsTransientStateAndLateCompletionsAreIgnored() {
        var state = presentedState()

        XCTAssertNil(reduce(&state, .reset))
        XCTAssertEqual(state, HomeThemeCardState())
        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertNil(reduce(&state, .flipCompleted(.front)))
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertNil(reduce(&state, .collapseCompleted))
        XCTAssertEqual(state, HomeThemeCardState())
    }

    func testRapidFlipRequestsRetargetAndIgnoreStaleCompletions() {
        var state = presentedState()
        _ = reduce(&state, .expansionCompleted)

        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
        XCTAssertEqual(state.phase, .flippingToBack)
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.front))
        XCTAssertEqual(state.phase, .flippingToFront)
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertEqual(state.phase, .flippingToFront)

        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
        XCTAssertEqual(state.phase, .flippingToBack)
        XCTAssertNil(reduce(&state, .flipCompleted(.front)))
        XCTAssertEqual(state.phase, .flippingToBack)
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertEqual(state.phase, .expandedBack)
    }

    private func presentedState(
        availableQuestionCounts: [Int] = [5, 10, 15]
    ) -> HomeThemeCardState {
        var state = HomeThemeCardState()
        _ = reduce(
            &state,
            .present(
                themeID: "music",
                availableQuestionCounts: availableQuestionCounts,
                preferredQuestionCount: 10
            )
        )
        return state
    }

    private func expandedBackState(
        availableQuestionCounts: [Int] = [5, 10, 15]
    ) -> HomeThemeCardState {
        var state = presentedState(availableQuestionCounts: availableQuestionCounts)
        _ = reduce(&state, .expansionCompleted)
        _ = reduce(&state, .flipRequested)
        _ = reduce(&state, .flipCompleted(.back))
        return state
    }

    @discardableResult
    private func reduce(
        _ state: inout HomeThemeCardState,
        _ action: HomeThemeCardAction
    ) -> HomeThemeCardEffect? {
        HomeThemeCardReducer.reduce(state: &state, action: action)
    }
}
