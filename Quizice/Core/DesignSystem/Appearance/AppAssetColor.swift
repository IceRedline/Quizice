import UIKit

// Design-system palette. Each case maps to a named color in
// `Assets.xcassets/QuiziceColors`. Extracted from AppAppearance.swift because
// the palette is stable and grows independently of the theme adapters below
// it, and living in its own file makes it easier to spot missing assets when
// the design system evolves.
enum AppAssetColor: String {
    case black = "themeBlack"
    case white = "themeWhite"
    case gray = "themeGray"
    case classicBackground = "themeClassicBackground"
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
    case aiGradientStart = "themeAIGradientStart"
    case aiGradientEnd = "themeAIGradientEnd"
    case aiAccent = "themeAIAccent"
    case fallbackIndigo = "themeFallbackIndigo"
    case fallbackTeal = "themeFallbackTeal"
    case fallbackOrange = "themeFallbackOrange"
    case fallbackPink = "themeFallbackPink"
    case fallbackGreen = "themeFallbackGreen"
    case fallbackPurple = "themeFallbackPurple"
    case fallbackBlue = "themeFallbackBlue"
    case fallbackRed = "themeFallbackRed"
    case meshSlateBright = "meshSlateBright"
    case meshSlateDark = "meshSlateDark"
    case meshSlateBlue = "meshSlateBlue"
    case meshSlateNearBlack = "meshSlateNearBlack"
    case meshSlateBase = "meshSlateBase"
    case meshSlateMid = "meshSlateMid"
    case meshSlateSoft = "meshSlateSoft"
    case meshSlateMuted = "meshSlateMuted"
    case meshSlateEdge = "meshSlateEdge"

    var uiColor: UIColor {
        guard let color = UIColor(named: rawValue) else {
            preconditionFailure("Missing color asset: \(rawValue)")
        }
        return color
    }
}
