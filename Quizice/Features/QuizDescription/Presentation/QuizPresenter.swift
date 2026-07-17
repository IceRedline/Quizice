import Foundation

final class QuizPresenter: QuizPresenterProtocol {
    private let session: QuizSessionManaging

    weak var view: QuizViewControllerProtocol?

    init(session: QuizSessionManaging = QuizSessionStore.shared) {
        self.session = session
    }

    func descriptionContent() -> QuizDescriptionContent {
        QuizDescriptionContent(
            themeName: session.chosenTheme?.themeName ?? L10n.Description.defaultThemeName,
            themeDescription: session.chosenTheme?.description ?? L10n.Description.defaultThemeDescription
        )
    }
}
