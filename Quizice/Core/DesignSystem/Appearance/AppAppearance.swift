import SwiftUI
import UIKit

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

    func themeCardIconColor(baseColor: UIColor) -> UIColor {
        designStyle == .classic
            ? baseColor
            : themeCardBorder(baseColor: baseColor)
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
