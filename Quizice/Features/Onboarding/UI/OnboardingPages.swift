import SwiftUI
import UIKit

struct OnboardingWelcomePage: View {
    let isActive: Bool

    @Environment(\.appAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 8)

                WelcomeArtwork(
                    isRevealed: isRevealed || reduceMotion || !UIView.areAnimationsEnabled
                )
                    .frame(height: 232)

                VStack(spacing: 12) {
                    Text(L10n.Onboarding.welcomeKicker)
                        .font(appearance.typography.swiftUIFont(size: 13, weight: .bold))
                        .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                        .textCase(.uppercase)
                        .tracking(0.8)

                    Text(L10n.Onboarding.welcomeTitle)
                        .font(appearance.typography.swiftUIFont(size: 38, weight: .bold))
                        .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(-2)
                        .minimumScaleFactor(0.76)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboardingWelcomeTitle")

                    Text(L10n.Onboarding.welcomeSubtitle)
                        .font(appearance.typography.swiftUIFont(size: 18, weight: .regular))
                        .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                Spacer(minLength: 18)
            }
            .frame(maxWidth: 520)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("onboardingWelcomePage")
        .onAppear(perform: updateReveal)
        .onChange(of: isActive) { _, _ in updateReveal() }
    }

    private func updateReveal() {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            isRevealed = reduceMotion || !UIView.areAnimationsEnabled ? isActive : false
        }
        guard isActive, !reduceMotion, UIView.areAnimationsEnabled else { return }
        Task { @MainActor in
            await Task.yield()
            isRevealed = true
        }
    }
}

private struct WelcomeArtwork: View {
    let isRevealed: Bool

    @Environment(\.appAppearance) private var appearance

    var body: some View {
        ZStack {
            decorativeCard(
                systemImage: "music.note",
                color: ThemeVisualCatalog.tintColor(for: "music"),
                size: 82
            )
            .rotationEffect(.degrees(isRevealed ? -13 : -24))
            .offset(x: isRevealed ? -96 : -122, y: isRevealed ? 42 : 68)

            decorativeCard(
                systemImage: "cpu.fill",
                color: ThemeVisualCatalog.tintColor(for: "technology"),
                size: 72
            )
            .rotationEffect(.degrees(isRevealed ? 12 : 24))
            .offset(x: isRevealed ? 104 : 132, y: isRevealed ? -38 : -58)

            decorativeCard(
                systemImage: "theatermasks.fill",
                color: ThemeVisualCatalog.tintColor(for: "history_culture"),
                size: 62
            )
            .rotationEffect(.degrees(isRevealed ? 8 : 18))
            .offset(x: isRevealed ? 108 : 136, y: isRevealed ? 72 : 98)

            RoundedRectangle(cornerRadius: 44, style: .continuous)
                .fill(Color(uiColor: appearance.card.backgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 44, style: .continuous)
                        .stroke(
                            Color(uiColor: appearance.card.borderColor),
                            lineWidth: max(appearance.card.borderWidth, 1)
                        )
                }
                .onboardingShadow(appearance.card.shadow)
                .frame(width: 160, height: 160)
                .overlay {
                    VStack(spacing: 8) {
                        ZStack {
                            Image(systemName: "snowflake")
                                .font(.system(size: 66, weight: .light))
                                .foregroundStyle(Color(uiColor: appearance.accentColor).opacity(0.22))

                            Image(systemName: "questionmark")
                                .font(.system(size: 44, weight: .black, design: .rounded))
                                .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                        }

                        Text("QUIZICE")
                            .font(appearance.typography.swiftUIFont(size: 13, weight: .bold))
                            .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                            .tracking(1.6)
                    }
                }
                .scaleEffect(isRevealed ? 1 : 0.92)
                .opacity(isRevealed ? 1 : 0.35)
        }
        .animation(
            .spring(response: 0.52, dampingFraction: 0.82, blendDuration: 0.08),
            value: isRevealed
        )
        .accessibilityHidden(true)
    }

    private func decorativeCard(systemImage: String, color: UIColor, size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
            .fill(Color(uiColor: appearance.themeCardBackground(baseColor: color)))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .stroke(Color(uiColor: appearance.themeCardBorder(baseColor: color)), lineWidth: 1.2)
            }
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.themeCardTextColor(baseColor: color)))
            }
            .onboardingShadow(appearance.themeCardShadow)
            .opacity(isRevealed ? 1 : 0.22)
    }
}

