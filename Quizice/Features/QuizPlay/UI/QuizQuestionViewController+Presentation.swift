import UIKit
import AVKit
import SwiftUI

extension QuizQuestionViewController {
    func colorAndDisableButtons() {
        let appearance = currentAppearance()
        for (index, button) in answerButtons.enumerated() {
            button.isEnabled = false
            guard
                let presenter,
                currentAnswerOptions.indices.contains(index)
            else { continue }
            switch presenter.answerFeedback(for: currentAnswerOptions[index].id) {
            case .correct:
                applyAnswerFeedback(.correct, to: button, appearance: appearance, animated: true)
            case .wrong:
                applyAnswerFeedback(.wrong, to: button, appearance: appearance, animated: true)
            case .normal:
                applyAnswerFeedback(.normal, to: button, appearance: appearance, animated: true)
            }
        }
        revealQuestionInfoButton()
    }
    
    func resetAllColors() {
        let appearance = currentAppearance()
        answerButtons.forEach { button in
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = true
        }
        setTimerBarColor(quizThemeAccentColor(for: appearance))
    }
    
    func loadQuestionToView(_ viewModel: QuizQuestionViewModel) {
        guard !isQuestionTransitionInProgress else { return }

        guard hasLoadedQuestion else {
            applyQuestion(viewModel, updatesQuestionNumber: true)
            hasLoadedQuestion = true
            presenter?.startTimer()
            return
        }

        guard shouldAnimateQuestionTransition else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        animateQuestionTransition(to: viewModel)
    }

    var shouldAnimateQuestionTransition: Bool {
        questionCardView.window != nil && !UIAccessibility.isReduceMotionEnabled
    }

    func applyQuestion(_ viewModel: QuizQuestionViewModel, updatesQuestionNumber: Bool) {
        resetQuestionScrollPosition()
        questionCardFaceTransitionDriver.reset(to: .front)
        setQuestionInfoButtonVisible(false)
        questionInfoButton.alpha = 1
        questionExplanationLabel.text = viewModel.explanation
        questionExplanationScrollView.setContentOffset(.zero, animated: false)
        resetAllColors()
        
        // The incoming card is prepared off-screen. Put its timer in the initial
        // state before the slide begins so no frame can expose the previous value.
        updateProgress(1)
        themeNameLabel.text = viewModel.themeName
        questionLabel.text = viewModel.questionText
        applyAnswers(viewModel.answers)
        if updatesQuestionNumber {
            questionNumberLabel.text = viewModel.questionNumberText
        }
        nextButton.isEnabled = false
    }

    func resetQuestionScrollPosition() {
        let topOffset = CGPoint(x: 0, y: -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(topOffset, animated: false)
    }

    func animateQuestionTransition(to viewModel: QuizQuestionViewModel) {
        guard let containerView = questionCardView.superview else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        containerView.layoutIfNeeded()
        guard let outgoingCardSnapshot = questionCardView.snapshotView(afterScreenUpdates: false) else {
            finishQuestionTransition(with: viewModel, animatedQuestionNumber: false)
            return
        }

        isQuestionTransitionInProgress = true
        questionCardView.isUserInteractionEnabled = false
        nextButton.isEnabled = false

        outgoingCardSnapshot.frame = questionCardView.frame
        containerView.insertSubview(outgoingCardSnapshot, aboveSubview: questionCardView)
        outgoingQuestionCardSnapshot = outgoingCardSnapshot

        let horizontalOffset = QuizCardSlideTransition.horizontalOffset(
            in: containerView,
            horizontalInset: Layout.cardHorizontalInset
        )
        questionCardView.transform = CGAffineTransform(translationX: horizontalOffset, y: 0)
        applyQuestion(viewModel, updatesQuestionNumber: false)

        UIView.transition(
            with: questionNumberLabel,
            duration: AnimationTiming.questionNumberTransitionDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                self.questionNumberLabel.text = viewModel.questionNumberText
            }
        )

        UIView.animate(
            withDuration: QuizCardSlideTransition.questionAdvanceDuration,
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: {
                outgoingCardSnapshot.transform = CGAffineTransform(translationX: -horizontalOffset, y: 0)
                self.questionCardView.transform = .identity
            },
            completion: { _ in
                outgoingCardSnapshot.removeFromSuperview()
                self.outgoingQuestionCardSnapshot = nil
                self.questionCardView.transform = .identity
                self.completeQuestionTransition()
            }
        )
    }

