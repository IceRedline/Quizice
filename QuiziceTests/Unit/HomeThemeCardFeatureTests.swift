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

final class HomeThemeCardExpansionParallaxStateTests: XCTestCase {
    func testProgressClampsAndResolvesExactDepthEndpoints() {
        let beforeStart = HomeThemeCardExpansionParallaxState(progress: -1)
        let start = HomeThemeCardExpansionParallaxState(progress: 0)
        let end = HomeThemeCardExpansionParallaxState(progress: 1)
        let afterEnd = HomeThemeCardExpansionParallaxState(progress: 2)

        XCTAssertEqual(beforeStart, start)
        XCTAssertEqual(afterEnd, end)
        XCTAssertEqual(start.artworkScale, 0.94, accuracy: 0.000_001)
        XCTAssertEqual(start.titleScale, 0.985, accuracy: 0.000_001)
        XCTAssertEqual(end.artworkScale, 1, accuracy: 0.000_001)
        XCTAssertEqual(end.titleScale, 1, accuracy: 0.000_001)
    }

    func testArtworkAndTitleDepthResolveMonotonicallyWithoutOvershoot() {
        let samples = [CGFloat(0), 0.25, 0.5, 0.75, 1].map {
            HomeThemeCardExpansionParallaxState(progress: $0)
        }

        for (previous, next) in zip(samples, samples.dropFirst()) {
            XCTAssertGreaterThan(next.artworkScale, previous.artworkScale)
            XCTAssertGreaterThan(next.titleScale, previous.titleScale)
            XCTAssertLessThanOrEqual(next.artworkScale, 1)
            XCTAssertLessThanOrEqual(next.titleScale, 1)
        }
        XCTAssertLessThan(samples[2].artworkScale, samples[2].titleScale)
    }
}

final class HomeThemeCardParallaxPresentationPhaseTests: XCTestCase {
    func testPresentedFacesAndFlipPermitContinuousDeviceMotion() {
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.front
                .permitsDeviceMotion(currentFace: .front)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.front
                .permitsDeviceMotion(currentFace: .back)
        )
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.back
                .permitsDeviceMotion(currentFace: .back)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.back
                .permitsDeviceMotion(currentFace: .front)
        )
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.flipping
                .permitsDeviceMotion(currentFace: .front)
        )
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.flipping
                .permitsDeviceMotion(currentFace: .back)
        )
        for phase in [
            HomeThemeCardParallaxPresentationPhase.inactive,
            .expanding,
            .collapsing
        ] {
            XCTAssertFalse(phase.permitsDeviceMotion(currentFace: .front))
            XCTAssertFalse(phase.permitsDeviceMotion(currentFace: .back))
        }
    }

    func testTouchParallaxRequiresAStableMatchingFace() {
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.front
                .permitsTouchParallax(currentFace: .front)
        )
        XCTAssertTrue(
            HomeThemeCardParallaxPresentationPhase.back
                .permitsTouchParallax(currentFace: .back)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.front
                .permitsTouchParallax(currentFace: .back)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.back
                .permitsTouchParallax(currentFace: .front)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.flipping
                .permitsTouchParallax(currentFace: .front)
        )
        XCTAssertFalse(
            HomeThemeCardParallaxPresentationPhase.flipping
                .permitsTouchParallax(currentFace: .back)
        )
    }

    func testOnlyPresentedAndFlippingPhasesPreserveParallaxContinuity() {
        XCTAssertTrue(HomeThemeCardParallaxPresentationPhase.front.preservesParallaxContinuity)
        XCTAssertTrue(HomeThemeCardParallaxPresentationPhase.flipping.preservesParallaxContinuity)
        XCTAssertTrue(HomeThemeCardParallaxPresentationPhase.back.preservesParallaxContinuity)
        XCTAssertFalse(HomeThemeCardParallaxPresentationPhase.inactive.preservesParallaxContinuity)
        XCTAssertFalse(HomeThemeCardParallaxPresentationPhase.expanding.preservesParallaxContinuity)
        XCTAssertFalse(HomeThemeCardParallaxPresentationPhase.collapsing.preservesParallaxContinuity)
    }

    func testReducerPhasesMapToParallaxLifecycle() {
        XCTAssertEqual(HomeThemeCardPhase.grid.parallaxPresentationPhase, .inactive)
        XCTAssertEqual(HomeThemeCardPhase.expanding.parallaxPresentationPhase, .expanding)
        XCTAssertEqual(HomeThemeCardPhase.expandedFront.parallaxPresentationPhase, .front)
        XCTAssertEqual(HomeThemeCardPhase.flippingToBack.parallaxPresentationPhase, .flipping)
        XCTAssertEqual(HomeThemeCardPhase.flippingToFront.parallaxPresentationPhase, .flipping)
        XCTAssertEqual(HomeThemeCardPhase.expandedBack.parallaxPresentationPhase, .back)
        XCTAssertEqual(HomeThemeCardPhase.collapsing.parallaxPresentationPhase, .collapsing)
        XCTAssertEqual(HomeThemeCardPhase.launching.parallaxPresentationPhase, .inactive)
    }

    func testStandardDeviceStyleKeepsRigidCardTiltSubtle() {
        let style = HomeThemeCardDeviceParallaxStyle.standard

        XCTAssertEqual(style.horizontalRotation, 7 * .pi / 180, accuracy: 0.000_001)
        XCTAssertEqual(style.verticalRotation, 5 * .pi / 180, accuracy: 0.000_001)
        XCTAssertGreaterThan(style.perspectiveDistance, 0)
    }
}

