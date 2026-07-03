//
//  QuizResultViewController.swift
//  My First App
//
//  Created by Артем Табенский on 07.10.2024.
//

import UIKit

final class QuizResultViewController: UIViewController, QuizResultViewControllerProtocol {
    
    private var resultLabel: UILabel!
    private var resultDescription: UILabel!
    
    private var restartButton: UIButton!
    
    var presenter: QuizResultPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter?.viewDidLoad()
    }
    
    func configurePresenter(_ presenter: QuizResultPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    func updateResultLabels(resultText: String, descriptionText: String) {
        resultLabel.text = resultText
        resultDescription.text = descriptionText
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        resultLabel = makeLabel(font: .systemFont(ofSize: 36, weight: .bold))
        resultDescription = makeLabel(font: .systemFont(ofSize: 22, weight: .regular))
        resultDescription.numberOfLines = 0
        
        restartButton = makeActionButton(title: "Начать заново")
        restartButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        [resultLabel, resultDescription, restartButton].forEach(rootView.addSubview)
        
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 96),
            resultLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 28),
            resultLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -28),
            
            resultDescription.topAnchor.constraint(equalTo: resultLabel.bottomAnchor, constant: 40),
            resultDescription.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 32),
            resultDescription.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -32),
            
            restartButton.topAnchor.constraint(greaterThanOrEqualTo: resultDescription.bottomAnchor, constant: 52),
            restartButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            restartButton.widthAnchor.constraint(equalToConstant: 240),
            restartButton.heightAnchor.constraint(equalToConstant: 54),
            restartButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -48)
        ])
    }
    
    private func makeLabel(font: UIFont) -> UILabel {
        let label = UILabel()
        label.textColor = .white
        label.font = font
        label.textAlignment = .center
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
    
    @IBAction func backButtonTapped() {
        let rootViewController = QuizViewController()
        let navigationController = UINavigationController(rootViewController: rootViewController)
        navigationController.setNavigationBarHidden(true, animated: false)
        view.window?.rootViewController = navigationController
        view.window?.makeKeyAndVisible()
    }
}
