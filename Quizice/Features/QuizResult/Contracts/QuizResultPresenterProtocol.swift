import Foundation

protocol QuizResultPresenterProtocol {
    var view: QuizResultViewControllerProtocol? { get set }
    var themeID: String? { get }
    var analyticsTheme: AnalyticsTheme { get }
    var correctAnswers: Int { get set }
    var totalQuestions: Int { get set }
    
    func viewDidLoad()
}

extension QuizResultPresenterProtocol {
    var themeID: String? { nil }
    var analyticsTheme: AnalyticsTheme { .unknown }
}
