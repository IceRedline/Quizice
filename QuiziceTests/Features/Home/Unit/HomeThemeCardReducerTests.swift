import XCTest
@testable import Quizice

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

    func testAIPresentationUsesDedicatedIdentityAndRequiresPromptBeforeShowingBack() {
        var state = HomeThemeCardState()

        XCTAssertEqual(reduce(&state, .presentAI), .expandAI)
        XCTAssertEqual(state.presentedCard, .ai)
        XCTAssertTrue(state.isAIThemePresented)
        XCTAssertFalse(state.isFlipAllowed)
        XCTAssertEqual(state.phase, .expanding)
        XCTAssertNil(reduce(&state, .presentAI))
        XCTAssertNil(reduce(&state, .presentStatistics))

        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertNil(reduce(&state, .flipRequested))
        XCTAssertEqual(state.phase, .expandedFront)

        XCTAssertNil(reduce(&state, .flipAvailabilityChanged(true)))
        XCTAssertTrue(state.isFlipAllowed)
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
        XCTAssertNil(reduce(&state, .flipCompleted(.back)))
        XCTAssertEqual(state.phase, .expandedBack)
    }

    func testAIBackAlwaysReturnsToFrontAndCollapsesWithDedicatedEffect() {
        var state = aiExpandedBackState()

        XCTAssertNil(reduce(&state, .flipAvailabilityChanged(false)))
        XCTAssertFalse(state.isFlipAllowed)
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.front))
        XCTAssertNil(reduce(&state, .flipCompleted(.front)))
        XCTAssertEqual(state.phase, .expandedFront)
        XCTAssertNil(reduce(&state, .flipRequested))

        XCTAssertEqual(reduce(&state, .closeRequested), .collapseAI)
        XCTAssertEqual(state.phase, .collapsing)
        XCTAssertTrue(state.isAIThemePresented)
        XCTAssertNil(reduce(&state, .collapseCompleted))
        XCTAssertEqual(state, HomeThemeCardState())
        XCTAssertFalse(state.isAIThemePresented)
    }

    func testAIExpansionCanReverseWithoutLosingPromptFlipAvailability() {
        var state = HomeThemeCardState()
        _ = reduce(&state, .presentAI)
        _ = reduce(&state, .flipAvailabilityChanged(true))

        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: false)
        )
        XCTAssertTrue(state.isAIThemePresented)
        XCTAssertTrue(state.isFlipAllowed)
        XCTAssertEqual(
            reduce(&state, .closeRequested),
            .reverseExpansion(shouldPresent: true)
        )
        XCTAssertEqual(state.presentedCard, .ai)
        XCTAssertTrue(state.isFlipAllowed)
        XCTAssertNil(reduce(&state, .expansionCompleted))
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
    }

    func testThemeFlipRemainsAvailableWithoutAIAvailabilitySignal() {
        var state = presentedState()
        _ = reduce(&state, .expansionCompleted)

        XCTAssertFalse(state.isFlipAllowed)
        XCTAssertEqual(reduce(&state, .flipRequested), .flip(.back))
        XCTAssertNil(reduce(&state, .flipAvailabilityChanged(true)))
        XCTAssertFalse(state.isFlipAllowed)
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

    private func aiExpandedBackState() -> HomeThemeCardState {
        var state = HomeThemeCardState()
        _ = reduce(&state, .presentAI)
        _ = reduce(&state, .flipAvailabilityChanged(true))
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
