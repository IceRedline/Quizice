import SwiftUI
import UIKit

/// Bridges UIKit Dynamics into the SwiftUI onboarding flow. Core Animation is
/// deliberately not used here: every card is a real dynamic body whose final
/// position is calculated from gravity and collisions, not a scripted endpoint.
struct FallingTopicsStage: UIViewRepresentable {
    let themes: [OnboardingTheme]
    @Binding var selectedThemeIDs: Set<String>
    let isActive: Bool

    @Environment(\.appAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedThemeIDs: $selectedThemeIDs)
    }

    func makeUIView(context: Context) -> TopicsPhysicsView {
        let view = TopicsPhysicsView()
        view.onThemeTapped = context.coordinator.toggle
        return view
    }

    func updateUIView(_ view: TopicsPhysicsView, context: Context) {
        context.coordinator.selectedThemeIDs = $selectedThemeIDs
        view.onThemeTapped = context.coordinator.toggle
        view.configure(
            appearance: appearance,
            themes: themes,
            selectedThemeIDs: selectedThemeIDs,
            usesStaticLayout: reduceMotion || !UIView.areAnimationsEnabled
        )
        view.setActive(isActive)
    }

    static func dismantleUIView(_ view: TopicsPhysicsView, coordinator: Coordinator) {
        view.stop()
    }

    final class Coordinator {
        var selectedThemeIDs: Binding<Set<String>>

        init(selectedThemeIDs: Binding<Set<String>>) {
            self.selectedThemeIDs = selectedThemeIDs
        }

        func toggle(_ themeID: String) {
            var updatedSelection = selectedThemeIDs.wrappedValue
            if updatedSelection.contains(themeID) {
                updatedSelection.remove(themeID)
            } else {
                updatedSelection.insert(themeID)
            }
            selectedThemeIDs.wrappedValue = updatedSelection
            UISelectionFeedbackGenerator().selectionChanged()
        }
    }
}

final class TopicsPhysicsView: UIView {
    var onThemeTapped: ((String) -> Void)?

