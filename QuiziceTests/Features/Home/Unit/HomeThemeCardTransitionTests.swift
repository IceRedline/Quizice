import XCTest
@testable import Quizice

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
