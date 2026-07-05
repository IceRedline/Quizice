import SwiftUI
import UIKit

enum AppDesignStyle: String, CaseIterable, Identifiable {
    case clean
    case radar
    case pixel
    case classic

    static let defaultStyle: AppDesignStyle = .classic
    static let settingsOrder: [AppDesignStyle] = [.classic, .radar, .clean, .pixel]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            return L10n.Settings.Design.clean
        case .radar:
            return L10n.Settings.Design.radar
        case .pixel:
            return L10n.Settings.Design.pixel
        case .classic:
            return L10n.Settings.Design.classic
        }
    }

    var isSelectable: Bool {
        self != .pixel
    }
}

enum CleanColorSchemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system:
            return L10n.Settings.Theme.system
        case .light:
            return L10n.Settings.Theme.light
        case .dark:
            return L10n.Settings.Theme.dark
        }
    }

    var overrideUserInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system:
            return .unspecified
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

extension Notification.Name {
    static let appAppearanceDidChange = Notification.Name("quizice.appAppearanceDidChange")
}

final class AppAppearanceStore {
    enum Keys {
        static let designStyle = "quizice.settings.designStyle"
        static let cleanColorScheme = "quizice.settings.theme"
    }

    static let shared = AppAppearanceStore()

    private let userDefaults: UserDefaults
    private let notificationCenter: NotificationCenter

    init(userDefaults: UserDefaults = .standard, notificationCenter: NotificationCenter = .default) {
        self.userDefaults = userDefaults
        self.notificationCenter = notificationCenter
    }

    var designStyle: AppDesignStyle {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.designStyle),
                let style = AppDesignStyle(rawValue: rawValue),
                style.isSelectable
            else { return AppDesignStyle.defaultStyle }
            return style
        }
        set {
            let nextStyle = newValue.isSelectable ? newValue : AppDesignStyle.defaultStyle
            guard designStyle != nextStyle else { return }
            userDefaults.set(nextStyle.rawValue, forKey: Keys.designStyle)
            notifyChange()
        }
    }

    var cleanColorSchemePreference: CleanColorSchemePreference {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.cleanColorScheme),
                let preference = CleanColorSchemePreference(rawValue: rawValue)
            else { return .system }
            return preference
        }
        set {
            guard cleanColorSchemePreference != newValue else { return }
            userDefaults.set(newValue.rawValue, forKey: Keys.cleanColorScheme)
            notifyChange()
        }
    }

    func appearance(compatibleWith traitCollection: UITraitCollection) -> AppAppearance {
        AppAppearance(
            designStyle: designStyle,
            cleanColorSchemePreference: cleanColorSchemePreference,
            traitCollection: traitCollection
        )
    }

    func notifyChange() {
        notificationCenter.post(name: .appAppearanceDidChange, object: self)
    }
}

enum AppFontFamily: String {
    case inter = "Inter"
    case jetBrainsMono = "JetBrains Mono"
    case rubikPixels = "Rubik Pixels"
    case manrope = "Manrope"

    var fallbackWeight: UIFont.Weight {
        switch self {
        case .inter, .manrope:
            return .semibold
        case .jetBrainsMono, .rubikPixels:
            return .medium
        }
    }

    func fontName(weight: UIFont.Weight) -> String? {
        let names = UIFont.fontNames(forFamilyName: rawValue)
        guard !names.isEmpty else { return nil }

        let preferredSuffixes: [String]
        switch weight {
        case .bold, .heavy, .black:
            preferredSuffixes = ["Bold", "ExtraBold", "SemiBold"]
        case .semibold:
            preferredSuffixes = ["SemiBold", "Bold", "Medium"]
        case .medium:
            preferredSuffixes = ["Medium", "SemiBold", "Regular"]
        default:
            preferredSuffixes = ["Regular", "Medium"]
        }

        for suffix in preferredSuffixes {
            if let name = names.first(where: { $0.localizedCaseInsensitiveContains(suffix) }) {
                return name
            }
        }
        return names.first
    }
}

struct AppTypography {
    let fontFamily: AppFontFamily

    func largeTitle() -> UIFont { font(size: 38, weight: .bold) }
    func title() -> UIFont { font(size: 30, weight: .bold) }
    func headline() -> UIFont { font(size: 22, weight: .semibold) }
    func body() -> UIFont { font(size: 18, weight: .regular) }
    func caption() -> UIFont { font(size: 15, weight: .medium) }
    func button() -> UIFont { font(size: 19, weight: .semibold) }
    func number() -> UIFont { font(size: 28, weight: .bold) }

