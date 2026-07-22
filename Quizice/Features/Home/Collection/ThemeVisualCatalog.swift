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

private struct ThemeVisualDescriptor {
    let classicSymbolName: String
    let fallbackClassicSymbolName: String
    let cleanSymbolName: String
    let fallbackCleanSymbolName: String
    let radarLogoName: String
    let tintColorName: String

    func logoImage(for designStyle: AppDesignStyle) -> UIImage? {
        switch designStyle {
        case .classic:
            let symbolImage = UIImage(systemName: classicSymbolName)
                ?? UIImage(systemName: fallbackClassicSymbolName)
            return symbolImage?.withRenderingMode(.alwaysTemplate)
        case .clean:
            let symbolImage = UIImage(systemName: cleanSymbolName) ?? UIImage(systemName: fallbackCleanSymbolName)
            return symbolImage?.withRenderingMode(.alwaysTemplate)
        case .radar:
            return UIImage(named: radarLogoName)
        }
    }
}

enum ThemeVisualCatalog {
    private static let descriptors: [String: ThemeVisualDescriptor] = [
        "music": ThemeVisualDescriptor(
            classicSymbolName: "music.note.list",
            fallbackClassicSymbolName: "music.note",
            cleanSymbolName: ThemesCollectionService.Content.musicThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "music.note",
            radarLogoName: ThemesCollectionService.Content.musicThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.musicThemeTintColorName
        ),
        "technology": ThemeVisualDescriptor(
            classicSymbolName: "cpu.fill",
            fallbackClassicSymbolName: "desktopcomputer",
            cleanSymbolName: ThemesCollectionService.Content.technologyThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: ThemesCollectionService.Content.technologyThemeLogoCleanSymbolName,
            radarLogoName: ThemesCollectionService.Content.technologyThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.technologyThemeTintColorName
        ),
        "history_culture": ThemeVisualDescriptor(
            classicSymbolName: "theatermask.and.paintbrush.fill",
            fallbackClassicSymbolName: "theatermasks",
            cleanSymbolName: ThemesCollectionService.Content.cultureThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "theatermask.and.paintbrush.fill",
            radarLogoName: ThemesCollectionService.Content.cultureThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.cultureThemeTintColorName
        ),
        "politics_business": ThemeVisualDescriptor(
            classicSymbolName: "briefcase.fill",
            fallbackClassicSymbolName: "building.columns.fill",
            cleanSymbolName: ThemesCollectionService.Content.politicsThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "building.columns.fill",
            radarLogoName: ThemesCollectionService.Content.politicsThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.politicsThemeTintColorName
        )
    ]

    static func logoImage(for themeID: String, designStyle: AppDesignStyle) -> UIImage? {
        descriptors[themeID]?.logoImage(for: designStyle)
            ?? UIImage(named: themeID)
            ?? UIImage(systemName: fallbackSymbolNames[paletteIndex(for: themeID)])
    }

    static func tintColor(for themeID: String) -> UIColor {
        tintColorIfAvailable(for: themeID) ?? fallbackTintColors[paletteIndex(for: themeID)]
    }

    static func tintColorIfAvailable(for themeID: String) -> UIColor? {
        guard let colorName = descriptors[themeID]?.tintColorName else { return nil }
        return UIColor(named: colorName)
    }

    private static let fallbackSymbolNames = [
        "sparkles",
        "book.closed.fill",
        "globe.europe.africa.fill",
        "atom",
        "gamecontroller.fill",
        "film.fill",
        "leaf.fill",
        "sportscourt.fill"
    ]

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
        return Int(hash % UInt64(fallbackSymbolNames.count))
    }
}
