import SwiftUI
import UIKit


private struct AppMeshGradientPreset {
    let width: Int
    let height: Int
    let points: [SIMD2<Float>]
    let colorHexes: [UInt32]
    let backgroundHex: UInt32

    var colors: [Color] {
        colorHexes.map { Color(uiColor: UIColor(hex: $0)) }
    }
}

private extension AppBackgroundStyle {
    var meshPreset: AppMeshGradientPreset {
        switch self {
        case .legacySlate:
            return AppMeshGradientPreset(
                width: 3,
                height: 3,
                points: [
                    .init(0.00, 0.00), .init(0.50, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.50), .init(0.50, 0.50), .init(1.00, 0.50),
                    .init(0.00, 1.00), .init(0.50, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x131824, 0x1E263A,
                    0x121722, 0x111620, 0x161C2A,
                    0x1C2437, 0x151B29, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        case .slate4x4:
            return AppMeshGradientPreset(
                width: 4,
                height: 4,
                points: [
                    .init(0.00, 0.00), .init(0.32, 0.00), .init(0.68, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.33), .init(0.28, 0.25), .init(0.72, 0.40), .init(1.00, 0.30),
                    .init(0.00, 0.67), .init(0.38, 0.72), .init(0.64, 0.58), .init(1.00, 0.70),
                    .init(0.00, 1.00), .init(0.33, 1.00), .init(0.67, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x131824, 0x131824, 0x1E263A,
                    0x121722, 0x131824, 0x111620, 0x161C2A,
                    0x1C2437, 0x111620, 0x151B29, 0x2B3756,
                    0x1C2437, 0x151B29, 0x151B29, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        case .slate5x5:
            return AppMeshGradientPreset(
                width: 5,
                height: 5,
                points: [
                    .init(0.00, 0.00), .init(0.25, 0.00), .init(0.50, 0.00), .init(0.75, 0.00), .init(1.00, 0.00),
                    .init(0.00, 0.25), .init(0.20, 0.18), .init(0.48, 0.30), .init(0.78, 0.20), .init(1.00, 0.25),
                    .init(0.00, 0.50), .init(0.30, 0.46), .init(0.42, 0.58), .init(0.72, 0.42), .init(1.00, 0.50),
                    .init(0.00, 0.75), .init(0.18, 0.82), .init(0.55, 0.68), .init(0.82, 0.80), .init(1.00, 0.75),
                    .init(0.00, 1.00), .init(0.25, 1.00), .init(0.50, 1.00), .init(0.75, 1.00), .init(1.00, 1.00)
                ],
                colorHexes: [
                    0x2A3755, 0x2A3755, 0x131824, 0x1E263A, 0x1E263A,
                    0x2A3755, 0x121722, 0x131824, 0x161C2A, 0x1E263A,
                    0x121722, 0x131824, 0x111620, 0x161C2A, 0x161C2A,
                    0x1C2437, 0x121722, 0x111620, 0x151B29, 0x2B3756,
                    0x1C2437, 0x1C2437, 0x151B29, 0x2B3756, 0x2B3756
                ],
                backgroundHex: 0x111620
            )
        }
    }
}

enum AppBackgroundMotionProfile: Equatable {
    case standard
    case edgeAware
}

struct AppBackgroundView: View {
    let appearance: AppAppearance
    let motionProfile: AppBackgroundMotionProfile

    init(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile = .standard
    ) {
        self.appearance = appearance
        self.motionProfile = motionProfile
    }

    var body: some View {
        Group {
            if appearance.designStyle == .classic {
                let preset = appearance.backgroundStyle.meshPreset
                if appearance.backgroundStyle == .slate5x5 {
                    AnimatedSlateMeshGradient(
                        preset: preset,
                        motionProfile: motionProfile
                    )
                } else {
                    MeshGradient(
                        width: preset.width,
                        height: preset.height,
                        points: preset.points,
                        colors: preset.colors,
                        background: Color(uiColor: UIColor(hex: preset.backgroundHex)),
                        smoothsColors: true
                    )
                }
            } else {
                Color(uiColor: appearance.backgroundColor)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

enum AppMeshGradientMotion {
    static func animatedPoints(
        at date: Date,
        width: Int,
        height: Int,
        basePoints: [SIMD2<Float>],
        cycleDuration: TimeInterval,
        horizontalAmplitude: Float,
        verticalAmplitude: Float,
        edgeAmplitude: Float,
        profile: AppBackgroundMotionProfile
    ) -> [SIMD2<Float>] {
        guard width == 5, height == 5, basePoints.count == 25 else {
            return basePoints
        }

        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
        let phase = Float(progress * 2 * Double.pi)
        let interiorPointCount = (width - 2) * (height - 2)
        let phaseStep = 2 * Float.pi / Float(interiorPointCount)
        var points = basePoints
        var interiorIndex = 0

        for row in 1..<(height - 1) {
            for column in 1..<(width - 1) {
                let pointIndex = row * width + column
                let localPhase = phase + Float(interiorIndex) * phaseStep
                points[pointIndex].x += horizontalAmplitude * sin(localPhase)
                points[pointIndex].y += verticalAmplitude * cos(localPhase)
                interiorIndex += 1
            }
        }

        guard profile == .edgeAware else { return points }

        let edgePhaseStep = Float.pi / 3
        for column in 1..<(width - 1) {
            let localPhase = phase + Float(column - 1) * edgePhaseStep
            points[column].x += edgeAmplitude * sin(localPhase)
            points[(height - 1) * width + column].x += edgeAmplitude * sin(localPhase + .pi)
        }

        for row in 1..<(height - 1) {
            let localPhase = phase + Float(row - 1) * edgePhaseStep + Float.pi / 2
            points[row * width].y += edgeAmplitude * sin(localPhase)
            points[row * width + width - 1].y += edgeAmplitude * sin(localPhase + .pi)
        }

        return points
    }
}

private struct AnimatedSlateMeshGradient: View {
    private enum Motion {
        static let cycleDuration: TimeInterval = 4
        static let minimumFrameInterval: TimeInterval = 1.0 / 30.0
        static let horizontalAmplitude: Float = 0.050
        static let verticalAmplitude: Float = 0.035
        static let edgeAmplitude: Float = 0.070
    }

    let preset: AppMeshGradientPreset
    let motionProfile: AppBackgroundMotionProfile

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let colors = preset.colors
        let background = Color(uiColor: UIColor(hex: preset.backgroundHex))
        let animationPaused = reduceMotion || !UIView.areAnimationsEnabled

        TimelineView(
            .animation(
                minimumInterval: Motion.minimumFrameInterval,
                paused: animationPaused
            )
        ) { context in
            MeshGradient(
                width: preset.width,
                height: preset.height,
                points: animationPaused ? preset.points : animatedPoints(at: context.date),
                colors: colors,
                background: background,
                smoothsColors: true
            )
        }
    }

    private func animatedPoints(at date: Date) -> [SIMD2<Float>] {
        AppMeshGradientMotion.animatedPoints(
            at: date,
            width: preset.width,
            height: preset.height,
            basePoints: preset.points,
            cycleDuration: Motion.cycleDuration,
            horizontalAmplitude: Motion.horizontalAmplitude,
            verticalAmplitude: Motion.verticalAmplitude,
            edgeAmplitude: Motion.edgeAmplitude,
            profile: motionProfile
        )
    }
}

final class AppBackgroundHostingView: UIView {
    private enum Animation {
        static let crossfadeDuration: TimeInterval = 0.32
    }

    private let hostingController: UIHostingController<AppBackgroundView>
    private var appearance: AppAppearance

    init(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile
    ) {
        self.appearance = appearance
        self.hostingController = UIHostingController(
            rootView: AppBackgroundView(
                appearance: appearance,
                motionProfile: motionProfile
            )
        )
        super.init(frame: .zero)

        accessibilityIdentifier = "appBackgroundView"
        accessibilityElementsHidden = true
        isUserInteractionEnabled = false
        translatesAutoresizingMaskIntoConstraints = false

        let hostedView = hostingController.view!
        hostedView.backgroundColor = .clear
        hostedView.isUserInteractionEnabled = false
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    func update(
        appearance: AppAppearance,
        motionProfile: AppBackgroundMotionProfile,
        animated: Bool
    ) {
        let shouldCrossfade = animated
            && self.appearance.designStyle == .classic
            && appearance.designStyle == .classic
            && self.appearance.backgroundStyle != appearance.backgroundStyle
            && UIView.areAnimationsEnabled
            && !UIAccessibility.isReduceMotionEnabled

        self.appearance = appearance
        let updates = { [hostingController] in
            hostingController.rootView = AppBackgroundView(
                appearance: appearance,
                motionProfile: motionProfile
            )
        }

        if shouldCrossfade {
            UIView.transition(
                with: self,
                duration: Animation.crossfadeDuration,
                options: [.transitionCrossDissolve, .beginFromCurrentState, .allowAnimatedContent],
                animations: updates
            )
        } else {
            updates()
        }
    }
}