    private lazy var animator = UIDynamicAnimator(referenceView: self)
    private var gravityBehavior: UIGravityBehavior?
    private var collisionBehavior: UICollisionBehavior?
    private var itemBehavior: UIDynamicItemBehavior?
    private var pendingDrops: [DispatchWorkItem] = []
    private var bodyViews: [UIView] = []
    private var descriptors: [TopicsPhysicsDescriptor] = []
    private var appearance: AppAppearance?
    private var themes: [OnboardingTheme] = []
    private var selectedThemeIDs: Set<String> = []
    private var appearanceKey = ""
    private var usesStaticLayout = false
    private var isActive = false
    private var lastLayoutSize = CGSize.zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        isAccessibilityElement = false
        accessibilityElementsHidden = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        appearance: AppAppearance,
        themes: [OnboardingTheme],
        selectedThemeIDs: Set<String>,
        usesStaticLayout: Bool
    ) {
        let newAppearanceKey = [
            appearance.designStyle.rawValue,
            appearance.cleanColorSchemePreference.rawValue,
            String(appearance.resolvedInterfaceStyle.rawValue)
        ].joined(separator: "-")
        let needsRebuild = self.appearance == nil
            || appearanceKey != newAppearanceKey
            || self.themes != themes
            || self.usesStaticLayout != usesStaticLayout

        self.appearance = appearance
        self.themes = themes
        self.appearanceKey = newAppearanceKey
        self.usesStaticLayout = usesStaticLayout
        self.selectedThemeIDs = selectedThemeIDs

        if needsRebuild {
            rebuildSceneIfPossible()
        } else {
            updateSelectionAppearance()
        }
    }

    func setActive(_ active: Bool) {
        guard isActive != active else { return }
        isActive = active
        if active {
            rebuildSceneIfPossible()
        } else {
            stopPhysics()
        }
    }

    func stop() {
        stopPhysics()
        bodyViews.forEach { $0.removeFromSuperview() }
        bodyViews.removeAll()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard abs(bounds.width - lastLayoutSize.width) > 1
                || abs(bounds.height - lastLayoutSize.height) > 1 else { return }
        lastLayoutSize = bounds.size
        rebuildSceneIfPossible()
    }

    private func rebuildSceneIfPossible() {
        guard bounds.width > 1, bounds.height > 1, let appearance else { return }

        stopPhysics()
        bodyViews.forEach { $0.removeFromSuperview() }
        descriptors = TopicsPhysicsDescriptor.make(from: themes)
        bodyViews = descriptors.map { descriptor in
            makeBodyView(for: descriptor, appearance: appearance)
        }

        if usesStaticLayout || !isActive {
            layoutStaticPile()
        } else {
            startPhysics()
        }
        updateSelectionAppearance()
    }

    private func makeBodyView(
        for descriptor: TopicsPhysicsDescriptor,
        appearance: AppAppearance
    ) -> UIView {
        let size = fittedSize(descriptor.size)
        let view: UIView
        let card = PhysicsTopicCardView(theme: descriptor.theme)
        card.configure(
            appearance: appearance,
            isSelected: selectedThemeIDs.contains(descriptor.theme.id)
        )
        card.addTarget(self, action: #selector(themeCardTapped(_:)), for: .touchUpInside)
        view = card
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = CGPoint(x: bounds.midX, y: -size.height)
        addSubview(view)
        return view
    }

    private func fittedSize(_ proposedSize: CGSize) -> CGSize {
        let populationScale: CGFloat = themes.count > 10 ? 0.78 : themes.count > 6 ? 0.88 : 1
        let widthScale = min(1, max(0.78, (bounds.width - 12) / 390))
        let scale = populationScale * widthScale
        return CGSize(width: proposedSize.width * scale, height: proposedSize.height * scale)
    }

    private func startPhysics() {
        let gravity = UIGravityBehavior()
        gravity.gravityDirection = CGVector(dx: 0, dy: 1)
        gravity.magnitude = 0.92

        let collisions = UICollisionBehavior()
        collisions.collisionMode = .everything
        let ceilingExtension = max(560, bounds.height * 1.7)
        collisions.addBoundary(
            withIdentifier: "left-wall" as NSString,
            from: CGPoint(x: 1, y: -ceilingExtension),
            to: CGPoint(x: 1, y: bounds.height)
        )
        collisions.addBoundary(
            withIdentifier: "right-wall" as NSString,
            from: CGPoint(x: bounds.width - 1, y: -ceilingExtension),
            to: CGPoint(x: bounds.width - 1, y: bounds.height)
        )
        collisions.addBoundary(
            withIdentifier: "floor" as NSString,
            from: CGPoint(x: 0, y: bounds.height - 1),
            to: CGPoint(x: bounds.width, y: bounds.height - 1)
        )

        let bodyProperties = UIDynamicItemBehavior()
        bodyProperties.allowsRotation = true
        bodyProperties.elasticity = 0.18
        bodyProperties.friction = 0.78
        bodyProperties.resistance = 0.12
        bodyProperties.angularResistance = 0.32
        bodyProperties.density = 0.72

        animator.addBehavior(gravity)
        animator.addBehavior(collisions)
        animator.addBehavior(bodyProperties)
        gravityBehavior = gravity
        collisionBehavior = collisions
        itemBehavior = bodyProperties

        for (index, pair) in zip(descriptors.indices, zip(descriptors, bodyViews)) {
            let (descriptor, view) = pair
            placeForDrop(view, descriptor: descriptor, index: index)

            let drop = DispatchWorkItem { [weak self, weak view] in
                guard let self, let view, self.isActive, !self.usesStaticLayout else { return }
                gravity.addItem(view)
                collisions.addItem(view)
                bodyProperties.addItem(view)
                bodyProperties.addAngularVelocity(descriptor.angularVelocity, for: view)
                bodyProperties.addLinearVelocity(
                    CGPoint(x: descriptor.horizontalVelocity, y: CGFloat(index % 3) * 8),
                    for: view
                )
            }
            pendingDrops.append(drop)
            DispatchQueue.main.asyncAfter(
                deadline: .now() + Double(index) * 0.075,
                execute: drop
            )
        }
    }

    private func placeForDrop(
        _ view: UIView,
        descriptor: TopicsPhysicsDescriptor,
        index: Int
    ) {
        let halfWidth = view.bounds.width / 2
        let proposedX = bounds.width * descriptor.spawnX
        let x = min(max(proposedX, halfWidth + 3), bounds.width - halfWidth - 3)
        view.center = CGPoint(
            x: x,
            y: -view.bounds.height - CGFloat(index % 3) * 28
        )
        view.transform = CGAffineTransform(rotationAngle: descriptor.initialAngle)
    }

    private func layoutStaticPile() {
        for (descriptor, view) in zip(descriptors, bodyViews) {
            view.center = CGPoint(
                x: bounds.width * descriptor.staticCenter.x,
                y: bounds.height * descriptor.staticCenter.y
            )
            view.transform = CGAffineTransform(rotationAngle: descriptor.staticAngle)
        }
        bodyViews.compactMap { $0 as? PhysicsTopicCardView }.forEach(bringSubviewToFront)
    }

    private func stopPhysics() {
        pendingDrops.forEach { $0.cancel() }
        pendingDrops.removeAll()
        animator.removeAllBehaviors()
        gravityBehavior = nil
        collisionBehavior = nil
        itemBehavior = nil
    }

    private func updateSelectionAppearance() {
        bodyViews.compactMap { $0 as? PhysicsTopicCardView }.forEach { card in
            guard let appearance else { return }
            card.configure(
                appearance: appearance,
                isSelected: selectedThemeIDs.contains(card.themeID)
            )
        }
    }

    @objc private func themeCardTapped(_ sender: PhysicsTopicCardView) {
        onThemeTapped?(sender.themeID)
    }
}

