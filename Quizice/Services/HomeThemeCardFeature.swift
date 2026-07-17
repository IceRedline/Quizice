import CoreGraphics
import CoreMotion
import QuartzCore

enum HomeThemeCardPhase: Equatable {
    case grid
    case expanding
    case expandedFront
    case flippingToBack
    case expandedBack
    case flippingToFront
    case collapsing
    case launching
}

struct HomeThemeCardTransitionGeometry: Equatable {
    let containerFrame: CGRect
    let targetFrame: CGRect

    var cardFrameInContainer: CGRect {
        centeredFrame(size: targetFrame.size)
    }

    var cardFrameInRoot: CGRect {
        cardFrameInContainer.offsetBy(
            dx: containerFrame.minX,
            dy: containerFrame.minY
        )
    }

    func centeredFrame(size: CGSize) -> CGRect {
        CGRect(
            x: (containerFrame.width - size.width) / 2,
            y: (containerFrame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

struct HomeThemeCardTransitionVisualState: Equatable {
    let progress: CGFloat

    init(progress: CGFloat) {
        self.progress = min(max(progress, 0), 1)
    }

    var sourceContentAlpha: CGFloat { 1 - progress }
    var expandedContentAlpha: CGFloat { progress }
    var expandedSurfaceLayerAlpha: CGFloat { progress }

    func compositedSurfaceAlpha(baseAlpha: CGFloat) -> CGFloat {
        let clampedBaseAlpha = min(max(baseAlpha, 0), 1)
        let overlayAlpha = clampedBaseAlpha * expandedSurfaceLayerAlpha
        return 1 - (1 - clampedBaseAlpha) * (1 - overlayAlpha)
    }
}

enum HomeThemeCardParallaxPresentationPhase: Equatable {
    case inactive
    case expanding
    case front
    case flipping
    case back
    case collapsing

    var preservesParallaxContinuity: Bool {
        switch self {
        case .front, .flipping, .back:
            return true
        case .inactive, .expanding, .collapsing:
            return false
        }
    }

    func permitsDeviceMotion(currentFace: HomeThemeCardFace) -> Bool {
        switch (self, currentFace) {
        case (.front, .front), (.back, .back), (.flipping, _):
            return true
        case (.inactive, _), (.expanding, _), (.front, .back),
             (.back, .front), (.collapsing, _):
            return false
        }
    }

    func permitsTouchParallax(currentFace: HomeThemeCardFace) -> Bool {
        switch (self, currentFace) {
        case (.front, .front), (.back, .back):
            return true
        case (.inactive, _), (.expanding, _), (.front, .back),
             (.flipping, _), (.back, .front), (.collapsing, _):
            return false
        }
    }
}

extension HomeThemeCardPhase {
    var parallaxPresentationPhase: HomeThemeCardParallaxPresentationPhase {
        switch self {
        case .grid, .launching:
            return .inactive
        case .expanding:
            return .expanding
        case .expandedFront:
            return .front
        case .flippingToBack, .flippingToFront:
            return .flipping
        case .expandedBack:
            return .back
        case .collapsing:
            return .collapsing
        }
    }
}

struct HomeThemeCardExpansionParallaxState: Equatable {
    let progress: CGFloat

    init(progress: CGFloat) {
        self.progress = min(max(progress, 0), 1)
    }

    /// The artwork emerges from a deeper plane than the title while the card grows.
    var artworkScale: CGFloat {
        interpolate(from: 0.94, to: 1)
    }

    var titleScale: CGFloat {
        interpolate(from: 0.985, to: 1)
    }

    private func interpolate(from start: CGFloat, to end: CGFloat) -> CGFloat {
        start + ((end - start) * progress)
    }
}

struct HomeThemeCardParallaxInput: Equatable {
    static let zero = HomeThemeCardParallaxInput(x: 0, y: 0)

    let x: CGFloat
    let y: CGFloat

    init(x: CGFloat, y: CGFloat) {
        self.x = min(max(x, -1), 1)
        self.y = min(max(y, -1), 1)
    }

    var isNeutral: Bool {
        abs(x) < 0.000_1 && abs(y) < 0.000_1
    }
}

struct HomeThemeCardPanParallaxMapper {
    private static let horizontalTravelRatio: CGFloat = 0.32
    private static let verticalTravelRatio: CGFloat = 0.24

    static func input(
        translation: CGPoint,
        in containerSize: CGSize,
        startingAt initialInput: HomeThemeCardParallaxInput = .zero
    ) -> HomeThemeCardParallaxInput {
        let horizontalTravel = max(containerSize.width * horizontalTravelRatio, 1)
        let verticalTravel = max(containerSize.height * verticalTravelRatio, 1)
        return HomeThemeCardParallaxInput(
            x: initialInput.x + translation.x / horizontalTravel,
            y: initialInput.y + translation.y / verticalTravel
        )
    }

    static func normalizedVelocity(
        _ velocity: CGPoint,
        in containerSize: CGSize
    ) -> CGVector {
        let horizontalTravel = max(containerSize.width * horizontalTravelRatio, 1)
        let verticalTravel = max(containerSize.height * verticalTravelRatio, 1)
        return CGVector(
            dx: velocity.x / horizontalTravel,
            dy: velocity.y / verticalTravel
        )
    }
}

struct HomeThemeCardParallaxGesturePolicy {
    static func permitsParallax(
        startedInDescription: Bool,
        descriptionCanScrollVertically: Bool,
        velocity: CGPoint
    ) -> Bool {
        guard startedInDescription, descriptionCanScrollVertically else { return true }
        return abs(velocity.x) > abs(velocity.y)
    }
}

struct HomeThemeCardDeviceParallaxStyle: Equatable {
    let horizontalRotation: CGFloat
    let verticalRotation: CGFloat
    let perspectiveDistance: CGFloat

    static let standard = HomeThemeCardDeviceParallaxStyle(
        horizontalRotation: 7 * .pi / 180,
        verticalRotation: 5 * .pi / 180,
        perspectiveDistance: 760
    )
}

struct HomeThemeCardParallaxRenderState: Equatable {
    let rotationX: CGFloat
    let rotationY: CGFloat
    let perspectiveDistance: CGFloat

    init(
        input: HomeThemeCardParallaxInput,
        style: HomeThemeCardDeviceParallaxStyle = .standard
    ) {
        rotationX = -input.y * style.verticalRotation
        // The card leans toward the drag: moving right brings its right edge
        // forward, matching the reference's negative Y-axis rotation.
        rotationY = -input.x * style.horizontalRotation
        perspectiveDistance = style.perspectiveDistance
    }

    var isNeutral: Bool {
        abs(rotationX) < 0.000_1 &&
            abs(rotationY) < 0.000_1
    }
}

protocol HomeThemeCardMotionProviding: AnyObject {
    var isAvailable: Bool { get }

    func start(receive: @escaping (HomeThemeCardParallaxInput) -> Void)
    func stop()
}

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

struct HomeThemeCardContentGeometry: Equatable {
    let containerSize: CGSize
    let imageCenter: CGPoint
    let titleCenter: CGPoint

    func imageTranslation(
        toAlignDestinationCenter destinationCenter: CGPoint,
        in destinationContainerSize: CGSize
    ) -> CGPoint {
        translation(
            sourceCenter: imageCenter,
            destinationCenter: destinationCenter,
            destinationContainerSize: destinationContainerSize
        )
    }

    func titleTranslation(
        toAlignDestinationCenter destinationCenter: CGPoint,
        in destinationContainerSize: CGSize
    ) -> CGPoint {
        translation(
            sourceCenter: titleCenter,
            destinationCenter: destinationCenter,
            destinationContainerSize: destinationContainerSize
        )
    }

    private func translation(
        sourceCenter: CGPoint,
        destinationCenter: CGPoint,
        destinationContainerSize: CGSize
    ) -> CGPoint {
        let sourceOffset = CGPoint(
            x: sourceCenter.x - containerSize.width / 2,
            y: sourceCenter.y - containerSize.height / 2
        )
        let destinationOffset = CGPoint(
            x: destinationCenter.x - destinationContainerSize.width / 2,
            y: destinationCenter.y - destinationContainerSize.height / 2
        )
        return CGPoint(
            x: sourceOffset.x - destinationOffset.x,
            y: sourceOffset.y - destinationOffset.y
        )
    }
}

enum HomeThemeCardFace: Equatable {
    case front
    case back

    var opposite: HomeThemeCardFace {
        self == .front ? .back : .front
    }
}

/// Pure geometry for a physical two-sided card.
///
/// Both faces keep a fixed 180-degree offset and travel on one shared carrier.
/// A positive projected width means that side faces the viewer; a negative value
/// means Core Animation must cull it because the plane is not double-sided.
struct HomeThemeCardFlipTransition: Equatable {
    let startFace: HomeThemeCardFace
    let targetFace: HomeThemeCardFace

    init?(startFace: HomeThemeCardFace, targetFace: HomeThemeCardFace) {
        guard startFace != targetFace else { return nil }
        self.startFace = startFace
        self.targetFace = targetFace
    }

    static func carrierAngle(showing face: HomeThemeCardFace) -> CGFloat {
        face == .front ? 0 : -.pi
    }

    static func localAngle(for face: HomeThemeCardFace) -> CGFloat {
        face == .front ? 0 : .pi
    }

    func carrierAngle(progress: CGFloat) -> CGFloat {
        let progress = min(max(progress, 0), 1)
        let startAngle = Self.carrierAngle(showing: startFace)
        let targetAngle = Self.carrierAngle(showing: targetFace)
        return startAngle + ((targetAngle - startAngle) * progress)
    }

    func worldAngle(for face: HomeThemeCardFace, progress: CGFloat) -> CGFloat {
        carrierAngle(progress: progress) + Self.localAngle(for: face)
    }

    func projectedWidth(for face: HomeThemeCardFace, progress: CGFloat) -> CGFloat {
        cos(worldAngle(for: face, progress: progress))
    }
}

enum HomePresentedCard: Equatable {
    case theme(String)
    case statistics
}

struct HomeThemeCardState: Equatable {
    fileprivate(set) var phase: HomeThemeCardPhase = .grid
    fileprivate(set) var presentedCard: HomePresentedCard?
    fileprivate(set) var availableQuestionCounts: [Int] = []
    fileprivate(set) var selectedQuestionCount: Int?

    var themeID: String? {
        guard case let .theme(themeID) = presentedCard else { return nil }
        return themeID
    }

    var isStatisticsPresented: Bool {
        guard phase != .grid, presentedCard == .statistics else { return false }
        return true
    }

    var presentedThemeID: String? {
        phase == .grid ? nil : themeID
    }

    var canStart: Bool {
        phase == .expandedBack &&
        selectedQuestionCount.map(availableQuestionCounts.contains) == true
    }

    init() {}
}

enum HomeThemeCardAction: Equatable {
    case present(
        themeID: String,
        availableQuestionCounts: [Int],
        preferredQuestionCount: Int?
    )
    case presentStatistics
    case expansionCompleted
    case flipRequested
    case flipCompleted(HomeThemeCardFace)
    case closeRequested
    case collapseCompleted
    case questionCountSelected(Int)
    case startRequested
    case reset
}

enum HomeThemeCardEffect: Equatable {
    case expand(themeID: String)
    case expandStatistics
    case flip(HomeThemeCardFace)
    case collapse(themeID: String)
    case collapseStatistics
    case reverseExpansion(shouldPresent: Bool)
    case launch(themeID: String, questionCount: Int)
}

enum HomeThemeCardReducer {
    @discardableResult
    static func reduce(
        state: inout HomeThemeCardState,
        action: HomeThemeCardAction
    ) -> HomeThemeCardEffect? {
        switch action {
        case let .present(themeID, availableQuestionCounts, preferredQuestionCount):
            guard state.phase == .grid, !themeID.isEmpty else { return nil }

            let normalizedCounts = QuizQuestionCountPolicy.supportedCounts.filter(
                availableQuestionCounts.contains
            )
            state.presentedCard = .theme(themeID)
            state.availableQuestionCounts = normalizedCounts
            state.selectedQuestionCount = QuizQuestionCountPolicy.initialSelection(
                preferred: preferredQuestionCount,
                available: normalizedCounts
            )
            state.phase = .expanding
            return .expand(themeID: themeID)

        case .presentStatistics:
            guard state.phase == .grid else { return nil }
            state.presentedCard = .statistics
            state.availableQuestionCounts = []
            state.selectedQuestionCount = nil
            state.phase = .expanding
            return .expandStatistics

        case .expansionCompleted:
            guard state.phase == .expanding else { return nil }
            state.phase = .expandedFront
            return nil

        case .flipRequested:
            guard state.themeID != nil else { return nil }
            switch state.phase {
            case .expandedFront:
                state.phase = .flippingToBack
                return .flip(.back)
            case .flippingToBack:
                state.phase = .flippingToFront
                return .flip(.front)
            case .expandedBack:
                state.phase = .flippingToFront
                return .flip(.front)
            case .flippingToFront:
                state.phase = .flippingToBack
                return .flip(.back)
            case .grid, .expanding, .collapsing, .launching:
                return nil
            }

        case let .flipCompleted(face):
            switch (state.phase, face) {
            case (.flippingToBack, .back):
                state.phase = .expandedBack
            case (.flippingToFront, .front):
                state.phase = .expandedFront
            case (.grid, _),
                 (.expanding, _),
                 (.expandedFront, _),
                 (.expandedBack, _),
                 (.flippingToBack, _),
                 (.flippingToFront, _),
                 (.collapsing, _),
                 (.launching, _):
                return nil
            }
            return nil

        case .closeRequested:
            guard let presentedCard = state.presentedCard else {
                return nil
            }
            switch state.phase {
            case .expanding:
                state.phase = .collapsing
                return .reverseExpansion(shouldPresent: false)
            case .expandedFront, .expandedBack:
                state.phase = .collapsing
                switch presentedCard {
                case let .theme(themeID):
                    return .collapse(themeID: themeID)
                case .statistics:
                    return .collapseStatistics
                }
            case .collapsing:
                state.phase = .expanding
                return .reverseExpansion(shouldPresent: true)
            case .grid, .flippingToBack, .flippingToFront, .launching:
                return nil
            }

        case .collapseCompleted:
            guard state.phase == .collapsing else { return nil }
            state = HomeThemeCardState()
            return nil

        case let .questionCountSelected(questionCount):
            guard
                state.themeID != nil,
                state.phase == .expandedBack,
                state.availableQuestionCounts.contains(questionCount)
            else {
                return nil
            }
            state.selectedQuestionCount = questionCount
            return nil

        case .startRequested:
            guard
                state.canStart,
                let themeID = state.themeID,
                let questionCount = state.selectedQuestionCount
            else {
                return nil
            }
            state.phase = .launching
            return .launch(themeID: themeID, questionCount: questionCount)

        case .reset:
            state = HomeThemeCardState()
            return nil
        }
    }
}
