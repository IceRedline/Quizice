import UIKit

extension UIView {
    func applySurfaceStyle(_ style: AppSurfaceStyle) {
        backgroundColor = style.backgroundColor
        layer.cornerRadius = style.cornerRadius
        layer.borderWidth = style.borderWidth
        layer.borderColor = style.borderColor.cgColor
        applyShadow(style.shadow)
    }

    func applyShadow(_ shadow: AppShadowStyle) {
        layer.shadowColor = shadow.color.cgColor
        layer.shadowOpacity = shadow.opacity
        layer.shadowRadius = shadow.radius
        layer.shadowOffset = shadow.offset
        layer.masksToBounds = false
    }
}

extension UIButton {
    func applyActionAppearance(_ style: AppSurfaceStyle, appearance: AppAppearance, textColor: UIColor? = nil) {
        applySurfaceStyle(style)
        setTitleColor(textColor ?? appearance.screenTextColor, for: .normal)
        setTitleColor(appearance.disabledTextColor, for: .disabled)
        tintColor = textColor ?? appearance.screenTextColor
    }
}

enum QuizThemeAccentStyle {
    static func accentColor(themeID _: String?, appearance: AppAppearance) -> UIColor {
        appearance.accentColor
    }

    static func primaryButtonStyle(themeID: String?, appearance: AppAppearance) -> AppSurfaceStyle {
        guard appearance.designStyle == .clean else { return appearance.primaryButton }
        let accentColor = accentColor(themeID: themeID, appearance: appearance)
        return AppSurfaceStyle(
            backgroundColor: accentColor,
            borderColor: accentColor,
            borderWidth: appearance.primaryButton.borderWidth,
            cornerRadius: appearance.primaryButton.cornerRadius,
            shadow: appearance.primaryButton.shadow
        )
    }

    static func primaryButtonTextColor(themeID _: String?, appearance: AppAppearance) -> UIColor {
        guard appearance.designStyle == .clean else { return appearance.screenTextColor }
        return appearance.accentForegroundColor
    }

    static func secondaryButtonStyle(themeID: String?, appearance: AppAppearance) -> AppSurfaceStyle {
        guard appearance.designStyle == .clean else { return appearance.secondaryButton }
        let accentColor = accentColor(themeID: themeID, appearance: appearance)
        let borderAlpha: CGFloat = appearance.resolvedInterfaceStyle == .dark ? 0.56 : 0.44
        return AppSurfaceStyle(
            backgroundColor: appearance.secondaryButton.backgroundColor,
            borderColor: accentColor.withAlphaComponent(borderAlpha),
            borderWidth: appearance.secondaryButton.borderWidth,
            cornerRadius: appearance.secondaryButton.cornerRadius,
            shadow: appearance.secondaryButton.shadow
        )
    }

    static func secondaryButtonTextColor(themeID: String?, appearance: AppAppearance) -> UIColor {
        guard appearance.designStyle == .clean else { return appearance.screenTextColor }
        return accentColor(themeID: themeID, appearance: appearance)
    }
}

class BaseQuizViewController: UIViewController {
    private let appearanceStore = AppAppearanceStore.shared
    private var appearanceObserver: NSObjectProtocol?
    private var localizationObserver: NSObjectProtocol?

    deinit {
        if let appearanceObserver {
            NotificationCenter.default.removeObserver(appearanceObserver)
        }
        if let localizationObserver {
            NotificationCenter.default.removeObserver(localizationObserver)
        }
    }

    func installAppearanceObserver() {
        appearanceObserver = NotificationCenter.default.addObserver(
            forName: .appAppearanceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyAppearance()
        }
    }

    func installAppearanceTraitObserver() {
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (viewController: BaseQuizViewController, _: UITraitCollection) in
            viewController.applyAppearance()
        }
    }

    func installLocalizationObserver() {
        localizationObserver = NotificationCenter.default.addObserver(
            forName: .appLocalizationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyLocalizedStrings()
        }
    }

    func currentAppearance() -> AppAppearance {
        appearanceStore.appearance(compatibleWith: traitCollection)
    }

    func applyAppearance() {}

    func applyLocalizedStrings() {}
}

