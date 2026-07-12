import SwiftUI

private enum Layout {
    static let contentHorizontalInset: CGFloat = 20
    static let contentTopInset: CGFloat = 28
    static let contentMinimumTopInset: CGFloat = 46
    static let contentBottomInset: CGFloat = 24
    static let titleRowSpacing: CGFloat = 14
    static let titleBottomSpacing: CGFloat = 10
    static let doneButtonHorizontalInset: CGFloat = 16
    static let doneButtonVerticalInset: CGFloat = 9
    static let sectionSpacing: CGFloat = 16
    static let sectionTitleHorizontalInset: CGFloat = 2
    static let sectionContentSpacing: CGFloat = 14
    static let sectionContentPadding: CGFloat = 16
    static let rowSpacing: CGFloat = 12
    static let rowAccessorySpacing: CGFloat = 6
    static let rowAccessoryMinimumSpacing: CGFloat = 12
    static let rowIconSize: CGFloat = 36
    static let rowTextSpacing: CGFloat = 3
    static let rowValueMinimumScaleFactor: CGFloat = 0.72
    static let iconChoicesSpacing: CGFloat = 10
    static let iconChoiceContentSpacing: CGFloat = 8
    static let iconChoiceImageSize: CGFloat = 48
    static let iconChoiceTextMinimumScaleFactor: CGFloat = 0.82
}

private enum Appearance {
    static let doneButtonBackgroundOpacity: CGFloat = 0.16
    static let doneButtonBorderOpacity: CGFloat = 0.22
    static let doneButtonCornerRadius: CGFloat = 20
    static let sectionBackgroundOpacity: CGFloat = 0.12
    static let sectionBorderOpacity: CGFloat = 0.18
    static let sectionCornerRadius: CGFloat = 30
    static let rowIconBackgroundOpacity: CGFloat = 0.14
    static let rowIconCornerRadius: CGFloat = 18
    static let iconChoiceCornerRadius: CGFloat = 20
    static let selectedIconChoiceBackgroundOpacity: CGFloat = 0.24
    static let defaultIconChoiceBackgroundOpacity: CGFloat = 0.12
    static let selectedIconChoiceBorderOpacity: CGFloat = 0.82
    static let defaultIconChoiceBorderOpacity: CGFloat = 0.18
    static let selectedIconChoiceTextOpacity: CGFloat = 1
    static let defaultIconChoiceTextOpacity: CGFloat = 0.72
    static let sectionTitleOpacity: CGFloat = 0.7
    static let rowSubtitleOpacity: CGFloat = 0.64
    static let rowChevronOpacity: CGFloat = 0.56
    static let menuChevronOpacity: CGFloat = 0.7
    static let dividerOpacity: CGFloat = 0.18
}

struct QuizSettingsView: View {
    private enum AppIcon: String, CaseIterable, Identifiable {
        case classic
        case dark
        case ice

        var id: String { rawValue }

        var title: String {
            switch self {
            case .classic: return L10n.Settings.Icon.classic
            case .dark: return L10n.Settings.Icon.dark
            case .ice: return L10n.Settings.Icon.ice
            }
        }

        var systemImage: String {
            switch self {
            case .classic: return "sparkles"
            case .dark: return "moon.stars.fill"
            case .ice: return "snowflake"
            }
        }
    }

    private enum SettingsAlert: Identifiable {
        case restart(String)
        case profile
        case feedback

        var id: String {
            switch self {
            case let .restart(title): return "restart-\(title)"
            case .profile: return "profile"
            case .feedback: return "feedback"
            }
        }

        var title: String {
            switch self {
            case .restart: return L10n.Settings.restartRequiredTitle
            case .profile: return L10n.Settings.profile
            case .feedback: return L10n.Settings.feedback
            }
        }

