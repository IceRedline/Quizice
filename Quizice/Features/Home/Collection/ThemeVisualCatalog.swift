import UIKit

private struct ThemeVisualDescriptor {
    let classicLogoName: String
    let cleanSymbolName: String
    let fallbackCleanSymbolName: String
    let radarLogoName: String
    let tintColorName: String

    func logoImage(for designStyle: AppDesignStyle) -> UIImage? {
        switch designStyle {
        case .clean:
            let symbolImage = UIImage(systemName: cleanSymbolName) ?? UIImage(systemName: fallbackCleanSymbolName)
            return symbolImage?.withRenderingMode(.alwaysTemplate)
        case .radar:
            return UIImage(named: radarLogoName)
        case .classic:
            return UIImage(named: classicLogoName)
        }
    }
}

enum ThemeVisualCatalog {
    private static let descriptors: [String: ThemeVisualDescriptor] = [
        "music": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.musicThemeLogoImageName,
            cleanSymbolName: ThemesCollectionService.Content.musicThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "music.note",
            radarLogoName: ThemesCollectionService.Content.musicThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.musicThemeTintColorName
        ),
        "technology": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.technologyThemeLogoImageName,
            cleanSymbolName: ThemesCollectionService.Content.technologyThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: ThemesCollectionService.Content.technologyThemeLogoCleanSymbolName,
            radarLogoName: ThemesCollectionService.Content.technologyThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.technologyThemeTintColorName
        ),
        "history_culture": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.cultureThemeLogoImageName,
            cleanSymbolName: ThemesCollectionService.Content.cultureThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "theatermasks.fill",
            radarLogoName: ThemesCollectionService.Content.cultureThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.cultureThemeTintColorName
        ),
        "politics_business": ThemeVisualDescriptor(
            classicLogoName: ThemesCollectionService.Content.politicsThemeLogoImageName,
            cleanSymbolName: ThemesCollectionService.Content.politicsThemeLogoCleanSymbolName,
            fallbackCleanSymbolName: "building.columns.fill",
            radarLogoName: ThemesCollectionService.Content.politicsThemeLogoRadarImageName,
            tintColorName: ThemesCollectionService.Content.politicsThemeTintColorName
        )
    ]

    static func logoImage(for themeID: String, designStyle: AppDesignStyle) -> UIImage? {
        descriptors[themeID]?.logoImage(for: designStyle) ?? UIImage(named: themeID)
    }

    static func tintColor(for themeID: String) -> UIColor {
        tintColorIfAvailable(for: themeID) ?? .white
    }

    static func tintColorIfAvailable(for themeID: String) -> UIColor? {
        guard let colorName = descriptors[themeID]?.tintColorName else { return nil }
        return UIColor(named: colorName)
    }
}
