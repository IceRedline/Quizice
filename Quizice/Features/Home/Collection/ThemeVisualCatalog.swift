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
    private static let tintColorNames: [String: String] = [
        "music": ThemesCollectionService.Content.musicThemeTintColorName,
        "technology": ThemesCollectionService.Content.technologyThemeTintColorName,
        "history_culture": ThemesCollectionService.Content.cultureThemeTintColorName,
        "politics_business": ThemesCollectionService.Content.politicsThemeTintColorName
    ]

    static func logoImage(sfSymbolName: String) -> UIImage? {
        let normalizedName = sfSymbolName.trimmingCharacters(in: .whitespacesAndNewlines)
        return (UIImage(systemName: normalizedName)
            ?? UIImage(systemName: QuizTheme.defaultSFSymbolName))?
            .withRenderingMode(.alwaysTemplate)
    }

    static func tintColor(for themeID: String) -> UIColor {
        tintColorIfAvailable(for: themeID) ?? fallbackTintColors[paletteIndex(for: themeID)]
    }

    static func tintColorIfAvailable(for themeID: String) -> UIColor? {
        guard let colorName = tintColorNames[themeID] else { return nil }
        return UIColor(named: colorName)
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