        var message: String {
            switch self {
            case let .restart(title): return L10n.Settings.restartRequiredMessage(selection: title)
            case .profile: return L10n.Settings.profileUnavailableMessage
            case .feedback: return L10n.Settings.feedbackUnavailableMessage
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppAppearanceStore.Keys.cleanColorScheme) private var selectedThemeID = CleanColorSchemePreference.system.rawValue
    @AppStorage(AppAppearanceStore.Keys.designStyle) private var selectedDesignStyleID = AppDesignStyle.defaultStyle.rawValue
    @AppStorage(AppAppearanceStore.Keys.backgroundStyle) private var selectedBackgroundStyleID = AppBackgroundStyle.defaultStyle.rawValue
    @AppStorage(AppLocalizationStore.Keys.language) private var selectedLanguageID = AppLanguagePreference.system.rawValue
    @AppStorage("quizice.settings.icon") private var selectedIconID = AppIcon.classic.rawValue
#if DEBUG
    @AppStorage(DebugBackendSettings.useLocalhostKey) private var usesLocalhostBackend = false
#endif
    @State private var activeAlert: SettingsAlert?
    @State private var didTrackScreen = false
    private let analytics: AnalyticsTracking

    init(analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared) {
        self.analytics = analytics
    }

    private var selectedTheme: CleanColorSchemePreference {
        CleanColorSchemePreference(rawValue: selectedThemeID) ?? .system
    }

    private var selectedDesignStyle: AppDesignStyle {
        guard
            let style = AppDesignStyle(rawValue: selectedDesignStyleID),
            style.isSelectable
        else { return AppDesignStyle.defaultStyle }
        return style
    }

    private var selectedLanguage: AppLanguagePreference {
        AppLanguagePreference(rawValue: selectedLanguageID) ?? .system
    }

    private var selectedBackgroundStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: selectedBackgroundStyleID) ?? .defaultStyle
    }

    private var selectedIcon: AppIcon {
        AppIcon(rawValue: selectedIconID) ?? .classic
    }