struct OnboardingTopicsPage: View {
    @Binding var selectedThemeIDs: Set<String>
    let isActive: Bool

    @Environment(\.appAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Text(L10n.Onboarding.topicsTitle)
                        .font(appearance.typography.swiftUIFont(size: 32, weight: .bold))
                        .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboardingTopicsTitle")

                    Text(L10n.Onboarding.topicsSubtitle)
                        .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                        .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 24)

                FallingTopicsStage(
                    selectedThemeIDs: $selectedThemeIDs,
                    isActive: isActive
                )
                .frame(height: 330)
                .padding(.horizontal, 10)

                Label(L10n.Onboarding.topicsSelectionHint, systemImage: "hand.tap.fill")
                    .font(appearance.typography.swiftUIFont(size: 14, weight: .medium))
                    .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)
            }
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .accessibilityIdentifier("onboardingTopicsPage")
    }
}

private struct FallingTopicDescriptor: Identifiable {
    let id: String
    let themeID: String?
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: Double
    let delay: Double
    let zIndex: Double

    static let all: [FallingTopicDescriptor] = [
        .init(id: "ghost-1", themeID: nil, x: 0.18, y: 0.13, width: 104, height: 46, rotation: -11, delay: 0.00, zIndex: 0),
        .init(id: "ghost-2", themeID: nil, x: 0.76, y: 0.12, width: 128, height: 50, rotation: 8, delay: 0.05, zIndex: 0),
        .init(id: "music", themeID: "music", x: 0.34, y: 0.27, width: 156, height: 68, rotation: -7, delay: 0.10, zIndex: 4),
        .init(id: "ghost-3", themeID: nil, x: 0.82, y: 0.32, width: 92, height: 44, rotation: 14, delay: 0.16, zIndex: 1),
        .init(id: "technology", themeID: "technology", x: 0.68, y: 0.43, width: 168, height: 68, rotation: 6, delay: 0.22, zIndex: 5),
        .init(id: "ghost-4", themeID: nil, x: 0.24, y: 0.48, width: 112, height: 48, rotation: -16, delay: 0.28, zIndex: 1),
        .init(id: "ghost-5", themeID: nil, x: 0.53, y: 0.59, width: 132, height: 52, rotation: 2, delay: 0.34, zIndex: 2),
        .init(id: "history", themeID: "history_culture", x: 0.31, y: 0.68, width: 174, height: 68, rotation: -5, delay: 0.40, zIndex: 6),
        .init(id: "ghost-6", themeID: nil, x: 0.83, y: 0.68, width: 98, height: 44, rotation: 11, delay: 0.46, zIndex: 2),
        .init(id: "politics", themeID: "politics_business", x: 0.67, y: 0.83, width: 178, height: 68, rotation: 5, delay: 0.52, zIndex: 7),
        .init(id: "ghost-7", themeID: nil, x: 0.22, y: 0.90, width: 108, height: 46, rotation: -8, delay: 0.58, zIndex: 3),
        .init(id: "ghost-8", themeID: nil, x: 0.88, y: 0.94, width: 86, height: 42, rotation: 13, delay: 0.64, zIndex: 3)
    ]
}

private struct FallingTopicsStage: View {
    @Binding var selectedThemeIDs: Set<String>
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasLanded = false
    @State private var landingTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(FallingTopicDescriptor.all) { descriptor in
                    fallingCard(descriptor, in: geometry.size)
                        .zIndex(descriptor.zIndex)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .onAppear(perform: restartAnimation)
        .onChange(of: isActive) { _, _ in restartAnimation() }
        .onDisappear {
            landingTask?.cancel()
            landingTask = nil
        }
    }

