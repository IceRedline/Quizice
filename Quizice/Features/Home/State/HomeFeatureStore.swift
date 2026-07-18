@MainActor
final class HomeFeatureStore {
    private(set) var cardState: HomeThemeCardState
    private(set) var aiThemeCardState: HomeAIThemeCardState

    init(
        cardState: HomeThemeCardState = HomeThemeCardState(),
        aiThemeCardState: HomeAIThemeCardState = HomeAIThemeCardState()
    ) {
        self.cardState = cardState
        self.aiThemeCardState = aiThemeCardState
    }

    @discardableResult
    func send(_ action: HomeThemeCardAction) -> HomeThemeCardEffect? {
        HomeThemeCardReducer.reduce(state: &cardState, action: action)
    }

    @discardableResult
    func sendAI(_ action: HomeAIThemeCardAction) -> HomeAIThemeCardEffect? {
        HomeAIThemeCardReducer.reduce(state: &aiThemeCardState, action: action)
    }
}
