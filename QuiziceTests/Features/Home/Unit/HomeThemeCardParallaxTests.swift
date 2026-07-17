import XCTest
@testable import Quizice

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
