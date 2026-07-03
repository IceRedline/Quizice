//
//  QuizViewController.swift
//  My First App
//
//  Created by Артем Табенский on 01.10.2024.
//

import UIKit
import AVKit

final class QuizViewController: UIViewController, QuizViewControllerProtocol, ThemeCollectionDelegate {
    
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var quiziceLabel: UIImageView!
    @IBOutlet weak var chooseThemeLabel: UILabel!
    
    @IBOutlet weak var musicThemeButton: UIButton!
    @IBOutlet weak var techThemeButton: UIButton!
    @IBOutlet weak var historyAndCultureThemeButton: UIButton!
    @IBOutlet weak var politicsAndBusinessThemeButton: UIButton!
    
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet weak var feelingLuckyButton: UIButton!
    
    @IBOutlet weak var themesCollectionView: UICollectionView!
    
    private let animationsEngine = Animations()
    private var soundPlayer: AVAudioPlayer!
    
    let themesCollectionService = ThemesCollectionService()
    var presenter: QuizPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
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
        welcomeLabel = makeLabel(text: "Добро пожаловать в", font: .systemFont(ofSize: 30, weight: .semibold))
        quiziceLabel = UIImageView(image: UIImage(named: "Quizice"))
        quiziceLabel.contentMode = .scaleAspectFit
        quiziceLabel.translatesAutoresizingMaskIntoConstraints = false
        chooseThemeLabel = makeLabel(text: "Выберите тему", font: .systemFont(ofSize: 28, weight: .semibold))
        
        musicThemeButton = makeLegacyThemeButton(named: "Музыка")
        techThemeButton = makeLegacyThemeButton(named: "Технологии")
        historyAndCultureThemeButton = makeLegacyThemeButton(named: "История и культура")
        politicsAndBusinessThemeButton = makeLegacyThemeButton(named: "Политика и бизнес")
        
        exitButton = makeActionButton(title: "Выход")
        exitButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        feelingLuckyButton = makeActionButton(title: "Мне повезет")
        feelingLuckyButton.addTarget(self, action: #selector(randomButtonTapped), for: .touchUpInside)
        
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 160, height: 160)
        layout.minimumLineSpacing = 20
        layout.minimumInteritemSpacing = 20
        layout.sectionInset = UIEdgeInsets(top: 0, left: 24, bottom: 0, right: 24)
        themesCollectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        themesCollectionView.showsHorizontalScrollIndicator = false
        themesCollectionView.translatesAutoresizingMaskIntoConstraints = false
        
        [welcomeLabel, quiziceLabel, chooseThemeLabel, themesCollectionView, exitButton, feelingLuckyButton].forEach(rootView.addSubview)
        [musicThemeButton, techThemeButton, historyAndCultureThemeButton, politicsAndBusinessThemeButton].forEach { button in
            button.isHidden = true
            rootView.addSubview(button)
        }
        
        NSLayoutConstraint.activate([
            welcomeLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 48),
            welcomeLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            welcomeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            welcomeLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            
            quiziceLabel.topAnchor.constraint(equalTo: welcomeLabel.bottomAnchor, constant: 16),
            quiziceLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            quiziceLabel.widthAnchor.constraint(lessThanOrEqualTo: rootView.widthAnchor, multiplier: 0.78),
            quiziceLabel.heightAnchor.constraint(equalToConstant: 96),
            
            chooseThemeLabel.topAnchor.constraint(equalTo: quiziceLabel.bottomAnchor, constant: 36),
            chooseThemeLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            chooseThemeLabel.leadingAnchor.constraint(greaterThanOrEqualTo: rootView.leadingAnchor, constant: 24),
            chooseThemeLabel.trailingAnchor.constraint(lessThanOrEqualTo: rootView.trailingAnchor, constant: -24),
            
            themesCollectionView.topAnchor.constraint(equalTo: chooseThemeLabel.bottomAnchor, constant: 24),
            themesCollectionView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            themesCollectionView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            themesCollectionView.heightAnchor.constraint(equalToConstant: 180),
            
            feelingLuckyButton.topAnchor.constraint(greaterThanOrEqualTo: themesCollectionView.bottomAnchor, constant: 32),
            feelingLuckyButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            feelingLuckyButton.widthAnchor.constraint(equalToConstant: 220),
            feelingLuckyButton.heightAnchor.constraint(equalToConstant: 52),
            
            exitButton.topAnchor.constraint(equalTo: feelingLuckyButton.bottomAnchor, constant: 16),
            exitButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            exitButton.widthAnchor.constraint(equalToConstant: 220),
            exitButton.heightAnchor.constraint(equalToConstant: 52),
            exitButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -32)
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
    
    private func makeActionButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        button.layer.cornerRadius = 18
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.4).cgColor
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
        let views = [welcomeLabel, quiziceLabel, themesCollectionView, chooseThemeLabel, exitButton, feelingLuckyButton]
        views.forEach { view in
            view?.alpha = 0
        }
    }
    
    private func animateViewsAndPlaySound() {
        
        let views = [welcomeLabel, quiziceLabel, themesCollectionView, chooseThemeLabel, exitButton, feelingLuckyButton]
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
                self.exitButton.fadeIn(duration: 1)
                self.feelingLuckyButton.fadeIn(duration: 1)
               
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
