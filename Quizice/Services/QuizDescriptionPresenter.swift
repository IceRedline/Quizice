//
//  QuizDescriptionPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

final class QuizDescriptionPresenter: QuizDescriptionPresenterProtocol {
    private let supportedNumberOfQuestionsOptions: [Int] = [5, 10, 15]
    private let session: QuizSessionManaging

    weak var view: QuizDescriptionViewControllerProtocol?

    var themeName: String = L10n.Description.defaultThemeName
    var themeDescription: String = L10n.Description.defaultThemeDescription
    var themeID: String? {
        session.chosenTheme?.themeID
    }
    var selectedQuestionCount: Int { session.questionsCount }
    
    init(session: QuizSessionManaging = QuizFactory.shared, content: QuizDescriptionContent? = nil) {
        self.session = session
        if let content {
            self.themeName = content.themeName
            self.themeDescription = content.themeDescription
        }
    }
    
    func viewDidLoad() {
        getLabelsText()
    }
    
    var numberOfQuestionsOptionCount: Int {
        numberOfQuestionsOptions.count
    }

    func numberOfQuestionsTitle(at row: Int) -> String? {
        let options = numberOfQuestionsOptions
        guard options.indices.contains(row) else { return nil }
        return String(options[row])
    }
    
    func getLabelsText() {
        view?.updateLabels(themeName: themeName, themeDescription: themeDescription)
    }
    
    func saveNumberOfQuestions(chosenRow: Int) {
        let options = numberOfQuestionsOptions
        guard options.indices.contains(chosenRow) else { return }
        session.questionsCount = options[chosenRow]
    }

    private var numberOfQuestionsOptions: [Int] {
        guard let chosenTheme = session.chosenTheme else {
            return supportedNumberOfQuestionsOptions
        }

        let usableQuestionCount = chosenTheme.questionsAndAnswers.filter(Self.isUsableQuestion).count
        return supportedNumberOfQuestionsOptions.filter { $0 <= usableQuestionCount }
    }

    private static func isUsableQuestion(_ question: QuestionModel) -> Bool {
        !question.questionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        question.answers.count >= 4 &&
        !question.correctAnswer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        question.answers.filter { $0 == question.correctAnswer }.count == 1
    }
}
