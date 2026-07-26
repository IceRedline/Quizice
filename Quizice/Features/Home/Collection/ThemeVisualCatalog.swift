import UIKit

enum ThemeIconVisualStyle {
    static let shadowOffset: CGFloat = 3
    static let shadowAlpha: CGFloat = 0.26
}

enum AIThemeVisualStyle {
    static let gradientStartColor = UIColor(hex: 0xFF4FD8)
    static let gradientEndColor = UIColor(hex: 0x36A3FF)

    static let gradientColors = [gradientStartColor, gradientEndColor]
}

enum ThemeVisualCatalog {
    static func logoImage(sfSymbolName: String) -> UIImage? {
        let normalizedName = sfSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (UIImage(systemName: normalizedName)
            ?? UIImage(systemName: QuizTheme.defaultSFSymbolName))?
            .withRenderingMode(.alwaysTemplate)
    }

    static func tintColor(for theme: QuizTheme) -> UIColor {
        tintColor(colorHex: theme.colorHex, themeID: theme.stableID)
    }

    static func tintColor(for theme: OnboardingTheme) -> UIColor {
        tintColor(colorHex: theme.colorHex, themeID: theme.id)
    }

    static func tintColor(colorHex: String?, themeID: String) -> UIColor {
        color(from: colorHex) ?? fallbackTintColors[paletteIndex(for: themeID)]
    }

    static func color(from colorHex: String?) -> UIColor? {
        guard
            let normalized = QuizThemeColor.normalizedHex(colorHex),
            let value = UInt32(normalized.dropFirst(), radix: 16)
        else { return nil }
        return UIColor(hex: value)
    }

    private static let fallbackTintColors = [
        UIColor.systemIndigo,
        UIColor.systemTeal,
        UIColor.systemOrange,
        UIColor.systemPink,
        UIColor.systemGreen,
        UIColor.systemPurple,
        UIColor.systemBlue,
        UIColor.systemRed
    ]

    private static func paletteIndex(for themeID: String) -> Int {
        let hash = themeID.utf8.reduce(UInt64(14_695_981_039_346_656_037)) { value, byte in
            (value ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Int(hash % UInt64(fallbackTintColors.count))
    }
}
