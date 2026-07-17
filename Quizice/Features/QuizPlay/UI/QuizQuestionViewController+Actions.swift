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
