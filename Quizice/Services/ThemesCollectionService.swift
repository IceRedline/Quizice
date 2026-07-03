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
        (quizFactory.themes?.count ?? 0) + 1
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "themeCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = .clear
        cell.backgroundColor = .clear
        
        if indexPath.item == 0 {
            configureStatisticsCard(in: cell)
            return cell
        }
        
        let themeIndex = indexPath.item - 1
        guard let theme = quizFactory.themes?[safe: themeIndex] else {
            return cell
        }
        configureThemeCard(in: cell, themeName: theme.theme)
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize { CGSize(width: 160, height: 160) }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { 20 }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { 20 }
    
    // MARK: - Methods
    
    private func configureThemeCard(in cell: UICollectionViewCell, themeName: String) {
        let button = UIButton(type: .custom)
        
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeName
        button.setImage(UIImage(named: themeName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 160),
            button.heightAnchor.constraint(equalToConstant: 160),
            button.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
        ])
    }
    
    private func configureStatisticsCard(in cell: UICollectionViewCell) {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "homeStatisticsCard"
        button.accessibilityLabel = "Общая статистика"
        button.accessibilityHint = "Открывает экран общей статистики по завершённым викторинам"
        button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        button.layer.cornerRadius = 24
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.36).cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(statisticsButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        
        let titleLabel = UILabel()
        titleLabel.text = "Статистика"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Общие итоги квизов"
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.84)
        descriptionLabel.font = .systemFont(ofSize: 14, weight: .medium)
        descriptionLabel.textAlignment = .center
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(button)
        button.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 160),
            button.heightAnchor.constraint(equalToConstant: 160),
            button.centerXAnchor.constraint(equalTo: cell.contentView.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: cell.contentView.centerYAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 14),
            stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -14),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
    }
    
    @objc func buttonTouchedDown(_ sender: UIButton) {
        delegate?.themeButtonTouchedDown(sender)
    }
    
    @objc func buttonTouchedUpInside(_ sender: UIButton) {
        guard
            let themeName = sender.accessibilityIdentifier,
            quizFactory.themes?.contains(where: { $0.theme == themeName }) == true
        else { return }
        delegate?.themeButtonTouchedUpInside(sender, themeName: themeName)
    }
    
    @objc func buttonTouchedUpOutside(_ sender: UIButton) {
        delegate?.themeButtonTouchedUpOutside(sender)
    }
    
    @objc func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        delegate?.statisticsButtonTouchedUpInside(sender)
    }
    
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