    private var appearance: AppAppearance {
        let traitCollection = UITraitCollection(userInterfaceStyle: selectedTheme.traitUserInterfaceStyle(fallback: colorScheme))
        return AppAppearance(
            designStyle: selectedDesignStyle,
            cleanColorSchemePreference: selectedTheme,
            backgroundStyle: selectedBackgroundStyle,
            traitCollection: traitCollection
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                settingsBackground

                ScrollView {
                    content(topInset: max(Layout.contentMinimumTopInset, geometry.safeAreaInsets.top + Layout.contentTopInset))
                }
            }
        }
        .environment(\.appAppearance, appearance)
        .preferredColorScheme(appearance.swiftUIColorScheme)
        .tint(Color(uiColor: appearance.screenTextColor))
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(L10n.Settings.alertAction))
            )
        }
        .onAppear {
            guard !didTrackScreen else { return }
            didTrackScreen = true
            analytics.track(.screenView(screen: .settings))
        }
    }

    @ViewBuilder
    private var settingsBackground: some View {
        if appearance.designStyle == .classic {
            AppBackgroundView(
                appearance: appearance,
                motionProfile: .edgeAware
            )
        } else {
            Color(uiColor: appearance.backgroundColor)
                .ignoresSafeArea()
        }
    }

    private func content(topInset: CGFloat) -> some View {
        VStack(spacing: Layout.sectionSpacing) {
            settingsTitle
            profileSection
            appearanceSection
#if DEBUG
            developerSection
#endif
            supportSection
        }
        .padding(.horizontal, Layout.contentHorizontalInset)
        .padding(.top, topInset)
        .padding(.bottom, Layout.contentBottomInset)
    }

    private var settingsTitle: some View {
        HStack(spacing: Layout.titleRowSpacing) {
            Text(L10n.Settings.title)
                .font(appearance.typography.swiftUIFont(size: 38, weight: .bold))
                .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                dismiss()
            } label: {
                Text(L10n.Settings.done)
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .padding(.horizontal, Layout.doneButtonHorizontalInset)
                    .padding(.vertical, Layout.doneButtonVerticalInset)
                    .background(
                        Color(uiColor: appearance.iconButton.backgroundColor),
                        in: RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                            .stroke(Color(uiColor: appearance.iconButton.borderColor), lineWidth: appearance.iconButton.borderWidth)
                    )
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(QuizPressButtonStyle())
        }
            .padding(.bottom, Layout.titleBottomSpacing)
    }

    private var profileSection: some View {
        SettingsSection(title: L10n.Settings.profileSectionTitle) {
            SettingsActionRow(
                systemImage: "person.crop.circle.fill",
                title: L10n.Settings.profile,
                subtitle: L10n.Settings.profileSubtitle
            ) {
                analytics.track(.settingsAction(.profile))
                activeAlert = .profile
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: L10n.Settings.appearanceSectionTitle) {
            Menu {
                ForEach(AppDesignStyle.settingsOrder) { designStyle in
                    Button(designStyle.title) {
                        let oldValue = selectedDesignStyleID
                        selectedDesignStyleID = designStyle.rawValue
                        AppAppearanceStore.shared.notifyChange()
                        trackSettingChange(setting: .design, oldValue: oldValue, newValue: designStyle.rawValue)
                    }
                    .disabled(!designStyle.isSelectable)
                }
            } label: {
                SettingsValueRow(
                    systemImage: "paintpalette.fill",
                    title: L10n.Settings.design,
                    subtitle: L10n.Settings.designSubtitle,
                    value: selectedDesignStyle.title
                )
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color(uiColor: appearance.card.borderColor))

            Menu {
                ForEach(AppLanguagePreference.allCases) { language in
                    Button(language.title) {
                        let oldValue = selectedLanguageID
                        AppLocalizationStore.shared.languagePreference = language
                        trackSettingChange(setting: .language, oldValue: oldValue, newValue: language.rawValue)
                    }
                }
            } label: {
                SettingsValueRow(
                    systemImage: "globe",
                    title: L10n.Settings.language,
                    subtitle: L10n.Settings.languageSubtitle,
                    value: selectedLanguage.title
                )
            }
            .buttonStyle(.plain)

            if selectedDesignStyle == .clean {
                Divider()
                    .background(Color(uiColor: appearance.card.borderColor))

                Menu {
                    ForEach(CleanColorSchemePreference.allCases) { theme in
                        Button(theme.title) {
                            let oldValue = selectedThemeID
                            selectedThemeID = theme.rawValue
                            AppAppearanceStore.shared.notifyChange()
                            trackSettingChange(setting: .theme, oldValue: oldValue, newValue: theme.rawValue)
                        }
                    }
                } label: {
                    SettingsValueRow(
                        systemImage: "circle.lefthalf.filled",
                        title: L10n.Settings.cleanThemeMode,
                        subtitle: L10n.Settings.cleanThemeModeSubtitle,
                        value: selectedTheme.title
                    )
                }
                .buttonStyle(.plain)
            }

            Divider()
                .background(Color(uiColor: appearance.card.borderColor))

            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                SettingsRowHeader(
                    systemImage: "app.fill",
                    title: L10n.Settings.icon,
                    subtitle: L10n.Settings.iconSubtitle
                )

                HStack(spacing: Layout.iconChoicesSpacing) {
                    ForEach(AppIcon.allCases) { icon in
                        let isEnabled = icon == .classic && selectedIcon != icon
                        IconChoiceButton(
                            title: icon.title,
                            systemImage: icon.systemImage,
                            isSelected: selectedIcon == icon,
                            isEnabled: isEnabled
                        ) {
                            let oldValue = selectedIconID
                            selectedIconID = icon.rawValue
                            trackSettingChange(setting: .icon, oldValue: oldValue, newValue: icon.rawValue)
                            activeAlert = .restart(icon.title)
                        }
                    }
                }
            }
        }
    }

    private var supportSection: some View {
        SettingsSection(title: L10n.Settings.supportSectionTitle) {
            SettingsActionRow(
                systemImage: "star.bubble.fill",
                title: L10n.Settings.feedback,
                subtitle: L10n.Settings.feedbackSubtitle
            ) {
                analytics.track(.settingsAction(.feedback))
                activeAlert = .feedback
            }
        }
    }

#if DEBUG
    private var developerSection: some View {
        SettingsSection(title: L10n.Settings.developerSectionTitle) {
            Toggle(isOn: $usesLocalhostBackend) {
                SettingsRowHeader(
                    systemImage: "server.rack",
                    title: L10n.Settings.localhostBackend,
                    subtitle: L10n.Settings.localhostBackendSubtitle
                )
            }
            .onChange(of: usesLocalhostBackend) { _, _ in
                activeAlert = .restart(L10n.Settings.localhostBackend)
            }
        }
    }
#endif

    private func trackSettingChange(setting: AnalyticsSetting, oldValue: String, newValue: String) {
        guard oldValue != newValue else { return }
        analytics.track(.settingChanged(setting: setting, oldValue: oldValue, newValue: newValue))
    }
}

