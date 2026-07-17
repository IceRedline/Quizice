import UIKit
import AVKit
import SwiftUI

extension QuizQuestionViewController {

    func quizThemeAccentColor(for appearance: AppAppearance) -> UIColor {
        QuizThemeAccentStyle.accentColor(themeID: presenter?.themeID, appearance: appearance)
    }

    func fitContentFonts() {
        guard !isFittingContentFonts else { return }
        isFittingContentFonts = true
        defer { isFittingContentFonts = false }

        for pass in 0..<Typography.maximumFontLayoutPasses {
            questionCardView?.layoutIfNeeded()
            answersStackView?.layoutIfNeeded()

            let questionFontChanged = fitQuestionFont()
            let answerLayoutChanged = fitAnswerFonts()

            answerButtons.forEach {
                $0.setNeedsLayout()
                $0.layoutIfNeeded()
            }

            let requiresAnotherPass = pass == 0 || questionFontChanged || answerLayoutChanged
            guard requiresAnotherPass else { break }
            view.setNeedsLayout()
            view.layoutIfNeeded()
        }
    }

    @discardableResult
    func fitQuestionFont() -> Bool {
        let baseFont = currentAppearance().typography.font(
            size: Typography.questionFontSize,
            weight: .bold,
            compatibleWith: view.traitCollection
        )
        let contentWidth = questionLabel.bounds.width
        guard contentWidth > .zero else { return false }

        let text = questionLabel.text ?? ""
        let fittedPointSize = fontFitter.fittedPointSize(
            for: text,
            baseFont: baseFont,
            minimumScaleFactor: Typography.questionMinimumScaleFactor,
            contentWidth: contentWidth,
            targetContentHeight: Layout.questionTargetMaximumHeight
        )
        questionLabel.preferredMaxLayoutWidth = contentWidth

        let fittedFont = baseFont.withSize(fittedPointSize)
        guard questionLabel.font.fontName != fittedFont.fontName
            || abs(questionLabel.font.pointSize - fittedFont.pointSize) > Typography.fontSizeComparisonTolerance
        else { return false }

        questionLabel.font = fittedFont
        questionLabel.invalidateIntrinsicContentSize()
        questionLabel.setNeedsLayout()
        return true
    }

    @discardableResult
    func fitAnswerFonts() -> Bool {
        let baseFont = currentAppearance().typography.font(
            size: Typography.answerButtonFontSize,
            weight: .semibold,
            compatibleWith: view.traitCollection
        )
        let targetContentHeight = Layout.answerMinimumHeight - (Layout.answerContentVerticalInset * 2)
        var requiresLayout = false

        for (index, button) in answerButtons.enumerated() {
            guard let titleLabel = button.titleLabel else { continue }
            let text = button.title(for: .normal) ?? ""
            let contentWidth = button.bounds.width - (Layout.answerContentHorizontalInset * 2)

            guard !text.isEmpty, contentWidth > .zero else {
                if applyAnswerFont(baseFont, to: button) {
                    requiresLayout = true
                }
                if answerHeightConstraints.indices.contains(index),
                   abs(answerHeightConstraints[index].constant - Layout.answerMinimumHeight) > Typography.fontSizeComparisonTolerance {
                    answerHeightConstraints[index].constant = Layout.answerMinimumHeight
                    requiresLayout = true
                }
                continue
            }

            let fittedPointSize = fontFitter.fittedPointSize(
                for: text,
                baseFont: baseFont,
                minimumScaleFactor: Typography.answerMinimumScaleFactor,
                contentWidth: contentWidth,
                targetContentHeight: targetContentHeight
            )

            let fittedFont = baseFont.withSize(fittedPointSize)
            if applyAnswerFont(fittedFont, to: button) {
                requiresLayout = true
            }
            titleLabel.preferredMaxLayoutWidth = contentWidth

            let requiredHeight = max(
                Layout.answerMinimumHeight,
                fontFitter.height(of: text, font: fittedFont, contentWidth: contentWidth)
                    + (Layout.answerContentVerticalInset * 2)
            )
            if answerHeightConstraints.indices.contains(index),
               abs(answerHeightConstraints[index].constant - requiredHeight) > Typography.fontSizeComparisonTolerance {
                answerHeightConstraints[index].constant = requiredHeight
                requiresLayout = true
            }
        }

        if requiresLayout {
            questionCardView?.setNeedsLayout()
            scrollView?.setNeedsLayout()
            view.setNeedsLayout()
        }
        return requiresLayout
    }

    @discardableResult
    func applyAnswerFont(_ font: UIFont, to button: UIButton) -> Bool {
        guard let titleLabel = button.titleLabel else { return false }
        if titleLabel.font.fontName != font.fontName
            || abs(titleLabel.font.pointSize - font.pointSize) > Typography.fontSizeComparisonTolerance {
            titleLabel.font = font
            titleLabel.invalidateIntrinsicContentSize()
            button.invalidateIntrinsicContentSize()
            button.setNeedsLayout()
            return true
        }
        return false
    }
    
    func showResults(_ result: QuizResultState) {
        fadeQuestionChromeForResultTransition()
        router?.showResult(result)
    }

    func fadeQuestionChromeForResultTransition() {
        let changes = {
            self.questionChromeViews.forEach { $0.alpha = 0 }
        }

        guard !UIAccessibility.isReduceMotionEnabled else {
            changes()
            return
        }

        UIView.animate(
            withDuration: QuizCardSlideTransition.presentationDuration,
            delay: 0,
            options: QuizCardSlideTransition.options,
            animations: changes
        )
    }
}
