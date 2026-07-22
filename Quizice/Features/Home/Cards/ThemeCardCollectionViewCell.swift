import UIKit

final class ThemeCardCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "homeThemeCardCell"

    private enum Layout {
        static let horizontalInset: CGFloat = 16
        static let iconSize: CGFloat = 42
        static let iconTitleSpacing: CGFloat = 12
        static let verticalInset: CGFloat = 10
    }

    private enum Typography {
        static let titleSize: CGFloat = 18
        static let titleMinimumScaleFactor: CGFloat = 0.72
    }

    let actionButton = UIButton(type: .custom)

    private let themeIconSlotView = UIView()
    private let themeIconShadowView = UIImageView()
    private let themeImageView = UIImageView()
    private let themeTitleLabel = ThemeCardFittingLabel(
        baseFont: .preferredFont(forTextStyle: .headline),
        minimumScaleFactor: Typography.titleMinimumScaleFactor
    )

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureViewHierarchy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: actionButton.layer.cornerRadius
        ).cgPath
    }

    override func prepareForReuse() {
        super.prepareForReuse()

        actionButton.removeTarget(nil, action: nil, for: .allEvents)
        actionButton.accessibilityIdentifier = nil
        actionButton.accessibilityLabel = nil
        actionButton.accessibilityHint = nil
        actionButton.backgroundColor = .clear
        actionButton.layer.cornerRadius = 0
        actionButton.layer.borderWidth = 0
        actionButton.layer.borderColor = nil
        actionButton.isHidden = false
        actionButton.isEnabled = true
        actionButton.isUserInteractionEnabled = true
        actionButton.accessibilityElementsHidden = false
        actionButton.alpha = 1
        actionButton.transform = .identity

        themeImageView.image = nil
        themeImageView.tintColor = nil
        themeImageView.transform = .identity
        themeImageView.accessibilityIdentifier = nil

        themeIconShadowView.image = nil
        themeIconShadowView.tintColor = nil
        themeIconShadowView.alpha = 1
        themeIconShadowView.transform = .identity

        themeTitleLabel.text = nil
        themeTitleLabel.textColor = nil
        themeTitleLabel.accessibilityIdentifier = nil

        contentView.backgroundColor = .clear
        backgroundColor = .clear
        applyShadow(.none)
    }

    func configure(theme: QuizTheme, appearance: AppAppearance, isSourceHidden: Bool) {
        let themeID = theme.stableID
        let tintColor = ThemeVisualCatalog.tintColor(for: theme)
        let borderColor = appearance.themeCardBorder(baseColor: tintColor)

        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        backgroundColor = .clear
        layer.masksToBounds = false
        applyShadow(appearance.themeCardShadow)

        actionButton.accessibilityIdentifier = themeID
        actionButton.accessibilityLabel = L10n.ThemeCard.accessibilityLabel(themeName: theme.theme)
        actionButton.accessibilityHint = L10n.ThemeCard.accessibilityHint
        actionButton.backgroundColor = appearance.themeCardBackground(baseColor: tintColor)
        actionButton.layer.cornerRadius = appearance.themeCardCornerRadius
        actionButton.layer.borderWidth = appearance.themeCardBorderWidth
        actionButton.layer.borderColor = borderColor.cgColor
        actionButton.layer.masksToBounds = true

        let isSymbolIcon = appearance.designStyle != .radar
        let logoImage = ThemeVisualCatalog.logoImage(
            sfSymbolName: theme.sfSymbolName
        )
        themeImageView.image = logoImage
        themeImageView.tintColor = appearance.designStyle == .classic
            ? tintColor
            : borderColor
        themeImageView.transform = .identity
        themeImageView.accessibilityIdentifier = "\(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix)-\(themeID)"

        themeIconShadowView.image = isSymbolIcon ? logoImage : nil
        themeIconShadowView.tintColor = .black
        themeIconShadowView.alpha = isSymbolIcon ? ThemeIconVisualStyle.shadowAlpha : 0
        themeIconShadowView.transform = isSymbolIcon
            ? CGAffineTransform(translationX: 0, y: ThemeIconVisualStyle.shadowOffset)
            : .identity

        themeTitleLabel.updateBaseFont(
            appearance.typography.font(size: Typography.titleSize, weight: .semibold)
        )
        themeTitleLabel.text = theme.theme
        themeTitleLabel.textColor = appearance.themeCardTextColor(baseColor: tintColor)
        themeTitleLabel.accessibilityIdentifier = "\(ThemesCollectionService.Content.themeTitleAccessibilityIDPrefix)-\(themeID)"

        setSourceHidden(isSourceHidden)
    }

    func makeTransitionContent() -> (view: UIView, geometry: HomeThemeCardContentGeometry) {
        layoutIfNeeded()
        actionButton.layoutIfNeeded()

        let containerView = UIView(frame: actionButton.bounds)
        containerView.backgroundColor = .clear
        containerView.isAccessibilityElement = false
        containerView.accessibilityElementsHidden = true
        containerView.isUserInteractionEnabled = false

        let imageCenter = themeImageView.convert(
            CGPoint(x: themeImageView.bounds.midX, y: themeImageView.bounds.midY),
            to: actionButton
        )
        let shadowCenter = themeIconShadowView.convert(
            CGPoint(x: themeIconShadowView.bounds.midX, y: themeIconShadowView.bounds.midY),
            to: actionButton
        )
        let imageView = UIImageView(image: themeImageView.image)
        imageView.bounds = themeImageView.bounds
        imageView.center = imageCenter
        imageView.transform = themeImageView.transform
        imageView.alpha = themeImageView.alpha
        imageView.contentMode = themeImageView.contentMode
        imageView.tintColor = themeImageView.tintColor
        imageView.clipsToBounds = themeImageView.clipsToBounds

        let titleLabel = UILabel()
        titleLabel.bounds = themeTitleLabel.bounds
        titleLabel.center = themeTitleLabel.center
        titleLabel.transform = themeTitleLabel.transform
        titleLabel.alpha = themeTitleLabel.alpha
        titleLabel.text = themeTitleLabel.text
        titleLabel.attributedText = themeTitleLabel.attributedText
        titleLabel.font = themeTitleLabel.font
        titleLabel.textColor = themeTitleLabel.textColor
        titleLabel.textAlignment = themeTitleLabel.textAlignment
        titleLabel.numberOfLines = themeTitleLabel.numberOfLines
        titleLabel.lineBreakMode = themeTitleLabel.lineBreakMode
        titleLabel.allowsDefaultTighteningForTruncation = themeTitleLabel.allowsDefaultTighteningForTruncation

        if themeIconShadowView.image != nil {
            let shadowImageView = UIImageView(image: themeIconShadowView.image)
            shadowImageView.bounds = themeIconShadowView.bounds
            shadowImageView.center = shadowCenter
            shadowImageView.transform = themeIconShadowView.transform
            shadowImageView.alpha = themeIconShadowView.alpha
            shadowImageView.contentMode = themeIconShadowView.contentMode
            shadowImageView.tintColor = themeIconShadowView.tintColor
            shadowImageView.clipsToBounds = themeIconShadowView.clipsToBounds
            containerView.addSubview(shadowImageView)
        }
        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        return (
            view: containerView,
            geometry: HomeThemeCardContentGeometry(
                containerSize: actionButton.bounds.size,
                imageCenter: imageCenter,
                titleCenter: themeTitleLabel.center
            )
        )
    }

    private func configureViewHierarchy() {
        contentView.backgroundColor = .clear
        contentView.clipsToBounds = false
        backgroundColor = .clear
        layer.masksToBounds = false

        actionButton.clipsToBounds = true
        actionButton.translatesAutoresizingMaskIntoConstraints = false

        themeIconSlotView.backgroundColor = .clear
        themeIconSlotView.isAccessibilityElement = false
        themeIconSlotView.isUserInteractionEnabled = false
        themeIconSlotView.translatesAutoresizingMaskIntoConstraints = false

        themeIconShadowView.contentMode = .scaleAspectFit
        themeIconShadowView.isAccessibilityElement = false
        themeIconShadowView.isUserInteractionEnabled = false
        themeIconShadowView.translatesAutoresizingMaskIntoConstraints = false

        themeImageView.contentMode = .scaleAspectFit
        themeImageView.isAccessibilityElement = false
        themeImageView.isUserInteractionEnabled = false
        themeImageView.translatesAutoresizingMaskIntoConstraints = false

        themeTitleLabel.adjustsFontForContentSizeCategory = true
        themeTitleLabel.textAlignment = .left
        themeTitleLabel.numberOfLines = 3
        themeTitleLabel.lineBreakMode = .byWordWrapping
        themeTitleLabel.allowsDefaultTighteningForTruncation = true
        themeTitleLabel.isAccessibilityElement = false
        themeTitleLabel.isUserInteractionEnabled = false
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(actionButton)
        actionButton.addSubview(themeIconSlotView)
        themeIconSlotView.addSubview(themeIconShadowView)
        themeIconSlotView.addSubview(themeImageView)
        actionButton.addSubview(themeTitleLabel)

        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            themeTitleLabel.leadingAnchor.constraint(
                equalTo: themeIconSlotView.trailingAnchor,
                constant: Layout.iconTitleSpacing
            ),
            themeTitleLabel.trailingAnchor.constraint(
                equalTo: actionButton.trailingAnchor,
                constant: -Layout.horizontalInset
            ),
            themeTitleLabel.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            themeTitleLabel.topAnchor.constraint(greaterThanOrEqualTo: actionButton.topAnchor, constant: Layout.verticalInset),
            themeTitleLabel.bottomAnchor.constraint(lessThanOrEqualTo: actionButton.bottomAnchor, constant: -Layout.verticalInset),

            themeIconSlotView.leadingAnchor.constraint(equalTo: actionButton.leadingAnchor, constant: Layout.horizontalInset),
            themeIconSlotView.centerYAnchor.constraint(equalTo: actionButton.centerYAnchor),
            themeIconSlotView.widthAnchor.constraint(equalToConstant: Layout.iconSize),
            themeIconSlotView.heightAnchor.constraint(equalToConstant: Layout.iconSize),

            themeIconShadowView.leadingAnchor.constraint(equalTo: themeIconSlotView.leadingAnchor),
            themeIconShadowView.trailingAnchor.constraint(equalTo: themeIconSlotView.trailingAnchor),
            themeIconShadowView.topAnchor.constraint(equalTo: themeIconSlotView.topAnchor),
            themeIconShadowView.bottomAnchor.constraint(equalTo: themeIconSlotView.bottomAnchor),

            themeImageView.leadingAnchor.constraint(equalTo: themeIconSlotView.leadingAnchor),
            themeImageView.trailingAnchor.constraint(equalTo: themeIconSlotView.trailingAnchor),
            themeImageView.topAnchor.constraint(equalTo: themeIconSlotView.topAnchor),
            themeImageView.bottomAnchor.constraint(equalTo: themeIconSlotView.bottomAnchor)
        ])
    }

    private func setSourceHidden(_ isHidden: Bool) {
        actionButton.isHidden = isHidden
        actionButton.isUserInteractionEnabled = !isHidden
        actionButton.accessibilityElementsHidden = isHidden
        if isHidden {
            layer.shadowOpacity = 0
        }
    }
}