    @ViewBuilder
    private func fallingCard(_ descriptor: FallingTopicDescriptor, in size: CGSize) -> some View {
        let isSettled = hasLanded || reduceMotion || !UIView.areAnimationsEnabled
        let card = Group {
            if let themeID = descriptor.themeID {
                FallingThemeCard(
                    themeID: themeID,
                    isSelected: selectedThemeIDs.contains(themeID),
                    action: { toggle(themeID) }
                )
            } else {
                FallingPlaceholderCard()
            }
        }
        .frame(width: min(descriptor.width, size.width * 0.52), height: descriptor.height)

        card
            .position(x: size.width * descriptor.x, y: size.height * descriptor.y)
            .offset(y: isSettled ? 0 : -(size.height * descriptor.y + descriptor.height + 90))
            .rotationEffect(.degrees(isSettled ? descriptor.rotation : descriptor.rotation * 1.8))
            .opacity(isSettled ? 1 : descriptor.themeID == nil ? 0.12 : 0.24)
            .animation(landingAnimation(delay: descriptor.delay), value: hasLanded)
    }

    private func restartAnimation() {
        landingTask?.cancel()
        landingTask = nil

        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            hasLanded = reduceMotion || !UIView.areAnimationsEnabled ? isActive : false
        }

        guard isActive, !reduceMotion, UIView.areAnimationsEnabled else { return }
        landingTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            hasLanded = true
        }
    }

    private func landingAnimation(delay: Double) -> Animation? {
        guard !reduceMotion, UIView.areAnimationsEnabled else {
            return .easeOut(duration: 0.16)
        }
        return .spring(response: 0.58, dampingFraction: 0.80, blendDuration: 0.08)
            .delay(delay)
    }

    private func toggle(_ themeID: String) {
        if selectedThemeIDs.contains(themeID) {
            selectedThemeIDs.remove(themeID)
        } else {
            selectedThemeIDs.insert(themeID)
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private struct FallingThemeCard: View {
    let themeID: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.appAppearance) private var appearance

    var body: some View {
        let tintColor = ThemeVisualCatalog.tintColor(for: themeID)
        let textColor = appearance.themeCardTextColor(baseColor: tintColor)

        Button(action: action) {
            HStack(spacing: 10) {
                Image(uiImage: themeImage)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(uiColor: textColor))
                    .frame(width: 25, height: 25)

                Text(themeTitle)
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: textColor))
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(Color(uiColor: textColor).opacity(isSelected ? 1 : 0.50))
            }
            .padding(.horizontal, 13)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(uiColor: appearance.themeCardBackground(baseColor: tintColor)),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        Color(uiColor: appearance.themeCardBorder(baseColor: tintColor)),
                        lineWidth: isSelected ? 2.4 : max(appearance.themeCardBorderWidth, 1)
                    )
            }
            .onboardingShadow(appearance.themeCardShadow)
        }
        .buttonStyle(QuizPressButtonStyle())
        .accessibilityLabel(themeTitle)
        .accessibilityValue(isSelected ? L10n.Onboarding.topicsSelected : "")
        .accessibilityHint(L10n.Onboarding.topicsSelectionHint)
        .accessibilityIdentifier("onboardingTopic-\(themeID)")
    }

    private var themeImage: UIImage {
        ThemeVisualCatalog.logoImage(for: themeID, designStyle: appearance.designStyle)
            ?? UIImage(systemName: "questionmark.square.dashed")!
    }

    private var themeTitle: String {
        switch themeID {
        case "music": return L10n.Onboarding.topicMusic
        case "technology": return L10n.Onboarding.topicTechnology
        case "history_culture": return L10n.Onboarding.topicHistoryCulture
        case "politics_business": return L10n.Onboarding.topicPoliticsBusiness
        default: return themeID
        }
    }
}

private struct FallingPlaceholderCard: View {
    @Environment(\.appAppearance) private var appearance

    var body: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(uiColor: appearance.card.backgroundColor).opacity(0.34))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color(uiColor: appearance.screenTextColor).opacity(0.13), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}

struct OnboardingTutorialPage: View {
    let isActive: Bool

    @Environment(\.appAppearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // Start in the final state so an initially presented tutorial never renders
    // as an empty page before `onAppear` gets a chance to run. When this page is
    // preloaded off-screen, `updateReveal()` resets it for the entrance motion.
    @State private var isRevealed = true

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    Text(L10n.Onboarding.tutorialTitle)
                        .font(appearance.typography.swiftUIFont(size: 32, weight: .bold))
                        .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.8)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("onboardingTutorialTitle")