final class HomeThemeCardParallaxInputTests: XCTestCase {
    func testInputClampsEachAxisToNormalizedRange() {
        let minimum = HomeThemeCardParallaxInput(x: -2, y: -1.5)
        let maximum = HomeThemeCardParallaxInput(x: 1.5, y: 2)
        let interior = HomeThemeCardParallaxInput(x: 0.375, y: -0.625)

        XCTAssertEqual(minimum.x, -1)
        XCTAssertEqual(minimum.y, -1)
        XCTAssertEqual(maximum.x, 1)
        XCTAssertEqual(maximum.y, 1)
        XCTAssertEqual(interior.x, 0.375)
        XCTAssertEqual(interior.y, -0.625)
    }

    func testInputNeutralityUsesTheDocumentedDeadBand() {
        XCTAssertTrue(HomeThemeCardParallaxInput.zero.isNeutral)
        XCTAssertTrue(HomeThemeCardParallaxInput(x: 0.000_09, y: -0.000_09).isNeutral)
        XCTAssertFalse(HomeThemeCardParallaxInput(x: 0.000_1, y: 0).isNeutral)
        XCTAssertFalse(HomeThemeCardParallaxInput(x: 0, y: -0.000_1).isNeutral)
    }
}

final class HomeThemeCardPanParallaxMapperTests: XCTestCase {
    private let containerSize = CGSize(width: 100, height: 100)

    func testTranslationPreservesFingerDirectionAndNormalizesByAxisTravel() {
        let input = HomeThemeCardPanParallaxMapper.input(
            translation: CGPoint(x: 16, y: -12),
            in: containerSize
        )

        XCTAssertEqual(input.x, 0.5, accuracy: 0.000_001)
        XCTAssertEqual(input.y, -0.5, accuracy: 0.000_001)
    }

    func testTranslationStartsFromExistingInputAndClampsAtBothEdges() {
        let positiveEdge = HomeThemeCardPanParallaxMapper.input(
            translation: CGPoint(x: 64, y: 48),
            in: containerSize,
            startingAt: HomeThemeCardParallaxInput(x: 0.25, y: 0.25)
        )
        let negativeEdge = HomeThemeCardPanParallaxMapper.input(
            translation: CGPoint(x: -64, y: -48),
            in: containerSize,
            startingAt: HomeThemeCardParallaxInput(x: -0.25, y: -0.25)
        )

        XCTAssertEqual(positiveEdge, HomeThemeCardParallaxInput(x: 1, y: 1))
        XCTAssertEqual(negativeEdge, HomeThemeCardParallaxInput(x: -1, y: -1))
    }

