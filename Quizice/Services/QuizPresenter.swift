//
//  QuizPresenter.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import Foundation

final class QuizPresenter: QuizPresenterProtocol {
    var view: QuizViewControllerProtocol?
    
    func configureDescriptionPresenter(viewController: QuizDescriptionViewController) {
        viewController.configurePresenter(QuizDescriptionPresenter())
        viewController.presenter?.themeName = QuizFactory.shared.chosenTheme?.themeName ?? "no themeName"
        viewController.presenter?.themeDescription = QuizFactory.shared.chosenTheme?.description ?? "no description"
    }
    
}
