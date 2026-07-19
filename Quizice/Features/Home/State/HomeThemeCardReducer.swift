import CoreGraphics

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
    case ai
}

struct HomeThemeCardState: Equatable {
    fileprivate(set) var phase: HomeThemeCardPhase = .grid
    fileprivate(set) var presentedCard: HomePresentedCard?
    fileprivate(set) var availableQuestionCounts: [Int] = []
    fileprivate(set) var selectedQuestionCount: Int?
    fileprivate(set) var isFlipAllowed = false

    var themeID: String? {
        guard case let .theme(themeID) = presentedCard else { return nil }
        return themeID
    }

    var isStatisticsPresented: Bool {
        guard phase != .grid, presentedCard == .statistics else { return false }
        return true
    }

    var isAIThemePresented: Bool {
        guard phase != .grid, presentedCard == .ai else { return false }
        return true
    }

    var presentedThemeID: String? {
        phase == .grid ? nil : themeID
    }

    var canStart: Bool {
        phase == .expandedBack &&
        selectedQuestionCount.map(availableQuestionCounts.contains) == true
    }

    fileprivate var canRevealBack: Bool {
        switch presentedCard {
        case .theme:
            return true
        case .ai:
            return isFlipAllowed
        case .statistics, nil:
            return false
        }
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
    case presentAI
    case expansionCompleted
    case flipAvailabilityChanged(Bool)
    case flipRequested
    case flipCompleted(HomeThemeCardFace)
    case closeRequested
    case collapseCompleted
    case questionCountSelected(Int)
    case startRequested
    case launchFailed
    case reset
}

enum HomeThemeCardEffect: Equatable {
    case expand(themeID: String)
    case expandStatistics
    case expandAI
    case flip(HomeThemeCardFace)
    case collapse(themeID: String)
    case collapseStatistics
    case collapseAI
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
            state.isFlipAllowed = false
            state.phase = .expanding
            return .expandStatistics

        case .presentAI:
            guard state.phase == .grid else { return nil }
            state.presentedCard = .ai
            state.availableQuestionCounts = []
            state.selectedQuestionCount = nil
            state.isFlipAllowed = false
            state.phase = .expanding
            return .expandAI

        case .expansionCompleted:
            guard state.phase == .expanding else { return nil }
            state.phase = .expandedFront
            return nil

        case let .flipAvailabilityChanged(isAllowed):
            guard state.presentedCard == .ai else { return nil }
            switch state.phase {
            case .expanding, .expandedFront, .flippingToBack,
                 .expandedBack, .flippingToFront:
                state.isFlipAllowed = isAllowed
            case .grid, .collapsing, .launching:
                return nil
            }
            return nil

        case .flipRequested:
            switch state.phase {
            case .expandedFront:
                guard state.canRevealBack else { return nil }
                state.phase = .flippingToBack
                return .flip(.back)
            case .flippingToBack:
                state.phase = .flippingToFront
                return .flip(.front)
            case .expandedBack:
                state.phase = .flippingToFront
                return .flip(.front)
            case .flippingToFront:
                guard state.canRevealBack else { return nil }
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
                case .ai:
                    return .collapseAI
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

        case .launchFailed:
            guard state.phase == .launching, state.themeID != nil else { return nil }
            state.phase = .expandedBack
            return nil

        case .reset:
            state = HomeThemeCardState()
            return nil
        }
    }
}
