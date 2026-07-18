import UIKit

extension ExpandedThemeCardView {
    func configureParallaxObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reduceMotionStatusDidChange),
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
    }

    private var canUseTouchParallax: Bool {
        window != nil &&
            isApplicationActive &&
            !reduceMotionProvider() &&
            parallaxPresentationPhase.permitsTouchParallax(currentFace: face) &&
            !isFaceTransitionActive
    }

    func updateDeviceParallaxAvailability() {
        let shouldEnableTouch = canUseTouchParallax
        if cardParallaxPanGestureRecognizer.isEnabled != shouldEnableTouch {
            cardParallaxPanGestureRecognizer.isEnabled = shouldEnableTouch
        }

        let shouldStartDeviceMotion = window != nil &&
            isApplicationActive &&
            !reduceMotionProvider() &&
            deviceParallaxEnabledProvider() &&
            deviceMotionProvider.isAvailable &&
            !isTouchParallaxActive &&
            parallaxReturnAnimator == nil &&
            parallaxPresentationPhase.permitsDeviceMotion(currentFace: face)

        if shouldStartDeviceMotion, !isDeviceMotionActive {
            isDeviceMotionActive = true
            deviceMotionProvider.start { [weak self] input in
                guard let self else { return }
                if Thread.isMainThread {
                    self.receiveDeviceParallaxInput(input)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.receiveDeviceParallaxInput(input)
                    }
                }
            }
        } else if !shouldStartDeviceMotion, isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
            if !isTouchParallaxActive, parallaxReturnAnimator == nil {
                applyParallaxInput(.zero, disablesImplicitAnimations: true)
            }
        } else if !shouldStartDeviceMotion,
                  !isTouchParallaxActive,
                  parallaxReturnAnimator == nil,
                  !renderedParallaxInput.isNeutral {
            applyParallaxInput(.zero, disablesImplicitAnimations: true)
        }
    }

    func receiveDeviceParallaxInput(_ input: HomeThemeCardParallaxInput) {
        guard
            isDeviceMotionActive,
            !isTouchParallaxActive,
            !reduceMotionProvider(),
            parallaxPresentationPhase.permitsDeviceMotion(currentFace: face)
        else { return }

        applyParallaxInput(input, disablesImplicitAnimations: true)
    }

    func applyParallaxInput(
        _ input: HomeThemeCardParallaxInput,
        disablesImplicitAnimations: Bool
    ) {
        let renderState = HomeThemeCardParallaxRenderState(
            input: input,
            style: deviceParallaxStyle
        )

        let applyChanges = {
            if renderState.isNeutral {
                self.layer.sublayerTransform = CATransform3DIdentity
                self.perspectiveStageView.layer.transform = CATransform3DIdentity
                self.parallaxPoseProbeView.transform = .identity
            } else {
                var perspective = CATransform3DIdentity
                perspective.m34 = -1 / renderState.perspectiveDistance
                self.layer.sublayerTransform = perspective

                var cardTransform = CATransform3DIdentity
                cardTransform = CATransform3DRotate(
                    cardTransform,
                    renderState.rotationX,
                    1,
                    0,
                    0
                )
                cardTransform = CATransform3DRotate(
                    cardTransform,
                    renderState.rotationY,
                    0,
                    1,
                    0
                )
                self.perspectiveStageView.layer.transform = cardTransform
                self.parallaxPoseProbeView.transform = CGAffineTransform(
                    translationX: input.x,
                    y: input.y
                )
            }
        }

        if disablesImplicitAnimations {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            applyChanges()
            CATransaction.commit()
        } else {
            applyChanges()
        }
        renderedParallaxInput = input
    }

    func beginTouchParallax() {
        guard canUseTouchParallax else { return }
        let liveInput = presentationParallaxInput()
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)

        if isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
        }
        touchParallaxStartInput = liveInput
        isTouchParallaxActive = true
    }

    func finishTouchParallax(velocity: CGPoint) {
        guard isTouchParallaxActive else { return }
        isTouchParallaxActive = false

        let liveInput = presentationParallaxInput()
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)
        let normalizedVelocity = HomeThemeCardPanParallaxMapper.normalizedVelocity(
            velocity,
            in: bounds.size
        )
        let timing = UISpringTimingParameters(
            dampingRatio: Animation.parallaxReturnDamping,
            initialVelocity: CGVector(
                dx: relativeSpringVelocity(
                    normalizedVelocity.dx,
                    currentValue: liveInput.x
                ),
                dy: relativeSpringVelocity(
                    normalizedVelocity.dy,
                    currentValue: liveInput.y
                )
            )
        )
        let animator = UIViewPropertyAnimator(
            duration: Animation.parallaxReturnDuration,
            timingParameters: timing
        )
        parallaxReturnAnimator = animator
        animator.addAnimations { [weak self] in
            self?.applyParallaxInput(.zero, disablesImplicitAnimations: false)
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.parallaxReturnAnimator === animator else { return }
            self.parallaxReturnAnimator = nil
            self.applyParallaxInput(.zero, disablesImplicitAnimations: true)
            self.updateDeviceParallaxAvailability()
        }
        animator.startAnimation()
    }

    func relativeSpringVelocity(
        _ velocity: CGFloat,
        currentValue: CGFloat
    ) -> CGFloat {
        let remainingDistance = -currentValue
        guard abs(remainingDistance) > 0.01 else { return 0 }
        return min(max(velocity / remainingDistance, -8), 8)
    }

    func presentationParallaxInput() -> HomeThemeCardParallaxInput {
        guard let presentationTransform = parallaxPoseProbeView.layer.presentation()?.transform else {
            return renderedParallaxInput
        }

        return HomeThemeCardParallaxInput(
            x: presentationTransform.m41,
            y: presentationTransform.m42
        )
    }

    func cancelTouchParallaxAndReset() {
        isTouchParallaxActive = false
        touchParallaxStartInput = .zero
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(.zero, disablesImplicitAnimations: true)
    }

    func settleParallaxForPresentationTransition() {
        isTouchParallaxActive = false
        touchParallaxStartInput = .zero

        if isDeviceMotionActive {
            isDeviceMotionActive = false
            deviceMotionProvider.stop()
        }

        guard !reduceMotionProvider() else {
            cancelTouchParallaxAndReset()
            return
        }

        let liveInput = presentationParallaxInput()
        parallaxReturnAnimator?.stopAnimation(true)
        parallaxReturnAnimator = nil
        applyParallaxInput(liveInput, disablesImplicitAnimations: true)

        guard !liveInput.isNeutral else {
            applyParallaxInput(.zero, disablesImplicitAnimations: true)
            return
        }

        let animator = UIViewPropertyAnimator(
            duration: Animation.parallaxTransitionSettleDuration,
            curve: .easeOut
        )
        parallaxReturnAnimator = animator
        animator.addAnimations { [weak self] in
            self?.applyParallaxInput(.zero, disablesImplicitAnimations: false)
        }
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.parallaxReturnAnimator === animator else { return }
            self.parallaxReturnAnimator = nil
            self.applyParallaxInput(.zero, disablesImplicitAnimations: true)
            self.updateDeviceParallaxAvailability()
        }
        animator.startAnimation()
    }

    @objc func cardParallaxPanned(_ recognizer: UIPanGestureRecognizer) {
        handleFrontParallaxPan(
            state: recognizer.state,
            translation: recognizer.translation(in: self),
            velocity: recognizer.velocity(in: self)
        )
    }

    func handleFrontParallaxPan(
        state: UIGestureRecognizer.State,
        translation: CGPoint,
        velocity: CGPoint
    ) {
        switch state {
        case .began:
            beginTouchParallax()

        case .changed:
            if !isTouchParallaxActive {
                beginTouchParallax()
            }
            guard isTouchParallaxActive else { return }
            let input = HomeThemeCardPanParallaxMapper.input(
                translation: translation,
                in: bounds.size,
                startingAt: touchParallaxStartInput
            )
            applyParallaxInput(input, disablesImplicitAnimations: true)

        case .ended:
            guard isTouchParallaxActive else { return }
            let input = HomeThemeCardPanParallaxMapper.input(
                translation: translation,
                in: bounds.size,
                startingAt: touchParallaxStartInput
            )
            applyParallaxInput(input, disablesImplicitAnimations: true)
            finishTouchParallax(velocity: velocity)

        case .cancelled, .failed:
            finishTouchParallax(velocity: .zero)

        case .possible:
            break

        @unknown default:
            cancelTouchParallaxAndReset()
        }
    }

    @objc func applicationWillResignActive() {
        isApplicationActive = false
        cancelTouchParallaxAndReset()
        updateDeviceParallaxAvailability()
    }

    @objc func applicationDidBecomeActive() {
        isApplicationActive = true
        updateDeviceParallaxAvailability()
    }

    @objc func reduceMotionStatusDidChange() {
        if reduceMotionProvider() {
            cancelTouchParallaxAndReset()
        }
        updateDeviceParallaxAvailability()
    }

    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === cardParallaxPanGestureRecognizer else { return true }
        return canUseTouchParallax
    }

    func allowsParallaxPan(startingAt touchedView: UIView?) -> Bool {
        guard let touchedView else { return false }

        switch face {
        case .front:
            let touchesFront = touchedView === frontFaceView ||
                touchedView.isDescendant(of: frontFaceView)
            let touchesClose = touchedView === closeButton ||
                touchedView.isDescendant(of: closeButton)
            let touchesInfo = touchedView === infoButton ||
                touchedView.isDescendant(of: infoButton)
            return touchesFront && !touchesClose && !touchesInfo

        case .back:
            let touchesBack = touchedView === backFaceView ||
                touchedView.isDescendant(of: backFaceView)
            // A pan has its own movement threshold. Let it begin anywhere on
            // the back, including over controls: a stationary touch still
            // reaches the control, while an intentional drag cancels that
            // touch and drives the card tilt. Filtering UIControl descendants
            // left the whole central controls column as a dead parallax
            // zone, so the gesture appeared to work only near the edges.
            return touchesBack
        }
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        if gestureRecognizer === cardParallaxPanGestureRecognizer {
            return allowsParallaxPan(startingAt: touch.view)
        }
        guard gestureRecognizer === backTapGestureRecognizer else { return true }
        guard
            !descriptionScrollView.isTracking,
            !descriptionScrollView.isDragging,
            !descriptionScrollView.isDecelerating
        else { return false }

        var touchedView = touch.view
        while let currentView = touchedView, currentView !== backFaceView {
            if currentView is UIControl {
                return false
            }
            touchedView = currentView.superview
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        let isParallaxAndDescriptionPair =
            (gestureRecognizer === cardParallaxPanGestureRecognizer &&
                otherGestureRecognizer === descriptionScrollView.panGestureRecognizer) ||
            (gestureRecognizer === descriptionScrollView.panGestureRecognizer &&
                otherGestureRecognizer === cardParallaxPanGestureRecognizer)
        guard isParallaxAndDescriptionPair else { return false }
        return HomeThemeCardParallaxGesturePolicy
            .permitsSimultaneousDescriptionScroll(on: face)
    }

    @objc func closeTapped() {
        onClose?()
    }

    @objc func flipTapped() {
        onFlip?()
    }

    @objc func backTapped() {
        onBack?()
    }

    @objc func questionCountChanged() {
        let index = questionCountControl.selectedSegmentIndex
        guard Self.supportedQuestionCounts.indices.contains(index) else { return }
        let count = Self.supportedQuestionCounts[index]
        guard availableQuestionCounts.contains(count) else { return }
        selectedQuestionCount = count
        onQuestionCountChanged?(count)
    }

    @objc func startTapped() {
        guard startButton.isEnabled, selectedQuestionCount != nil else { return }
        onStart?()
    }
}
