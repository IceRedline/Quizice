import SwiftUI
import UIKit

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
