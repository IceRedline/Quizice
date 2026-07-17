import CoreGraphics

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
    static func permitsSimultaneousDescriptionScroll(on face: HomeThemeCardFace) -> Bool {
        face == .back
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
