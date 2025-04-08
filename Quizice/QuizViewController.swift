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
            
            self.soundPlayer.play()
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
        QuizFactory.shared.loadTheme(themeName: themeName)
        showDescriptionViewController()
    }
    
    func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }
    
    private func showDescriptionViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QuizDescriptionID") as? QuizDescriptionViewController {
            presenter?.configureDescriptionPresenter(viewController: vc)
            self.present(vc, animated: true)
        }
    }
    
    @IBAction private func randomButtonTapped() {
        QuizFactory.shared.loadTheme(themeName: (QuizFactory.shared.themes?.randomElement()!.theme)!)
        showDescriptionViewController()
    }
    
    @IBAction private func backButtonTapped() {
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
