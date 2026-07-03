//
//  QuizViewController.swift
//  My First App
//
//  Created by Артем Табенский on 01.10.2024.
//

import UIKit
import AVKit

final class QuizViewController: UIViewController, QuizViewControllerProtocol, ThemeCollectionDelegate {
    
    private var welcomeLabel: UILabel!
    private var quiziceLabel: UIImageView!
    private var chooseThemeLabel: UILabel!
    
    private var musicThemeButton: UIButton!
    private var techThemeButton: UIButton!
    private var historyAndCultureThemeButton: UIButton!
    private var politicsAndBusinessThemeButton: UIButton!
    
    private var exitButton: UIButton!
    private var feelingLuckyButton: UIButton!
    private var actionButtonsStackView: UIStackView!
    
    private var themesCollectionView: UICollectionView!
    
    private let animationsEngine = Animations()
    private var soundPlayer: AVAudioPlayer!
    
    let themesCollectionService = ThemesCollectionService()
    var presenter: QuizPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        if let backgroundImage = UIImage(named: "backgroundImage") {
            rootView.backgroundColor = UIColor(patternImage: backgroundImage)
        } else {
            rootView.backgroundColor = .systemBackground
        }
        rootView.accessibilityIdentifier = "homeRootView"
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if QuizFactory.shared.startup1st {
            QuizFactory.shared.loadData()
        }
        
        configurePresenter(QuizPresenter())
        
