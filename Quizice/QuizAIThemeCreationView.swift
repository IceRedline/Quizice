import SwiftUI

struct AIThemeKeyboardStyle {
    let interfaceStyle: UIUserInterfaceStyle
    let doneButtonTintColor: UIColor

    init(appearance: AppAppearance) {
        interfaceStyle = appearance.resolvedInterfaceStyle
        switch appearance.designStyle {
        case .clean, .radar:
            doneButtonTintColor = appearance.accentColor
        case .classic:
            doneButtonTintColor = .systemBlue
        }
    }
}

struct AIQuizGenerationAlert: Identifiable, Equatable {
    enum Kind: String {
        case refusal
        case network
        case service
        case invalidQuiz
        case unavailable
    }

    let kind: Kind

    var id: String { kind.rawValue }

    var title: String {
        switch kind {
        case .refusal: return L10n.AITheme.Error.Refusal.title
        case .network: return L10n.AITheme.Error.Network.title
        case .service: return L10n.AITheme.Error.Service.title
        case .invalidQuiz: return L10n.AITheme.Error.InvalidQuiz.title
        case .unavailable: return L10n.AITheme.Error.Unavailable.title
        }
    }

    var message: String {
        switch kind {
        case .refusal: return L10n.AITheme.Error.Refusal.message
        case .network: return L10n.AITheme.Error.Network.message
        case .service: return L10n.AITheme.Error.Service.message
        case .invalidQuiz: return L10n.AITheme.Error.InvalidQuiz.message
        case .unavailable: return L10n.AITheme.Error.Unavailable.message
        }
    }

    var canRetry: Bool {
        switch kind {
        case .network, .service, .invalidQuiz: return true
        case .refusal, .unavailable: return false
        }
    }

    var shouldFocusPromptOnDismiss: Bool {
        kind == .refusal || kind == .invalidQuiz
    }

    init(error: Error) {
        guard let serviceError = error as? YandexAIQuizThemeServiceError else {
            kind = .unavailable
            return
        }

        switch serviceError {
        case .refused:
            kind = .refusal
        case let .network(code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                kind = .network
            default:
                kind = .service
            }
        case let .httpStatus(statusCode) where statusCode == 429 || statusCode >= 500:
            kind = .service
        case .generationStatus:
            kind = .service
        case .invalidResponseJSON, .missingOutputText, .invalidQuizJSON, .invalidContract:
            kind = .invalidQuiz
        case .unavailableInRelease, .missingAPIKey, .emptyPrompt, .requestEncodingFailed,
             .invalidHTTPResponse, .httpStatus:
            kind = .unavailable
        }
    }
}

struct QuizAIThemeCreationView: View {
    private enum AccessibilityID {
        static let rootView = "aiThemeRootView"
        static let promptEditor = "aiThemePromptEditor"
        static let questionCountSelector = "aiThemeQuestionCountSelector"
        static let difficultySelector = "aiThemeDifficultySelector"
        static let submitButton = "aiThemeSubmitButton"
        static let keyboardDoneButton = "aiThemeKeyboardDoneButton"
        static let progressStatus = "aiThemeProgressStatus"
    }

    private enum Layout {
        static let contentHorizontalInset: CGFloat = 20
        static let contentTopInset: CGFloat = 24
        static let contentMinimumTopInset: CGFloat = 48
        static let contentBottomInset: CGFloat = 24
        static let titleRowSpacing: CGFloat = 14
        static let titleBottomSpacing: CGFloat = 18
        static let closeButtonVisualSize: CGFloat = 36
        static let closeButtonHitSize: CGFloat = 44
        static let cardSpacing: CGFloat = 16
        static let cardPadding: CGFloat = 16
        static let editorMinHeight: CGFloat = 118
        static let editorPadding: CGFloat = 12
        static let selectorSpacing: CGFloat = 8
        static let selectorHeight: CGFloat = 44
        static let buttonHeight: CGFloat = 54
        static let buttonContentSpacing: CGFloat = 10
        static let progressMinimumHeight: CGFloat = 24
    }

    private enum Appearance {
        static let disabledOpacity: CGFloat = 0.52
        static let unselectedOptionOpacity: CGFloat = 0.78
    }

    private enum GenerationPhase: Int, CaseIterable {
        case analyzing
        case sending
        case generating
        case almostReady

