//
//  QuizViewController.swift
//  My First App
//
//  Created by Артем Табенский on 01.10.2024.
//

import UIKit
import AVKit

final class QuizViewController: UIViewController {
    
    @IBOutlet weak var welcomeLabel: UILabel!
    @IBOutlet weak var quiziceLabel: UIImageView!
    @IBOutlet weak var chooseThemeLabel: UILabel!
    
    @IBOutlet weak var musicThemeButton: UIButton!
    @IBOutlet weak var techThemeButton: UIButton!
    @IBOutlet weak var historyAndCultureThemeButton: UIButton!
    @IBOutlet weak var politicsAndBusinessThemeButton: UIButton!
    
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet weak var feelingLuckyButton: UIButton!
    
    private let animationsEngine = Animations()
    private var soundPlayer: AVAudioPlayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if QuizFactory.shared.startup1st == true {
            QuizFactory.shared.loadData()
            animateViewsAndPlaySound()
            QuizFactory.shared.startup1st = false
        }
    }
    
    private func animateViewsAndPlaySound() {
        
        let views = [welcomeLabel, quiziceLabel, chooseThemeLabel, musicThemeButton, techThemeButton, historyAndCultureThemeButton, politicsAndBusinessThemeButton, exitButton, feelingLuckyButton]
        let buttons = [musicThemeButton, techThemeButton, historyAndCultureThemeButton, politicsAndBusinessThemeButton]
        
        views.forEach { view in
            view?.alpha = 0
        }
        buttons.forEach { button in
            button?.isEnabled = false
        }
        
        if let startupSoundURL = Bundle.main.url(forResource: "Quizice Enter", withExtension: "m4a") {
            soundPlayer = try? AVAudioPlayer(contentsOf: startupSoundURL)
        }
        
        welcomeLabel.fadeIn(duration: 1)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            
            self.soundPlayer.play()
            self.quiziceLabel.fadeIn(duration: 2)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                
                self.chooseThemeLabel.fadeIn(duration: 1)
                self.exitButton.fadeIn(duration: 1)
                self.feelingLuckyButton.fadeIn(duration: 1)
                
                for (index, button) in buttons.enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.15) {
                        button?.fadeIn(duration: 1) {
                            button?.isEnabled = true
                        }
                    }
                }
            }
        }
    }
    
    @IBAction private func themeButtonTouchedDown(_ sender: UIButton) {
        animationsEngine.animateDownFloat(sender)
    }
    
    @IBAction private func themeButtonTouchedUpInside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
        QuizFactory.shared.loadTheme(button: sender)
        showDescriptionViewController()
    }
    
    @IBAction private func themeButtonTouchedUpOutside(_ sender: UIButton) {
        animationsEngine.animateUpFloat(sender)
    }
    
    private func showDescriptionViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let vc = storyboard.instantiateViewController(withIdentifier: "QuizDescriptionID") as? QuizDescriptionViewController {
            configureDescriptionPresenter(viewController: vc)
            self.present(vc, animated: true)
        }
    }
    
    func configureDescriptionPresenter(viewController: QuizDescriptionViewController) {
        viewController.configurePresenter(QuizDescriptionPresenter())
        viewController.presenter?.themeName = QuizFactory.shared.chosenTheme?.themeName ?? "no themeName"
        viewController.presenter?.themeDescription = QuizFactory.shared.chosenTheme?.description ?? "no description"
    }
    
    @IBAction private func progressButtonTapped() {
        let alert = UIAlertController(
            title: "Ой!",
            message: "Этой страницы пока нету",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "ОК", style: .default))
        present(alert, animated: true)
    }
    
    @IBAction private func backButtonTapped() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let vc = storyboard.instantiateViewController(withIdentifier: "Navigation")
        self.present(vc, animated: true)
    }
    
}
