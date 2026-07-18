import CoreGraphics
import CoreMotion
import Foundation
import QuartzCore

struct HomeThemeCardMotionInputMapper {
    static func input(
        relativeRoll: CGFloat,
        relativePitch: CGFloat,
        responseAngle: CGFloat
    ) -> HomeThemeCardParallaxInput {
        let safeResponseAngle = max(abs(responseAngle), .leastNonzeroMagnitude)
        return HomeThemeCardParallaxInput(
            // The shared renderer maps positive x to a negative Y rotation.
            // Inverting roll keeps physical +Y device rotation aligned with it.
            x: -relativeRoll / safeResponseAngle,
            y: relativePitch / safeResponseAngle
        )
    }
}

final class CoreMotionHomeThemeCardMotionProvider: NSObject, HomeThemeCardMotionProviding {
    private enum Constants {
        static let updateInterval: TimeInterval = 1 / 60
        static let responseAngle: CGFloat = 12 * .pi / 180
        static let smoothingFactor: CGFloat = 0.18
        static let deadZone: CGFloat = 0.012
    }

    private let motionManager: CMMotionManager
    private var displayLink: CADisplayLink?
    private var receive: ((HomeThemeCardParallaxInput) -> Void)?
    private var referenceAttitude: CMAttitude?
    private var filteredInput = HomeThemeCardParallaxInput.zero

    init(motionManager: CMMotionManager = CMMotionManager()) {
        self.motionManager = motionManager
        super.init()
    }

    deinit {
        displayLink?.invalidate()
        motionManager.stopDeviceMotionUpdates()
    }

    var isAvailable: Bool {
        motionManager.isDeviceMotionAvailable
    }

    func start(receive: @escaping (HomeThemeCardParallaxInput) -> Void) {
        stop()
        guard isAvailable else { return }

        self.receive = receive
        referenceAttitude = nil
        filteredInput = .zero
        motionManager.deviceMotionUpdateInterval = Constants.updateInterval
        let availableFrames = CMMotionManager.availableAttitudeReferenceFrames()
        if availableFrames.contains(.xArbitraryZVertical) {
            motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)
        } else {
            motionManager.startDeviceMotionUpdates()
        }

        let displayLink = CADisplayLink(target: self, selector: #selector(sampleMotion))
        displayLink.preferredFrameRateRange = CAFrameRateRange(
            minimum: 30,
            maximum: 60,
            preferred: 60
        )
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        motionManager.stopDeviceMotionUpdates()
        receive = nil
        referenceAttitude = nil
        filteredInput = .zero
    }

    @objc private func sampleMotion() {
        guard let motion = motionManager.deviceMotion else { return }

        guard let referenceAttitude else {
            self.referenceAttitude = motion.attitude.copy() as? CMAttitude
            receive?(.zero)
            return
        }

        guard let relativeAttitude = motion.attitude.copy() as? CMAttitude else { return }
        relativeAttitude.multiply(byInverseOf: referenceAttitude)

        let target = HomeThemeCardMotionInputMapper.input(
            relativeRoll: CGFloat(relativeAttitude.roll),
            relativePitch: CGFloat(relativeAttitude.pitch),
            responseAngle: Constants.responseAngle
        )
        let smoothed = HomeThemeCardParallaxInput(
            x: filteredInput.x + (target.x - filteredInput.x) * Constants.smoothingFactor,
            y: filteredInput.y + (target.y - filteredInput.y) * Constants.smoothingFactor
        )
        filteredInput = HomeThemeCardParallaxInput(
            x: abs(smoothed.x) < Constants.deadZone ? 0 : smoothed.x,
            y: abs(smoothed.y) < Constants.deadZone ? 0 : smoothed.y
        )
        receive?(filteredInput)
    }
}