    func font(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if let name = fontFamily.fontName(weight: weight) {
            return UIFontMetrics.default.scaledFont(for: UIFont(name: name, size: size) ?? fallbackFont(size: size, weight: weight))
        }
        return UIFontMetrics.default.scaledFont(for: fallbackFont(size: size, weight: weight))
    }

    func swiftUIFont(size: CGFloat, weight: Font.Weight) -> Font {
        if let name = fontFamily.fontName(weight: weight.uiFontWeight) {
            return .custom(name, size: size)
        }
        return .system(size: size, weight: weight)
    }

    private func fallbackFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if fontFamily == .jetBrainsMono || fontFamily == .rubikPixels {
            return .monospacedSystemFont(ofSize: size, weight: weight)
        }
        return .systemFont(ofSize: size, weight: weight)
    }
}

struct AppShadowStyle {
    let color: UIColor
    let opacity: Float
    let radius: CGFloat
    let offset: CGSize

    static let none = AppShadowStyle(color: .clear, opacity: 0, radius: 0, offset: .zero)
}

struct AppSurfaceStyle {
    let backgroundColor: UIColor
    let borderColor: UIColor
    let borderWidth: CGFloat
    let cornerRadius: CGFloat
    let shadow: AppShadowStyle
}

private enum AppThemeColor: String {
    case black = "themeBlack"
    case white = "themeWhite"
    case cleanBackground = "themeCleanBackground"
    case cleanScreenText = "themeCleanScreenText"
    case cleanSurfaceText = "themeCleanSurfaceText"
    case cleanCardDark = "themeCleanCardDark"
    case cleanRowDark = "themeCleanRowDark"
    case cleanSecondaryLight = "themeCleanSecondaryLight"
    case cleanSecondaryDark = "themeCleanSecondaryDark"
    case cleanAccent = "themeCleanAccent"
    case cleanDanger = "themeCleanDanger"
    case cleanCorrect = "themeCleanCorrect"
    case cleanAnswerDark = "themeCleanAnswerDark"
    case cleanDisabledText = "themeCleanDisabledText"
    case radarBackground = "themeRadarBackground"
    case radarGreen = "themeRadarGreen"
    case radarDeepGreen = "themeRadarDeepGreen"
    case radarDanger = "themeRadarDanger"
    case pixelBackground = "themePixelBackground"
    case pixelSurface = "themePixelSurface"
    case pixelRow = "themePixelRow"
    case pixelYellow = "themePixelYellow"
    case pixelPink = "themePixelPink"
    case pixelCyan = "themePixelCyan"
    case pixelCorrect = "themePixelCorrect"

    var uiColor: UIColor {
        UIColor(named: rawValue) ?? .systemPink
    }
}

struct AppAppearance {
    let designStyle: AppDesignStyle
    let cleanColorSchemePreference: CleanColorSchemePreference
    let resolvedInterfaceStyle: UIUserInterfaceStyle

    let typography: AppTypography
    let backgroundColor: UIColor
    let backgroundImageName: String?
    let overlayColor: UIColor
    let screenTextColor: UIColor
    let secondaryScreenTextColor: UIColor
    let surfaceTextColor: UIColor
    let secondarySurfaceTextColor: UIColor
    let accentColor: UIColor
    let destructiveColor: UIColor
    let answerDefaultColor: UIColor
    let correctAnswerColor: UIColor
    let wrongAnswerColor: UIColor
    let disabledTextColor: UIColor
    let progressTrackColor: UIColor
    let card: AppSurfaceStyle
    let row: AppSurfaceStyle
    let primaryButton: AppSurfaceStyle
    let secondaryButton: AppSurfaceStyle
    let iconButton: AppSurfaceStyle
    let themeCardCornerRadius: CGFloat
    let themeCardBorderWidth: CGFloat
    let themeCardShadow: AppShadowStyle

