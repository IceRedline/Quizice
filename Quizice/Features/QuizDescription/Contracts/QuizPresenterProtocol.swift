import Foundation

struct QuizDescriptionContent: Equatable {
    let themeName: String
    let themeDescription: String
}

protocol QuizPresenterProtocol {
    var view: QuizViewControllerProtocol? { get set }
    
    func descriptionContent() -> QuizDescriptionContent
}
