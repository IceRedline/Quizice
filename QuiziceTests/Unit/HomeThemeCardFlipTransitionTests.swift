import XCTest
@testable import Quizice

final class HomeThemeCardFlipTransitionTests: XCTestCase {
    func testFrontToBackUsesOneMonotonicHalfTurn() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .front, targetFace: .back)
        )

        let angles = [CGFloat(0), 0.25, 0.5, 0.75, 1].map {
            transition.carrierAngle(progress: $0)
        }

        XCTAssertEqual(angles[0], 0, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[1], -.pi / 4, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[2], -.pi / 2, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[3], -.pi * 3 / 4, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[4], -.pi, accuracy: 0.000_000_001)
        zip(angles, angles.dropFirst()).forEach { previous, next in
            XCTAssertLessThan(next, previous)
        }
    }

    func testBackToFrontReversesTheSameCarrierPath() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .back, targetFace: .front)
        )

        let angles = [CGFloat(0), 0.25, 0.5, 0.75, 1].map {
            transition.carrierAngle(progress: $0)
        }

        XCTAssertEqual(angles[0], -.pi, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[1], -.pi * 3 / 4, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[2], -.pi / 2, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[3], -.pi / 4, accuracy: 0.000_000_001)
        XCTAssertEqual(angles[4], 0, accuracy: 0.000_000_001)
        zip(angles, angles.dropFirst()).forEach { previous, next in
            XCTAssertGreaterThan(next, previous)
        }
    }

    func testFacesKeepAFixedHalfTurnOffsetThroughoutTheFlip() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .front, targetFace: .back)
        )

        XCTAssertEqual(
            HomeThemeCardFlipTransition.localAngle(for: .back) -
                HomeThemeCardFlipTransition.localAngle(for: .front),
            .pi,
            accuracy: 0.000_000_001
        )
        for progress in stride(from: CGFloat(0), through: 1, by: 0.1) {
            XCTAssertEqual(
                transition.worldAngle(for: .back, progress: progress) -
                    transition.worldAngle(for: .front, progress: progress),
                .pi,
                accuracy: 0.000_000_001
            )
        }
    }

    func testFrontToBackHandsVisibilityOverAtTheCardEdge() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .front, targetFace: .back)
        )

        assertEdgeHandoff(
            transition,
            outgoingFace: .front,
            incomingFace: .back
        )
    }

    func testBackToFrontHandsVisibilityOverAtTheCardEdge() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .back, targetFace: .front)
        )

        assertEdgeHandoff(
            transition,
            outgoingFace: .back,
            incomingFace: .front
        )
    }

    func testProgressIsClampedToUnitInterval() throws {
        let transition = try XCTUnwrap(
            HomeThemeCardFlipTransition(startFace: .front, targetFace: .back)
        )

        XCTAssertEqual(
            transition.carrierAngle(progress: -1),
            transition.carrierAngle(progress: 0),
            accuracy: 0.000_000_001
        )
        XCTAssertEqual(
            transition.carrierAngle(progress: 2),
            transition.carrierAngle(progress: 1),
            accuracy: 0.000_000_001
        )
        for face in [HomeThemeCardFace.front, .back] {
            XCTAssertEqual(
                transition.worldAngle(for: face, progress: -1),
                transition.worldAngle(for: face, progress: 0),
                accuracy: 0.000_000_001
            )
            XCTAssertEqual(
                transition.projectedWidth(for: face, progress: -1),
                transition.projectedWidth(for: face, progress: 0),
                accuracy: 0.000_000_001
            )
            XCTAssertEqual(
                transition.worldAngle(for: face, progress: 2),
                transition.worldAngle(for: face, progress: 1),
                accuracy: 0.000_000_001
            )
            XCTAssertEqual(
                transition.projectedWidth(for: face, progress: 2),
                transition.projectedWidth(for: face, progress: 1),
                accuracy: 0.000_000_001
            )
        }
    }

    func testTransitionIsNilWhenFacesAreEqual() {
        XCTAssertNil(HomeThemeCardFlipTransition(startFace: .front, targetFace: .front))
        XCTAssertNil(HomeThemeCardFlipTransition(startFace: .back, targetFace: .back))
    }

    private func assertEdgeHandoff(
        _ transition: HomeThemeCardFlipTransition,
        outgoingFace: HomeThemeCardFace,
        incomingFace: HomeThemeCardFace,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let outgoingBefore = transition.projectedWidth(for: outgoingFace, progress: 0.49)
        let outgoingAtEdge = transition.projectedWidth(for: outgoingFace, progress: 0.50)
        let outgoingAfter = transition.projectedWidth(for: outgoingFace, progress: 0.51)

        XCTAssertGreaterThan(outgoingBefore, 0, file: file, line: line)
        XCTAssertEqual(outgoingAtEdge, 0, accuracy: 0.000_000_001, file: file, line: line)
        XCTAssertLessThan(outgoingAfter, 0, file: file, line: line)

        let incomingBefore = transition.projectedWidth(for: incomingFace, progress: 0.49)
        let incomingAtEdge = transition.projectedWidth(for: incomingFace, progress: 0.50)
        let incomingAfter = transition.projectedWidth(for: incomingFace, progress: 0.51)

        XCTAssertLessThan(incomingBefore, 0, file: file, line: line)
        XCTAssertEqual(incomingAtEdge, 0, accuracy: 0.000_000_001, file: file, line: line)
        XCTAssertGreaterThan(incomingAfter, 0, file: file, line: line)
    }
}