    init(
        designStyle: AppDesignStyle,
        cleanColorSchemePreference: CleanColorSchemePreference,
        traitCollection: UITraitCollection
    ) {
        let cleanIsDark: Bool
        switch cleanColorSchemePreference {
        case .system:
            cleanIsDark = traitCollection.userInterfaceStyle == .dark
        case .light:
            cleanIsDark = false
        case .dark:
            cleanIsDark = true
        }

        switch designStyle {
        case .clean:
            self = AppAppearance.makeClean(
                cleanColorSchemePreference: cleanColorSchemePreference,
                isDark: cleanIsDark
            )
        case .radar:
            self = AppAppearance.makeRadar(cleanColorSchemePreference: cleanColorSchemePreference)
        case .pixel:
            self = AppAppearance.makePixel(cleanColorSchemePreference: cleanColorSchemePreference)
        case .classic:
            self = AppAppearance.makeClassic(cleanColorSchemePreference: cleanColorSchemePreference)
        }
    }

    var swiftUIColorScheme: ColorScheme? {
        guard designStyle == .clean else { return .dark }
        switch cleanColorSchemePreference {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    func applyBackground(to view: UIView) {
        if let backgroundImageName, let image = UIImage(named: backgroundImageName) {
            view.backgroundColor = UIColor(patternImage: image)
        } else {
            view.backgroundColor = backgroundColor
        }
        view.overrideUserInterfaceStyle = resolvedInterfaceStyle
    }

    func themeCardBackground(baseColor: UIColor) -> UIColor {
        switch designStyle {
        case .clean:
            return card.backgroundColor
        case .radar:
            return AppThemeColor.black.uiColor.withAlphaComponent(0.84)
        case .pixel:
            return baseColor.withAlphaComponent(0.92)
        case .classic:
            return baseColor.withAlphaComponent(0.20)
        }
    }

    func themeCardBorder(baseColor: UIColor) -> UIColor {
        switch designStyle {
        case .clean:
            return baseColor.withAlphaComponent(0.75)
        case .radar:
            return accentColor.withAlphaComponent(0.80)
        case .pixel:
            return AppThemeColor.white.uiColor.withAlphaComponent(0.90)
        case .classic:
            return baseColor.withAlphaComponent(0.45)
        }
    }

    func themeCardTextColor(baseColor: UIColor) -> UIColor {
        switch designStyle {
        case .clean:
            return surfaceTextColor
        case .radar:
            return accentColor
        case .pixel, .classic:
            return .white
        }
    }

    private static func makeClean(
        cleanColorSchemePreference: CleanColorSchemePreference,
        isDark: Bool
    ) -> AppAppearance {
        let background = isDark ? AppThemeColor.black.uiColor : AppThemeColor.cleanBackground.uiColor
        let screenText = isDark ? AppThemeColor.white.uiColor : AppThemeColor.cleanScreenText.uiColor
        let cardBackground = isDark ? AppThemeColor.cleanCardDark.uiColor : AppThemeColor.white.uiColor
        let surfaceText = isDark ? AppThemeColor.white.uiColor : AppThemeColor.cleanSurfaceText.uiColor
        let accent = AppThemeColor.cleanAccent.uiColor
        let subtleBorder = isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.10) : AppThemeColor.black.uiColor.withAlphaComponent(0.04)
        return AppAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: cleanColorSchemePreference,
            resolvedInterfaceStyle: cleanColorSchemePreference.overrideUserInterfaceStyle,
            typography: AppTypography(fontFamily: .inter),
            backgroundColor: background,
            backgroundImageName: nil,
            overlayColor: isDark ? .clear : AppThemeColor.white.uiColor.withAlphaComponent(0.12),
            screenTextColor: screenText,
            secondaryScreenTextColor: screenText.withAlphaComponent(0.62),
            surfaceTextColor: surfaceText,
            secondarySurfaceTextColor: surfaceText.withAlphaComponent(0.58),
            accentColor: accent,
            destructiveColor: AppThemeColor.cleanDanger.uiColor,
            answerDefaultColor: isDark ? AppThemeColor.cleanAnswerDark.uiColor : AppThemeColor.white.uiColor,
            correctAnswerColor: AppThemeColor.cleanCorrect.uiColor,
            wrongAnswerColor: AppThemeColor.cleanDanger.uiColor,
            disabledTextColor: AppThemeColor.cleanDisabledText.uiColor,
            progressTrackColor: isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.18) : AppThemeColor.black.uiColor.withAlphaComponent(0.12),
            card: AppSurfaceStyle(
                backgroundColor: cardBackground,
                borderColor: subtleBorder,
                borderWidth: 1,
                cornerRadius: 30,
                shadow: AppShadowStyle(color: .black, opacity: isDark ? 0 : 0.12, radius: 18, offset: CGSize(width: 0, height: 10))
            ),
            row: AppSurfaceStyle(
                backgroundColor: isDark ? AppThemeColor.cleanRowDark.uiColor : AppThemeColor.white.uiColor,
                borderColor: isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.08) : AppThemeColor.black.uiColor.withAlphaComponent(0.06),
                borderWidth: 1,
                cornerRadius: 22,
                shadow: .none
            ),
            primaryButton: AppSurfaceStyle(
                backgroundColor: accent,
                borderColor: accent,
                borderWidth: 1,
                cornerRadius: 24,
                shadow: AppShadowStyle(color: .black, opacity: 0.16, radius: 12, offset: CGSize(width: 0, height: 6))
            ),
            secondaryButton: AppSurfaceStyle(
                backgroundColor: isDark ? AppThemeColor.cleanSecondaryDark.uiColor : AppThemeColor.cleanSecondaryLight.uiColor,
                borderColor: isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.12) : AppThemeColor.black.uiColor.withAlphaComponent(0.06),
                borderWidth: 1,
                cornerRadius: 22,
                shadow: .none
            ),
            iconButton: AppSurfaceStyle(
                backgroundColor: isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.12) : AppThemeColor.black.uiColor.withAlphaComponent(0.08),
                borderColor: isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.16) : AppThemeColor.black.uiColor.withAlphaComponent(0.08),
                borderWidth: 1,
                cornerRadius: 22,
                shadow: AppShadowStyle(color: .black, opacity: 0.12, radius: 10, offset: CGSize(width: 0, height: 4))
            ),
            themeCardCornerRadius: 28,
            themeCardBorderWidth: 2,
            themeCardShadow: AppShadowStyle(color: .black, opacity: isDark ? 0.16 : 0.10, radius: 14, offset: CGSize(width: 0, height: 8))
        )
    }

    private static func makeRadar(cleanColorSchemePreference: CleanColorSchemePreference) -> AppAppearance {
        let green = AppThemeColor.radarGreen.uiColor
        let deepGreen = AppThemeColor.radarDeepGreen.uiColor
        return AppAppearance(
            designStyle: .radar,
            cleanColorSchemePreference: cleanColorSchemePreference,
            resolvedInterfaceStyle: .dark,
            typography: AppTypography(fontFamily: .jetBrainsMono),
            backgroundColor: AppThemeColor.radarBackground.uiColor,
            backgroundImageName: nil,
            overlayColor: .clear,
            screenTextColor: green,
            secondaryScreenTextColor: green.withAlphaComponent(0.68),
            surfaceTextColor: green,
            secondarySurfaceTextColor: green.withAlphaComponent(0.62),
            accentColor: green,
            destructiveColor: AppThemeColor.radarDanger.uiColor,
            answerDefaultColor: deepGreen,
            correctAnswerColor: green,
            wrongAnswerColor: AppThemeColor.radarDanger.uiColor,
            disabledTextColor: green.withAlphaComponent(0.36),
            progressTrackColor: green.withAlphaComponent(0.20),
            card: AppSurfaceStyle(
                backgroundColor: deepGreen.withAlphaComponent(0.88),
                borderColor: green.withAlphaComponent(0.70),
                borderWidth: 1,
                cornerRadius: 12,
                shadow: AppShadowStyle(color: green, opacity: 0.12, radius: 14, offset: .zero)
            ),
            row: AppSurfaceStyle(
                backgroundColor: deepGreen.withAlphaComponent(0.76),
                borderColor: green.withAlphaComponent(0.54),
                borderWidth: 1,
                cornerRadius: 8,
                shadow: .none
            ),
            primaryButton: AppSurfaceStyle(
                backgroundColor: green.withAlphaComponent(0.18),
                borderColor: green,
                borderWidth: 1,
                cornerRadius: 10,
                shadow: AppShadowStyle(color: green, opacity: 0.18, radius: 12, offset: .zero)
            ),
            secondaryButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.black.uiColor.withAlphaComponent(0.54),
                borderColor: green.withAlphaComponent(0.62),
                borderWidth: 1,
                cornerRadius: 10,
                shadow: .none
            ),
            iconButton: AppSurfaceStyle(
                backgroundColor: deepGreen,
                borderColor: green.withAlphaComponent(0.72),
                borderWidth: 1,
                cornerRadius: 10,
                shadow: .none
            ),
            themeCardCornerRadius: 10,
            themeCardBorderWidth: 1,
            themeCardShadow: AppShadowStyle(color: green, opacity: 0.12, radius: 12, offset: .zero)
        )
    }

    private static func makePixel(cleanColorSchemePreference: CleanColorSchemePreference) -> AppAppearance {
        let yellow = AppThemeColor.pixelYellow.uiColor
        let pink = AppThemeColor.pixelPink.uiColor
        return AppAppearance(
            designStyle: .pixel,
            cleanColorSchemePreference: cleanColorSchemePreference,
            resolvedInterfaceStyle: .dark,
            typography: AppTypography(fontFamily: .rubikPixels),
            backgroundColor: AppThemeColor.pixelBackground.uiColor,
            backgroundImageName: nil,
            overlayColor: .clear,
            screenTextColor: yellow,
            secondaryScreenTextColor: AppThemeColor.pixelCyan.uiColor,
            surfaceTextColor: AppThemeColor.white.uiColor,
            secondarySurfaceTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.76),
            accentColor: yellow,
            destructiveColor: pink,
            answerDefaultColor: AppThemeColor.pixelSurface.uiColor,
            correctAnswerColor: AppThemeColor.pixelCorrect.uiColor,
            wrongAnswerColor: pink,
            disabledTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.42),
            progressTrackColor: AppThemeColor.white.uiColor.withAlphaComponent(0.20),
            card: AppSurfaceStyle(
                backgroundColor: AppThemeColor.pixelSurface.uiColor,
                borderColor: yellow,
                borderWidth: 3,
                cornerRadius: 0,
                shadow: .none
            ),
            row: AppSurfaceStyle(
                backgroundColor: AppThemeColor.pixelRow.uiColor,
                borderColor: AppThemeColor.pixelCyan.uiColor,
                borderWidth: 3,
                cornerRadius: 0,
                shadow: .none
            ),
            primaryButton: AppSurfaceStyle(
                backgroundColor: yellow,
                borderColor: AppThemeColor.white.uiColor,
                borderWidth: 3,
                cornerRadius: 0,
                shadow: .none
            ),
            secondaryButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.pixelSurface.uiColor,
                borderColor: AppThemeColor.pixelCyan.uiColor,
                borderWidth: 3,
                cornerRadius: 0,
                shadow: .none
            ),
            iconButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.pixelRow.uiColor,
                borderColor: yellow,
                borderWidth: 3,
                cornerRadius: 0,
                shadow: .none
            ),
            themeCardCornerRadius: 0,
            themeCardBorderWidth: 3,
            themeCardShadow: .none
        )
    }

    private static func makeClassic(cleanColorSchemePreference: CleanColorSchemePreference) -> AppAppearance {
        return AppAppearance(
            designStyle: .classic,
            cleanColorSchemePreference: cleanColorSchemePreference,
            resolvedInterfaceStyle: .dark,
            typography: AppTypography(fontFamily: .manrope),
            backgroundColor: .black,
            backgroundImageName: "backgroundImage",
            overlayColor: .clear,
            screenTextColor: AppThemeColor.white.uiColor,
            secondaryScreenTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.82),
            surfaceTextColor: AppThemeColor.white.uiColor,
            secondarySurfaceTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.90),
            accentColor: .defaultButton,
            destructiveColor: .wrongAnswerButton,
            answerDefaultColor: .defaultButton,
            correctAnswerColor: .correctAnswerButton,
            wrongAnswerColor: .wrongAnswerButton,
            disabledTextColor: .gray,
            progressTrackColor: AppThemeColor.white.uiColor.withAlphaComponent(0.25),
            card: AppSurfaceStyle(
                backgroundColor: AppThemeColor.black.uiColor.withAlphaComponent(0.26),
                borderColor: AppThemeColor.white.uiColor.withAlphaComponent(0.18),
                borderWidth: 1,
                cornerRadius: 30,
                shadow: AppShadowStyle(color: .black, opacity: 0.22, radius: 16, offset: CGSize(width: 0, height: 10))
            ),
            row: AppSurfaceStyle(
                backgroundColor: AppThemeColor.white.uiColor.withAlphaComponent(0.12),
                borderColor: AppThemeColor.white.uiColor.withAlphaComponent(0.22),
                borderWidth: 1,
                cornerRadius: 18,
                shadow: .none
            ),
            primaryButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.white.uiColor.withAlphaComponent(0.22),
                borderColor: AppThemeColor.white.uiColor.withAlphaComponent(0.50),
                borderWidth: 1,
                cornerRadius: 22,
                shadow: AppShadowStyle(color: .black, opacity: 0.20, radius: 10, offset: CGSize(width: 0, height: 6))
            ),
            secondaryButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.white.uiColor.withAlphaComponent(0.12),
                borderColor: AppThemeColor.white.uiColor.withAlphaComponent(0.34),
                borderWidth: 1,
                cornerRadius: 20,
                shadow: .none
            ),
            iconButton: AppSurfaceStyle(
                backgroundColor: AppThemeColor.white.uiColor.withAlphaComponent(0.14),
                borderColor: AppThemeColor.white.uiColor.withAlphaComponent(0.22),
                borderWidth: 1,
                cornerRadius: 22,
                shadow: AppShadowStyle(color: .black, opacity: 0.18, radius: 12, offset: CGSize(width: 0, height: 6))
            ),
            themeCardCornerRadius: 28,
            themeCardBorderWidth: 1,
            themeCardShadow: AppShadowStyle(color: .black, opacity: 0.22, radius: 22, offset: CGSize(width: 0, height: 12))
        )
    }

    private init(
        designStyle: AppDesignStyle,
        cleanColorSchemePreference: CleanColorSchemePreference,
        resolvedInterfaceStyle: UIUserInterfaceStyle,
        typography: AppTypography,
        backgroundColor: UIColor,
        backgroundImageName: String?,
        overlayColor: UIColor,
        screenTextColor: UIColor,
        secondaryScreenTextColor: UIColor,
        surfaceTextColor: UIColor,
        secondarySurfaceTextColor: UIColor,
        accentColor: UIColor,
        destructiveColor: UIColor,
        answerDefaultColor: UIColor,
        correctAnswerColor: UIColor,
        wrongAnswerColor: UIColor,
        disabledTextColor: UIColor,
        progressTrackColor: UIColor,
        card: AppSurfaceStyle,
        row: AppSurfaceStyle,
        primaryButton: AppSurfaceStyle,
        secondaryButton: AppSurfaceStyle,
        iconButton: AppSurfaceStyle,
        themeCardCornerRadius: CGFloat,
        themeCardBorderWidth: CGFloat,
        themeCardShadow: AppShadowStyle
    ) {
        self.designStyle = designStyle
        self.cleanColorSchemePreference = cleanColorSchemePreference
        self.resolvedInterfaceStyle = resolvedInterfaceStyle
        self.typography = typography
        self.backgroundColor = backgroundColor
        self.backgroundImageName = backgroundImageName
        self.overlayColor = overlayColor
        self.screenTextColor = screenTextColor
        self.secondaryScreenTextColor = secondaryScreenTextColor
        self.surfaceTextColor = surfaceTextColor
        self.secondarySurfaceTextColor = secondarySurfaceTextColor
        self.accentColor = accentColor
        self.destructiveColor = destructiveColor
        self.answerDefaultColor = answerDefaultColor
        self.correctAnswerColor = correctAnswerColor
        self.wrongAnswerColor = wrongAnswerColor
        self.disabledTextColor = disabledTextColor
        self.progressTrackColor = progressTrackColor
        self.card = card
        self.row = row
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
        self.iconButton = iconButton
        self.themeCardCornerRadius = themeCardCornerRadius
        self.themeCardBorderWidth = themeCardBorderWidth
        self.themeCardShadow = themeCardShadow
    }
}

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

extension Font.Weight {
    var uiFontWeight: UIFont.Weight {
        switch self {
        case .black:
            return .black
        case .bold:
            return .bold
        case .heavy:
            return .heavy
        case .light:
            return .light
        case .medium:
            return .medium
        case .semibold:
            return .semibold
        case .thin:
            return .thin
        case .ultraLight:
            return .ultraLight
        default:
            return .regular
        }
    }
}

private struct AppAppearanceEnvironmentKey: EnvironmentKey {
    static var defaultValue: AppAppearance {
        AppAppearanceStore.shared.appearance(compatibleWith: .current)
    }
}

extension EnvironmentValues {
    var appAppearance: AppAppearance {
        get { self[AppAppearanceEnvironmentKey.self] }
        set { self[AppAppearanceEnvironmentKey.self] = newValue }
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