        var title: String {
            switch self {
            case .analyzing: return L10n.AITheme.Progress.analyzing
            case .sending: return L10n.AITheme.Progress.sending
            case .generating: return L10n.AITheme.Progress.generating
            case .almostReady: return L10n.AITheme.Progress.almostReady
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(AppAppearanceStore.Keys.cleanColorScheme) private var selectedThemeID = CleanColorSchemePreference.system.rawValue
    @AppStorage(AppAppearanceStore.Keys.designStyle) private var selectedDesignStyleID = AppDesignStyle.defaultStyle.rawValue
    @AppStorage(AppAppearanceStore.Keys.backgroundStyle) private var selectedBackgroundStyleID = AppBackgroundStyle.defaultStyle.rawValue
    @State private var prompt = ""
    @State private var selectedQuestionCount = AIQuizGenerationConfiguration.supportedQuestionCounts[0]
    @State private var selectedDifficulty = AIQuizDifficulty.medium
    @State private var isSubmitting = false
    @State private var activeAlert: AIQuizGenerationAlert?
    @State private var generationPhase: GenerationPhase?
    @State private var submitTask: Task<Void, Never>?
    @State private var progressTask: Task<Void, Never>?
    @State private var submissionStartedAt: Date?
    @State private var submissionLocaleIdentifier: String?
    @State private var didTrackScreen = false
    @FocusState private var isPromptFocused: Bool

    private let service: AIQuizThemeServiceProtocol
    private let analytics: AnalyticsTracking
    private let now: () -> Date
    private let onGenerated: (QuizTheme) -> Void

    init(
        service: AIQuizThemeServiceProtocol = MockAIQuizThemeService(),
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        now: @escaping () -> Date = Date.init,
        onGenerated: @escaping (QuizTheme) -> Void = { _ in }
    ) {
        self.service = service
        self.analytics = analytics
        self.now = now
        self.onGenerated = onGenerated
    }

    private var selectedTheme: CleanColorSchemePreference {
        CleanColorSchemePreference(rawValue: selectedThemeID) ?? .system
    }

    private var selectedDesignStyle: AppDesignStyle {
        guard let style = AppDesignStyle(rawValue: selectedDesignStyleID), style.isSelectable else {
            return AppDesignStyle.defaultStyle
        }
        return style
    }

    private var selectedBackgroundStyle: AppBackgroundStyle {
        AppBackgroundStyle(rawValue: selectedBackgroundStyleID) ?? .defaultStyle
    }

    private var appearance: AppAppearance {
        let traitCollection = UITraitCollection(userInterfaceStyle: traitUserInterfaceStyle(for: selectedTheme))
        return AppAppearance(
            designStyle: selectedDesignStyle,
            cleanColorSchemePreference: selectedTheme,
            backgroundStyle: selectedBackgroundStyle,
            traitCollection: traitCollection
        )
    }

    private var trimmedPrompt: String {
        prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var keyboardStyle: AIThemeKeyboardStyle {
        AIThemeKeyboardStyle(appearance: appearance)
    }

    private var selectedLocale: Locale {
        AppLocalizationStore.shared.resolvedLocale
    }

    private var canSubmit: Bool {
        !trimmedPrompt.isEmpty && !isSubmitting
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .top) {
                aiThemeBackground

                ScrollView {
                    content
                        .padding(
                            .top,
                            max(Layout.contentMinimumTopInset, geometry.safeAreaInsets.top + Layout.contentTopInset)
                        )
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
            .accessibilityIdentifier(AccessibilityID.rootView)
        }
        .environment(\.appAppearance, appearance)
        .preferredColorScheme(appearance.swiftUIColorScheme)
        .tint(Color(uiColor: appearance.screenTextColor))
        .ignoresSafeArea(.container, edges: .top)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button(L10n.Settings.done) {
                    isPromptFocused = false
                }
                .tint(Color(uiColor: keyboardStyle.doneButtonTintColor))
                .accessibilityIdentifier(AccessibilityID.keyboardDoneButton)
            }
        }
        .alert(item: $activeAlert, content: makeAlert)
        .onDisappear { cancelSubmission() }
        .onAppear {
            guard !didTrackScreen else { return }
            didTrackScreen = true
            analytics.track(.screenView(screen: .aiThemeCreation))
        }
    }

    @ViewBuilder
    private var aiThemeBackground: some View {
        if appearance.designStyle == .classic {
            AppBackgroundView(appearance: appearance)
        } else {
            Color(uiColor: appearance.backgroundColor)
                .ignoresSafeArea()
        }
    }

    private var content: some View {
        VStack(spacing: Layout.titleBottomSpacing) {
            titleRow
            promptCard
            configurationCard
            submitButton
            progressStatus
        }
        .padding(.horizontal, Layout.contentHorizontalInset)
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
        ZStack(alignment: .topLeading) {
            TextEditor(text: $prompt)
                .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
                .scrollContentBackground(.hidden)
                .padding(Layout.editorPadding)
                .frame(minHeight: Layout.editorMinHeight)
                .focused($isPromptFocused)
                .disabled(isSubmitting)
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
        .padding(Layout.cardPadding)
        .background(cardBackground)
        .overlay(cardBorder)
        .opacity(isSubmitting ? Appearance.disabledOpacity : 1)
    }

    private var configurationCard: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
            VStack(alignment: .leading, spacing: Layout.selectorSpacing) {
                selectorTitle(L10n.AITheme.questionCount)
                questionCountSelector
                    .accessibilityIdentifier(AccessibilityID.questionCountSelector)
            }

            VStack(alignment: .leading, spacing: Layout.selectorSpacing) {
                selectorTitle(L10n.AITheme.difficulty)
                difficultySelector
                    .accessibilityIdentifier(AccessibilityID.difficultySelector)
            }
        }
        .padding(Layout.cardPadding)
        .background(cardBackground)
        .overlay(cardBorder)
        .disabled(isSubmitting)
        .opacity(isSubmitting ? Appearance.disabledOpacity : 1)
    }