    func testVelocityIsNormalizedWithMatchingSignsWithoutInputClamping() {
        let velocity = HomeThemeCardPanParallaxMapper.normalizedVelocity(
            CGPoint(x: 64, y: -48),
            in: containerSize
        )

        XCTAssertEqual(velocity.dx, 2, accuracy: 0.000_001)
        XCTAssertEqual(velocity.dy, -2, accuracy: 0.000_001)
    }
}

final class HomeThemeCardParallaxGesturePolicyTests: XCTestCase {
    func testBackPermitsParallaxAlongsideDescriptionScrolling() {
        XCTAssertTrue(
            HomeThemeCardParallaxGesturePolicy
                .permitsSimultaneousDescriptionScroll(on: .back)
        )
    }

    func testFrontDoesNotShareItsPanWithHiddenBackDescription() {
        XCTAssertFalse(
            HomeThemeCardParallaxGesturePolicy
                .permitsSimultaneousDescriptionScroll(on: .front)
        )
    }
}

final class HomeThemeCardParallaxRenderStateTests: XCTestCase {
    func testRenderStateMapsInputToExactRigidCardRotation() {
        let style = HomeThemeCardDeviceParallaxStyle(
            horizontalRotation: 0.7,
            verticalRotation: 0.5,
            perspectiveDistance: 760
        )
        let state = HomeThemeCardParallaxRenderState(
            input: HomeThemeCardParallaxInput(x: 0.5, y: -0.25),
            style: style
        )

        XCTAssertEqual(state.rotationX, 0.125, accuracy: 0.000_001)
        XCTAssertEqual(state.rotationY, -0.35, accuracy: 0.000_001)
        XCTAssertEqual(state.perspectiveDistance, 760)
        XCTAssertFalse(state.isNeutral)
    }

    func testZeroInputProducesAnExactlyNeutralVisibleTransform() {
        let state = HomeThemeCardParallaxRenderState(input: .zero)

        XCTAssertEqual(state.rotationX, 0)
        XCTAssertEqual(state.rotationY, 0)
        XCTAssertEqual(
            state.perspectiveDistance,
            HomeThemeCardDeviceParallaxStyle.standard.perspectiveDistance
        )
        XCTAssertTrue(state.isNeutral)
    }
}

final class HomeThemeCardMotionInputMapperTests: XCTestCase {
    func testMotionInputPreservesPhysicalRotationWhileSharingTouchRenderer() {
        let input = HomeThemeCardMotionInputMapper.input(
            relativeRoll: 0.25,
            relativePitch: -0.5,
            responseAngle: 1
        )
        let state = HomeThemeCardParallaxRenderState(
            input: input,
            style: HomeThemeCardDeviceParallaxStyle(
                horizontalRotation: 1,
                verticalRotation: 1,
                perspectiveDistance: 760
            )
        )

        XCTAssertEqual(input.x, -0.25, accuracy: 0.000_001)
        XCTAssertEqual(input.y, -0.5, accuracy: 0.000_001)
        XCTAssertEqual(state.rotationY, 0.25, accuracy: 0.000_001)
        XCTAssertEqual(state.rotationX, 0.5, accuracy: 0.000_001)
    }

    func testMotionInputClampsAndHandlesZeroResponseAngle() {
        let input = HomeThemeCardMotionInputMapper.input(
            relativeRoll: -2,
            relativePitch: 2,
            responseAngle: 0
        )

        XCTAssertEqual(input, HomeThemeCardParallaxInput(x: 1, y: 1))
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
