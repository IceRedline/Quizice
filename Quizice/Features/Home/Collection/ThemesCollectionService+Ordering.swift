import Foundation

extension ThemesCollectionService {
    static func orderedThemes(_ themes: [QuizTheme], preferredThemeIDs: [String]) -> [QuizTheme] {
        guard !preferredThemeIDs.isEmpty else { return themes }
        let preferredRank = Dictionary(
            uniqueKeysWithValues: preferredThemeIDs.enumerated().map { ($0.element, $0.offset) }
        )

        return themes.enumerated()
            .sorted { lhs, rhs in
                let lhsRank = preferredRank[lhs.element.stableID]
                let rhsRank = preferredRank[rhs.element.stableID]
                switch (lhsRank, rhsRank) {
                case let (.some(lhsRank), .some(rhsRank)):
                    return lhsRank < rhsRank
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    return lhs.offset < rhs.offset
                }
            }
            .map { $0.element }
    }
}
