import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeExpandedThemeCardMotionTests: HomeScreenVisualStateTestCase {
    func testExpandedThemeExpansionUsesIndependentArtworkAndTitleDepth() throws {
        let card = ExpandedThemeCardView(frame: CGRect(x: 0, y: 0, width: 350, height: 518))
        card.reduceMotionProvider = { false }
        card.configure(
            theme: makeTheme(name: "Музыка", questionCount: 5),
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            availableQuestionCounts: [5],
            selectedQuestionCount: 5
        )
        card.layoutIfNeeded()

        let artworkDepth = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontArtworkDepth")
        )
        let titleDepth = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontTitleDepth")
        )
        let sourceGeometry = HomeThemeCardContentGeometry(
            containerSize: CGSize(width: 163, height: 163),
            imageCenter: CGPoint(x: 81.5, y: 54),
            titleCenter: CGPoint(x: 81.5, y: 132)
        )

        card.setTransitionContentProgress(0, sourceGeometry: sourceGeometry)

        XCTAssertEqual(artworkDepth.transform.a, 0.94, accuracy: 0.000_001)
        XCTAssertEqual(artworkDepth.transform.d, 0.94, accuracy: 0.000_001)
        XCTAssertEqual(titleDepth.transform.a, 0.985, accuracy: 0.000_001)
        XCTAssertEqual(titleDepth.transform.d, 0.985, accuracy: 0.000_001)
        XCTAssertNotEqual(artworkDepth.transform.ty, 0)
        XCTAssertNotEqual(titleDepth.transform.ty, 0)

        card.setTransitionContentProgress(1, sourceGeometry: sourceGeometry)

        XCTAssertTrue(artworkDepth.transform.isIdentity)
        XCTAssertTrue(titleDepth.transform.isIdentity)
    }

    func testExpandedThemeInjectedDevicePoseTiltsWholeCardWithoutDetachingFrontContent() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            cardReduceMotionProvider: { false },
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCard"
            ) as? ExpandedThemeCardView
        )
        let parallaxCarrier = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier"
            )
        )
        let frontImage = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardFrontImageView"
            )
        )
        let frontTitle = card.frontFocusView
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardInfoButton"
            ) as? UIButton
        )
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardCloseButton"
            ) as? UIButton
        )
        let rotatingCarrier = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier"
            )
        )

        XCTAssertGreaterThanOrEqual(motionProvider.startCallCount, 1)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        motionProvider.send(HomeThemeCardParallaxInput(x: 0.5, y: -0.25))

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(closeButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        motionProvider.send(.zero)

        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(closeButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
    }

    func testExpandedThemeMotionProviderStaysActiveAcrossFlipAndBackThenStopsOnRemoval() throws {
        let motionProvider = HomeThemeCardMotionProviderFake()
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView

        card.setParallaxPresentationPhase(.front)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertTrue(motionProvider.isStarted)

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.75, y: 0.5))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        let frontPoseTransform = parallaxCarrier.layer.transform

        card.setParallaxPresentationPhase(.flipping)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                parallaxCarrier.layer.transform,
                frontPoseTransform
            )
        )

        var completedFace: HomeThemeCardFace?
        card.setFace(.back, animated: true) { face in
            completedFace = face
            card.setParallaxPresentationPhase(.back)
        }
        let flippingCarrierTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: 0.4, y: 0.3))

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertFalse(
            CATransform3DEqualToTransform(
                parallaxCarrier.layer.transform,
                frontPoseTransform
            )
        )
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                flippingCarrierTransform
            )
        )
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertNil(completedFace)

        drainAnimations(0.34)

        XCTAssertEqual(completedFace, .back)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        let backFlipTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.2, y: -0.6))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.removeFromSuperview()
        XCTAssertEqual(motionProvider.stopCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
    }

    func testExpandedThemeFrontPanTiltsRigidCardAndSpringsBackToIdentity() throws {
        let motionProvider = HomeThemeCardMotionProviderFake(isAvailable: false)
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView
        let infoButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )

        card.setParallaxPresentationPhase(.front)
        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 72, y: -84),
            velocity: .zero
        )

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        card.handleFrontParallaxPan(
            state: .ended,
            translation: CGPoint(x: 72, y: -84),
            velocity: CGPoint(x: 180, y: -120)
        )
        drainAnimations(0.45)

        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
    }

    func testExpandedThemeBackDeviceMotionAndPanBothTiltWholeCard() throws {
        let motionProvider = HomeThemeCardMotionProviderFake()
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView

        card.setParallaxPresentationPhase(.front)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        card.setParallaxPresentationPhase(.flipping)
        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        let backFlipTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.5, y: 0.25))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        XCTAssertEqual(motionProvider.stopCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)

        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 112, y: -40),
            velocity: .zero
        )
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.handleFrontParallaxPan(
            state: .ended,
            translation: CGPoint(x: 112, y: -40),
            velocity: CGPoint(x: 150, y: -80)
        )
        drainAnimations(0.45)

        XCTAssertEqual(motionProvider.startCallCount, 2)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
    }

    func testExpandedThemeParallaxPanLeavesBackScrollAndControlsInteractive() throws {
        let card = makeHostedExpandedThemeCard(
            motionProvider: HomeThemeCardMotionProviderFake(isAvailable: false)
        )
        card.setParallaxPresentationPhase(.front)

        let parallaxPan = try XCTUnwrap(
            parallaxPanGestureRecognizer(in: card)
        )
        let infoButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        let closeButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        let descriptionScrollView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView
        )
        let descriptionLabel = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel
        )
        let backTitleLabel = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel
        )
        let backSurfaceButton = try XCTUnwrap(
            card.descendant(
                withAccessibilityIdentifier: "expandedThemeCardBackSurfaceButton"
            ) as? UIButton
        )
        let backFaceView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let backTap = try XCTUnwrap(
            backFaceView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first
        )
        let questionCountControl = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UISegmentedControl
        )
        let startButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        let backButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )

        XCTAssertTrue(parallaxPan.cancelsTouchesInView)
        XCTAssertFalse(parallaxPan.delaysTouchesBegan)
        XCTAssertEqual(parallaxPan.maximumNumberOfTouches, 1)
        XCTAssertTrue(parallaxPan.isEnabled)
        XCTAssertTrue(hitView(in: card, for: infoButton)?.isDescendant(of: infoButton) == true)
        XCTAssertTrue(hitView(in: card, for: closeButton)?.isDescendant(of: closeButton) == true)
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)

        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        card.layoutIfNeeded()

        var selectedQuestionCount: Int?
        var startCallCount = 0
        var backCallCount = 0
        card.onQuestionCountChanged = { selectedQuestionCount = $0 }
        card.onStart = { startCallCount += 1 }
        card.onBack = { backCallCount += 1 }

        XCTAssertTrue(parallaxPan.isEnabled)
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)
        XCTAssertTrue(descriptionScrollView.isDirectionalLockEnabled)
        XCTAssertFalse(parallaxPan === descriptionScrollView.panGestureRecognizer)
        XCTAssertTrue(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: descriptionScrollView.panGestureRecognizer
            )
        )
        XCTAssertTrue(
            card.gestureRecognizer(
                descriptionScrollView.panGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: parallaxPan
            )
        )
        XCTAssertFalse(
            card.gestureRecognizer(
                backTap,
                shouldRecognizeSimultaneouslyWith: parallaxPan
            )
        )
        XCTAssertFalse(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: backTap
            )
        )
        XCTAssertTrue(questionCountControl.isEnabled)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
        XCTAssertTrue(card.gestureRecognizerShouldBegin(parallaxPan))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: descriptionScrollView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: descriptionLabel))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: questionCountControl))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: startButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backTitleLabel))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backSurfaceButton))
        let questionCountHitView = try XCTUnwrap(hitView(in: card, for: questionCountControl))
        let startHitView = try XCTUnwrap(hitView(in: card, for: startButton))
        let backHitView = try XCTUnwrap(hitView(in: card, for: backButton))
        XCTAssertTrue(questionCountHitView.isDescendant(of: questionCountControl))
        XCTAssertTrue(startHitView.isDescendant(of: startButton))
        XCTAssertTrue(backHitView.isDescendant(of: backButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: questionCountHitView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: startHitView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backHitView))

        questionCountControl.selectedSegmentIndex = 0
        questionCountControl.sendActions(for: .valueChanged)
        startButton.sendActions(for: .touchUpInside)
        backButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(selectedQuestionCount, 5)
        XCTAssertEqual(startCallCount, 1)
        XCTAssertEqual(backCallCount, 1)
    }

    func testExpandedThemeBackCenterSupportsVerticalTiltAndDescriptionScrollTogether() throws {
        let card = makeHostedExpandedThemeCard(
            motionProvider: HomeThemeCardMotionProviderFake(isAvailable: false)
        )
        let longDescription = Array(
            repeating: "A deliberately long theme description that must scroll vertically.",
            count: 24
        ).joined(separator: " ")
        card.configure(
            theme: makeTheme(
                name: "Музыка",
                questionCount: 5,
                description: longDescription
            ),
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            availableQuestionCounts: [5],
            selectedQuestionCount: 5
        )
        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        card.layoutIfNeeded()

        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let parallaxPan = try XCTUnwrap(parallaxPanGestureRecognizer(in: card))
        let descriptionScrollView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView
        )
        let centerInCard = descriptionScrollView.convert(
            CGPoint(
                x: descriptionScrollView.bounds.midX,
                y: descriptionScrollView.bounds.midY
            ),
            to: card
        )
        let centerHitView = try XCTUnwrap(card.hitTest(centerInCard, with: nil))

        XCTAssertGreaterThan(
            descriptionScrollView.contentSize.height,
            descriptionScrollView.bounds.height
        )
        XCTAssertTrue(
            centerHitView === descriptionScrollView ||
                centerHitView.isDescendant(of: descriptionScrollView)
        )
        XCTAssertTrue(card.allowsParallaxPan(startingAt: centerHitView))
        XCTAssertTrue(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: descriptionScrollView.panGestureRecognizer
            )
        )

        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 0, y: 72),
            velocity: CGPoint(x: 0, y: 180)
        )

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)

        card.handleFrontParallaxPan(
            state: .cancelled,
            translation: CGPoint(x: 0, y: 72),
            velocity: .zero
        )
        drainAnimations(0.45)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
    }

    func testExpandedThemeStartStopsBackMotionBeforeRoutingAndIgnoresRepeatedStart() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            cardReduceMotionProvider: { false },
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let infoButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardInfoButton"
            ) as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCard"
            ) as? ExpandedThemeCardView
        )
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let parallaxPan = try XCTUnwrap(parallaxPanGestureRecognizer(in: card))
        let startButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )

        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(parallaxPan.isEnabled)
        motionProvider.send(HomeThemeCardParallaxInput(x: 0.6, y: -0.4))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))

        var providerWasStoppedBeforeRouting: Bool?
        var panWasDisabledBeforeRouting: Bool?
        router.onShowQuestion = {
            providerWasStoppedBeforeRouting = !motionProvider.isStarted &&
                motionProvider.stopCallCount > 0
            panWasDisabledBeforeRouting = !parallaxPan.isEnabled
        }

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(providerWasStoppedBeforeRouting, true)
        XCTAssertEqual(panWasDisabledBeforeRouting, true)
        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertFalse(card.isUserInteractionEnabled)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)
    }

}
