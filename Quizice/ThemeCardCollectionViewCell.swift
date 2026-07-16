import UIKit

final class ThemeCardCollectionViewCell: UICollectionViewCell {
    static let reuseIdentifier = "homeThemeCardCell"

    private enum Layout {
        static let imageTopInset: CGFloat = 14
        static let imageHorizontalInset: CGFloat = 4
        static let titleHorizontalInset: CGFloat = 8
        static let titleBottomInset: CGFloat = 6
        static let titleHeight: CGFloat = 56
        static let cleanSymbolScale: CGFloat = 0.70
    }

    private enum Typography {
        static let titleSize: CGFloat = 18
        static let titleMinimumScaleFactor: CGFloat = 0.72
    }

    let actionButton = UIButton(type: .custom)

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

        themeTitleLabel.text = nil
        themeTitleLabel.textColor = nil
        themeTitleLabel.accessibilityIdentifier = nil

        contentView.backgroundColor = .clear
        backgroundColor = .clear
        applyShadow(.none)
    }

    func configure(theme: QuizTheme, appearance: AppAppearance, isSourceHidden: Bool) {
        let themeID = theme.stableID
        let tintColor = ThemeVisualCatalog.tintColor(for: themeID)
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

        themeImageView.image = ThemeVisualCatalog.logoImage(
            for: themeID,
            designStyle: appearance.designStyle
        )
        themeImageView.tintColor = borderColor
        themeImageView.transform = appearance.designStyle == .clean
            ? CGAffineTransform(scaleX: Layout.cleanSymbolScale, y: Layout.cleanSymbolScale)
            : .identity
        themeImageView.accessibilityIdentifier = "\(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix)-\(themeID)"

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

        let imageView = UIImageView(image: themeImageView.image)
        imageView.bounds = themeImageView.bounds
        imageView.center = themeImageView.center
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

        containerView.addSubview(imageView)
        containerView.addSubview(titleLabel)
        return (
            view: containerView,
            geometry: HomeThemeCardContentGeometry(
                containerSize: actionButton.bounds.size,
                imageCenter: themeImageView.center,
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

        themeImageView.contentMode = .scaleAspectFit
        themeImageView.isAccessibilityElement = false
        themeImageView.isUserInteractionEnabled = false
        themeImageView.translatesAutoresizingMaskIntoConstraints = false

        themeTitleLabel.adjustsFontForContentSizeCategory = true
        themeTitleLabel.textAlignment = .center
        themeTitleLabel.numberOfLines = 2
        themeTitleLabel.lineBreakMode = .byWordWrapping
        themeTitleLabel.allowsDefaultTighteningForTruncation = true
        themeTitleLabel.isAccessibilityElement = false
        themeTitleLabel.isUserInteractionEnabled = false
        themeTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(actionButton)
        actionButton.addSubview(themeImageView)
        actionButton.addSubview(themeTitleLabel)

        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: contentView.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            themeImageView.topAnchor.constraint(
                equalTo: actionButton.topAnchor,
                constant: Layout.imageTopInset
            ),
            themeImageView.leadingAnchor.constraint(
                equalTo: actionButton.leadingAnchor,
                constant: Layout.imageHorizontalInset
            ),
            themeImageView.trailingAnchor.constraint(
                equalTo: actionButton.trailingAnchor,
                constant: -Layout.imageHorizontalInset
            ),

            themeTitleLabel.topAnchor.constraint(equalTo: themeImageView.bottomAnchor),
            themeTitleLabel.leadingAnchor.constraint(
                equalTo: actionButton.leadingAnchor,
                constant: Layout.titleHorizontalInset
            ),
            themeTitleLabel.trailingAnchor.constraint(
                equalTo: actionButton.trailingAnchor,
                constant: -Layout.titleHorizontalInset
            ),
            themeTitleLabel.bottomAnchor.constraint(
                equalTo: actionButton.bottomAnchor,
                constant: -Layout.titleBottomInset
            ),
            themeTitleLabel.heightAnchor.constraint(equalToConstant: Layout.titleHeight)
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
