import UIKit
import AVKit
import SwiftUI

extension QuizQuestionViewController {
    @IBAction func answerChosen(_ sender: UIButton) {
        guard sender.isEnabled else { return }
        guard
            let selectedIndex = answerButtons.firstIndex(where: { $0 === sender }),
            currentAnswerOptions.indices.contains(selectedIndex)
        else { return }
        
        feedbackPlayer.prepare()
        feedbackPlayer.reset()
        colorAndDisableButtons()
        presenter?.checkAnswer(optionID: currentAnswerOptions[selectedIndex].id)
        presenter?.stopTimer()
        nextButton.isEnabled = true
    }
    
    @IBAction func nextButtonTapped() {
        guard !isQuestionTransitionInProgress else { return }
        presenter?.checkQuestionNumberAndProceed()
    }

    @objc func questionInfoButtonTapped() {
        guard
            isQuestionInfoAvailable,
            !isQuestionExplanationVisible,
            !isQuestionTransitionInProgress
        else { return }
        setQuestionExplanationVisible(true, animated: true)
    }

    @objc func questionExplanationBackButtonTapped() {
        guard isQuestionExplanationVisible, !isQuestionTransitionInProgress else { return }
        setQuestionExplanationVisible(false, animated: true)
    }

    func setQuestionExplanationVisible(_ isVisible: Bool, animated: Bool) {
        guard questionLabel != nil else { return }

        guard isQuestionExplanationVisible != isVisible else {
            applyQuestionExplanationVisibility()
            return
        }

        isQuestionExplanationVisible = isVisible
        if isVisible {
            questionExplanationScrollView.setContentOffset(.zero, animated: false)
        }

        let outgoingViews: [UIView]
        let incomingViews: [UIView]
        if isVisible {
            outgoingViews = [questionLabel, questionInfoButton]
            incomingViews = [questionExplanationScrollView, questionExplanationBackButton]
        } else {
            outgoingViews = [questionExplanationScrollView, questionExplanationBackButton]
            incomingViews = isQuestionInfoAvailable
                ? [questionLabel, questionInfoButton]
                : [questionLabel]
        }

        let shouldAnimate = animated
            && UIView.areAnimationsEnabled
            && !UIAccessibility.isReduceMotionEnabled
            && view.window != nil
        guard shouldAnimate else {
            applyQuestionExplanationVisibility()
            postQuestionContentAccessibilityFocus()
            return
        }

        incomingViews.forEach {
            $0.alpha = 0
            $0.isHidden = false
        }
        outgoingViews.forEach {
            $0.alpha = 1
            $0.isHidden = false
        }

        UIView.animate(
            withDuration: AnimationTiming.explanationTransitionDuration,
            delay: 0,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: {
                outgoingViews.forEach { $0.alpha = 0 }
                incomingViews.forEach { $0.alpha = 1 }
            },
            completion: { [weak self] _ in
                guard let self else { return }
                self.applyQuestionExplanationVisibility()
                self.postQuestionContentAccessibilityFocus()
            }
        )
    }

    func applyQuestionExplanationVisibility() {
        questionLabel.isHidden = isQuestionExplanationVisible
        questionExplanationScrollView.isHidden = !isQuestionExplanationVisible
        questionInfoButton.isHidden = !isQuestionInfoAvailable || isQuestionExplanationVisible
        questionExplanationBackButton.isHidden = !isQuestionExplanationVisible
        [
            questionLabel,
            questionExplanationScrollView,
            questionInfoButton,
            questionExplanationBackButton
        ].forEach { $0?.alpha = 1 }
    }

    func postQuestionContentAccessibilityFocus() {
        UIAccessibility.post(
            notification: .layoutChanged,
            argument: isQuestionExplanationVisible ? questionExplanationLabel : questionLabel
        )
    }
    
    @objc func closeButtonTapped() {
        guard presentedViewController == nil, activeExitAlertID == nil else { return }
        let alertID = UUID()
        activeExitAlertID = alertID
        exitAlertPresenter.presentingViewController = self
        guard exitAlertPresenter.present(
            makeExitConfirmationAlertOverlay(alertID: alertID),
            appearance: currentAppearance(),
            reduceMotion: UIAccessibility.isReduceMotionEnabled
        ) else {
            activeExitAlertID = nil
            return
        }

        presenter?.pauseTimer()
        analytics.track(.quizExitRequested(presenter?.analyticsProgress ?? .empty))
    }

    func makeExitConfirmationAlertOverlay() -> QuizAlertOverlay {
        makeExitConfirmationAlertOverlay(alertID: activeExitAlertID)
    }

    func makeExitConfirmationAlertOverlay(alertID: UUID?) -> QuizAlertOverlay {
        let cancelAction: () -> Void = { [weak self] in
            self?.cancelExitConfirmation(alertID: alertID)
        }
        return QuizAlertOverlay(
            title: L10n.Question.exitAlertTitle,
            message: L10n.Question.exitAlertMessage,
            systemImage: "rectangle.portrait.and.arrow.right",
            iconColor: QuizAlertAction.Emphasis.destructive.tintColor(in: currentAppearance()),
            primaryAction: QuizAlertAction(
                title: L10n.Common.exit,
                emphasis: .destructive,
                accessibilityIdentifier: AccessibilityID.exitAlertConfirmButton,
                action: { [weak self] in self?.confirmExitAndReturnToThemes(alertID: alertID) }
            ),
            secondaryAction: QuizAlertAction(
                title: L10n.Common.no,
                emphasis: .secondary,
                accessibilityIdentifier: AccessibilityID.exitAlertCancelButton,
                action: cancelAction
            ),
            onEscape: cancelAction
        )
    }

    func cancelExitConfirmation() {
        cancelExitConfirmation(alertID: activeExitAlertID)
    }

    func cancelExitConfirmation(alertID: UUID?) {
        guard let alertID, activeExitAlertID == alertID else { return }
        exitAlertPresenter.dismiss { [weak self] in
            guard let self, self.activeExitAlertID == alertID else { return }
            self.activeExitAlertID = nil
            self.analytics.track(.quizExitCancelled(self.presenter?.analyticsProgress ?? .empty))
            self.presenter?.resumeTimer()
        }
    }

    func confirmExitAndReturnToThemes() {
        confirmExitAndReturnToThemes(alertID: activeExitAlertID)
    }

    func confirmExitAndReturnToThemes(alertID: UUID?) {
        guard let alertID, activeExitAlertID == alertID else { return }
        exitAlertPresenter.dismiss { [weak self] in
            guard let self, self.activeExitAlertID == alertID else { return }
            self.activeExitAlertID = nil
            self.analytics.track(.quizAbandoned(self.presenter?.analyticsProgress ?? .empty))
            self.presenter?.resetGameProgress()
            self.router?.closeQuestion()
        }
    }

}
