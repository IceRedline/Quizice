import SwiftUI

struct QuizAIThemeCreationView: View {
    private enum AccessibilityID {
        static let rootView = "aiThemeRootView"
        static let promptEditor = "aiThemePromptEditor"
        static let submitButton = "aiThemeSubmitButton"
    }

    private enum Layout {
        static let contentHorizontalInset: CGFloat = 20
        static let contentTopInset: CGFloat = 76
        static let contentBottomInset: CGFloat = 24
        static let titleRowSpacing: CGFloat = 14
        static let titleBottomSpacing: CGFloat = 18
        static let closeButtonSize: CGFloat = 40
        static let cardSpacing: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let editorMinHeight: CGFloat = 150
        static let editorPadding: CGFloat = 12
        static let buttonHeight: CGFloat = 54
        static let buttonContentSpacing: CGFloat = 10
    }

    private enum Appearance {
        static let backgroundOverlayOpacity: CGFloat = 0.42
        static let disabledOpacity: CGFloat = 0.52
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppAppearanceStore.Keys.cleanColorScheme) private var selectedThemeID = CleanColorSchemePreference.system.rawValue
    @AppStorage(AppAppearanceStore.Keys.designStyle) private var selectedDesignStyleID = AppDesignStyle.defaultStyle.rawValue
    @State private var prompt = ""
    @State private var isSubmitting = false
    @State private var isShowingError = false

    private let service: AIQuizThemeServiceProtocol

    init(service: AIQuizThemeServiceProtocol = MockAIQuizThemeService()) {
        self.service = service
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

    private var appearance: AppAppearance {
        let traitCollection = UITraitCollection(userInterfaceStyle: traitUserInterfaceStyle(for: selectedTheme))
        return AppAppearance(
            designStyle: selectedDesignStyle,
            cleanColorSchemePreference: selectedTheme,
            traitCollection: traitCollection
        )
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedPrompt.isEmpty && !isSubmitting
    }

    private func traitUserInterfaceStyle(for selectedTheme: CleanColorSchemePreference) -> UIUserInterfaceStyle {
        switch selectedTheme {
        case .system:
            return colorScheme == .dark ? .dark : .light
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var body: some View {
        ZStack {
            aiThemeBackground

            ScrollView {
                content
            }
        }
        .accessibilityIdentifier(AccessibilityID.rootView)
        .environment(\.appAppearance, appearance)
        .preferredColorScheme(appearance.swiftUIColorScheme)
        .tint(Color(uiColor: appearance.screenTextColor))
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(L10n.AITheme.errorTitle, isPresented: $isShowingError) {
            Button(L10n.Settings.alertAction, role: .cancel) {}
        } message: {
            Text(L10n.AITheme.errorMessage)
        }
    }

    @ViewBuilder
    private var aiThemeBackground: some View {
        if let imageName = appearance.backgroundImageName {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()

            Color(uiColor: appearance.overlayColor)
                .opacity(Appearance.backgroundOverlayOpacity)
                .ignoresSafeArea()
        } else {
            Color(uiColor: appearance.backgroundColor)
                .ignoresSafeArea()
        }
    }

    private var content: some View {
        VStack(spacing: Layout.titleBottomSpacing) {
            titleRow
            promptCard
            submitButton
        }
        .padding(.horizontal, Layout.contentHorizontalInset)
        .padding(.top, Layout.contentTopInset)
        .padding(.bottom, Layout.contentBottomInset)
    }

    private var titleRow: some View {
        HStack(spacing: Layout.titleRowSpacing) {
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.AITheme.title)
                    .font(appearance.typography.swiftUIFont(size: 34, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(L10n.AITheme.subtitle)
                    .font(appearance.typography.swiftUIFont(size: 16, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .frame(width: Layout.closeButtonSize, height: Layout.closeButtonSize)
                    .background(
                        Color(uiColor: appearance.iconButton.backgroundColor),
                        in: RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                            .stroke(Color(uiColor: appearance.iconButton.borderColor), lineWidth: appearance.iconButton.borderWidth)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Settings.close)
        }
    }

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
                    .scrollContentBackground(.hidden)
                    .padding(Layout.editorPadding)
                    .frame(minHeight: Layout.editorMinHeight)
                    .background(
                        Color(uiColor: appearance.row.backgroundColor),
                        in: RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                            .stroke(Color(uiColor: appearance.row.borderColor), lineWidth: appearance.row.borderWidth)
                    )
                    .accessibilityIdentifier(AccessibilityID.promptEditor)

                if prompt.isEmpty {
                    Text(L10n.AITheme.promptPlaceholder)
                        .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                        .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                        .padding(.horizontal, Layout.editorPadding + 5)
                        .padding(.vertical, Layout.editorPadding + 8)
                        .allowsHitTesting(false)
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(
            Color(uiColor: appearance.card.backgroundColor),
            in: RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
                .stroke(Color(uiColor: appearance.card.borderColor), lineWidth: appearance.card.borderWidth)
        )
    }

    private var submitButton: some View {
        Button {
            Task {
                await submitTheme()
            }
        } label: {
            HStack(spacing: Layout.buttonContentSpacing) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(L10n.AITheme.submit)
                    .font(appearance.typography.swiftUIFont(size: 19, weight: .semibold))
            }
            .foregroundStyle(Color(uiColor: submitButtonTextColor))
            .frame(maxWidth: .infinity, minHeight: Layout.buttonHeight)
            .background(
                Color(uiColor: submitButtonBackgroundColor),
                in: RoundedRectangle(cornerRadius: appearance.primaryButton.cornerRadius, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: appearance.primaryButton.cornerRadius, style: .continuous)
                    .stroke(Color(uiColor: submitButtonBorderColor), lineWidth: appearance.primaryButton.borderWidth)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit)
        .opacity(canSubmit ? 1 : Appearance.disabledOpacity)
        .accessibilityIdentifier(AccessibilityID.submitButton)
    }

    private var submitButtonBackgroundColor: UIColor {
        canSubmit ? appearance.primaryButton.backgroundColor : appearance.row.backgroundColor
    }

    private var submitButtonBorderColor: UIColor {
        canSubmit ? appearance.primaryButton.borderColor : appearance.row.borderColor
    }

    private var submitButtonTextColor: UIColor {
        if canSubmit {
            return appearance.designStyle == .pixel ? .black : appearance.screenTextColor
        }
        return appearance.disabledTextColor
    }

    private func submitTheme() async {
        let prompt = trimmedPrompt
        guard !prompt.isEmpty else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        do {
            _ = try await service.generateQuizTheme(for: prompt)
            dismiss()
        } catch {
            isShowingError = true
        }
    }
}

#if DEBUG
#Preview("AI Theme") {
    QuizAIThemeCreationView()
}
#endif
