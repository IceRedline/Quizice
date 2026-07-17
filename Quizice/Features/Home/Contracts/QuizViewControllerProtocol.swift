import Foundation

protocol QuizViewControllerProtocol: AnyObject {
    var presenter: QuizPresenterProtocol? { get set }
    
    func configurePresenter(_ presenter: QuizPresenterProtocol)
}
