//
//  Animations.swift
//  My First App
//
//  Created by Артем Табенский on 14.12.2024.
//

import UIKit

final class Animations {
    
    func animateDownSpring(_ viewToAnimate: UIView) {
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.2,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
            viewToAnimate.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    func animateUpSpring(_ viewToAnimate: UIView) {
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            usingSpringWithDamping: 0.2,
            initialSpringVelocity: 10,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
            viewToAnimate.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
    
    func animateDownFloat(_ viewToAnimate: UIView, duration: Double = 0.2) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0.2,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
            viewToAnimate.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        })
    }
    
    func animateUpFloat(_ viewToAnimate: UIView, duration: Double = 0.15) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
            viewToAnimate.transform = CGAffineTransform(scaleX: 1, y: 1)
        })
    }
    
    func animateDownRadius(_ viewToAnimate: UIView) {
        if viewToAnimate.layer.cornerRadius == 0 {
            UIView.animate(withDuration: 1, delay: 0) {
                viewToAnimate.layer.cornerRadius = 15
            }
        } else {
            UIView.animate(withDuration: 1, delay: 0) {
                viewToAnimate.layer.cornerRadius = 0
            }
        }
    }
    
    func animateTintColor(_ viewToAnimate: UIView, color: UIColor = UIColor.black, duration: Double = 0.5) {
        UIView.transition(
            with: viewToAnimate,
            duration: duration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
            viewToAnimate.tintColor = color
        })
    }
    
    func animateBackgroundColor(_ viewToAnimate: UIView, color: CGColor, duration: Double = 0.5) {
        UIView.transition(
            with: viewToAnimate,
            duration: duration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                viewToAnimate.layer.backgroundColor = color
            })
    }
}

extension UIView {
    
    func fadeIn(duration: TimeInterval = 0.2, onCompletion: (() -> Void)? = nil) {
        self.alpha = 0
        self.isHidden = false
        UIView.animate(withDuration: duration,
                       animations: { self.alpha = 1 },
                       completion: { (value: Bool) in
                          if let complete = onCompletion { complete() }
                       }
        )
    }
    
    func fadeOut(duration: TimeInterval = 0.2, onCompletion: (() -> Void)? = nil) {
        UIView.animate(withDuration: duration,
                       animations: { self.alpha = 0 },
                       completion: { (value: Bool) in
                           self.isHidden = true
                           if let complete = onCompletion { complete() }
                       }
        )
    }
}

enum QuizCardSlideTransition {
    static let duration: TimeInterval = 0.34
    static let options: UIView.AnimationOptions = [.curveEaseInOut]

    static func horizontalOffset(in containerView: UIView, horizontalInset: CGFloat) -> CGFloat {
        containerView.bounds.width + horizontalInset
    }
}

protocol QuizCardSlideTransitionSource: AnyObject {
    var cardSlideTransitionSourceView: UIView { get }
    var cardSlideTransitionHorizontalInset: CGFloat { get }
}

protocol QuizCardSlideTransitionDestination: AnyObject {
    var cardSlideTransitionDestinationView: UIView { get }
    var cardSlideTransitionHorizontalInset: CGFloat { get }
    var cardSlideTransitionDestinationCompanionViews: [UIView] { get }
}

extension QuizCardSlideTransitionDestination {
    var cardSlideTransitionDestinationCompanionViews: [UIView] { [] }
}

final class QuizCardSlidePresentationAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    weak var sourceViewController: QuizCardSlideTransitionSource?

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        QuizCardSlideTransition.duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard
            let toViewController = transitionContext.viewController(forKey: .to),
            let toView = transitionContext.view(forKey: .to)
        else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: toViewController)
        toView.frame = finalFrame.isEmpty ? containerView.bounds : finalFrame
        containerView.addSubview(toView)

        guard
            !UIAccessibility.isReduceMotionEnabled,
            let fromViewController = sourceViewController ?? (transitionContext.viewController(forKey: .from) as? QuizCardSlideTransitionSource),
            let toViewController = toViewController as? QuizCardSlideTransitionDestination
        else {
            sourceViewController = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        toView.setNeedsLayout()
        toView.layoutIfNeeded()

        let sourceView = fromViewController.cardSlideTransitionSourceView
        let destinationView = toViewController.cardSlideTransitionDestinationView
        let destinationCompanionViews = toViewController.cardSlideTransitionDestinationCompanionViews
        let originalBackgroundColor = toView.backgroundColor
        let horizontalInset = max(
            fromViewController.cardSlideTransitionHorizontalInset,
            toViewController.cardSlideTransitionHorizontalInset
        )
        let horizontalOffset = QuizCardSlideTransition.horizontalOffset(
            in: containerView,
            horizontalInset: horizontalInset
        )

        guard
            horizontalOffset > 0,
            let sourceSnapshot = sourceView.snapshotView(afterScreenUpdates: false)
        else {
            sourceViewController = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            return
        }

        sourceSnapshot.frame = sourceView.convert(sourceView.bounds, to: containerView)
        sourceView.isHidden = true
        toView.backgroundColor = .clear
        destinationView.transform = CGAffineTransform(translationX: horizontalOffset, y: 0)
        destinationCompanionViews.forEach { $0.alpha = 0 }
        destinationView.isUserInteractionEnabled = false
        containerView.addSubview(sourceSnapshot)

        UIView.animate(
            withDuration: transitionDuration(using: transitionContext),
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: {
                sourceSnapshot.transform = CGAffineTransform(translationX: -horizontalOffset, y: 0)
                destinationView.transform = .identity
                destinationCompanionViews.forEach { $0.alpha = 1 }
            },
            completion: { _ in
                let completed = !transitionContext.transitionWasCancelled
                sourceSnapshot.removeFromSuperview()
                sourceView.isHidden = false
                destinationView.transform = .identity
                destinationCompanionViews.forEach { $0.alpha = 1 }
                destinationView.isUserInteractionEnabled = true
                toView.backgroundColor = originalBackgroundColor
                self.sourceViewController = nil
                transitionContext.completeTransition(completed)
            }
        )
    }
}