private struct TopicsPhysicsDescriptor {
    let theme: OnboardingTheme
    let size: CGSize
    let spawnX: CGFloat
    let initialAngle: CGFloat
    let angularVelocity: CGFloat
    let horizontalVelocity: CGFloat
    let staticCenter: CGPoint
    let staticAngle: CGFloat

    static func make(from themes: [OnboardingTheme]) -> [TopicsPhysicsDescriptor] {
        let columnCount = themes.count <= 4 ? 2 : 3
        let rowCount = max(Int(ceil(Double(themes.count) / Double(columnCount))), 1)
        let rowSpacing = min(0.22, 0.72 / CGFloat(max(rowCount - 1, 1)))

        return themes.enumerated().map { index, theme in
            let hash = stableHash(theme.id)
            let column = index % columnCount
            let row = index / columnCount
            let direction: CGFloat = index.isMultiple(of: 2) ? 1 : -1
            let titleWidth = CGFloat(theme.title.count) * 9.2 + 82
            return TopicsPhysicsDescriptor(
                theme: theme,
                size: CGSize(width: min(max(titleWidth, 156), 196), height: 68),
                spawnX: 0.16 + CGFloat(hash % 69) / 100,
                initialAngle: direction * (0.06 + CGFloat(hash % 9) / 100),
                angularVelocity: direction * (0.14 + CGFloat(hash % 18) / 100),
                horizontalVelocity: -12 + CGFloat(hash % 25),
                staticCenter: CGPoint(
                    x: (CGFloat(column) + 0.5) / CGFloat(columnCount),
                    y: 0.91 - CGFloat(row) * rowSpacing
                ),
                staticAngle: direction * (0.025 + CGFloat(hash % 5) / 100)
            )
        }
    }

    private static func stableHash(_ value: String) -> UInt64 {
        value.utf8.reduce(14_695_981_039_346_656_037) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }
}

private final class PhysicsTopicCardView: UIControl {
    let theme: OnboardingTheme
    var themeID: String { theme.id }

    private let iconView = UIImageView()
    private let titleLabel = UILabel()

    init(theme: OnboardingTheme) {
        self.theme = theme
        super.init(frame: .zero)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        addSubview(iconView)

        titleLabel.numberOfLines = 2
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.76
        titleLabel.isUserInteractionEnabled = false
        addSubview(titleLabel)

        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "onboardingTopic-\(theme.id)"
        accessibilityHint = L10n.Onboarding.topicsSelectionHint
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isHighlighted: Bool {
        didSet { alpha = isHighlighted ? 0.78 : 1 }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 13
        let iconSize: CGFloat = 25
        iconView.frame = CGRect(
            x: inset,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
        let labelX = iconView.frame.maxX + 10
        titleLabel.frame = CGRect(
            x: labelX,
            y: 7,
            width: max(0, bounds.width - inset - labelX),
            height: bounds.height - 14
        )
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: 22).cgPath
    }

    func configure(appearance: AppAppearance, isSelected: Bool) {
        let tint = ThemeVisualCatalog.tintColor(for: themeID)
        let textColor = appearance.themeCardTextColor(baseColor: tint)
        backgroundColor = appearance.themeCardBackground(baseColor: tint)
        layer.borderColor = appearance.themeCardBorder(baseColor: tint).cgColor
        layer.borderWidth = isSelected ? 2.4 : max(appearance.themeCardBorderWidth, 1)
        applyShadow(appearance.themeCardShadow)

        iconView.image = ThemeVisualCatalog.logoImage(
            sfSymbolName: theme.sfSymbolName
        ) ?? UIImage(systemName: "questionmark.square.dashed")
        iconView.tintColor = textColor
        iconView.image = iconView.image?.withRenderingMode(.alwaysTemplate)

        titleLabel.text = theme.title
        titleLabel.font = appearance.typography.font(size: 15, weight: .semibold)
        titleLabel.textColor = textColor

        accessibilityLabel = theme.title
        accessibilityValue = isSelected ? L10n.Onboarding.topicsSelected : ""
        accessibilityTraits = isSelected ? [.button, .selected] : .button
    }

}
