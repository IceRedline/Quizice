import SwiftUI
import UIKit

enum FakeLaunchCompletionStyle: Equatable {
    case revealHome
    case crossfade
}

struct FakeLaunchMotion {
    static let standard = FakeLaunchMotion(
        logoZoomScale: 42,
        logoZoomDuration: 0.82
    )

    let logoZoomScale: CGFloat
    let logoZoomDuration: TimeInterval

    var logoZoomAnimation: Animation {
        .timingCurve(0.77, 0, 0.175, 1, duration: logoZoomDuration)
    }
}

enum FakeLaunchMarkStyle: Equatable {
    case classicImage
    case radarText
    case cleanText
}

struct FakeLaunchVisualStyle {
    let markStyle: FakeLaunchMarkStyle
    let backgroundColor: UIColor
    let foregroundColor: UIColor?
    let revealsAppBackground: Bool

    init(appearance: AppAppearance) {
        switch appearance.designStyle {
        case .classic:
            markStyle = .classicImage
            backgroundColor = UIColor(hex: 0x111620)
            foregroundColor = nil
            revealsAppBackground = true
        case .radar:
            markStyle = .radarText
            backgroundColor = .black
            foregroundColor = appearance.accentColor
            revealsAppBackground = false
        case .clean:
            markStyle = .cleanText
            backgroundColor = appearance.accentForegroundColor
            foregroundColor = appearance.accentColor
            revealsAppBackground = false
        }
    }
}

struct FakeLaunchScreenView: View {
    private enum Phase {
        case holding
        case zooming
    }

    private enum Layout {
        static let logoWidthRatio: CGFloat = 0.7
        static let maximumLogoWidth: CGFloat = 360
        static let logoAspectRatio: CGFloat = 399 / 742
        static let centerGapRatio: CGFloat = 0.05
        static let radarFontSizeRatio: CGFloat = 0.52
        static let radarHorizontalOffsetRatio: CGFloat = -0.105
        static let radarVerticalOffsetRatio: CGFloat = -0.035
        static let radarItalicShear: CGFloat = -0.18
        static let cleanFontSizeRatio: CGFloat = 0.684
        static let cleanHorizontalOffsetRatio: CGFloat = 0.052
        static let cleanVerticalOffsetRatio: CGFloat = -0.037
    }

    private enum Motion {
        static let revealDuration: TimeInterval = 0.35
    }

    let appearance: AppAppearance
    private let holdDuration: TimeInterval
    private let motion: FakeLaunchMotion
    private let onFinished: (FakeLaunchCompletionStyle) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isRevealed = false
    @State private var phase = Phase.holding
    @State private var didFinish = false

    init(
        appearance: AppAppearance,
        holdDuration: TimeInterval = 1.15,
        motion: FakeLaunchMotion = .standard,
        onFinished: @escaping (FakeLaunchCompletionStyle) -> Void = { _ in }
    ) {
        self.appearance = appearance
        self.holdDuration = holdDuration
        self.motion = motion
        self.onFinished = onFinished
    }

    var body: some View {
        GeometryReader { geometry in
            let visualStyle = FakeLaunchVisualStyle(appearance: appearance)
            let logoWidth = min(
                geometry.size.width * Layout.logoWidthRatio,
                Layout.maximumLogoWidth
            )
            let logoHeight = logoWidth * Layout.logoAspectRatio

            ZStack {
                Color(uiColor: visualStyle.backgroundColor)

                if visualStyle.revealsAppBackground {
                    AppBackgroundView(appearance: appearance)
                        .opacity(isRevealed ? 1 : 0)
                }

                launchMark(
                    style: visualStyle,
                    width: logoWidth,
                    height: logoHeight
                )
                .scaleEffect(phase == .zooming && !reduceMotion ? motion.logoZoomScale : 1)
                .offset(
                    x: phase == .holding
                        ? horizontalMarkOffset(for: visualStyle.markStyle, width: logoWidth)
                        : 0
                )
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .onAppear(perform: reveal)
        .task {
            await runSequence()
        }
    }

    @ViewBuilder
    private func launchMark(
        style: FakeLaunchVisualStyle,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        switch style.markStyle {
        case .classicImage:
            Image("QII")
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: width)
        case .radarText:
            splitTextMark(
                font: radarFont(size: width * Layout.radarFontSizeRatio),
                color: style.foregroundColor ?? appearance.accentColor,
                width: width,
                height: height
            )
            .transformEffect(
                CGAffineTransform(
                    a: 1,
                    b: 0,
                    c: Layout.radarItalicShear,
                    d: 1,
                    tx: 0,
                    ty: 0
                )
            )
            .offset(y: width * Layout.radarVerticalOffsetRatio)
        case .cleanText:
            splitTextMark(
                font: .system(
                    size: width * Layout.cleanFontSizeRatio,
                    weight: .bold,
                    design: .default
                ),
                color: style.foregroundColor ?? appearance.accentColor,
                width: width,
                height: height
            )
            .italic()
            .offset(y: width * Layout.cleanVerticalOffsetRatio)
        }
    }

    private func splitTextMark(
        font: Font,
        color: UIColor,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let centerGap = width * Layout.centerGapRatio
        let sideWidth = (width - centerGap) / 2

        return HStack(spacing: centerGap) {
            Text("Q")
                .font(font)
                .fixedSize()
                .frame(width: sideWidth, alignment: .trailing)

            Text("II")
                .font(font)
                .fixedSize()
                .frame(width: sideWidth, alignment: .leading)
        }
        .foregroundStyle(Color(uiColor: color))
        .frame(width: width, height: height)
    }

    private func radarFont(size: CGFloat) -> Font {
        if let fontName = AppFontFamily.jetBrainsMono.fontName(weight: .medium) {
            return .custom(fontName, fixedSize: size)
        }
        return .system(size: size, weight: .medium, design: .monospaced)
    }

    private func horizontalMarkOffset(
        for style: FakeLaunchMarkStyle,
        width: CGFloat
    ) -> CGFloat {
        switch style {
        case .classicImage:
            return 0
        case .radarText:
            return width * Layout.radarHorizontalOffsetRatio
        case .cleanText:
            return width * Layout.cleanHorizontalOffsetRatio
        }
    }

    private func reveal() {
        guard FakeLaunchVisualStyle(appearance: appearance).revealsAppBackground else {
            isRevealed = true
            return
        }

        guard !reduceMotion, UIView.areAnimationsEnabled else {
            isRevealed = true
            return
        }

        withAnimation(.easeOut(duration: Motion.revealDuration)) {
            isRevealed = true
        }
    }

    @MainActor
    private func runSequence() async {
        let nanoseconds = UInt64(max(0, holdDuration) * 1_000_000_000)
        do {
            try await Task.sleep(nanoseconds: nanoseconds)
        } catch {
            return
        }

        guard !Task.isCancelled else { return }
        guard !reduceMotion, UIView.areAnimationsEnabled else {
            finish(with: .crossfade)
            return
        }

        withAnimation(
            motion.logoZoomAnimation,
            completionCriteria: .logicallyComplete
        ) {
            phase = .zooming
        } completion: {
            finish(with: .revealHome)
        }
    }

    private func finish(with style: FakeLaunchCompletionStyle) {
        guard !didFinish else { return }
        didFinish = true
        onFinished(style)
    }
}
