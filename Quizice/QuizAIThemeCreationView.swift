import SwiftUI

struct QuizAIThemeCreationView: View {
    private enum AccessibilityID {
        static let rootView = "aiThemeRootView"
        static let promptEditor = "aiThemePromptEditor"
        static let submitButton = "aiThemeSubmitButton"
    }

    private enum Layout {
        static let contentHorizontalInset: CGFloat = 20
        static let contentTopInset: CGFloat = 48
        static let contentBottomInset: CGFloat = 24
        static let titleRowSpacing: CGFloat = 14
        static let titleBottomSpacing: CGFloat = 18
        static let closeButtonVisualSize: CGFloat = 36
        static let closeButtonHitSize: CGFloat = 44
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
    @State private var submitTask: Task<Void, Never>?

    private let service: AIQuizThemeServiceProtocol
    private let onGenerated: (QuizTheme) -> Void

    init(
        service: AIQuizThemeServiceProtocol = MockAIQuizThemeService(),
        onGenerated: @escaping (QuizTheme) -> Void = { _ in }
    ) {
        self.service = service
        self.onGenerated = onGenerated
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

    private var selectedLocale: Locale {
        AppLocalizationStore.shared.resolvedLocale
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
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                aiThemeBackground
                    .accessibilityIdentifier(AccessibilityID.rootView)

                content
                    .frame(width: geometry.size.width, alignment: .top)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .environment(\.appAppearance, appearance)
        .preferredColorScheme(appearance.swiftUIColorScheme)
        .tint(Color(uiColor: appearance.screenTextColor))
        .ignoresSafeArea(.container, edges: .top)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .alert(L10n.AITheme.errorTitle, isPresented: $isShowingError) {
            Button(L10n.Settings.alertAction, role: .cancel) {}
        } message: {
            Text(L10n.AITheme.errorMessage)
        }
        .onDisappear {
            cancelSubmission()
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
                cancelSubmission()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .frame(width: Layout.closeButtonVisualSize, height: Layout.closeButtonVisualSize)
                    .background(
                        Color(uiColor: appearance.iconButton.backgroundColor),
                        in: RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                            .stroke(Color(uiColor: appearance.iconButton.borderColor), lineWidth: appearance.iconButton.borderWidth)
                    )
                    .frame(minWidth: Layout.closeButtonHitSize, minHeight: Layout.closeButtonHitSize)
            }
            .buttonStyle(QuizPressButtonStyle())
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
                    .frame(height: Layout.editorMinHeight)
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
            startSubmission()
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
        .buttonStyle(QuizPressButtonStyle())
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

    private func startSubmission() {
        let prompt = trimmedPrompt
        guard !prompt.isEmpty else {
            AppLog.quiz.debug("AI quiz submission ignored: empty prompt")
            return
        }
        guard !isSubmitting else {
            AppLog.quiz.debug("AI quiz submission ignored: request already in progress")
            return
        }

        isSubmitting = true
        isShowingError = false
        let locale = selectedLocale
        AppLog.quiz.info(
            "AI quiz submission started: locale=\(locale.identifier, privacy: .public) prompt_length=\(prompt.count, privacy: .public)"
        )
        submitTask = Task {
            await submitTheme(prompt: prompt, locale: locale)
        }
    }

    private func submitTheme(prompt: String, locale: Locale) async {
        defer {
            isSubmitting = false
            submitTask = nil
        }

        do {
            let theme = try await service.generateQuizTheme(for: prompt, locale: locale)
            try Task.checkCancellation()
            AppLog.quiz.debug("AI quiz submission succeeded; handing result to coordinator")
            onGenerated(theme)
        } catch is CancellationError {
            AppLog.quiz.debug("AI quiz submission task cancelled")
            return
        } catch {
            guard !Task.isCancelled else { return }
            let errorType = String(describing: type(of: error))
            AppLog.quiz.error(
                "AI quiz submission failed; showing alert. error_type=\(errorType, privacy: .public)"
            )
            isShowingError = true
        }
    }

    private func cancelSubmission() {
        submitTask?.cancel()
        submitTask = nil
        isSubmitting = false
    }
}

#if DEBUG
#Preview("AI Theme") {
    QuizAIThemeCreationView()
}
#endif
