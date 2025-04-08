//
//  ThemeCollectionDelegate.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import UIKit

protocol ThemeCollectionDelegate {
    func themeButtonTouchedDown(_ sender: UIButton)
    func themeButtonTouchedUpInside(_ sender: UIButton, themeName: String)
    func themeButtonTouchedUpOutside(_ sender: UIButton)
}
