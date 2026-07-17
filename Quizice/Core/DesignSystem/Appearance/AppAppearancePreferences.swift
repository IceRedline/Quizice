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

