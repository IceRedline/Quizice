import Foundation
import StoreKit
import SwiftUI

extension Notification.Name {
    static let subscriptionEntitlementDidChange = Notification.Name(
        "ru.avtabenskiy.Quizice.subscriptionEntitlementDidChange"
    )
}

protocol SubscriptionEntitlementProviding: AnyObject {
    var hasActivePlusSubscription: Bool { get }
}

final class SubscriptionEntitlementStore: SubscriptionEntitlementProviding, @unchecked Sendable {
    static let plusMonthlyProductID = "quizice.plus.monthly"
    static let shared = SubscriptionEntitlementStore()
#if DEBUG
    static let debugSubscriptionActiveKey = "quizice.debug.subscription.active"
#endif

    private let lock = NSLock()
    private var storeKitHasActivePlus = false
#if DEBUG
    private var debugHasActivePlus = UserDefaults.standard.bool(
        forKey: debugSubscriptionActiveKey
    )
#endif
    private var updatesTask: Task<Void, Never>?

    var hasActivePlusSubscription: Bool {
        lock.withLock { resolvedHasActivePlus }
    }

    private init() {
        updatesTask = Task { [weak self] in
            await self?.refresh()
            for await _ in Transaction.updates {
                await self?.refresh()
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    private func refresh() async {
        var isActive = false
        let now = Date()

        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result else { continue }
            guard transaction.productID == Self.plusMonthlyProductID else { continue }
            guard transaction.revocationDate == nil else { continue }
            guard transaction.expirationDate.map({ $0 > now }) ?? true else { continue }
            isActive = true
            break
        }

        let didChange = lock.withLock {
            let previousValue = resolvedHasActivePlus
            storeKitHasActivePlus = isActive
            return previousValue != resolvedHasActivePlus
        }
        guard didChange else { return }
        NotificationCenter.default.post(name: .subscriptionEntitlementDidChange, object: self)
    }

    private var resolvedHasActivePlus: Bool {
#if DEBUG
        debugHasActivePlus
#else
        storeKitHasActivePlus
#endif
    }

#if DEBUG
    func setDebugSubscriptionActive(_ isActive: Bool) {
        let didChange = lock.withLock {
            guard debugHasActivePlus != isActive else { return false }
            debugHasActivePlus = isActive
            return true
        }
        guard didChange else { return }
        UserDefaults.standard.set(isActive, forKey: Self.debugSubscriptionActiveKey)
        NotificationCenter.default.post(name: .subscriptionEntitlementDidChange, object: self)
    }
#endif
}

struct SubscriptionOffer: Equatable {
    let productID: String
    let displayPrice: String
    let freeQuestionsPerQuiz: Int
    let premiumQuestionsPerQuiz: Int
    let generationLimitMultiplier: Int

    static func planned(
        locale: Locale = AppLocalizationStore.shared.resolvedLocale
    ) -> SubscriptionOffer {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        return SubscriptionOffer(
            productID: SubscriptionEntitlementStore.plusMonthlyProductID,
            displayPrice: formatter.string(
                from: NSDecimalNumber(string: "1.99")
            ) ?? "$1.99",
            freeQuestionsPerQuiz: 5,
            premiumQuestionsPerQuiz: 15,
            generationLimitMultiplier: 20
        )
    }
}

struct SubscriptionPaywallView: View {
    enum AccessibilityID {
        static let root = "subscriptionPaywall"
        static let closeButton = "subscriptionPaywallCloseButton"
        static let comparison = "subscriptionPaywallComparison"
        static let plan = "subscriptionPaywallPlan"
        static let subscribeButton = "subscriptionPaywallSubscribeButton"
        static let restoreButton = "subscriptionPaywallRestoreButton"
    }

    private enum Layout {
        static let maximumContentWidth: CGFloat = 520
        static let horizontalInset: CGFloat = 20
        static let topInset: CGFloat = 14
        static let bottomInset: CGFloat = 28
        static let sectionSpacing: CGFloat = 18
        static let compactSpacing: CGFloat = 8
        static let cardPadding: CGFloat = 18
        static let cardCornerRadius: CGFloat = 28
        static let radarCardCornerRadius: CGFloat = 12
        static let closeButtonSize: CGFloat = 44
        static let metricMinimumHeight: CGFloat = 118
        static let benefitIconSize: CGFloat = 38
        static let primaryButtonHeight: CGFloat = 56
    }

    private enum Palette {
        static let gradientPink = Color(uiColor: AIThemeVisualStyle.gradientStartColor)
        static let gradientBlue = Color(uiColor: AIThemeVisualStyle.gradientEndColor)
        static let accent = Color(uiColor: AIThemeVisualStyle.accentColor)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var didTrackScreen = false

    private let offer: SubscriptionOffer
    private let appearance: AppAppearance
    private let analytics: AnalyticsTracking
    private let onSubscribe: () -> Void
    private let onRestore: () -> Void
    private let onClose: () -> Void

    init(
        offer: SubscriptionOffer = .planned(),
        appearance: AppAppearance,
        analytics: AnalyticsTracking = AppMetricaAnalyticsTracker.shared,
        onSubscribe: @escaping () -> Void,
        onRestore: @escaping () -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.offer = offer
        self.appearance = appearance
        self.analytics = analytics
        self.onSubscribe = onSubscribe
        self.onRestore = onRestore
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            paywallBackground
            decorativeGlow

            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    topBar
                    hero
                    comparisonCard
                    benefitsCard
                    planCard
                    secondaryActions
                }
                .frame(maxWidth: Layout.maximumContentWidth)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Layout.horizontalInset)
                .padding(.top, Layout.topInset)
                .padding(.bottom, Layout.bottomInset)
            }
            .scrollIndicators(.hidden)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            primaryActionBar
        }
        .accessibilityIdentifier(AccessibilityID.root)
        .environment(\.appAppearance, appearance)
        .preferredColorScheme(appearance.swiftUIColorScheme)
        .tint(Color(uiColor: appearance.screenTextColor))
        .onAppear {
            guard !didTrackScreen else { return }
            didTrackScreen = true
            analytics.track(.screenView(screen: .subscription))
        }
    }

    func subscribe() {
        onSubscribe()
    }

    func restore() {
        onRestore()
    }

    func close() {
        onClose()
        dismiss()
    }

    @ViewBuilder
    private var paywallBackground: some View {
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

    private var decorativeGlow: some View {
        GeometryReader { geometry in
            let glowSize = min(max(geometry.size.width * 0.88, 280), 430)
            Circle()
                .fill(aiGradient)
                .frame(width: glowSize, height: glowSize)
                .blur(radius: 72)
                .opacity(appearance.designStyle == .radar ? 0.08 : 0.13)
                .offset(
                    x: geometry.size.width * 0.42,
                    y: -glowSize * 0.52
                )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Label {
                Text(L10n.Subscription.eyebrow)
                    .font(appearance.typography.swiftUIFont(size: 13, weight: .bold))
            } icon: {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(premiumAccentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(uiColor: appearance.row.backgroundColor),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .stroke(premiumStroke, lineWidth: premiumBorderWidth)
            )

            Spacer(minLength: 12)

            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .frame(
                        width: Layout.closeButtonSize,
                        height: Layout.closeButtonSize
                    )
                    .background(
                        Color(uiColor: appearance.iconButton.backgroundColor),
                        in: RoundedRectangle(
                            cornerRadius: appearance.iconButton.cornerRadius,
                            style: .continuous
                        )
                    )
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: appearance.iconButton.cornerRadius,
                            style: .continuous
                        )
                        .stroke(
                            Color(uiColor: appearance.iconButton.borderColor),
                            lineWidth: appearance.iconButton.borderWidth
                        )
                    )
            }
            .buttonStyle(QuizPressButtonStyle())
            .accessibilityIdentifier(AccessibilityID.closeButton)
            .accessibilityLabel(L10n.Subscription.close)
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Subscription.title)
                .font(appearance.typography.swiftUIFont(size: 36, weight: .bold))
                .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                .tracking(-0.7)
                .fixedSize(horizontal: false, vertical: true)

            Text(L10n.Subscription.subtitle)
                .font(appearance.typography.swiftUIFont(size: 17, weight: .regular))
                .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var comparisonCard: some View {
        VStack(spacing: 14) {
            Text(L10n.Subscription.multiplier)
                .font(appearance.typography.swiftUIFont(size: 14, weight: .bold))
                .foregroundStyle(premiumAccentColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Color(uiColor: appearance.row.backgroundColor),
                    in: Capsule()
                )

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: 10) {
                    metricCard(
                        label: L10n.Subscription.free,
                        value: "1×",
                        isPremium: false
                    )
                    Image(systemName: "arrow.down")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(premiumAccentColor)
                        .accessibilityHidden(true)
                    metricCard(
                        label: L10n.Subscription.plus,
                        value: "\(offer.generationLimitMultiplier)×",
                        isPremium: true
                    )
                }
            } else {
                HStack(spacing: 12) {
                    metricCard(
                        label: L10n.Subscription.free,
                        value: "1×",
                        isPremium: false
                    )
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(premiumAccentColor)
                        .accessibilityHidden(true)
                    metricCard(
                        label: L10n.Subscription.plus,
                        value: "\(offer.generationLimitMultiplier)×",
                        isPremium: true
                    )
                }
            }
        }
        .padding(Layout.cardPadding)
        .background(cardBackground)
        .overlay(cardOutline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(AccessibilityID.comparison)
    }

    private func metricCard(
        label: String,
        value: String,
        isPremium: Bool
    ) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                if isPremium {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(premiumAccentColor)
                        .accessibilityHidden(true)
                }
                Text(label)
                    .font(appearance.typography.swiftUIFont(size: 13, weight: .bold))
                    .foregroundStyle(
                        isPremium
                            ? premiumAccentColor
                            : Color(uiColor: appearance.secondarySurfaceTextColor)
                    )
            }

            Text(value)
                .font(appearance.typography.swiftUIFont(size: 38, weight: .bold))
                .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))

            Text(L10n.Subscription.generationLimit)
                .font(appearance.typography.swiftUIFont(size: 13, weight: .medium))
                .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.metricMinimumHeight)
        .padding(.horizontal, 10)
        .background(
            Color(uiColor: appearance.row.backgroundColor),
            in: RoundedRectangle(
                cornerRadius: max(cardCornerRadius - 10, 8),
                style: .continuous
            )
        )
        .overlay {
            if isPremium {
                RoundedRectangle(
                    cornerRadius: max(cardCornerRadius - 10, 8),
                    style: .continuous
                )
                .stroke(premiumStroke, lineWidth: premiumBorderWidth)
            }
        }
    }

    private var benefitsCard: some View {
        VStack(spacing: 0) {
            benefitRow(
                systemImage: "text.badge.plus",
                title: L10n.Subscription.limitBenefitTitle,
                subtitle: L10n.Subscription.limitBenefitSubtitle
            )

            Divider()
                .overlay(Color(uiColor: appearance.card.borderColor))
                .padding(.vertical, 14)

            benefitRow(
                systemImage: "slider.horizontal.3",
                title: L10n.Subscription.flexibilityBenefitTitle,
                subtitle: L10n.Subscription.flexibilityBenefitSubtitle
            )
        }
        .padding(Layout.cardPadding)
        .background(cardBackground)
        .overlay(cardOutline)
    }

    private func benefitRow(
        systemImage: String,
        title: String,
        subtitle: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(premiumAccentColor)
                .frame(
                    width: Layout.benefitIconSize,
                    height: Layout.benefitIconSize
                )
                .background(
                    Color(uiColor: appearance.row.backgroundColor),
                    in: RoundedRectangle(
                        cornerRadius: appearance.row.cornerRadius,
                        style: .continuous
                    )
                )
                .overlay(
                    RoundedRectangle(
                        cornerRadius: appearance.row.cornerRadius,
                        style: .continuous
                    )
                    .stroke(premiumStroke, lineWidth: premiumBorderWidth)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(appearance.typography.swiftUIFont(size: 16, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))

                Text(subtitle)
                    .font(appearance.typography.swiftUIFont(size: 14, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var planCard: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                planDescription
                Spacer(minLength: 8)
                planPrice
            }

            VStack(alignment: .leading, spacing: 12) {
                planDescription
                planPrice
            }
        }
        .padding(Layout.cardPadding)
        .background(cardBackground)
        .overlay(cardOutline)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(AccessibilityID.plan)
    }

    private var planDescription: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(L10n.Subscription.planTitle)
                .font(appearance.typography.swiftUIFont(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))

            Text(L10n.Subscription.planNote)
                .font(appearance.typography.swiftUIFont(size: 13, weight: .regular))
                .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var planPrice: some View {
        Text(L10n.Subscription.pricePerMonth(offer.displayPrice))
            .font(appearance.typography.swiftUIFont(size: 18, weight: .bold))
            .foregroundStyle(premiumAccentColor)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var secondaryActions: some View {
        VStack(spacing: 12) {
            Button(action: restore) {
                Text(L10n.Subscription.restore)
                    .font(appearance.typography.swiftUIFont(size: 15, weight: .semibold))
                    .foregroundStyle(Color(uiColor: appearance.screenTextColor))
                    .frame(minHeight: 44)
            }
            .buttonStyle(QuizPressButtonStyle())
            .accessibilityIdentifier(AccessibilityID.restoreButton)

            Text(L10n.Subscription.legal)
                .font(appearance.typography.swiftUIFont(size: 12, weight: .regular))
                .foregroundStyle(Color(uiColor: appearance.secondaryScreenTextColor))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var primaryActionBar: some View {
        VStack(spacing: 0) {
            Button(action: subscribe) {
                Text(L10n.Subscription.subscribeCTA(offer.displayPrice))
                    .font(appearance.typography.swiftUIFont(size: 17, weight: .semibold))
                    .foregroundStyle(primaryButtonTextColor)
                    .frame(maxWidth: .infinity, minHeight: Layout.primaryButtonHeight)
                    .padding(.horizontal, 18)
                    .background(primaryButtonBackground)
                    .overlay(primaryButtonOutline)
                    .contentShape(
                        RoundedRectangle(
                            cornerRadius: appearance.primaryButton.cornerRadius,
                            style: .continuous
                        )
                    )
            }
            .buttonStyle(QuizPressButtonStyle())
            .accessibilityIdentifier(AccessibilityID.subscribeButton)
            .frame(maxWidth: Layout.maximumContentWidth)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, Layout.horizontalInset)
            .padding(.top, 12)
            .padding(.bottom, 8)
        }
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color(uiColor: appearance.card.borderColor))
                .frame(height: 1)
        }
    }

    private var cardCornerRadius: CGFloat {
        appearance.designStyle == .radar
            ? Layout.radarCardCornerRadius
            : Layout.cardCornerRadius
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .fill(Color(uiColor: appearance.card.backgroundColor))
    }

    private var cardOutline: some View {
        RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
            .stroke(premiumStroke, lineWidth: premiumBorderWidth)
    }

    private var aiGradient: LinearGradient {
        if appearance.designStyle == .radar {
            return LinearGradient(
                colors: [
                    Color(uiColor: appearance.accentColor),
                    Color(uiColor: appearance.accentColor.withAlphaComponent(0.45))
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [Palette.gradientPink, Palette.gradientBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var premiumStroke: LinearGradient {
        aiGradient
    }

    private var premiumBorderWidth: CGFloat {
        appearance.designStyle == .radar ? 1 : 1.6
    }

    private var premiumAccentColor: Color {
        appearance.designStyle == .radar
            ? Color(uiColor: appearance.accentColor)
            : Palette.accent
    }

    private var primaryButtonTextColor: Color {
        appearance.designStyle == .radar
            ? Color(uiColor: appearance.screenTextColor)
            : .white
    }

    @ViewBuilder
    private var primaryButtonBackground: some View {
        if appearance.designStyle == .radar {
            RoundedRectangle(
                cornerRadius: appearance.primaryButton.cornerRadius,
                style: .continuous
            )
            .fill(Color(uiColor: appearance.primaryButton.backgroundColor))
        } else {
            RoundedRectangle(
                cornerRadius: appearance.primaryButton.cornerRadius,
                style: .continuous
            )
            .fill(aiGradient)
        }
    }

    @ViewBuilder
    private var primaryButtonOutline: some View {
        if appearance.designStyle == .radar {
            RoundedRectangle(
                cornerRadius: appearance.primaryButton.cornerRadius,
                style: .continuous
            )
            .stroke(
                Color(uiColor: appearance.primaryButton.borderColor),
                lineWidth: appearance.primaryButton.borderWidth
            )
        }
    }
}
