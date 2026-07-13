import SwiftUI
import UIKit

enum AppDesignStyle: String, CaseIterable, Identifiable {
    case clean
    case radar
    case classic

    static let defaultStyle: AppDesignStyle = .classic
    static let settingsOrder: [AppDesignStyle] = [.classic, .radar, .clean]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .clean:
            return L10n.Settings.Design.clean
        case .radar:
            return L10n.Settings.Design.radar
        case .classic:
            return L10n.Settings.Design.classic
        }
    }

    var isSelectable: Bool {
        true
    }
}

enum AppBackgroundStyle: String, CaseIterable, Identifiable {
    case legacySlate
    case slate4x4
    case slate5x5

    static let defaultStyle: AppBackgroundStyle = .slate5x5

    var id: String { rawValue }

    var title: String {
        switch self {
        case .legacySlate:
            return L10n.Home.BackgroundStyle.original
        case .slate4x4:
            return L10n.Home.BackgroundStyle.grid4x4
        case .slate5x5:
            return L10n.Home.BackgroundStyle.grid5x5
        }
    }

    var systemImageName: String {
        switch self {
        case .legacySlate:
            return "circle.lefthalf.filled"
        case .slate4x4:
            return "square.grid.4x3.fill"
        case .slate5x5:
            return "square.grid.3x3.fill"
        }
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
        static let backgroundStyle = "quizice.experimental.backgroundStyle"
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

    var backgroundStyle: AppBackgroundStyle {
        get {
            guard
                let rawValue = userDefaults.string(forKey: Keys.backgroundStyle),
                let style = AppBackgroundStyle(rawValue: rawValue)
            else { return AppBackgroundStyle.defaultStyle }
            return style
        }
        set {
            guard backgroundStyle != newValue else { return }
            userDefaults.set(newValue.rawValue, forKey: Keys.backgroundStyle)
            notifyChange()
        }
    }

    func appearance(compatibleWith traitCollection: UITraitCollection) -> AppAppearance {
        AppAppearance(
            designStyle: designStyle,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: backgroundStyle,
            traitCollection: effectiveTraitCollection(compatibleWith: traitCollection)
        )
    }

    func notifyChange() {
        notificationCenter.post(name: .appAppearanceDidChange, object: self)
    }

    private func effectiveTraitCollection(compatibleWith traitCollection: UITraitCollection) -> UITraitCollection {
        guard designStyle == .clean, cleanColorSchemePreference == .system else {
            return traitCollection
        }

        let systemStyle = UIScreen.main.traitCollection.userInterfaceStyle
        guard systemStyle != .unspecified else { return traitCollection }
        return UITraitCollection(userInterfaceStyle: systemStyle)
    }
}

enum AppFontFamily: String {
    case inter = "Inter"
    case jetBrainsMono = "JetBrains Mono"
    case manrope = "Manrope"

