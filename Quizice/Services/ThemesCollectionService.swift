//
//  File.swift
//  Quizice
//
//  Created by Артем Табенский on 08.04.2025.
//

import UIKit

final class ThemesCollectionService: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    var delegate: ThemeCollectionDelegate?
    
    private let quizFactory = QuizFactory.shared
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if let themesCount = quizFactory.themes?.count {
            return themesCount
        } else {
            fatalError("Не удалось задать колчество ячеек коллекции")
        }
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "themeCell", for: indexPath)
        let themeName = quizFactory.themes?[indexPath.item].theme ?? "Музыка"
        let button = UIButton()
        
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeName
        button.setImage(UIImage(named: themeName), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 160),
            button.heightAnchor.constraint(equalToConstant: 160),
            button.centerXAnchor.constraint(equalTo: cell.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: 160, height: 160) }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { 20 }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 20 }
    
    // MARK: - Methods
    
    @objc func buttonTouchedDown(_ sender: UIButton) {
        delegate?.themeButtonTouchedDown(sender)
    }
    
    @objc func buttonTouchedUpInside(_ sender: UIButton) {
        delegate?.themeButtonTouchedUpInside(sender, themeName: sender.accessibilityIdentifier!)
    }
    
    @objc func buttonTouchedUpOutside(_ sender: UIButton) {
        delegate?.themeButtonTouchedUpOutside(sender)
    }
    
}
