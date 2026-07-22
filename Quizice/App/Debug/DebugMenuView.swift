#if DEBUG
import PulseUI
import SwiftUI

@MainActor
final class DebugMenuViewModel: ObservableObject {
    @Published private(set) var isInterfaceHidden: Bool
    @Published private(set) var usesLocalhostBackend: Bool
    @Published private(set) var usesLocalContentOnly: Bool
    @Published private(set) var usesDirectAI: Bool
    @Published private(set) var backgroundStyle: AppBackgroundStyle

    let showsBackgroundStyles: Bool

    private let toggleInterfaceVisibilityAction: () -> Void
    private let toggleLocalhostBackendAction: () -> Void
    private let toggleLocalContentOnlyAction: () -> Void
    private let toggleDirectAIAction: () -> Void
    private let selectBackgroundStyleAction: (AppBackgroundStyle) -> Void
    private let defaults: UserDefaults

    init(
        isInterfaceHidden: Bool,
        appearance: AppAppearance,
        defaults: UserDefaults = .standard,
        toggleInterfaceVisibility: @escaping () -> Void,
        toggleLocalhostBackend: @escaping () -> Void,
        toggleLocalContentOnly: @escaping () -> Void,
        toggleDirectAI: @escaping () -> Void,
        selectBackgroundStyle: @escaping (AppBackgroundStyle) -> Void
    ) {
        self.isInterfaceHidden = isInterfaceHidden
        self.usesLocalhostBackend = defaults.bool(forKey: DebugBackendSettings.useLocalhostKey)
        self.usesLocalContentOnly = defaults.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey)
        self.usesDirectAI = defaults.bool(forKey: DebugAIRuntimeSettings.useDirectAIKey)
        self.backgroundStyle = appearance.backgroundStyle
        self.showsBackgroundStyles = appearance.designStyle == .classic
        self.defaults = defaults
        self.toggleInterfaceVisibilityAction = toggleInterfaceVisibility
        self.toggleLocalhostBackendAction = toggleLocalhostBackend
        self.toggleLocalContentOnlyAction = toggleLocalContentOnly
        self.toggleDirectAIAction = toggleDirectAI
        self.selectBackgroundStyleAction = selectBackgroundStyle
    }

    func toggleInterfaceVisibility() {
        toggleInterfaceVisibilityAction()
        isInterfaceHidden.toggle()
    }

    func toggleLocalhostBackend() {
        toggleLocalhostBackendAction()
        refreshRuntimeSettings()
    }

    func toggleLocalContentOnly() {
        toggleLocalContentOnlyAction()
        refreshRuntimeSettings()
    }

    func toggleDirectAI() {
        toggleDirectAIAction()
        refreshRuntimeSettings()
    }

    func selectBackgroundStyle(_ style: AppBackgroundStyle) {
        selectBackgroundStyleAction(style)
        backgroundStyle = style
    }

    private func refreshRuntimeSettings() {
        usesLocalhostBackend = defaults.bool(forKey: DebugBackendSettings.useLocalhostKey)
        usesLocalContentOnly = defaults.bool(forKey: DebugBackendSettings.useLocalContentOnlyKey)
        usesDirectAI = defaults.bool(forKey: DebugAIRuntimeSettings.useDirectAIKey)
    }
}

struct DebugMenuView: View {
    enum AccessibilityID {
        static let root = "debugMenuRoot"
        static let interfaceToggle = "debugMenuInterfaceToggle"
        static let localhostToggle = "debugMenuLocalhostToggle"
        static let localContentToggle = "debugMenuLocalContentToggle"
        static let directAIToggle = "debugMenuDirectAIToggle"
        static let pulse = "debugMenuPulse"
        static let backgroundStyle = "debugMenuBackgroundStyle"
    }

    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DebugMenuViewModel

    var body: some View {
        NavigationStack {
            List {
                interfaceSection
                backendSection
                toolsSection
                if viewModel.showsBackgroundStyles {
                    backgroundSection
                }
            }
            .accessibilityIdentifier(AccessibilityID.root)
            .navigationTitle(L10n.DebugMenu.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.Settings.done) {
                        dismiss()
                    }
                }
            }
        }
        .tint(.blue)
        .preferredColorScheme(.dark)
    }

    private var interfaceSection: some View {
        Section(L10n.DebugMenu.interfaceSectionTitle) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.isInterfaceHidden },
                    set: { _ in viewModel.toggleInterfaceVisibility() }
                )
            ) {
                DebugMenuRowLabel(
                    title: L10n.DebugMenu.hideInterface,
                    subtitle: L10n.DebugMenu.hideInterfaceSubtitle,
                    systemImage: "eye.slash.fill",
                    color: .orange
                )
            }
            .accessibilityIdentifier(AccessibilityID.interfaceToggle)
        }
    }

    private var backendSection: some View {
        Section(L10n.DebugMenu.backendSectionTitle) {
            Toggle(
                isOn: Binding(
                    get: { viewModel.usesLocalhostBackend },
                    set: { _ in viewModel.toggleLocalhostBackend() }
                )
            ) {
                DebugMenuRowLabel(
                    title: L10n.Settings.localhostBackend,
                    subtitle: L10n.Settings.localhostBackendSubtitle,
                    systemImage: "server.rack",
                    color: .blue
                )
            }
            .accessibilityIdentifier(AccessibilityID.localhostToggle)

            Toggle(
                isOn: Binding(
                    get: { viewModel.usesLocalContentOnly },
                    set: { _ in viewModel.toggleLocalContentOnly() }
                )
            ) {
                DebugMenuRowLabel(
                    title: L10n.Settings.localContentOnly,
                    subtitle: L10n.Settings.localContentOnlySubtitle,
                    systemImage: "externaldrive.fill",
                    color: .indigo
                )
            }
            .accessibilityIdentifier(AccessibilityID.localContentToggle)

            Toggle(
                isOn: Binding(
                    get: { viewModel.usesDirectAI },
                    set: { _ in viewModel.toggleDirectAI() }
                )
            ) {
                DebugMenuRowLabel(
                    title: L10n.Settings.directAI,
                    subtitle: L10n.Settings.directAISubtitle,
                    systemImage: "key.fill",
                    color: .yellow
                )
            }
            .accessibilityIdentifier(AccessibilityID.directAIToggle)
        }
    }

    private var toolsSection: some View {
        Section(L10n.DebugMenu.toolsSectionTitle) {
            NavigationLink {
                DebugPulseConsoleView()
            } label: {
                DebugMenuRowLabel(
                    title: L10n.DebugMenu.pulse,
                    subtitle: L10n.DebugMenu.pulseSubtitle,
                    systemImage: "waveform.path.ecg",
                    color: .red
                )
            }
            .accessibilityIdentifier(AccessibilityID.pulse)
        }
    }

    private var backgroundSection: some View {
        Section(L10n.Home.backgroundStyleSwitcher) {
            ForEach(AppBackgroundStyle.allCases) { style in
                Button {
                    viewModel.selectBackgroundStyle(style)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: style.systemImageName)
                            .frame(width: 28)
                        Text(style.title)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.backgroundStyle == style {
                            Image(systemName: "checkmark")
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier(AccessibilityID.backgroundStyle)
    }
}

private struct DebugMenuRowLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28)
        }
    }
}

private struct DebugPulseConsoleView: View {
    var body: some View {
        ConsoleView(mode: .network)
            .closeButtonHidden()
            .navigationBarTitleDisplayMode(.inline)
    }
}
#endif
