import Foundation

protocol QuizResultPresenterProtocol {
    var view: QuizResultViewControllerProtocol? { get set }
    var themeID: String? { get }
    var analyticsTheme: AnalyticsTheme { get }
    var correctAnswers: Int { get set }
    var totalQuestions: Int { get set }
    // Pre-built VoiceOver announcement string. The result screen cannot
    // build this itself — S03 contract forbids it from referencing
    // total-question fields — so the presenter formats it and hands over
    // an opaque string.
    var resultAnnouncement: String { get }

    func viewDidLoad()
}

extension QuizResultPresenterProtocol {
    var themeID: String? { nil }
    var analyticsTheme: AnalyticsTheme { .unknown }
}