                    Text(L10n.Onboarding.tutorialSubtitle)
                        .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                        .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)

                VStack(spacing: 12) {
                    ForEach(Array(features.enumerated()), id: \.element.id) { index, feature in
                        TutorialFeatureRow(feature: feature)
                            // Keep the content readable even if the page is captured or
                            // interrupted before its reveal transaction commits.
                            .scaleEffect(showsContent ? 1 : 0.985)
                            .offset(y: showsContent ? 0 : 14)
                            .animation(revealAnimation(index: index), value: isRevealed)
                    }
                }
            }
            .frame(maxWidth: 540)
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .frame(maxWidth: .infinity)
        }
        .accessibilityIdentifier("onboardingTutorialPage")
        .onAppear(perform: updateReveal)
        .onChange(of: isActive) { _, _ in updateReveal() }
    }

    private var features: [TutorialFeature] {
        [
            TutorialFeature(
                id: "themes",
                kind: .theme,
                title: L10n.Onboarding.tutorialThemesTitle,
                detail: L10n.Onboarding.tutorialThemesDetail
            ),
            TutorialFeature(
                id: "ai",
                kind: .ai,
                title: L10n.Onboarding.tutorialAITitle,
                detail: L10n.Onboarding.tutorialAIDetail
            ),
            TutorialFeature(
                id: "statistics",
                kind: .statistics,
                title: L10n.Onboarding.tutorialStatisticsTitle,
                detail: L10n.Onboarding.tutorialStatisticsDetail
            )
        ]
    }

    private var showsContent: Bool {
        isRevealed || reduceMotion || !UIView.areAnimationsEnabled
    }

    private func updateReveal() {
        var resetTransaction = Transaction()
        resetTransaction.disablesAnimations = true
        withTransaction(resetTransaction) {
            isRevealed = reduceMotion || !UIView.areAnimationsEnabled ? isActive : false
        }
        guard isActive, !reduceMotion, UIView.areAnimationsEnabled else { return }
        Task { @MainActor in
            await Task.yield()
            isRevealed = true
        }
    }

    private func revealAnimation(index: Int) -> Animation? {
        guard !reduceMotion, UIView.areAnimationsEnabled else { return nil }
        return .timingCurve(0.23, 1, 0.32, 1, duration: 0.34)
            .delay(Double(index) * 0.07)
    }
}

private struct TutorialFeature: Identifiable {
    enum Kind {
        case theme
        case ai
        case statistics
    }

    let id: String
    let kind: Kind
    let title: String
    let detail: String
}

private struct TutorialFeatureRow: View {
    let feature: TutorialFeature

    @Environment(\.appAppearance) private var appearance

    var body: some View {
        HStack(spacing: 15) {
            preview
                .frame(width: 74, height: 74)

            VStack(alignment: .leading, spacing: 5) {
                Text(feature.title)
                    .font(appearance.typography.swiftUIFont(size: 18, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
                    .fixedSize(horizontal: false, vertical: true)

                Text(feature.detail)
                    .font(appearance.typography.swiftUIFont(size: 14, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor).opacity(0.7))
        }
        .padding(14)
        .background(
            Color(uiColor: appearance.card.backgroundColor),
            in: RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: appearance.card.cornerRadius, style: .continuous)
                .stroke(Color(uiColor: appearance.card.borderColor), lineWidth: appearance.card.borderWidth)
        }
        .onboardingShadow(appearance.card.shadow)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var preview: some View {
        switch feature.kind {
        case .theme:
            let tintColor = ThemeVisualCatalog.tintColor(for: "music")
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: appearance.themeCardBackground(baseColor: tintColor)))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(uiColor: appearance.themeCardBorder(baseColor: tintColor)), lineWidth: 1.3)
                }
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(uiColor: appearance.themeCardTextColor(baseColor: tintColor)))
                }

        case .ai:
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(uiColor: appearance.secondaryButton.backgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(uiColor: AIThemeVisualStyle.gradientStartColor),
                                    Color(uiColor: AIThemeVisualStyle.gradientEndColor)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 2
                        )
                }
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                }

        case .statistics:
            ZStack {
                Circle()
                    .stroke(Color(uiColor: appearance.progressTrackColor), lineWidth: 7)

                Circle()
                    .trim(from: 0, to: 0.78)
                    .stroke(
                        Color(uiColor: appearance.correctAnswerColor),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("78%")
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
            }
            .padding(5)
        }
    }
}
