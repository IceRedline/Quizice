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

final class MoreThemesCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "homeMoreThemesCell"

    let actionButton = UIButton(type: .system)

    private let materialView = UIVisualEffectView()
    private let materialMask = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = false
        contentView.clipsToBounds = false

        materialView.isUserInteractionEnabled = false
        materialView.translatesAutoresizingMaskIntoConstraints = false
        materialMask.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(0.76).cgColor,
            UIColor.black.cgColor
        ]
        materialMask.locations = [0, 0.55, 1]
        materialView.layer.mask = materialMask

        actionButton.translatesAutoresizingMaskIntoConstraints = false
        var buttonConfiguration = UIButton.Configuration.plain()
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20)
        buttonConfiguration.imagePadding = 8
        buttonConfiguration.imagePlacement = .trailing
        actionButton.configuration = buttonConfiguration
        actionButton.installPressFeedback()

        contentView.addSubview(materialView)
        contentView.addSubview(actionButton)
        NSLayoutConstraint.activate([
            materialView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            materialView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            materialView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: -64),
            materialView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            actionButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actionButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            actionButton.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            actionButton.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24),
            actionButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        materialMask.frame = materialView.bounds
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        actionButton.removeTarget(nil, action: nil, for: .allEvents)
    }

    func configure(appearance: AppAppearance) {
        if UIAccessibility.isReduceTransparencyEnabled {
            materialView.effect = nil
            materialView.backgroundColor = appearance.card.backgroundColor.withAlphaComponent(0.96)
        } else {
            materialView.effect = UIBlurEffect(style: .systemThinMaterial)
            materialView.backgroundColor = appearance.backgroundColor.withAlphaComponent(0.72)
        }

        actionButton.accessibilityIdentifier = ThemesCollectionService.Content.moreThemesAccessibilityID
        actionButton.accessibilityLabel = L10n.Home.moreThemes
        actionButton.accessibilityHint = L10n.Home.moreThemesAccessibilityHint
        actionButton.applyActionAppearance(appearance.secondaryButton, appearance: appearance)
        actionButton.setTitle(L10n.Home.moreThemes, for: .normal)
        actionButton.setTitleColor(appearance.screenTextColor, for: .normal)
        actionButton.titleLabel?.font = appearance.typography.font(size: 17, weight: .semibold)
        actionButton.titleLabel?.adjustsFontForContentSizeCategory = true
        actionButton.setImage(
            UIImage(systemName: "chevron.down", withConfiguration: UIImage.SymbolConfiguration(weight: .bold)),
            for: .normal
        )
        actionButton.tintColor = appearance.screenTextColor
    }
}
