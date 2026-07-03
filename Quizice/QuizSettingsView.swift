import SwiftUI

private enum Layout {
    static let contentHorizontalInset: CGFloat = 20
    static let contentTopInset: CGFloat = 76
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
    static let iconChoicesSpacing: CGFloat = 10
    static let iconChoiceContentSpacing: CGFloat = 8
    static let iconChoiceImageSize: CGFloat = 48
    static let iconChoiceTextMinimumScaleFactor: CGFloat = 0.82
}

private enum Appearance {
    static let backgroundOverlayOpacity: CGFloat = 0.42
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
    private enum SettingsTheme: String, CaseIterable, Identifiable {
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
    }

    private enum AppIcon: String, CaseIterable, Identifiable {
        case classic
        case dark
        case ice

        var id: String { rawValue }

        var title: String {
            switch self {
            case .classic:
                return L10n.Settings.Icon.classic
            case .dark:
                return L10n.Settings.Icon.dark
            case .ice:
                return L10n.Settings.Icon.ice
            }
        }

        var systemImage: String {
            switch self {
            case .classic:
                return "sparkles"
            case .dark:
                return "moon.stars.fill"
            case .ice:
                return "snowflake"
            }
        }
    }

    private enum SettingsAlert: Identifiable {
        case restart(String)
        case profile
        case feedback

        var id: String {
            switch self {
            case let .restart(title):
                return "restart-\(title)"
            case .profile:
                return "profile"
            case .feedback:
                return "feedback"
            }
        }

        var title: String {
            switch self {
            case .restart:
                return L10n.Settings.restartRequiredTitle
            case .profile:
                return L10n.Settings.profile
            case .feedback:
                return L10n.Settings.feedback
            }
        }

        var message: String {
            switch self {
            case let .restart(title):
                return L10n.Settings.restartRequiredMessage(selection: title)
            case .profile:
                return L10n.Settings.profileUnavailableMessage
            case .feedback:
                return L10n.Settings.feedbackUnavailableMessage
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("quizice.settings.theme") private var selectedThemeID = SettingsTheme.system.rawValue
    @AppStorage("quizice.settings.icon") private var selectedIconID = AppIcon.classic.rawValue
    @State private var activeAlert: SettingsAlert?

    private var selectedTheme: SettingsTheme {
        SettingsTheme(rawValue: selectedThemeID) ?? .system
    }

    private var selectedIcon: AppIcon {
        AppIcon(rawValue: selectedIconID) ?? .classic
    }

    var body: some View {
        ZStack {
            Image("backgroundImage")
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color.black
                .opacity(Appearance.backgroundOverlayOpacity)
                .ignoresSafeArea()

            ScrollView {
                content
            }
        }
        .tint(.white)
        .alert(item: $activeAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text(L10n.Settings.alertAction))
            )
        }
    }

    private var content: some View {
        VStack(spacing: Layout.sectionSpacing) {
            settingsTitle
            profileSection
            appearanceSection
            supportSection
        }
        .padding(.horizontal, Layout.contentHorizontalInset)
        .padding(.top, Layout.contentTopInset)
        .padding(.bottom, Layout.contentBottomInset)
    }

    private var settingsTitle: some View {
        HStack(spacing: Layout.titleRowSpacing) {
            Text(L10n.Settings.title)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                dismiss()
            } label: {
                Text(L10n.Settings.done)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Layout.doneButtonHorizontalInset)
                    .padding(.vertical, Layout.doneButtonVerticalInset)
                    .background(
                        Color.white.opacity(Appearance.doneButtonBackgroundOpacity),
                        in: RoundedRectangle(cornerRadius: Appearance.doneButtonCornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Appearance.doneButtonCornerRadius, style: .continuous)
                            .stroke(.white.opacity(Appearance.doneButtonBorderOpacity), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
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
                activeAlert = .profile
            }
        }
    }

