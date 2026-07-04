//
//  QuizPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import Foundation

final class QuizPresenter: QuizPresenterProtocol {
    weak var view: QuizViewControllerProtocol?

    func configureDescriptionPresenter(viewController: QuizDescriptionViewController) {
        viewController.configurePresenter(QuizDescriptionPresenter())
        viewController.presenter?.themeName = QuizFactory.shared.chosenTheme?.themeName ?? L10n.Description.defaultThemeName
        viewController.presenter?.themeDescription = QuizFactory.shared.chosenTheme?.description ?? L10n.Description.defaultThemeDescription
    }
    
}
