import UIKit

@MainActor
struct QuestionFontFitter {
    let searchIterations: Int
    private let measuringLabel = UILabel()

    func fittedPointSize(
        for text: String,
        baseFont: UIFont,
        minimumScaleFactor: CGFloat,
        contentWidth: CGFloat,
        targetContentHeight: CGFloat,
        requiresFit: Bool = false
    ) -> CGFloat {
        guard !text.isEmpty else { return baseFont.pointSize }
        guard height(of: text, font: baseFont, contentWidth: contentWidth) > targetContentHeight else {
            return baseFont.pointSize
        }

        var minimumPointSize = baseFont.pointSize * minimumScaleFactor
        // On the fixed question card, exceptionally long content must still
        // fit. Use all available space before going below the preferred size.
        if requiresFit {
            while minimumPointSize > 1,
                  height(of: text, font: baseFont.withSize(minimumPointSize), contentWidth: contentWidth) > targetContentHeight {
                minimumPointSize = max(1, minimumPointSize / 2)
            }
        }
        let minimumFont = baseFont.withSize(minimumPointSize)
        guard height(of: text, font: minimumFont, contentWidth: contentWidth) <= targetContentHeight else {
            return minimumPointSize
        }

        var lowerBound = minimumPointSize
        var upperBound = baseFont.pointSize
        for _ in 0..<searchIterations {
            let candidate = (lowerBound + upperBound) / 2
            let candidateFont = baseFont.withSize(candidate)
            if height(of: text, font: candidateFont, contentWidth: contentWidth) <= targetContentHeight {
                lowerBound = candidate
            } else {
                upperBound = candidate
            }
        }
        return lowerBound
    }

    func height(of text: String, font: UIFont, contentWidth: CGFloat) -> CGFloat {
        // Measure with the same renderer as the visible text. NSString's
        // boundingRect can undercount UILabel's wrapped lines (notably Radar).
        measuringLabel.numberOfLines = 0
        measuringLabel.lineBreakMode = .byWordWrapping
        measuringLabel.font = font
        measuringLabel.text = text
        return ceil(measuringLabel.sizeThatFits(
            CGSize(width: contentWidth, height: .greatestFiniteMagnitude)
        ).height)
    }
}