        themesCollectionView.backgroundColor = .clear
        themesCollectionService.delegate = self
        themesCollectionView.delegate = themesCollectionService
        themesCollectionView.dataSource = themesCollectionService
        themesCollectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "themeCell")
        updateThemeAvailabilityMessage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if QuizFactory.shared.startup1st {
            animateViewsAndPlaySound()
            QuizFactory.shared.startup1st = false
        }
    }
    
    func configurePresenter(_ presenter: any QuizPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        welcomeLabel = makeLabel(text: "Добро пожаловать в", font: .systemFont(ofSize: 26, weight: .semibold))
        welcomeLabel.accessibilityIdentifier = "homeWelcomeLabel"
        welcomeLabel.adjustsFontForContentSizeCategory = true
        quiziceLabel = UIImageView(image: UIImage(named: "Quizice"))
        quiziceLabel.accessibilityIdentifier = "homeLogoImageView"
        quiziceLabel.accessibilityLabel = "Quizice"
        quiziceLabel.contentMode = .scaleAspectFit
        quiziceLabel.translatesAutoresizingMaskIntoConstraints = false
        chooseThemeLabel = makeLabel(text: "Выберите тему", font: .systemFont(ofSize: 24, weight: .semibold))
        chooseThemeLabel.accessibilityIdentifier = "homeChooseThemeLabel"
        chooseThemeLabel.adjustsFontForContentSizeCategory = true
        
        musicThemeButton = makeLegacyThemeButton(named: "Музыка")
        techThemeButton = makeLegacyThemeButton(named: "Технологии")
        historyAndCultureThemeButton = makeLegacyThemeButton(named: "История и культура")
        politicsAndBusinessThemeButton = makeLegacyThemeButton(named: "Политика и бизнес")
        
        exitButton = makeSecondaryActionButton(title: "Выход")
        exitButton.accessibilityIdentifier = "homeExitButton"
        exitButton.accessibilityLabel = "Выход"
        exitButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        feelingLuckyButton = makePrimaryActionButton(title: "Мне повезет")
        feelingLuckyButton.accessibilityIdentifier = "homeFeelingLuckyButton"
        feelingLuckyButton.accessibilityLabel = "Мне повезет"
        feelingLuckyButton.addTarget(self, action: #selector(randomButtonTapped), for: .touchUpInside)
        
        actionButtonsStackView = UIStackView(arrangedSubviews: [feelingLuckyButton, exitButton])
        actionButtonsStackView.accessibilityIdentifier = "homeActionButtonsStackView"
        actionButtonsStackView.axis = .vertical
        actionButtonsStackView.spacing = 12
        actionButtonsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 16
        layout.minimumInteritemSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 24, right: 24)
        themesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        themesCollectionView.accessibilityIdentifier = "homeThemesCollectionView"
        themesCollectionView.accessibilityLabel = "Темы викторины"
        themesCollectionView.alwaysBounceVertical = true
        themesCollectionView.showsVerticalScrollIndicator = false
        themesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        [welcomeLabel, quiziceLabel, chooseThemeLabel, themesCollectionView, actionButtonsStackView].forEach(rootView.addSubview)
        [musicThemeButton, techThemeButton, historyAndCultureThemeButton, politicsAndBusinessThemeButton].forEach { button in
            button.isHidden = true
            rootView.addSubview(button)
        }
        
        NSLayoutConstraint.activate([
            welcomeLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 28),
            welcomeLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            welcomeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            welcomeLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            
            quiziceLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 10),
            quiziceLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            quiziceLabel.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, multiplier: 0.7),
            quiziceLabel.heightAnchor.constraint(equalToConstant: 84),
            
            chooseThemeLabel.topAnchor.constraint(equalTo: quiziceLabel.bottomAnchor, constant: 24),
            chooseThemeLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            chooseThemeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            chooseThemeLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            
            themesCollectionView.topAnchor.constraint(equalTo: chooseThemeLabel.bottomAnchor, constant: 18),
            themesCollectionView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            themesCollectionView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            themesCollectionView.bottomAnchor.constraint(equalTo: feelingLuckyButton.topAnchor, constant: -24),
            
            actionButtonsStackView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            actionButtonsStackView.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 32),
            actionButtonsStackView.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -32),
            actionButtonsStackView.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            actionButtonsStackView.widthAnchor.constraint(lessThanOrEqualToConstant: 280),
            actionButtonsStackView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            
            feelingLuckyButton.heightAnchor.constraint(equalToConstant: 54),
            exitButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func makeLabel(text: String, font: UIFont) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = .white
        label.font = font
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makePrimaryActionButton(title: String) -> UIButton {
        let button = makeBaseActionButton(title: title)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.88)
        button.layer.cornerRadius = 22
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.24
        button.layer.shadowRadius = 14
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        return button
    }
    
    private func makeSecondaryActionButton(title: String) -> UIButton {
        let button = makeBaseActionButton(title: title)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        button.layer.cornerRadius = 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.36).cgColor
        return button
    }
    
    private func makeBaseActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 19, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func makeLegacyThemeButton(named themeName: String) -> UIButton {
        let button = UIButton(type: .custom)
        button.accessibilityIdentifier = themeName
        button.setImage(UIImage(named: themeName), for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    private func hideAllViews() {
        let views = [welcomeLabel, quiziceLabel, themesCollectionView, chooseThemeLabel, actionButtonsStackView]
        views.forEach { view in
            view?.alpha = 0
        }
    }
    
    private func animateViewsAndPlaySound() {
        
        let views = [welcomeLabel, quiziceLabel, themesCollectionView, chooseThemeLabel, actionButtonsStackView]
        let visibleCells = themesCollectionView.visibleCells.sorted { $0.frame.origin.x < $1.frame.origin.x }
        
        views.forEach { view in
            view?.alpha = 0
        }
        
        visibleCells.forEach { cell in
            cell.alpha = 0
        }
        
        visibleCells.forEach { cell in
            cell.isUserInteractionEnabled = false
        }
        
        if let startupSoundURL = Bundle.main.url(forResource: "Quizice Enter", withExtension: "m4a") {
            soundPlayer = try? AVAudioPlayer(contentsOf: startupSoundURL)
        }
        
        welcomeLabel.fadeIn(duration: 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            self.soundPlayer?.play()
            self.quiziceLabel.fadeIn(duration: 2)
            self.themesCollectionView.alpha = 1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                
                self.chooseThemeLabel.fadeIn(duration: 1)
                self.actionButtonsStackView.fadeIn(duration: 1)
               
                for (index, cell) in visibleCells.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                        cell.fadeIn(duration: 1) {
                            cell.isUserInteractionEnabled = true
                        }
                    }
                }
            }
        }
    }
    
    func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }
    
    func themeButtonTouchedUpInside(_ sender: UIButton, themeName: String) {
        animationsEngine.animateUpFloat(sender)
        guard QuizFactory.shared.loadTheme(themeName: themeName) else {
            updateThemeAvailabilityMessage()
            return
        }
        showDescriptionViewController()
    }
    
    func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }
    
    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        let viewController = StatisticsViewController()
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func showDescriptionViewController() {
        let viewController = QuizDescriptionViewController()
        presenter?.configureDescriptionPresenter(viewController: viewController)
        navigationController?.pushViewController(viewController, animated: true)
    }
    
    private func updateThemeAvailabilityMessage() {
        let hasThemes = QuizFactory.shared.themes?.isEmpty == false
        chooseThemeLabel.text = hasThemes ? "Выберите тему" : "Темы пока недоступны"
    }
    
    @objc private func randomButtonTapped() {
        guard
            let theme = QuizFactory.shared.themes?.randomElement()?.theme,
            QuizFactory.shared.loadTheme(themeName: theme)
        else {
            updateThemeAvailabilityMessage()
            return
        }
        showDescriptionViewController()
    }
    
    @objc private func backButtonTapped() {
        let alert = UIAlertController(
            title: "Выход",
            message: "Вы уверены что хотите выйти?",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Нет", style: .cancel))
        alert.addAction(UIAlertAction(title: "Да", style: .destructive, handler: { _ in
            exit(-1)
        }))
        present(alert, animated: true)
    }
}
