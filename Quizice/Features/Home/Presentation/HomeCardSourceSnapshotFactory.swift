import UIKit

struct HomeCardSourceSnapshotFactory {
    func makeFallback(from sourceView: UIView) -> UIView {
        let fallbackView = UIView()
        fallbackView.backgroundColor = sourceView.backgroundColor
        fallbackView.layer.cornerRadius = sourceView.layer.cornerRadius
        fallbackView.layer.cornerCurve = sourceView.layer.cornerCurve
        fallbackView.layer.borderWidth = sourceView.layer.borderWidth
        fallbackView.layer.borderColor = sourceView.layer.borderColor
        return fallbackView
    }

    func makeThemeContent(
        from sourceView: UIView
    ) -> (view: UIView, geometry: HomeThemeCardContentGeometry) {
        var ancestor: UIView? = sourceView
        while let currentView = ancestor {
            if let cell = currentView as? ThemeCardCollectionViewCell {
                return cell.makeTransitionContent()
            }
            ancestor = currentView.superview
        }

        let containerView = snapshotContainer(matching: sourceView)
        var imageCenter = CGPoint(x: sourceView.bounds.midX, y: sourceView.bounds.midY)
        var titleCenter = imageCenter

        sourceView.subviews.forEach { contentView in
            guard
                let identifier = contentView.accessibilityIdentifier,
                identifier.hasPrefix(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix)
                    || identifier.hasPrefix(ThemesCollectionService.Content.themeTitleAccessibilityIDPrefix),
                let snapshotView = contentView.snapshotView(afterScreenUpdates: false)
            else { return }

            let contentFrame = contentView.convert(contentView.bounds, to: sourceView)
            snapshotView.frame = contentFrame
            containerView.addSubview(snapshotView)

            if identifier.hasPrefix(ThemesCollectionService.Content.themeImageAccessibilityIDPrefix) {
                imageCenter = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            } else {
                titleCenter = CGPoint(x: contentFrame.midX, y: contentFrame.midY)
            }
        }
        return (
            view: containerView,
            geometry: HomeThemeCardContentGeometry(
                containerSize: sourceView.bounds.size,
                imageCenter: imageCenter,
                titleCenter: titleCenter
            )
        )
    }

    func makeStatisticsContent(from sourceView: UIView) -> UIView {
        var ancestor: UIView? = sourceView
        while let currentView = ancestor {
            if let cell = currentView as? StatisticsCardCollectionViewCell {
                return cell.makeTransitionContent()
            }
            ancestor = currentView.superview
        }

        let containerView = snapshotContainer(matching: sourceView)
        if let contentView = sourceView.subviews.first(where: { $0 is UIStackView }),
           let snapshotView = contentView.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = contentView.convert(contentView.bounds, to: sourceView)
            containerView.addSubview(snapshotView)
        }
        return containerView
    }

    func makeAIThemeContent(from sourceView: UIView) -> UIView {
        let wasHidden = sourceView.isHidden
        let sourceControl = sourceView as? UIControl
        let wasEnabled = sourceControl?.isEnabled
        sourceView.isHidden = false
        sourceControl?.isEnabled = true
        sourceView.layoutIfNeeded()
        defer {
            sourceView.isHidden = wasHidden
            if let wasEnabled {
                sourceControl?.isEnabled = wasEnabled
            }
        }

        let containerView = snapshotContainer(matching: sourceView)
        var didCopyContent = false
        if let button = sourceView as? UIButton,
           let titleLabel = button.titleLabel,
           let titleSnapshot = titleLabel.snapshotView(afterScreenUpdates: false) {
            titleSnapshot.frame = titleLabel.convert(titleLabel.bounds, to: sourceView)
            containerView.addSubview(titleSnapshot)
            didCopyContent = true
        }
        if let betaBadge = sourceView.subviews.first(where: {
            $0.accessibilityIdentifier == ThemesCollectionService.Content.aiThemeBetaBadgeAccessibilityID
        }), let badgeSnapshot = betaBadge.snapshotView(afterScreenUpdates: false) {
            badgeSnapshot.frame = betaBadge.convert(betaBadge.bounds, to: sourceView)
            containerView.addSubview(badgeSnapshot)
            didCopyContent = true
        }

        if !didCopyContent,
           let snapshotView = sourceView.snapshotView(afterScreenUpdates: false) {
            snapshotView.frame = sourceView.bounds
            containerView.addSubview(snapshotView)
        }
        return containerView
    }

    private func snapshotContainer(matching sourceView: UIView) -> UIView {
        let containerView = UIView(frame: sourceView.bounds)
        containerView.backgroundColor = .clear
        containerView.isUserInteractionEnabled = false
        containerView.accessibilityElementsHidden = true
        return containerView
    }
}