private struct SettingsSection<Content: View>: View {
    @Environment(\.appAppearance) private var appearance

    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(title)
                .font(appearance.typography.swiftUIFont(size: 13, weight: .semibold))
                .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                .textCase(.uppercase)
                .padding(.horizontal, Layout.sectionTitleHorizontalInset)

            VStack(spacing: Layout.sectionContentSpacing) {
                content
            }
            .padding(Layout.sectionContentPadding)
            .background(
                Color(uiColor: appearance.card.backgroundColor),
                in: RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
                    .stroke(Color(uiColor: appearance.card.borderColor), lineWidth: appearance.card.borderWidth)
            )
        }
    }
}

private struct SettingsActionRow: View {
    @Environment(\.appAppearance) private var appearance

    let systemImage: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.rowSpacing) {
                SettingsRowHeader(systemImage: systemImage, title: title, subtitle: subtitle)
                    .layoutPriority(1)

                Spacer(minLength: Layout.rowAccessoryMinimumSpacing)

                Image(systemName: "chevron.right")
                    .font(appearance.typography.swiftUIFont(size: 13, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(QuizPressButtonStyle())
    }
}

private struct SettingsValueRow: View {
    @Environment(\.appAppearance) private var appearance

    let systemImage: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            SettingsRowHeader(systemImage: systemImage, title: title, subtitle: subtitle)
                .layoutPriority(1)

            Spacer(minLength: Layout.rowAccessoryMinimumSpacing)

            HStack(spacing: Layout.rowAccessorySpacing) {
                Text(value)
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
                    .multilineTextAlignment(.trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.rowValueMinimumScaleFactor)
                    .allowsTightening(true)
                    .layoutPriority(1)

                Image(systemName: "chevron.down")
                    .font(appearance.typography.swiftUIFont(size: 12, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
            }
            .layoutPriority(1)
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsRowHeader: View {
    @Environment(\.appAppearance) private var appearance

    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: systemImage)
                .font(appearance.typography.swiftUIFont(size: 20, weight: .semibold))
                .foregroundStyle(Color(uiColor: settingsIconColor))
                .frame(width: Layout.rowIconSize, height: Layout.rowIconSize)
                .background(
                    Color(uiColor: appearance.row.backgroundColor),
                    in: RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: Layout.rowTextSpacing) {
                Text(title)
                    .font(appearance.typography.swiftUIFont(size: 17, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))

                Text(subtitle)
                    .font(appearance.typography.swiftUIFont(size: 13, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var settingsIconColor: UIColor {
        appearance.designStyle == .classic ? .white : appearance.accentColor
    }
}

private struct IconChoiceButton: View {
    @Environment(\.appAppearance) private var appearance

    let title: String
    let systemImage: String
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Layout.iconChoiceContentSpacing) {
                Image(systemName: systemImage)
                    .font(appearance.typography.swiftUIFont(size: 22, weight: .semibold))
                    .foregroundStyle(Color(uiColor: settingsIconColor))
                    .frame(width: Layout.iconChoiceImageSize, height: Layout.iconChoiceImageSize)
                    .background(
                        RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                            .fill(
                                isSelected
                                    ? Color(uiColor: appearance.accentColor).opacity(0.22)
                                    : Color(uiColor: appearance.row.backgroundColor)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color(uiColor: appearance.accentColor)
                                    : Color(uiColor: appearance.row.borderColor),
                                lineWidth: appearance.row.borderWidth
                            )
                    )

                Text(title)
                    .font(appearance.typography.swiftUIFont(size: 12, weight: .semibold))
                    .foregroundStyle(
                        Color(uiColor: isSelected ? appearance.surfaceTextColor : appearance.secondarySurfaceTextColor)
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.iconChoiceTextMinimumScaleFactor)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : 0.38)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var settingsIconColor: UIColor {
        appearance.designStyle == .classic ? .white : appearance.accentColor
    }
}

private extension CleanColorSchemePreference {
    func traitUserInterfaceStyle(fallback colorScheme: ColorScheme) -> UIUserInterfaceStyle {
        switch self {
        case .system:
            return colorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

#if DEBUG
#Preview("Settings") {
    QuizSettingsView()
}
#endif
