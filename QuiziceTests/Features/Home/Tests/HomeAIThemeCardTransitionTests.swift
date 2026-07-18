import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeAIThemeCardTransitionTests: HomeScreenVisualStateTestCase {
    func testAIThemeGradientOutlineRemainsPresentThroughoutExpandAndCollapse() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let viewController = QuizViewController(cardReduceMotionProvider: { false })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton
        )
        let sourceHeight = sourceButton.bounds.height
        sourceButton.sendActions(for: .touchUpInside)
        CATransaction.flush()

        var outline = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionGradientOutline"
            )
        )
        var transition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedAIThemeCardTransition")
        )
        let expandedCard = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedAIThemeCard")
        )
        let targetHeight = expandedCard.bounds.height
        var animator = try XCTUnwrap(viewController.expandedCardAnimatorForTesting)
        try assertActualGradientOutlineMorphMidpoint(
            animator: animator,
            outline: outline,
            transition: transition,
            sourceHeight: sourceHeight,
            targetHeight: targetHeight
        )

        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionGradientOutline"
            )
        )

        let closeButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedAIThemeCardCloseButton"
            ) as? UIButton
        )
        closeButton.sendActions(for: .touchUpInside)
        CATransaction.flush()
        outline = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionGradientOutline"
            )
        )
        transition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedAIThemeCardTransition")
        )
        animator = try XCTUnwrap(viewController.expandedCardAnimatorForTesting)
        try assertActualGradientOutlineMorphMidpoint(
            animator: animator,
            outline: outline,
            transition: transition,
            sourceHeight: sourceHeight,
            targetHeight: targetHeight
        )

        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionGradientOutline"
            )
        )
    }

    func testRadarAIThemeTransitionKeepsTheExpandedAccentBorderAtBothHandoffs() throws {
        useDesignStyle(.radar)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let appearance = SnapshotSupport.appearance(designStyle: .radar)
        let viewController = QuizViewController(cardReduceMotionProvider: { false })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        CATransaction.flush()

        var transition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedAIThemeCardTransition")
        )
        try assertRadarAITransitionBorder(
            transition,
            appearance: appearance
        )

        var animator = try XCTUnwrap(viewController.expandedCardAnimatorForTesting)
        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)

        let closeButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedAIThemeCardCloseButton"
            ) as? UIButton
        )
        closeButton.sendActions(for: .touchUpInside)
        CATransaction.flush()

        transition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedAIThemeCardTransition")
        )
        try assertRadarAITransitionBorder(
            transition,
            appearance: appearance
        )

        animator = try XCTUnwrap(viewController.expandedCardAnimatorForTesting)
        animator.stopAnimation(false)
        animator.finishAnimation(at: .end)
    }

    private func assertRadarAITransitionBorder(
        _ transition: UIView,
        appearance: AppAppearance,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        XCTAssertNil(
            transition.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionGradientOutline"
            ),
            file: file,
            line: line
        )
        let chromeView = try XCTUnwrap(
            transition.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardTransitionChrome"
            ),
            file: file,
            line: line
        )
        let clippingView = try XCTUnwrap(chromeView.superview, file: file, line: line)
        let borderColor = clippingView.layer.borderColor.map { UIColor(cgColor: $0) }
        assertColor(borderColor, equals: appearance.accentColor, file: file, line: line)
        XCTAssertEqual(
            clippingView.layer.borderWidth,
            max(appearance.card.borderWidth, 1),
            accuracy: 0.001,
            file: file,
            line: line
        )
    }

    private func assertActualGradientOutlineMorphMidpoint(
        animator: UIViewPropertyAnimator,
        outline: UIView,
        transition: UIView,
        sourceHeight: CGFloat,
        targetHeight: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        animator.pauseAnimation()
        animator.fractionComplete = 0.5
        CATransaction.flush()

        XCTAssertEqual(animator.state, .active, file: file, line: line)
        XCTAssertFalse(animator.isRunning, file: file, line: line)
        XCTAssertEqual(animator.fractionComplete, 0.5, accuracy: 0.001, file: file, line: line)

        XCTAssertFalse(outline.layer is CAGradientLayer, file: file, line: line)
        let collapsedRing = try XCTUnwrap(
            outline.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionCollapsedGradientRing"
            ) as? UIImageView,
            file: file,
            line: line
        )
        let expandedRing = try XCTUnwrap(
            outline.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransitionExpandedGradientRing"
            ) as? UIImageView,
            file: file,
            line: line
        )
        XCTAssertEqual(collapsedRing.image?.resizingMode, .stretch, file: file, line: line)
        XCTAssertEqual(expandedRing.image?.resizingMode, .stretch, file: file, line: line)
        for ring in [collapsedRing, expandedRing] {
            let animationKeys = Set(ring.layer.animationKeys() ?? [])
            XCTAssertTrue(animationKeys.contains("position"), file: file, line: line)
            XCTAssertTrue(animationKeys.contains("bounds.size"), file: file, line: line)
            try assertMatchingFrameAnimations(
                ring.layer,
                outline.layer,
                file: file,
                line: line
            )
            assertFrame(
                ring.frame,
                equals: outline.bounds,
                accuracy: 0.001,
                file: file,
                line: line
            )
        }

        let clippingView = try XCTUnwrap(
            outline.superview,
            file: file,
            line: line
        )
        assertFrame(
            outline.frame,
            equals: clippingView.bounds,
            accuracy: 0.001,
            file: file,
            line: line
        )
        outline.layoutIfNeeded()
        let centerAlpha = try renderedAlpha(
            in: outline,
            at: CGPoint(x: outline.bounds.midX, y: outline.bounds.midY),
            file: file,
            line: line
        )
        let topBorderAlpha = try renderedAlpha(
            in: outline,
            at: CGPoint(x: outline.bounds.midX, y: 0.8),
            file: file,
            line: line
        )
        XCTAssertLessThan(centerAlpha, 0.02, file: file, line: line)
        XCTAssertGreaterThan(topBorderAlpha, 0.2, file: file, line: line)

        let transitionAnimationKeys = Set(transition.layer.animationKeys() ?? [])
        XCTAssertTrue(transitionAnimationKeys.contains("position"), file: file, line: line)
        XCTAssertTrue(transitionAnimationKeys.contains("bounds.size"), file: file, line: line)

        let outlineAnimationKeys = Set(outline.layer.animationKeys() ?? [])
        XCTAssertTrue(outlineAnimationKeys.contains("position"), file: file, line: line)
        XCTAssertTrue(outlineAnimationKeys.contains("bounds.size"), file: file, line: line)

        XCTAssertTrue(clippingView.layer.masksToBounds, file: file, line: line)
        XCTAssertGreaterThan(clippingView.layer.cornerRadius, 0, file: file, line: line)
        let clippingAnimationKeys = Set(clippingView.layer.animationKeys() ?? [])
        XCTAssertTrue(clippingAnimationKeys.contains("position"), file: file, line: line)
        XCTAssertTrue(clippingAnimationKeys.contains("bounds.size"), file: file, line: line)
        XCTAssertTrue(clippingAnimationKeys.contains("cornerRadius"), file: file, line: line)

        let chromeView = try XCTUnwrap(
            transition.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransitionChrome"),
            file: file,
            line: line
        )
        let chromeAnimationKeys = Set(chromeView.layer.animationKeys() ?? [])
        XCTAssertTrue(chromeAnimationKeys.contains("position"), file: file, line: line)
        XCTAssertTrue(chromeAnimationKeys.contains("bounds.size"), file: file, line: line)
        XCTAssertGreaterThan(chromeView.frame.minX, clippingView.bounds.minX, file: file, line: line)
        XCTAssertGreaterThan(chromeView.frame.minY, clippingView.bounds.minY, file: file, line: line)

        let transitionAnimation = try XCTUnwrap(
            transition.layer.animation(forKey: "bounds.size"),
            file: file,
            line: line
        )
        XCTAssertGreaterThan(transitionAnimation.duration, 0, file: file, line: line)

        let lowerHeight = min(sourceHeight, targetHeight)
        let upperHeight = max(sourceHeight, targetHeight)
        XCTAssertGreaterThan(
            upperHeight,
            lowerHeight + 1,
            file: file,
            line: line
        )
    }

    private func renderedAlpha(
        in view: UIView,
        at point: CGPoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CGFloat {
        var pixel = [UInt8](repeating: 0, count: 4)
        let context = try XCTUnwrap(
            CGContext(
                data: &pixel,
                width: 1,
                height: 1,
                bitsPerComponent: 8,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ),
            file: file,
            line: line
        )
        context.translateBy(x: -point.x, y: -point.y)
        view.layer.render(in: context)
        return CGFloat(pixel[3]) / 255
    }

    private func assertFrame(
        _ actual: CGRect,
        equals expected: CGRect,
        accuracy: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.minY, expected.minY, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, file: file, line: line)
    }

    private func assertMatchingFrameAnimations(
        _ childLayer: CALayer,
        _ parentLayer: CALayer,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        for key in ["position", "bounds.size"] {
            let childAnimation = try XCTUnwrap(
                childLayer.animation(forKey: key) as? CABasicAnimation,
                file: file,
                line: line
            )
            let parentAnimation = try XCTUnwrap(
                parentLayer.animation(forKey: key) as? CABasicAnimation,
                file: file,
                line: line
            )
            XCTAssertEqual(childAnimation.keyPath, parentAnimation.keyPath, file: file, line: line)
            XCTAssertEqual(
                String(describing: childAnimation.fromValue),
                String(describing: parentAnimation.fromValue),
                file: file,
                line: line
            )
            XCTAssertEqual(
                String(describing: childAnimation.toValue),
                String(describing: parentAnimation.toValue),
                file: file,
                line: line
            )
        }
    }

}
