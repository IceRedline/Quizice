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
}

struct HomeThemeCardState: Equatable {
    fileprivate(set) var phase: HomeThemeCardPhase = .grid
    fileprivate(set) var themeID: String?
    fileprivate(set) var availableQuestionCounts: [Int] = []
    fileprivate(set) var selectedQuestionCount: Int?

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
    case flip(HomeThemeCardFace)
    case collapse(themeID: String)
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
            state.themeID = themeID
            state.availableQuestionCounts = normalizedCounts
            state.selectedQuestionCount = QuizQuestionCountPolicy.initialSelection(
                preferred: preferredQuestionCount,
                available: normalizedCounts
            )
            state.phase = .expanding
            return .expand(themeID: themeID)

        case .expansionCompleted:
            guard state.phase == .expanding else { return nil }
            state.phase = .expandedFront
            return nil

        case .flipRequested:
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
            guard let themeID = state.themeID else {
                return nil
            }
            switch state.phase {
            case .expanding:
                state.phase = .collapsing
                return .reverseExpansion(shouldPresent: false)
            case .expandedFront, .expandedBack:
                state.phase = .collapsing
                return .collapse(themeID: themeID)
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
