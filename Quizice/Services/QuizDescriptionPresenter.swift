//
//  QuizDescriptionPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 28.03.2025.
//

import Foundation

final class QuizDescriptionPresenter: QuizDescriptionPresenterProtocol {
    private let numberOfQuestionsOptions: [Int] = [5, 10, 15]
    private let session: QuizSessionManaging

    weak var view: QuizDescriptionViewControllerProtocol?

    var themeName: String = L10n.Description.defaultThemeName
    var themeDescription: String = L10n.Description.defaultThemeDescription
    var themeID: String? {
        session.chosenTheme?.themeID
    }
    
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
        guard numberOfQuestionsOptions.indices.contains(row) else { return nil }
        return String(numberOfQuestionsOptions[row])
    }
    
    func getLabelsText() {
        view?.updateLabels(themeName: themeName, themeDescription: themeDescription)
    }
    
    func saveNumberOfQuestions(chosenRow: Int) {
        guard numberOfQuestionsOptions.indices.contains(chosenRow) else { return }
        session.questionsCount = numberOfQuestionsOptions[chosenRow]
    }
}
