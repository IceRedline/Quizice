import Foundation

protocol QuizResultViewControllerProtocol: AnyObject {
    var presenter: QuizResultPresenterProtocol? { get set }
    
    func updateResultLabels(resultText: String, descriptionText: String)
    func setPerfectScoreEffectVisible(_ isVisible: Bool)
}

extension QuizResultViewControllerProtocol {
    func setPerfectScoreEffectVisible(_ isVisible: Bool) {}
}