    func finishQuestionTransition(with viewModel: QuizQuestionViewModel, animatedQuestionNumber: Bool) {
        isQuestionTransitionInProgress = false
        questionCardView.isUserInteractionEnabled = true
        questionCardView.transform = .identity
        applyQuestion(viewModel, updatesQuestionNumber: !animatedQuestionNumber)
        if animatedQuestionNumber {
            UIView.transition(
                with: questionNumberLabel,
                duration: AnimationTiming.questionNumberTransitionDuration,
                options: [.transitionCrossDissolve, .allowUserInteraction],
                animations: {
                    self.questionNumberLabel.text = viewModel.questionNumberText
                }
            )
        }
        presenter?.startTimer()
    }

    func completeQuestionTransition() {
        isQuestionTransitionInProgress = false
        questionCardView.isUserInteractionEnabled = true
        presenter?.startTimer()
    }
    
    func applyAnswers(_ currentAnswers: [QuizAnswerOption]) {
        currentAnswerOptions = currentAnswers
        for (index, button) in answerButtons.enumerated() {
            let hasAnswer = currentAnswers.indices.contains(index)
            button.setTitle(hasAnswer ? currentAnswers[index].title : L10n.Question.unavailableAnswer, for: .normal)
            button.isEnabled = hasAnswer
        }
        layoutContentIfPossible()
    }
    
    func showQuestionUnavailable(themeName: String?, message: String) {
        hasLoadedQuestion = false
        isQuestionTransitionInProgress = false
        outgoingQuestionCardSnapshot?.removeFromSuperview()
        outgoingQuestionCardSnapshot = nil
        questionCardView.transform = .identity
        questionCardView.isUserInteractionEnabled = true
        questionCardFaceTransitionDriver.reset(to: .front)
        setQuestionInfoButtonVisible(false)
        questionExplanationLabel.text = nil
        themeNameLabel.text = themeName ?? L10n.Question.fallbackTheme
        questionNumberLabel.text = L10n.Question.unavailableNumber
        questionLabel.text = message
        currentAnswerOptions = []
        timerBar.progress = .zero
        let appearance = currentAppearance()
        setTimerBarColor(quizThemeAccentColor(for: appearance))
        answerButtons.forEach { button in
            button.setTitle(Content.disabledAnswerPlaceholder, for: .normal)
            applyAnswerFeedback(.normal, to: button, appearance: appearance)
            button.isEnabled = false
        }
        layoutContentIfPossible()
        nextButton.isEnabled = false
    }

    func revealQuestionInfoButton() {
        guard questionInfoButton.isHidden else { return }
        questionCardFrontView.layoutIfNeeded()
        setQuestionInfoButtonVisible(true)

        guard !UIAccessibility.isReduceMotionEnabled else {
            questionInfoButton.alpha = 1
            questionCardFrontView.layoutIfNeeded()
            return
        }

        questionInfoButton.alpha = 0
        UIView.animate(
            withDuration: AnimationTiming.answerFeedbackDuration,
            delay: 0,
            options: AnimationTiming.answerFeedbackOptions,
            animations: {
                self.questionInfoButton.alpha = 1
                self.questionCardFrontView.layoutIfNeeded()
            }
        )
    }

    func setQuestionInfoButtonVisible(_ isVisible: Bool) {
        guard questionInfoButton != nil else { return }

        if isVisible {
            timerLeadingToCardConstraint?.isActive = false
            timerLeadingToInfoConstraint?.isActive = true
        } else {
            timerLeadingToInfoConstraint?.isActive = false
            timerLeadingToCardConstraint?.isActive = true
        }
        questionInfoButton.isHidden = !isVisible
        questionCardFrontView?.setNeedsLayout()
    }
    
