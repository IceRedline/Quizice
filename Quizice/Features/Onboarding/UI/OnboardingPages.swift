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
                        Image(systemName: "questionmark")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Color(uiColor: appearance.screenTextColor))

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
    let themes: [OnboardingTheme]
    let catalogOrigin: QuizCatalogOrigin
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

#if DEBUG
                    if DebugBackendSettings.shouldShowSourceIndicators {
                        OnboardingCatalogSourceBadge(origin: catalogOrigin)
                    }
#endif
                }
                .padding(.horizontal, 24)

                FallingTopicsStage(
                    themes: themes,
                    selectedThemeIDs: $selectedThemeIDs,
                    isActive: isActive
                )
                .frame(height: 350)
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

#if DEBUG
private struct OnboardingCatalogSourceBadge: View {
    let origin: QuizCatalogOrigin

    var body: some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color(uiColor: backgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .accessibilityLabel(title)
            .accessibilityIdentifier("onboardingBackendCatalogSource")
    }

    private var title: String {
        switch origin {
        case .backend: "CATALOG: BACKEND"
        case .bundled: "CATALOG: LOCAL"
        }
    }

    private var backgroundColor: UIColor {
        switch origin {
        case .backend: .systemGreen
        case .bundled: .systemOrange
        }
    }
}
#endif

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
