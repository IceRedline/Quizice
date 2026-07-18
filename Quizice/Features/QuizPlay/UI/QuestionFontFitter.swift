import UIKit

struct QuestionFontFitter {
    let searchIterations: Int

    func fittedPointSize(
        for text: String,
        baseFont: UIFont,
        minimumScaleFactor: CGFloat,
        contentWidth: CGFloat,
        targetContentHeight: CGFloat
    ) -> CGFloat {
        guard !text.isEmpty else { return baseFont.pointSize }
        guard height(of: text, font: baseFont, contentWidth: contentWidth) > targetContentHeight else {
            return baseFont.pointSize
        }

        let minimumPointSize = baseFont.pointSize * minimumScaleFactor
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
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height
        )
    }
}
