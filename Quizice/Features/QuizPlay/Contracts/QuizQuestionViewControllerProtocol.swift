import Foundation

protocol QuizQuestionViewControllerProtocol: AnyObject {
    var presenter: QuizQuestionPresenterProtocol? { get set }
    
    func updateProgress(_ progress: Float)
    func showTimeExpired()
    func loadQuestionToView(_ viewModel: QuizQuestionViewModel)
    func showQuestionUnavailable(themeName: String?, message: String)
    func correctAnswerTapped(isTrue: Bool)
    func showResults(_ result: QuizResultState)
}