    func correctAnswerTapped(isTrue: Bool) {
        let appearance = currentAppearance()
        if isTrue {
            feedbackPlayer.play(.correct)
            animateTimerBarColor(timerFeedbackColor(isCorrect: true, appearance: appearance))
        } else {
            feedbackPlayer.play(.incorrect)
            animateTimerBarColor(timerFeedbackColor(isCorrect: false, appearance: appearance))
        }
    }

    func applyAnswerFeedback(
        _ state: AnswerFeedbackState,
        to button: UIButton,
        appearance: AppAppearance,
        animated: Bool = false
    ) {
        let changes = answerFeedbackChanges(for: state, appearance: appearance)
        button.setTitleColor(changes.normalTitleColor, for: .normal)
        button.setTitleColor(changes.disabledTitleColor, for: .disabled)

        let animations = {
            button.alpha = changes.alpha
            button.backgroundColor = changes.backgroundColor
            button.layer.borderWidth = changes.borderWidth
            button.layer.borderColor = changes.borderColor.cgColor
        }

        if animated {
            UIView.animate(
                withDuration: AnimationTiming.answerFeedbackDuration,
                delay: 0,
                options: AnimationTiming.answerFeedbackOptions,
                animations: animations
            )
        } else {
            animations()
        }

        if animated, changes.shouldAnimateLegacyBackground {
            animationsEngine.animateBackgroundColor(
                button,
                color: changes.backgroundColor.cgColor,
                duration: AnimationTiming.answerFeedbackDuration
            )
        }
    }

    struct AnswerFeedbackChanges {
        let alpha: CGFloat
        let backgroundColor: UIColor
        let borderWidth: CGFloat
        let borderColor: UIColor
        let normalTitleColor: UIColor
        let disabledTitleColor: UIColor
        let shouldAnimateLegacyBackground: Bool
    }

    func answerFeedbackChanges(for state: AnswerFeedbackState, appearance: AppAppearance) -> AnswerFeedbackChanges {
        var alpha: CGFloat = 1
        var backgroundColor = appearance.answerDefaultColor
        var borderWidth = appearance.row.borderWidth
        var borderColor = appearance.row.borderColor
        let normalTitleColor = appearance.surfaceTextColor
        var disabledTitleColor = appearance.disabledTextColor
        var shouldAnimateLegacyBackground = false

        switch (appearance.designStyle, state) {
        case (_, .normal):
            break

        case (.clean, .correct):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.correctAnswerColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.clean, .wrong):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.wrongAnswerColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.radar, .correct):
            borderWidth = Appearance.answerFeedbackBorderWidth
            borderColor = appearance.accentColor
            disabledTitleColor = appearance.surfaceTextColor

        case (.radar, .wrong):
            borderColor = appearance.disabledTextColor
            disabledTitleColor = appearance.disabledTextColor
            alpha = Appearance.radarDimmedAnswerAlpha

        case (_, .correct):
            backgroundColor = appearance.correctAnswerColor
            disabledTitleColor = appearance.surfaceTextColor
            shouldAnimateLegacyBackground = true

        case (_, .wrong):
            backgroundColor = appearance.wrongAnswerColor
            shouldAnimateLegacyBackground = true
        }

        return AnswerFeedbackChanges(
            alpha: alpha,
            backgroundColor: backgroundColor,
            borderWidth: borderWidth,
            borderColor: borderColor,
            normalTitleColor: normalTitleColor,
            disabledTitleColor: disabledTitleColor,
            shouldAnimateLegacyBackground: shouldAnimateLegacyBackground
        )
    }

    func timerFeedbackColor(isCorrect: Bool, appearance: AppAppearance) -> UIColor {
        switch appearance.designStyle {
        case .radar:
            return isCorrect ? appearance.accentColor : appearance.disabledTextColor
        default:
            return isCorrect ? appearance.correctAnswerColor : appearance.wrongAnswerColor
        }
    }

    func setTimerBarColor(_ color: UIColor) {
        timerBar.progressTintColor = color
        timerBar.tintColor = color
    }

    func animateTimerBarColor(_ color: UIColor) {
        UIView.transition(
            with: timerBar,
            duration: AnimationTiming.answerFeedbackDuration,
            options: [.transitionCrossDissolve, .allowUserInteraction],
            animations: {
                self.setTimerBarColor(color)
            }
        )
    }
}
