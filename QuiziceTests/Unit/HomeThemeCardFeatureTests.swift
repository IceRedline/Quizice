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
    func testCenteredContentKeepsNaturalBoundsAndFollowsContainerCenterThroughoutReveal() {
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
            let sourceContentFrameInContainer = geometry.centeredFrame(size: sourceFrame.size)
            let sourceContentFrameInRoot = sourceContentFrameInContainer.offsetBy(
                dx: containerFrame.minX,
                dy: containerFrame.minY
            )

            XCTAssertEqual(geometry.cardFrameInContainer.size, targetFrame.size)
            XCTAssertEqual(sourceContentFrameInContainer.size, sourceFrame.size)
            XCTAssertEqual(
                geometry.cardFrameInRoot.midX,
                containerFrame.midX,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                geometry.cardFrameInRoot.midY,
                containerFrame.midY,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                sourceContentFrameInRoot.midX,
                containerFrame.midX,
                accuracy: 0.000_001
            )
            XCTAssertEqual(
                sourceContentFrameInRoot.midY,
                containerFrame.midY,
                accuracy: 0.000_001
            )

            if progress == 1 {
                XCTAssertEqual(geometry.cardFrameInRoot, targetFrame)
            }
        }
    }

    func testContentTranslationsAlignImageAndTitleOffsetsWithoutChangingBounds() {
        let sourceGeometry = HomeThemeCardContentGeometry(
            containerSize: CGSize(width: 163, height: 163),
            imageCenter: CGPoint(x: 81.5, y: 57),
            titleCenter: CGPoint(x: 81.5, y: 129)
        )
        let destinationSize = CGSize(width: 350, height: 518)
        let destinationImageCenter = CGPoint(x: 175, y: 231)
        let destinationTitleCenter = CGPoint(x: 152, y: 478)

        let imageTranslation = sourceGeometry.imageTranslation(
            toAlignDestinationCenter: destinationImageCenter,
            in: destinationSize
        )
        let titleTranslation = sourceGeometry.titleTranslation(
            toAlignDestinationCenter: destinationTitleCenter,
            in: destinationSize
        )

        XCTAssertEqual(
            destinationImageCenter.x - destinationSize.width / 2 + imageTranslation.x,
            sourceGeometry.imageCenter.x - sourceGeometry.containerSize.width / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            destinationImageCenter.y - destinationSize.height / 2 + imageTranslation.y,
            sourceGeometry.imageCenter.y - sourceGeometry.containerSize.height / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            destinationTitleCenter.x - destinationSize.width / 2 + titleTranslation.x,
            sourceGeometry.titleCenter.x - sourceGeometry.containerSize.width / 2,
            accuracy: 0.000_001
        )
        XCTAssertEqual(
            destinationTitleCenter.y - destinationSize.height / 2 + titleTranslation.y,
            sourceGeometry.titleCenter.y - sourceGeometry.containerSize.height / 2,
            accuracy: 0.000_001
        )
    }

    private func interpolate(_ start: CGFloat, _ end: CGFloat, progress: CGFloat) -> CGFloat {
        start + (end - start) * progress
    }
}

final class HomeThemeCardTransitionVisualStateTests: XCTestCase {
    private let progressSamples: [CGFloat] = [0, 0.25, 0.5, 0.75, 1]

    func testProgressClampsToUnitInterval() {
        XCTAssertEqual(HomeThemeCardTransitionVisualState(progress: -0.5).progress, 0)
        XCTAssertEqual(HomeThemeCardTransitionVisualState(progress: 0.4).progress, 0.4)
        XCTAssertEqual(HomeThemeCardTransitionVisualState(progress: 1.5).progress, 1)
    }

    func testSourceAndExpandedContentAlphasAreComplementary() {
        for progress in progressSamples {
            let state = HomeThemeCardTransitionVisualState(progress: progress)

            XCTAssertEqual(state.sourceContentAlpha, 1 - progress, accuracy: 0.000_001)
            XCTAssertEqual(state.expandedContentAlpha, progress, accuracy: 0.000_001)
            XCTAssertEqual(
                state.sourceContentAlpha + state.expandedContentAlpha,
                1,
                accuracy: 0.000_001
            )
        }
    }

    func testExpandedSurfaceLayerAlphaIsMonotonic() {
        let alphas = progressSamples.map {
            HomeThemeCardTransitionVisualState(progress: $0).expandedSurfaceLayerAlpha
        }

        XCTAssertEqual(alphas.first, 0)
        XCTAssertEqual(alphas.last, 1)
        for (previous, current) in zip(alphas, alphas.dropFirst()) {
            XCTAssertGreaterThanOrEqual(current, previous)
        }
    }

