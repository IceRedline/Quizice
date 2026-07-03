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
    private let sectionInsets = UIEdgeInsets(top: 0, left: 24, bottom: 32, right: 24)
    private let itemSpacing: CGFloat = 16
    private let themeCardCornerRadius: CGFloat = 28
    private let statisticsCardCornerRadius: CGFloat = 30
    
    private var statisticsIndex: Int {
        quizFactory.themes?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        statisticsIndex + 1
    }
    
    // MARK: - UICollectionViewDataSource
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "themeCell", for: indexPath)
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }
        cell.contentView.backgroundColor = .clear
        cell.contentView.clipsToBounds = false
        cell.backgroundColor = .clear
        cell.layer.masksToBounds = false
        cell.layer.shadowColor = UIColor.black.cgColor
        cell.layer.shadowOffset = CGSize(width: 0, height: 12)
        cell.layer.shadowRadius = 22
        cell.layer.shadowOpacity = 0.22
        
        if indexPath.item == statisticsIndex {
            configureStatisticsCard(in: cell)
            return cell
        }
        
        guard let theme = quizFactory.themes?[safe: indexPath.item] else {
            return cell
        }
        configureThemeCard(in: cell, themeName: theme.theme)
        return cell
    }
    
    
    // MARK: - UICollectionViewDelegateFlowLayout

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let availableWidth = max(collectionView.bounds.width - sectionInsets.left - sectionInsets.right, 0)
        if indexPath.item == statisticsIndex {
            return CGSize(width: availableWidth, height: 112)
        }
        
        let twoColumnWidth = floor((availableWidth - itemSpacing) / 2)
        return CGSize(width: twoColumnWidth, height: twoColumnWidth)
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat { itemSpacing }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat { itemSpacing }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets { sectionInsets }
    
    // MARK: - Methods
    
    private func configureThemeCard(in cell: UICollectionViewCell, themeName: String) {
        let button = UIButton(type: .custom)
        
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        button.accessibilityIdentifier = themeName
        button.accessibilityLabel = "\(themeName) theme card"
        button.accessibilityHint = "Starts a quiz in this theme"
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = themeCardCornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        button.clipsToBounds = true
        button.adjustsImageWhenHighlighted = false
        button.imageEdgeInsets = UIEdgeInsets(top: 18, left: 18, bottom: 18, right: 18)
        button.setImage(UIImage(named: themeName), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.translatesAutoresizingMaskIntoConstraints = false
        cell.contentView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
        ])
    }
    
    private func configureStatisticsCard(in cell: UICollectionViewCell) {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = "homeStatisticsCard"
        button.accessibilityLabel = "Общая статистика"
        button.accessibilityHint = "Открывает экран общей статистики по завершённым викторинам"
        button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
        button.layer.cornerRadius = statisticsCardCornerRadius
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.40).cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(buttonTouchedDown(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(statisticsButtonTouchedUpInside(_:)), for: .touchUpInside)
        button.addTarget(self, action: #selector(buttonTouchedUpOutside(_:)), for: .touchUpOutside)
        
        let titleLabel = UILabel()
        titleLabel.text = "Статистика"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .left
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Общие итоги квизов"
        descriptionLabel.textColor = UIColor.white.withAlphaComponent(0.84)
        descriptionLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        descriptionLabel.textAlignment = .left
        descriptionLabel.numberOfLines = 2
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let stackView = UIStackView(arrangedSubviews: [titleLabel, descriptionLabel])
        stackView.axis = .vertical
        stackView.alignment = .leading
        stackView.spacing = 6
        stackView.isUserInteractionEnabled = false
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(button)
        button.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            button.topAnchor.constraint(equalTo: cell.contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor),
            
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: -24),
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