private final class ThemeCardFittingLabel: UILabel {
    private enum Fitting {
        static let iterations = 10
        static let tolerance: CGFloat = 0.1
    }

    private var baseFont: UIFont
    private let fittingMinimumScaleFactor: CGFloat

    init(baseFont: UIFont, minimumScaleFactor: CGFloat) {
        self.baseFont = baseFont
        self.fittingMinimumScaleFactor = minimumScaleFactor
        super.init(frame: .zero)
        font = baseFont
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func updateBaseFont(_ font: UIFont) {
        baseFont = font
        self.font = font
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitFontToBounds()
    }

    private func fitFontToBounds() {
        guard let text, !text.isEmpty, bounds.width > 0, bounds.height > 0 else { return }

        let minimumPointSize = baseFont.pointSize * fittingMinimumScaleFactor
        guard !textFits(text, font: baseFont) else {
            applyFontIfNeeded(baseFont)
            return
        }

        var lowerBound = minimumPointSize
        var upperBound = baseFont.pointSize
        for _ in 0..<Fitting.iterations {
            let candidatePointSize = (lowerBound + upperBound) / 2
            let candidateFont = baseFont.withSize(candidatePointSize)
            if textFits(text, font: candidateFont) {
                lowerBound = candidatePointSize
            } else {
                upperBound = candidatePointSize
            }
        }

        applyFontIfNeeded(baseFont.withSize(lowerBound))
    }

    private func textFits(_ text: String, font: UIFont) -> Bool {
        let maximumLineHeight = numberOfLines > 0
            ? font.lineHeight * CGFloat(numberOfLines)
            : bounds.height
        let maximumHeight = min(bounds.height, maximumLineHeight)
        let requiredBounds = (text as NSString).boundingRect(
            with: CGSize(width: bounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return ceil(requiredBounds.height) <= ceil(maximumHeight) + Fitting.tolerance
    }

    private func applyFontIfNeeded(_ fittedFont: UIFont) {
        guard abs(font.pointSize - fittedFont.pointSize) > Fitting.tolerance else { return }
        font = fittedFont
        invalidateIntrinsicContentSize()
    }
}