    func testCompositedSurfaceAlphaIsExactAndMonotonicForSupportedBaseAlphas() {
        for baseAlpha in [CGFloat(0.2), 0.84, 1.0] {
            let actualAlphas = progressSamples.map { progress in
                HomeThemeCardTransitionVisualState(progress: progress)
                    .compositedSurfaceAlpha(baseAlpha: baseAlpha)
            }
            let expectedAlphas = progressSamples.map { progress in
                baseAlpha + baseAlpha * (1 - baseAlpha) * progress
            }

            for (actual, expected) in zip(actualAlphas, expectedAlphas) {
                XCTAssertEqual(actual, expected, accuracy: 0.000_001)
            }
            for (previous, current) in zip(actualAlphas, actualAlphas.dropFirst()) {
                XCTAssertGreaterThanOrEqual(current, previous)
            }
        }
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

    func testStatisticsPresentationUsesDedicatedIdentityAndClearsThemeSetupState() {
        var state = HomeThemeCardState()

        let effect = reduce(&state, .presentStatistics)

        XCTAssertEqual(effect, .expandStatistics)
        XCTAssertEqual(state.phase, .expanding)
        XCTAssertEqual(state.presentedCard, .statistics)
        XCTAssertTrue(state.isStatisticsPresented)
        XCTAssertNil(state.themeID)
        XCTAssertNil(state.presentedThemeID)
        XCTAssertEqual(state.availableQuestionCounts, [])
        XCTAssertNil(state.selectedQuestionCount)
        XCTAssertFalse(state.canStart)

        XCTAssertNil(reduce(&state, .presentStatistics))
        XCTAssertNil(
            reduce(
                &state,
                .present(
                    themeID: "music",
                    availableQuestionCounts: [5, 10, 15],
                    preferredQuestionCount: 10
                )
            )
        )
        XCTAssertEqual(state.presentedCard, .statistics)
        XCTAssertEqual(state.phase, .expanding)
    }

    func testExpandedStatisticsRejectsThemeOnlyActionsAndCollapsesToGrid() {
        var state = statisticsPresentedState()

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(state.phase, .expandedFront)
        XCTAssertTrue(state.isStatisticsPresented)

        let expandedState = state
        XCTAssertNil(reduce(&state, .flipRequested))
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertNil(reduce(&state, .questionCountSelected(5)))
        XCTAssertNil(reduce(&state, .startRequested))
        XCTAssertEqual(state, expandedState)

        XCTAssertEqual(reduce(&state, .closeRequested), .collapseStatistics)
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertTrue(state.isStatisticsPresented)
        XCTAssertNil(reduce(&state, .collapseCompleted))
        XCTAssertEqual(state, HomeThemeCardState())
        XCTAssertFalse(state.isStatisticsPresented)
    }

    func testStatisticsExpansionCanReverseWithoutLosingItsIdentity() {
        var state = statisticsPresentedState()

        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: false)
        )
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertEqual(state.presentedCard, .statistics)
        XCTAssertTrue(state.isStatisticsPresented)

        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: true)
        )
        XCTAssertEqual(state.phase, .expanding)
        XCTAssertEqual(state.presentedCard, .statistics)

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(state.phase, .expandedFront)
        XCTAssertTrue(state.isStatisticsPresented)
    }

    func testThemePresentationRejectsStatisticsUntilThemeReturnsToGrid() {
        var state = presentedState()

        XCTAssertNil(reduce(&state, .presentStatistics))
        XCTAssertEqual(state.presentedCard, .theme("music"))
        XCTAssertFalse(state.isStatisticsPresented)

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(reduce(&state, .closeRequested), .collapse(themeID: "music"))
        XCTAssertNil(reduce(&state, .collapseCompleted))
        XCTAssertEqual(state, HomeThemeCardState())

        XCTAssertEqual(reduce(&state, .presentStatistics), .expandStatistics)
        XCTAssertEqual(state.presentedCard, .statistics)
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

    func testRapidCloseRequestsReverseExpansionWithoutLosingThemeState() {
        var state = presentedState()

        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: false)
        )
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertEqual(state.themeID, "music")

        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: true)
        )
        XCTAssertEqual(state.phase, .expanding)
        XCTAssertEqual(state.themeID, "music")

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(state.phase, .expandedFront)
    }

    func testCollapsingExpandedCardCanBeReopenedBeforeCompletion() {
        var state = presentedState()
        _ = reduce(&state, .expansionCompleted)

        XCTAssertEqual(reduce(&state, .closeRequested), .collapse(themeID: "music"))
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: true)
        )
        XCTAssertEqual(state.phase, .expanding)
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

    private func statisticsPresentedState() -> HomeThemeCardState {
        var state = HomeThemeCardState()
        _ = reduce(&state, .presentStatistics)
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
