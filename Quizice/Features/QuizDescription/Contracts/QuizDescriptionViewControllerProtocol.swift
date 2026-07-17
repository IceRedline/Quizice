import Foundation

protocol QuizDescriptionViewControllerProtocol: AnyObject {
    var presenter: QuizDescriptionPresenterProtocol? { get set }
    
    func configurePresenter(_ presenter: QuizDescriptionPresenterProtocol)
    func updateLabels(themeName: String, themeDescription: String)
}
