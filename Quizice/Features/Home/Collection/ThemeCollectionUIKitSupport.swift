import UIKit

extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

final class InsetLabel: UILabel {
    private let contentInsets: UIEdgeInsets

    init(contentInsets: UIEdgeInsets) {
        self.contentInsets = contentInsets
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(
            width: size.width + contentInsets.left + contentInsets.right,
            height: size.height + contentInsets.top + contentInsets.bottom
        )
    }

    override func drawText(in rect: CGRect) {
        super.drawText(in: rect.inset(by: contentInsets))
    }
}

final class GradientBorderView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let borderMaskLayer = CAShapeLayer()
    private let lineWidth: CGFloat
    private let cornerRadius: CGFloat?

    init(colors: [UIColor], lineWidth: CGFloat, cornerRadius: CGFloat? = nil) {
        self.lineWidth = lineWidth
        self.cornerRadius = cornerRadius
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.mask = borderMaskLayer
        layer.addSublayer(gradientLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds

        let cornerRadius = cornerRadius ?? superview?.layer.cornerRadius ?? layer.cornerRadius
        let innerBounds = bounds.insetBy(dx: lineWidth, dy: lineWidth)
        let borderPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
        borderPath.append(
            UIBezierPath(
                roundedRect: innerBounds,
                cornerRadius: max(cornerRadius - lineWidth, 0)
            )
        )

        borderMaskLayer.frame = bounds
        borderMaskLayer.fillColor = UIColor.black.cgColor
        borderMaskLayer.fillRule = .evenOdd
        borderMaskLayer.strokeColor = nil
        borderMaskLayer.lineWidth = 0
        borderMaskLayer.path = borderPath.cgPath
    }
}