    private func selectorTitle(_ title: String) -> some View {
        Text(title)
            .font(appearance.typography.swiftUIFont(size: 16, weight: .semibold))
            .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
    }

    private var questionCountSelector: some View {
        HStack(spacing: Layout.selectorSpacing) {
            ForEach(AIQuizGenerationConfiguration.supportedQuestionCounts, id: \.self) { count in
                optionButton(title: String(count), isSelected: selectedQuestionCount == count) {
                    selectedQuestionCount = count
                }
                .accessibilityLabel(L10n.AITheme.questionCountAccessibility(count: count))
            }
        }
    }

    private var difficultySelector: some View {
        HStack(spacing: Layout.selectorSpacing) {
            ForEach(AIQuizDifficulty.allCases) { difficulty in
                optionButton(title: difficulty.title, isSelected: selectedDifficulty == difficulty) {
                    selectedDifficulty = difficulty
                }
            }
        }
    }

    private func optionButton(
        title: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(appearance.typography.swiftUIFont(size: 15, weight: .semibold))
                .foregroundStyle(
                    Color(uiColor: isSelected ? appearance.accentForegroundColor : appearance.surfaceTextColor)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: Layout.selectorHeight)
                .background(
                    Color(uiColor: isSelected ? appearance.primaryButton.backgroundColor : appearance.row.backgroundColor),
                    in: RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: appearance.row.cornerRadius, style: .continuous)
                        .stroke(
                            Color(uiColor: isSelected ? appearance.primaryButton.borderColor : appearance.row.borderColor),
                            lineWidth: isSelected ? appearance.primaryButton.borderWidth : appearance.row.borderWidth
                        )
                )
                .opacity(isSelected ? 1 : Appearance.unselectedOptionOpacity)
        }
        .buttonStyle(QuizPressButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var submitButton: some View {
        Button(action: startSubmission) {
            HStack(spacing: Layout.buttonContentSpacing) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                }

                Text(isSubmitting ? L10n.AITheme.generating : L10n.AITheme.submit)
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
        .opacity(canSubmit || isSubmitting ? 1 : Appearance.disabledOpacity)
        .accessibilityIdentifier(AccessibilityID.submitButton)
    }

    @ViewBuilder
    private var progressStatus: some View {
        ZStack {
            if let generationPhase {
                Text(generationPhase.title)
                    .id(generationPhase)
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .medium))
                    .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                    .multilineTextAlignment(.center)
                    .transition(.opacity)
                    .accessibilityIdentifier(AccessibilityID.progressStatus)
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .frame(minHeight: Layout.progressMinimumHeight)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
            .fill(Color(uiColor: appearance.card.backgroundColor))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
            .stroke(Color(uiColor: appearance.card.borderColor), lineWidth: appearance.card.borderWidth)
    }

    private var submitButtonBackgroundColor: UIColor {
        canSubmit || isSubmitting ? appearance.primaryButton.backgroundColor : appearance.row.backgroundColor
    }

    private var submitButtonBorderColor: UIColor {
        canSubmit || isSubmitting ? appearance.primaryButton.borderColor : appearance.row.borderColor
    }

    private var submitButtonTextColor: UIColor {
        canSubmit || isSubmitting ? appearance.accentForegroundColor : appearance.disabledTextColor
    }

    private func traitUserInterfaceStyle(for selectedTheme: CleanColorSchemePreference) -> UIUserInterfaceStyle {
        switch selectedTheme {
        case .system: return colorScheme == .dark ? .dark : .light
        case .light: return .light
        case .dark: return .dark
        }
    }

    private func makeAlert(_ alert: AIQuizGenerationAlert) -> Alert {
        let title = Text(alert.title)
        let message = Text(alert.message)

        if alert.canRetry {
            return Alert(
                title: title,
                message: message,
                primaryButton: .default(Text(L10n.AITheme.retry), action: startSubmission),
                secondaryButton: .cancel(Text(L10n.AITheme.editTheme)) {
                    if alert.shouldFocusPromptOnDismiss { isPromptFocused = true }
                }
            )
        }

        let actionTitle = alert.shouldFocusPromptOnDismiss ? L10n.AITheme.editTheme : L10n.Settings.alertAction
        return Alert(
            title: title,
            message: message,
            dismissButton: .default(Text(actionTitle)) {
                if alert.shouldFocusPromptOnDismiss { isPromptFocused = true }
            }
        )
    }

    private func startSubmission() {
        let prompt = trimmedPrompt
        guard !prompt.isEmpty, !isSubmitting else { return }

        isPromptFocused = false
        isSubmitting = true
        activeAlert = nil
        setGenerationPhase(.analyzing)

        let configuration = AIQuizGenerationConfiguration(
            theme: prompt,
            questionCount: selectedQuestionCount,
            difficulty: selectedDifficulty,
            locale: selectedLocale
        )
        submissionStartedAt = now()
        submissionLocaleIdentifier = configuration.locale.identifier
        analytics.track(
            .aiGenerationStarted(
                locale: configuration.locale.identifier,
                promptLength: prompt.count,
                questionCount: configuration.questionCount,
                difficulty: configuration.difficulty
            )
        )
        AppLog.quiz.info(
            "AI quiz submission started: locale=\(configuration.locale.identifier, privacy: .public) prompt_length=\(prompt.count, privacy: .public) questions=\(configuration.questionCount, privacy: .public) difficulty=\(configuration.difficulty.rawValue, privacy: .public)"
        )

        startProgressUpdates()
        submitTask = Task { await submitTheme(configuration: configuration) }
    }

    private func submitTheme(configuration: AIQuizGenerationConfiguration) async {
        defer {
            isSubmitting = false
            submitTask = nil
            stopProgressUpdates()
            submissionStartedAt = nil
            submissionLocaleIdentifier = nil
        }

        do {
            let theme = try await service.generateQuizTheme(configuration: configuration)
            try Task.checkCancellation()
            analytics.track(
                .aiGenerationSucceeded(
                    locale: configuration.locale.identifier,
                    questionCount: theme.questions.count,
                    difficulty: configuration.difficulty,
                    durationMilliseconds: submissionDurationMilliseconds()
                )
            )
            onGenerated(theme)
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            let errorCode = (error as? YandexAIQuizThemeServiceError)?.analyticsCode ?? "unexpected"
            analytics.track(
                .aiGenerationFailed(
                    locale: configuration.locale.identifier,
                    errorCode: errorCode,
                    durationMilliseconds: submissionDurationMilliseconds()
                )
            )
            analytics.reportOperationalError(error, context: .aiGeneration(code: errorCode))
            activeAlert = AIQuizGenerationAlert(error: error)
        }
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task {
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                try Task.checkCancellation()
                setGenerationPhase(.sending)
                try await Task.sleep(nanoseconds: 1_500_000_000)
                try Task.checkCancellation()
                setGenerationPhase(.generating)
                try await Task.sleep(nanoseconds: 3_500_000_000)
                try Task.checkCancellation()
                setGenerationPhase(.almostReady)
            } catch {
                return
            }
        }
    }

    private func setGenerationPhase(_ phase: GenerationPhase?) {
        if reduceMotion {
            generationPhase = phase
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                generationPhase = phase
            }
        }
    }

    private func stopProgressUpdates() {
        progressTask?.cancel()
        progressTask = nil
        setGenerationPhase(nil)
    }

    private func cancelSubmission() {
        if isSubmitting {
            analytics.track(
                .aiGenerationCancelled(
                    locale: submissionLocaleIdentifier ?? selectedLocale.identifier,
                    durationMilliseconds: submissionDurationMilliseconds()
                )
            )
        }
        submitTask?.cancel()
        submitTask = nil
        isSubmitting = false
        stopProgressUpdates()
        submissionStartedAt = nil
        submissionLocaleIdentifier = nil
    }

    private func submissionDurationMilliseconds() -> Int {
        guard let submissionStartedAt else { return 0 }
        return max(Int(now().timeIntervalSince(submissionStartedAt) * 1_000), 0)
    }
}

#if DEBUG
#Preview("AI Theme") {
    QuizAIThemeCreationView()
}
#endif
