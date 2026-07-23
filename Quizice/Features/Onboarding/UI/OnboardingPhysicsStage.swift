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
    private enum Layout {
        static let glowSafetyInset: CGFloat = 28
    }

    private enum Animation {
        static let replayFadeDuration: TimeInterval = 0.5
    }

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
    private var hasPresentedActiveScene = false
    private var replayFadeGeneration = 0
    private var isReplayFadeRunning = false
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
            if usesStaticLayout || !hasPresentedActiveScene {
                hasPresentedActiveScene = true
                rebuildSceneIfPossible()
            } else {
                fadeOutCurrentSceneAndReplay()
            }
        } else {
            cancelReplayFadePreservingCurrentAppearance()
            stopPhysics()
        }
    }

    func stop() {
        replayFadeGeneration &+= 1
        isReplayFadeRunning = false
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

        if usesStaticLayout {
            layoutStaticPile()
        } else if isActive {
            startPhysics()
        } else {
            prepareBodiesForDrop()
        }
        updateSelectionAppearance()
    }

    private func makeBodyView(
        for descriptor: TopicsPhysicsDescriptor,
        appearance: AppAppearance
    ) -> UIView {
        let card = PhysicsTopicCardView(theme: descriptor.theme)
        card.configure(
            appearance: appearance,
            isSelected: selectedThemeIDs.contains(descriptor.theme.id)
        )
        card.addTarget(self, action: #selector(themeCardTapped(_:)), for: .touchUpInside)
        let size = fittedSize(
            card.preferredSize(
                maximumWidth: max(bounds.width - Layout.glowSafetyInset * 2, 1)
            )
        )
        let view: UIView = card
        view.bounds = CGRect(origin: .zero, size: size)
        view.center = CGPoint(x: bounds.midX, y: -size.height)
        addSubview(view)
        return view
    }

    private func fittedSize(_ proposedSize: CGSize) -> CGSize {
        let populationScale: CGFloat = themes.count > 10 ? 0.78 : themes.count > 6 ? 0.88 : 1
        return CGSize(
            width: min(proposedSize.width, max(bounds.width - 12, 1)),
            height: max(proposedSize.height * populationScale, 54)
        )
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
            from: CGPoint(x: Layout.glowSafetyInset, y: -ceilingExtension),
            to: CGPoint(x: Layout.glowSafetyInset, y: bounds.height - Layout.glowSafetyInset)
        )
        collisions.addBoundary(
            withIdentifier: "right-wall" as NSString,
            from: CGPoint(x: bounds.width - Layout.glowSafetyInset, y: -ceilingExtension),
            to: CGPoint(
                x: bounds.width - Layout.glowSafetyInset,
                y: bounds.height - Layout.glowSafetyInset
            )
        )
        collisions.addBoundary(
            withIdentifier: "floor" as NSString,
            from: CGPoint(
                x: Layout.glowSafetyInset,
                y: bounds.height - Layout.glowSafetyInset
            ),
            to: CGPoint(
                x: bounds.width - Layout.glowSafetyInset,
                y: bounds.height - Layout.glowSafetyInset
            )
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

    private func prepareBodiesForDrop() {
        guard !usesStaticLayout else { return }
        for (index, pair) in zip(descriptors.indices, zip(descriptors, bodyViews)) {
            let (descriptor, view) = pair
            placeForDrop(view, descriptor: descriptor, index: index)
        }
    }

    private func fadeOutCurrentSceneAndReplay() {
        stopPhysics()
        replayFadeGeneration &+= 1
        let generation = replayFadeGeneration
        let visibleBodies = bodyViews.filter { $0.alpha > 0.001 }

        guard !visibleBodies.isEmpty else {
            rebuildSceneIfPossible()
            return
        }

        isReplayFadeRunning = true
        visibleBodies.forEach { $0.isUserInteractionEnabled = false }
        UIView.animate(
            withDuration: Animation.replayFadeDuration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .curveEaseInOut]
        ) {
            visibleBodies.forEach { $0.alpha = 0 }
        } completion: { [weak self] _ in
            guard let self else { return }
            guard self.replayFadeGeneration == generation else { return }
            self.isReplayFadeRunning = false
            guard self.isActive else { return }
            self.rebuildSceneIfPossible()
        }
    }

    private func cancelReplayFadePreservingCurrentAppearance() {
        guard isReplayFadeRunning else { return }
        replayFadeGeneration &+= 1
        isReplayFadeRunning = false

        for view in bodyViews {
            let currentAlpha = view.layer.presentation()?.opacity ?? Float(view.alpha)
            view.layer.removeAllAnimations()
            view.alpha = CGFloat(currentAlpha)
            view.isUserInteractionEnabled = true
        }
    }

    private func placeForDrop(
        _ view: UIView,
        descriptor: TopicsPhysicsDescriptor,
        index: Int
    ) {
        let halfWidth = view.bounds.width / 2
        let proposedX = bounds.width * descriptor.spawnX
        let minimumX = halfWidth + Layout.glowSafetyInset
        let maximumX = bounds.width - halfWidth - Layout.glowSafetyInset
        let x = min(max(proposedX, minimumX), maximumX)
        view.center = CGPoint(
            x: x,
            y: -view.bounds.height - CGFloat(index % 3) * 28
        )
        view.transform = CGAffineTransform(rotationAngle: descriptor.initialAngle)
    }

    private func layoutStaticPile() {
        for (descriptor, view) in zip(descriptors, bodyViews) {
            let proposedCenter = CGPoint(
                x: bounds.width * descriptor.staticCenter.x,
                y: bounds.height * descriptor.staticCenter.y
            )
            view.center = clampedCenter(proposedCenter, for: view)
            view.transform = CGAffineTransform(rotationAngle: descriptor.staticAngle)
        }
        bodyViews.compactMap { $0 as? PhysicsTopicCardView }.forEach(bringSubviewToFront)
    }

    private func clampedCenter(_ proposedCenter: CGPoint, for view: UIView) -> CGPoint {
        let halfWidth = view.bounds.width / 2
        let halfHeight = view.bounds.height / 2
        return CGPoint(
            x: min(
                max(proposedCenter.x, halfWidth + Layout.glowSafetyInset),
                bounds.width - halfWidth - Layout.glowSafetyInset
            ),
            y: min(
                max(proposedCenter.y, halfHeight + Layout.glowSafetyInset),
                bounds.height - halfHeight - Layout.glowSafetyInset
            )
        )
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
            return TopicsPhysicsDescriptor(
                theme: theme,
                spawnX: 0.16 + CGFloat(hash % 69) / 100,
                initialAngle: direction * (0.06 + CGFloat(hash % 9) / 100),
                angularVelocity: direction * (0.14 + CGFloat(hash % 18) / 100),
                horizontalVelocity: -12 + CGFloat(hash % 25),
                staticCenter: CGPoint(
                    x: (CGFloat(column) + 0.5) / CGFloat(columnCount),
                    y: 0.91
                        - CGFloat(row) * rowSpacing
                        - CGFloat(column) * rowSpacing / 2
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

enum OnboardingTopicSelectionAnimationTiming {
    static let selectionDuration: TimeInterval = 0.38
    static let iconDuration: TimeInterval = selectionDuration * 3
    static let iconSpringDamping: CGFloat = 0.86
}

private final class PhysicsTopicCardView: UIControl {
    let theme: OnboardingTheme
    var themeID: String { theme.id }

    private let selectionOverlayView = UIView()
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private var selectionState: Bool?

    init(theme: OnboardingTheme) {
        self.theme = theme
        super.init(frame: .zero)
        layer.cornerRadius = 22
        layer.cornerCurve = .continuous

        selectionOverlayView.isUserInteractionEnabled = false
        selectionOverlayView.alpha = 0
        selectionOverlayView.accessibilityIdentifier = "onboardingTopicSelectionOverlay-\(theme.id)"
        addSubview(selectionOverlayView)

        iconView.contentMode = .scaleAspectFit
        iconView.isUserInteractionEnabled = false
        iconView.accessibilityIdentifier = "onboardingTopicIcon-\(theme.id)"
        addSubview(iconView)

        titleLabel.numberOfLines = 1
        titleLabel.lineBreakMode = .byTruncatingTail
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
        selectionOverlayView.frame = bounds
        selectionOverlayView.layer.cornerRadius = layer.cornerRadius
        selectionOverlayView.layer.cornerCurve = .continuous
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

    func preferredSize(maximumWidth: CGFloat) -> CGSize {
        let horizontalChrome: CGFloat = 13 + 25 + 10 + 13
        let titleWidth = titleLabel.sizeThatFits(
            CGSize(width: CGFloat.greatestFiniteMagnitude, height: 68)
        ).width
        return CGSize(
            width: min(max(ceil(titleWidth) + horizontalChrome, 156), maximumWidth),
            height: 68
        )
    }

    func configure(appearance: AppAppearance, isSelected: Bool) {
        let tint = ThemeVisualCatalog.tintColor(for: theme)
        let textColor = appearance.themeCardTextColor(baseColor: tint)
        backgroundColor = appearance.themeCardBackground(baseColor: tint)

        iconView.image = ThemeVisualCatalog.logoImage(
            sfSymbolName: theme.sfSymbolName
        ) ?? UIImage(systemName: "questionmark.square.dashed")
        iconView.tintColor = appearance.themeCardIconColor(baseColor: tint)
        iconView.image = iconView.image?.withRenderingMode(.alwaysTemplate)

        titleLabel.text = theme.title
        titleLabel.font = appearance.typography.font(size: 15, weight: .semibold)
        titleLabel.textColor = textColor

        accessibilityLabel = theme.title
        accessibilityValue = isSelected ? L10n.Onboarding.topicsSelected : ""
        accessibilityTraits = isSelected ? [.button, .selected] : .button

        let previousSelection = selectionState
        selectionState = isSelected
        guard previousSelection != isSelected else { return }
        let usesMotionEmphasis = !UIAccessibility.isReduceMotionEnabled
        let applyCardSelection = { [self] in
            selectionOverlayView.backgroundColor = tint.withAlphaComponent(
                appearance.designStyle == .clean ? 0.14 : 0.24
            )
            selectionOverlayView.alpha = isSelected ? 1 : 0
            layer.borderColor = (
                isSelected ? tint : appearance.themeCardBorder(baseColor: tint)
            ).cgColor
            layer.borderWidth = isSelected
                ? max(appearance.themeCardBorderWidth + 1.5, 3)
                : max(appearance.themeCardBorderWidth, 1)
            titleLabel.transform = isSelected && usesMotionEmphasis
                ? CGAffineTransform(translationX: 2, y: 0)
                : .identity
            if isSelected {
                layer.shadowColor = tint.cgColor
                layer.shadowOpacity = 0.52
                layer.shadowRadius = 15
                layer.shadowOffset = .zero
            } else {
                applyShadow(appearance.themeCardShadow)
            }
        }
        let applyIconSelection = { [self] in
            iconView.transform = isSelected && usesMotionEmphasis
                ? CGAffineTransform(scaleX: 1.18, y: 1.18)
                : .identity
        }

        guard
            previousSelection != nil,
            UIView.areAnimationsEnabled
        else {
            applyCardSelection()
            applyIconSelection()
            return
        }

        if UIAccessibility.isReduceMotionEnabled {
            UIView.animate(
                withDuration: 0.18,
                delay: 0,
                options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState],
                animations: {
                    applyCardSelection()
                    applyIconSelection()
                }
            )
        } else {
            UIView.animate(
                withDuration: OnboardingTopicSelectionAnimationTiming.selectionDuration,
                delay: 0,
                usingSpringWithDamping: isSelected ? 0.72 : 1,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: applyCardSelection
            )
            UIView.animate(
                withDuration: OnboardingTopicSelectionAnimationTiming.iconDuration,
                delay: 0,
                usingSpringWithDamping: OnboardingTopicSelectionAnimationTiming.iconSpringDamping,
                initialSpringVelocity: 0,
                options: [.allowUserInteraction, .beginFromCurrentState],
                animations: applyIconSelection
            )
        }
    }

}
