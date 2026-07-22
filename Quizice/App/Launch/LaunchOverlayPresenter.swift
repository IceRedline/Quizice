import SwiftUI
import UIKit

@MainActor
final class LaunchOverlayPresenter {
    private enum Timing {
        static let holdDuration: TimeInterval = 1.15
        static let homeRevealDuration: TimeInterval = 0.24
        static let reducedMotionRevealDuration: TimeInterval = 0.18
    }

    static let accessibilityIdentifier = "fakeLaunchScreen"

    private var overlayWindow: UIWindow?
    private var activePresentationID: UUID?
    private var activeDismissalID: UUID?
    private var preparationTask: Task<Void, Never>?
    private var isPreparationComplete = true
    private var pendingCompletionStyle: FakeLaunchCompletionStyle?
    private weak var coveredAccessibilityView: UIView?
    private var coveredViewWasAccessibilityHidden = false

    func present(
        in window: UIWindow,
        appearance: AppAppearance,
        holdDuration: TimeInterval = Timing.holdDuration,
        motion: FakeLaunchMotion = .standard,
        preparation: (@MainActor () async -> Void)? = nil
    ) {
        guard
            overlayWindow == nil,
            let windowScene = window.windowScene,
            let coveredView = window.rootViewController?.view
        else { return }

        let visualStyle = FakeLaunchVisualStyle(appearance: appearance)
        let presentationID = UUID()
        let hostingController = UIHostingController(
            rootView: FakeLaunchScreenView(
                appearance: appearance,
                holdDuration: holdDuration,
                motion: motion,
                onFinished: { [weak self] style in
                    self?.completePresentation(presentationID, with: style)
                }
            )
        )
        let overlayView = hostingController.view!
        overlayView.accessibilityIdentifier = Self.accessibilityIdentifier
        overlayView.accessibilityElementsHidden = true
        overlayView.backgroundColor = visualStyle.backgroundColor
        hostingController.overrideUserInterfaceStyle = appearance.resolvedInterfaceStyle

        let overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow.accessibilityIdentifier = Self.accessibilityIdentifier
        overlayWindow.accessibilityViewIsModal = true
        overlayWindow.backgroundColor = visualStyle.backgroundColor
        overlayWindow.windowLevel = UIWindow.Level(rawValue: window.windowLevel.rawValue + 1)
        overlayWindow.rootViewController = hostingController

        coveredAccessibilityView = coveredView
        coveredViewWasAccessibilityHidden = coveredView.accessibilityElementsHidden
        coveredView.accessibilityElementsHidden = true
        activePresentationID = presentationID
        isPreparationComplete = preparation == nil
        pendingCompletionStyle = nil
        self.overlayWindow = overlayWindow
        overlayWindow.isHidden = false

        if let preparation {
            preparationTask = Task { @MainActor [weak self] in
                await preparation()
                guard
                    let self,
                    activePresentationID == presentationID,
                    !Task.isCancelled
                else { return }
                preparationTask = nil
                isPreparationComplete = true
                guard let pendingCompletionStyle else { return }
                self.pendingCompletionStyle = nil
                completePresentation(presentationID, with: pendingCompletionStyle)
            }
        }
    }

    func dismiss(animated: Bool = true) {
        let duration = UIAccessibility.isReduceMotionEnabled
            ? Timing.reducedMotionRevealDuration
            : Timing.homeRevealDuration
        dismiss(animated: animated, duration: duration)
    }

    private func dismiss(animated: Bool, duration: TimeInterval) {
        preparationTask?.cancel()
        preparationTask = nil
        pendingCompletionStyle = nil
        isPreparationComplete = true
        activePresentationID = nil

        guard let overlayWindow else { return }

        guard animated, UIView.areAnimationsEnabled else {
            activeDismissalID = nil
            overlayWindow.layer.removeAllAnimations()
            finishDismissal(expectedWindow: overlayWindow)
            return
        }

        let dismissalID = UUID()
        activeDismissalID = dismissalID
        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]
        ) {
            overlayWindow.alpha = 0
        } completion: { [weak self, weak overlayWindow] _ in
            guard
                let self,
                let overlayWindow,
                activeDismissalID == dismissalID
            else { return }
            finishDismissal(expectedWindow: overlayWindow)
        }
    }

    private func completePresentation(
        _ presentationID: UUID,
        with style: FakeLaunchCompletionStyle
    ) {
        guard activePresentationID == presentationID else { return }
        guard isPreparationComplete else {
            pendingCompletionStyle = style
            return
        }

        switch style {
        case .revealHome:
            dismiss(animated: true, duration: Timing.homeRevealDuration)
        case .crossfade:
            dismiss(animated: true, duration: Timing.reducedMotionRevealDuration)
        }
    }

    private func finishDismissal(expectedWindow: UIWindow? = nil) {
        if let expectedWindow, overlayWindow !== expectedWindow {
            return
        }

        overlayWindow?.layer.removeAllAnimations()
        activePresentationID = nil
        activeDismissalID = nil
        pendingCompletionStyle = nil
        isPreparationComplete = true
        overlayWindow?.isHidden = true
        overlayWindow?.rootViewController = nil
        overlayWindow = nil

        coveredAccessibilityView?.accessibilityElementsHidden = coveredViewWasAccessibilityHidden
        coveredAccessibilityView = nil
        UIAccessibility.post(notification: .screenChanged, argument: nil)
    }
}