    var fallbackWeight: UIFont.Weight {
        switch self {
        case .inter, .manrope:
            return .semibold
        case .jetBrainsMono:
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

    func font(
        size: CGFloat,
        weight: UIFont.Weight,
        compatibleWith traitCollection: UITraitCollection? = nil
    ) -> UIFont {
        let textStyle = uiTextStyle(for: size)
        let baseFont: UIFont
        if let name = fontFamily.fontName(weight: weight) {
            baseFont = UIFont(name: name, size: size) ?? fallbackFont(size: size, weight: weight)
        } else {
            baseFont = fallbackFont(size: size, weight: weight)
        }
        return UIFontMetrics(forTextStyle: textStyle).scaledFont(
            for: baseFont,
            compatibleWith: traitCollection
        )
    }

    func swiftUIFont(size: CGFloat, weight: Font.Weight) -> Font {
        let textStyle = swiftUITextStyle(for: size)
        if let name = fontFamily.fontName(weight: weight.uiFontWeight) {
            return .custom(name, size: size, relativeTo: textStyle)
        }
        return .system(textStyle, design: .default, weight: weight)
    }

    private func uiTextStyle(for size: CGFloat) -> UIFont.TextStyle {
        switch size {
        case 36...: return .largeTitle
        case 30...: return .title1
        case 24...: return .title2
        case 20...: return .title3
        case 17...: return .body
        case 15...: return .subheadline
        default: return .caption1
        }
    }

    private func swiftUITextStyle(for size: CGFloat) -> Font.TextStyle {
        switch size {
        case 36...: return .largeTitle
        case 30...: return .title
        case 24...: return .title2
        case 20...: return .title3
        case 17...: return .body
        case 15...: return .subheadline
        default: return .caption
        }
    }

    private func fallbackFont(size: CGFloat, weight: UIFont.Weight) -> UIFont {
        if fontFamily == .jetBrainsMono {
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
    case cleanDanger = "themeCleanDanger"
    case cleanCorrect = "themeCleanCorrect"
    case cleanAnswerDark = "themeCleanAnswerDark"
    case cleanDisabledText = "themeCleanDisabledText"
    case radarBackground = "themeRadarBackground"
    case radarGreen = "themeRadarGreen"
    case radarDeepGreen = "themeRadarDeepGreen"
    case radarDanger = "themeRadarDanger"

    var uiColor: UIColor {
        UIColor(named: rawValue) ?? .systemPink
    }
}

struct AppAppearance {
    let designStyle: AppDesignStyle
    let cleanColorSchemePreference: CleanColorSchemePreference
    let backgroundStyle: AppBackgroundStyle
    let resolvedInterfaceStyle: UIUserInterfaceStyle

    let typography: AppTypography
    let backgroundColor: UIColor
    let screenTextColor: UIColor
    let secondaryScreenTextColor: UIColor
    let surfaceTextColor: UIColor
    let secondarySurfaceTextColor: UIColor
    let accentColor: UIColor
    let accentForegroundColor: UIColor
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
        backgroundStyle: AppBackgroundStyle = .defaultStyle,
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
                backgroundStyle: backgroundStyle,
                isDark: cleanIsDark
            )
        case .radar:
            self = AppAppearance.makeRadar(
                cleanColorSchemePreference: cleanColorSchemePreference,
                backgroundStyle: backgroundStyle
            )
        case .classic:
            self = AppAppearance.makeClassic(
                cleanColorSchemePreference: cleanColorSchemePreference,
                backgroundStyle: backgroundStyle
            )
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

    var dialogSurface: AppSurfaceStyle {
        switch designStyle {
        case .clean:
            return card
        case .radar:
            return AppSurfaceStyle(
                backgroundColor: card.backgroundColor.withAlphaComponent(0.98),
                borderColor: accentColor.withAlphaComponent(0.86),
                borderWidth: card.borderWidth,
                cornerRadius: card.cornerRadius,
                shadow: AppShadowStyle(color: accentColor, opacity: 0.22, radius: 20, offset: .zero)
            )
        case .classic:
            return AppSurfaceStyle(
                backgroundColor: UIColor.black.withAlphaComponent(0.82),
                borderColor: UIColor.white.withAlphaComponent(0.32),
                borderWidth: card.borderWidth,
                cornerRadius: card.cornerRadius,
                shadow: AppShadowStyle(
                    color: .black,
                    opacity: 0.55,
                    radius: 30,
                    offset: CGSize(width: 0, height: 14)
                )
            )
        }
    }

    var dialogScrimOpacity: Double {
        switch designStyle {
        case .clean:
            return resolvedInterfaceStyle == .dark ? 0.62 : 0.38
        case .radar:
            return 0.64
        case .classic:
            return 0.50
        }
    }

    func applyBackground(
        to view: UIView,
        motionProfile: AppBackgroundMotionProfile = .standard
    ) {
        view.backgroundColor = backgroundColor
        if let backgroundView = view.subviews.first(where: { $0 is AppBackgroundHostingView }) as? AppBackgroundHostingView {
            backgroundView.update(
                appearance: self,
                motionProfile: motionProfile,
                animated: true
            )
            view.sendSubviewToBack(backgroundView)
        } else {
            let backgroundView = AppBackgroundHostingView(
                appearance: self,
                motionProfile: motionProfile
            )
            view.insertSubview(backgroundView, at: 0)
            NSLayoutConstraint.activate([
                backgroundView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                backgroundView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                backgroundView.topAnchor.constraint(equalTo: view.topAnchor),
                backgroundView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
        }
        view.overrideUserInterfaceStyle = resolvedInterfaceStyle
    }

    func themeCardBackground(baseColor: UIColor) -> UIColor {
        switch designStyle {
        case .clean:
            return card.backgroundColor
        case .radar:
            return AppThemeColor.black.uiColor.withAlphaComponent(0.84)
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
        case .classic:
            return .white
        }
    }

    private static func makeClean(
        cleanColorSchemePreference: CleanColorSchemePreference,
        backgroundStyle: AppBackgroundStyle,
        isDark: Bool
    ) -> AppAppearance {
        let background = isDark ? AppThemeColor.black.uiColor : AppThemeColor.cleanBackground.uiColor
        let screenText = isDark ? AppThemeColor.white.uiColor : AppThemeColor.cleanScreenText.uiColor
        let cardBackground = isDark ? AppThemeColor.cleanCardDark.uiColor : AppThemeColor.white.uiColor
        let surfaceText = isDark ? AppThemeColor.white.uiColor : AppThemeColor.cleanSurfaceText.uiColor
        let accent = isDark ? AppThemeColor.white.uiColor : AppThemeColor.black.uiColor
        let accentForeground = isDark ? AppThemeColor.black.uiColor : AppThemeColor.white.uiColor
        let subtleBorder = isDark ? AppThemeColor.white.uiColor.withAlphaComponent(0.10) : AppThemeColor.black.uiColor.withAlphaComponent(0.04)
        return AppAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: backgroundStyle,
            resolvedInterfaceStyle: cleanColorSchemePreference.overrideUserInterfaceStyle,
            typography: AppTypography(fontFamily: .inter),
            backgroundColor: background,
            screenTextColor: screenText,
            secondaryScreenTextColor: screenText.withAlphaComponent(0.62),
            surfaceTextColor: surfaceText,
            secondarySurfaceTextColor: surfaceText.withAlphaComponent(0.58),
            accentColor: accent,
            accentForegroundColor: accentForeground,
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
            themeCardShadow: isDark
                ? AppShadowStyle(color: .black, opacity: 0.16, radius: 14, offset: CGSize(width: 0, height: 8))
                : .none
        )
    }

    private static func makeRadar(
        cleanColorSchemePreference: CleanColorSchemePreference,
        backgroundStyle: AppBackgroundStyle
    ) -> AppAppearance {
        let green = AppThemeColor.radarGreen.uiColor
        let deepGreen = AppThemeColor.radarDeepGreen.uiColor
        return AppAppearance(
            designStyle: .radar,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: backgroundStyle,
            resolvedInterfaceStyle: .dark,
            typography: AppTypography(fontFamily: .jetBrainsMono),
            backgroundColor: AppThemeColor.radarBackground.uiColor,
            screenTextColor: green,
            secondaryScreenTextColor: green.withAlphaComponent(0.68),
            surfaceTextColor: green,
            secondarySurfaceTextColor: green.withAlphaComponent(0.62),
            accentColor: green,
            accentForegroundColor: green,
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

    private static func makeClassic(
        cleanColorSchemePreference: CleanColorSchemePreference,
        backgroundStyle: AppBackgroundStyle
    ) -> AppAppearance {
        return AppAppearance(
            designStyle: .classic,
            cleanColorSchemePreference: cleanColorSchemePreference,
            backgroundStyle: backgroundStyle,
            resolvedInterfaceStyle: .dark,
            typography: AppTypography(fontFamily: .manrope),
            backgroundColor: UIColor(hex: 0x111620),
            screenTextColor: AppThemeColor.white.uiColor,
            secondaryScreenTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.82),
            surfaceTextColor: AppThemeColor.white.uiColor,
            secondarySurfaceTextColor: AppThemeColor.white.uiColor.withAlphaComponent(0.90),
            accentColor: .defaultButton,
            accentForegroundColor: AppThemeColor.white.uiColor,
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
        backgroundStyle: AppBackgroundStyle,
        resolvedInterfaceStyle: UIUserInterfaceStyle,
        typography: AppTypography,
        backgroundColor: UIColor,
        screenTextColor: UIColor,
        secondaryScreenTextColor: UIColor,
        surfaceTextColor: UIColor,
        secondarySurfaceTextColor: UIColor,
        accentColor: UIColor,
        accentForegroundColor: UIColor,
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
        self.backgroundStyle = backgroundStyle
        self.resolvedInterfaceStyle = resolvedInterfaceStyle
        self.typography = typography
        self.backgroundColor = backgroundColor
        self.screenTextColor = screenTextColor
        self.secondaryScreenTextColor = secondaryScreenTextColor
        self.surfaceTextColor = surfaceTextColor
        self.secondarySurfaceTextColor = secondarySurfaceTextColor
        self.accentColor = accentColor
        self.accentForegroundColor = accentForegroundColor
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

private struct AppMeshGradientPreset {
    let width: Int
    let height: Int
    let points: [SIMD2<Float>]
    let colorHexes: [UInt32]
    let backgroundHex: UInt32

    var colors: [Color] {
        colorHexes.map { Color(uiColor: UIColor(hex: $0)) }
    }
}

private extension AppBackgroundStyle {
    var meshPreset: AppMeshGradientPreset {
        switch self {
        case .legacySlate:
            return AppMeshGradientPreset(
                width: 3,
                height: 3,
                points: [
                    .init(0.00, 0.00), .init(0.50, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.50), .init(0.50, 0.50), .init(1.00, 0.50),
                    .init(0.00, 1.00), .init(0.50, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x131824, 0x1E263A,
                    0x121722, 0x111620, 0x161C2A,
                    0x1C2437, 0x151B29, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        case .slate4x4:
            return AppMeshGradientPreset(
                width: 4,
                height: 4,
                points: [
                    .init(0.00, 0.00), .init(0.32, 0.00), .init(0.68, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.33), .init(0.28, 0.25), .init(0.72, 0.40), .init(1.00, 0.30),
                    .init(0.00, 0.67), .init(0.38, 0.72), .init(0.64, 0.58), .init(1.00, 0.70),
                    .init(0.00, 1.00), .init(0.33, 1.00), .init(0.67, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x131824, 0x131824, 0x1E263A,
                    0x121722, 0x131824, 0x111620, 0x161C2A,
                    0x1C2437, 0x111620, 0x151B29, 0x2B3756,
                    0x1C2437, 0x151B29, 0x151B29, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        case .slate5x5:
            return AppMeshGradientPreset(
                width: 5,
                height: 5,
                points: [
                    .init(0.00, 0.00), .init(0.25, 0.00), .init(0.50, 0.00), .init(0.75, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.25), .init(0.20, 0.18), .init(0.48, 0.30), .init(0.78, 0.20), .init(1.00, 0.25),
                    .init(0.00, 0.50), .init(0.30, 0.46), .init(0.42, 0.58), .init(0.72, 0.42), .init(1.00, 0.50),
                    .init(0.00, 0.75), .init(0.18, 0.82), .init(0.55, 0.68), .init(0.82, 0.80), .init(1.00, 0.75),
                    .init(0.00, 1.00), .init(0.25, 1.00), .init(0.50, 1.00), .init(0.75, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x2A3755, 0x131824, 0x1E263A, 0x1E263A,
                    0x2A3755, 0x121722, 0x131824, 0x161C2A, 0x1E263A,
                    0x121722, 0x131824, 0x111620, 0x161C2A, 0x161C2A,
                    0x1C2437, 0x121722, 0x111620, 0x151B29, 0x2B3756,
                    0x1C2437, 0x1C2437, 0x151B29, 0x2B3756, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        }
    }
}

enum AppBackgroundMotionProfile: Equatable {
    case standard
    case edgeAware
}

struct AppBackgroundView: View {
    let appearance: AppAppearance
    let motionProfile: AppBackgroundMotionProfile

    init(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile = .standard
    ) {
        self.appearance = appearance
        self.motionProfile = motionProfile
    }

    var body: some View {
        Group {
            if appearance.designStyle == .classic {
                let preset = appearance.backgroundStyle.meshPreset
                if appearance.backgroundStyle == .slate5x5 {
                    AnimatedSlateMeshGradient(
                        preset: preset,
                        motionProfile: motionProfile
                    )
                } else {
                    MeshGradient(
                        width: preset.width,
                        height: preset.height,
                        points: preset.points,
                        colors: preset.colors,
                        background: Color(uiColor: UIColor(hex: preset.backgroundHex)),
                        smoothsColors: true
                    )
                }
            } else {
                Color(uiColor: appearance.backgroundColor)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum AppMeshGradientMotion {
    static func animatedPoints(
        at date: Date,
        width: Int,
        height: Int,
        basePoints: [SIMD2<Float>],
        cycleDuration: TimeInterval,
        horizontalAmplitude: Float,
        verticalAmplitude: Float,
        edgeAmplitude: Float,
        profile: AppBackgroundMotionProfile
    ) -> [SIMD2<Float>] {
        guard width == 5, height == 5, basePoints.count == 25 else {
            return basePoints
        }

        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        let phase = Float(progress * 2 * Double.pi)
        let interiorPointCount = (width - 2) * (height - 2)
        let phaseStep = 2 * Float.pi / Float(interiorPointCount)
        var points = basePoints
        var interiorIndex = 0

        for row in 1..<(height - 1) {
            for column in 1..<(width - 1) {
                let pointIndex = row * width + column
                let localPhase = phase + Float(interiorIndex) * phaseStep
                points[pointIndex].x += horizontalAmplitude * sin(localPhase)
                points[pointIndex].y += verticalAmplitude * cos(localPhase)
                interiorIndex += 1
            }
        }

        guard profile == .edgeAware else { return points }

        let edgePhaseStep = Float.pi / 3
        for column in 1..<(width - 1) {
            let localPhase = phase + Float(column - 1) * edgePhaseStep
            points[column].x += edgeAmplitude * sin(localPhase)
            points[(height - 1) * width + column].x += edgeAmplitude * sin(localPhase + .pi)
        }

        for row in 1..<(height - 1) {
            let localPhase = phase + Float(row - 1) * edgePhaseStep + Float.pi / 2
            points[row * width].y += edgeAmplitude * sin(localPhase)
            points[row * width + width - 1].y += edgeAmplitude * sin(localPhase + .pi)
        }

        return points
    }
}

private struct AnimatedSlateMeshGradient: View {
    private enum Motion {
        static let cycleDuration: TimeInterval = 4
        static let minimumFrameInterval: TimeInterval = 1.0 / 30.0
        static let horizontalAmplitude: Float = 0.050
        static let verticalAmplitude: Float = 0.035
        static let edgeAmplitude: Float = 0.070
    }

    let preset: AppMeshGradientPreset
    let motionProfile: AppBackgroundMotionProfile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = preset.colors
        let background = Color(uiColor: UIColor(hex: preset.backgroundHex))
        let animationPaused = reduceMotion || !UIView.areAnimationsEnabled

        TimelineView(
            .animation(
                minimumInterval: Motion.minimumFrameInterval,
                paused: animationPaused
            )
        ) { context in
            MeshGradient(
                width: preset.width,
                height: preset.height,
                points: animationPaused ? preset.points : animatedPoints(at: context.date),
                colors: colors,
                background: background,
                smoothsColors: true
            )
        }
    }

    private func animatedPoints(at date: Date) -> [SIMD2<Float>] {
        AppMeshGradientMotion.animatedPoints(
            at: date,
            width: preset.width,
            height: preset.height,
            basePoints: preset.points,
            cycleDuration: Motion.cycleDuration,
            horizontalAmplitude: Motion.horizontalAmplitude,
            verticalAmplitude: Motion.verticalAmplitude,
            edgeAmplitude: Motion.edgeAmplitude,
            profile: motionProfile
        )
    }
}

private final class AppBackgroundHostingView: UIView {
    private enum Animation {
        static let crossfadeDuration: TimeInterval = 0.32
    }

    private let hostingController: UIHostingController<AppBackgroundView>
    private var appearance: AppAppearance

    init(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile
    ) {
        self.appearance = appearance
        self.hostingController = UIHostingController(
            rootView: AppBackgroundView(
                appearance: appearance,
                motionProfile: motionProfile
            )
        )
        super.init(frame: .zero)

        accessibilityIdentifier = "appBackgroundView"
        accessibilityElementsHidden = true
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false

        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.isUserInteractionEnabled = false
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func update(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile,
        animated: Bool
    ) {
        let shouldCrossfade = animated
            && self.appearance.designStyle == .classic
            && appearance.designStyle == .classic
            && self.appearance.backgroundStyle != appearance.backgroundStyle
            && UIView.areAnimationsEnabled
            && !UIAccessibility.isReduceMotionEnabled

        self.appearance = appearance
        let updates = { [hostingController] in
            hostingController.rootView = AppBackgroundView(
                appearance: appearance,
                motionProfile: motionProfile
            )
        }

        if shouldCrossfade {
            UIView.transition(
                with: self,
                duration: Animation.crossfadeDuration,
                options: [.transitionCrossDissolve, .beginFromCurrentState, .allowAnimatedContent],
                animations: updates
            )
        } else {
            updates()
        }
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