    private var appearanceSection: some View {
        SettingsSection(title: L10n.Settings.appearanceSectionTitle) {
            Menu {
                ForEach(SettingsTheme.allCases) { theme in
                    Button(theme.title) {
                        selectedThemeID = theme.rawValue
                        activeAlert = .restart(theme.title)
                    }
                }
            } label: {
                SettingsValueRow(
                    systemImage: "paintpalette.fill",
                    title: L10n.Settings.theme,
                    subtitle: L10n.Settings.themeSubtitle,
                    value: selectedTheme.title
                )
            }
            .buttonStyle(.plain)

            Divider()
                .background(Color.white.opacity(Appearance.dividerOpacity))

            VStack(alignment: .leading, spacing: Layout.rowSpacing) {
                SettingsRowHeader(
                    systemImage: "app.fill",
                    title: L10n.Settings.icon,
                    subtitle: L10n.Settings.iconSubtitle
                )

                HStack(spacing: Layout.iconChoicesSpacing) {
                    ForEach(AppIcon.allCases) { icon in
                        IconChoiceButton(
                            title: icon.title,
                            systemImage: icon.systemImage,
                            isSelected: selectedIcon == icon
                        ) {
                            selectedIconID = icon.rawValue
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
                activeAlert = .feedback
            }
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.white.opacity(Appearance.sectionTitleOpacity))
                .textCase(.uppercase)
                .padding(.horizontal, Layout.sectionTitleHorizontalInset)

            VStack(spacing: Layout.sectionContentSpacing) {
                content
            }
            .padding(Layout.sectionContentPadding)
            .background(
                .white.opacity(Appearance.sectionBackgroundOpacity),
                in: RoundedRectangle(cornerRadius: Appearance.sectionCornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Appearance.sectionCornerRadius, style: .continuous)
                    .stroke(.white.opacity(Appearance.sectionBorderOpacity), lineWidth: 1)
            )
        }
    }
}

private struct SettingsActionRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Layout.rowSpacing) {
                SettingsRowHeader(systemImage: systemImage, title: title, subtitle: subtitle)

                Spacer(minLength: Layout.rowAccessoryMinimumSpacing)

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.white.opacity(Appearance.rowChevronOpacity))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct SettingsValueRow: View {
    let systemImage: String
    let title: String
    let subtitle: String
    let value: String

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            SettingsRowHeader(systemImage: systemImage, title: title, subtitle: subtitle)

            Spacer(minLength: Layout.rowAccessoryMinimumSpacing)

            HStack(spacing: Layout.rowAccessorySpacing) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(Appearance.menuChevronOpacity))
            }
        }
        .contentShape(Rectangle())
    }
}

private struct SettingsRowHeader: View {
    let systemImage: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: Layout.rowSpacing) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: Layout.rowIconSize, height: Layout.rowIconSize)
                .background(
                    Color.white.opacity(Appearance.rowIconBackgroundOpacity),
                    in: RoundedRectangle(cornerRadius: Appearance.rowIconCornerRadius, style: .continuous)
                )

            VStack(alignment: .leading, spacing: Layout.rowTextSpacing) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(Appearance.rowSubtitleOpacity))
                    .lineLimit(2)
            }
        }
    }
}

private struct IconChoiceButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: Layout.iconChoiceContentSpacing) {
                Image(systemName: systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: Layout.iconChoiceImageSize, height: Layout.iconChoiceImageSize)
                    .background(
                        RoundedRectangle(cornerRadius: Appearance.iconChoiceCornerRadius, style: .continuous)
                            .fill(
                                isSelected
                                    ? Color.white.opacity(Appearance.selectedIconChoiceBackgroundOpacity)
                                    : Color.white.opacity(Appearance.defaultIconChoiceBackgroundOpacity)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: Appearance.iconChoiceCornerRadius, style: .continuous)
                            .stroke(
                                isSelected
                                    ? Color.white.opacity(Appearance.selectedIconChoiceBorderOpacity)
                                    : Color.white.opacity(Appearance.defaultIconChoiceBorderOpacity),
                                lineWidth: 1
                            )
                    )

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        .white.opacity(
                            isSelected
                                ? Appearance.selectedIconChoiceTextOpacity
                                : Appearance.defaultIconChoiceTextOpacity
                        )
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(Layout.iconChoiceTextMinimumScaleFactor)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Settings") {
    QuizSettingsView()
}
#endif
