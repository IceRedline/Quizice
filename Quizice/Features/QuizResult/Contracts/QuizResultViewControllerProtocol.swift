import Foundation

protocol QuizResultViewControllerProtocol: AnyObject {
    var presenter: QuizResultPresenterProtocol? { get set }
    
    func updateResultLabels(resultText: String, descriptionText: String)
}
