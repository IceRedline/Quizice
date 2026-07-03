//
//  QuizResultViewController.swift
//  My First App
//
//  Created by Артем Табенский on 07.10.2024.
//

import UIKit

final class QuizResultViewController: UIViewController, QuizResultViewControllerProtocol {
    
    private var resultCardView: UIView!
    private var contentStackView: UIStackView!
    private var resultLabel: UILabel!
    private var resultDescription: UILabel!
    
    private var restartButton: UIButton!
    
    var presenter: QuizResultPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        rootView.accessibilityIdentifier = "resultRootView"
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
        resultCardView = UIView()
        resultCardView.accessibilityIdentifier = "resultCardView"
        resultCardView.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        resultCardView.layer.cornerRadius = 30
        resultCardView.layer.borderWidth = 1
        resultCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        resultCardView.layer.shadowColor = UIColor.black.cgColor
        resultCardView.layer.shadowOpacity = 0.22
        resultCardView.layer.shadowRadius = 16
        resultCardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        resultCardView.translatesAutoresizingMaskIntoConstraints = false
        
        resultLabel = makeLabel(font: .systemFont(ofSize: 38, weight: .bold), accessibilityIdentifier: "resultScoreLabel")
        resultLabel.numberOfLines = 0
        resultLabel.adjustsFontSizeToFitWidth = true
        resultLabel.minimumScaleFactor = 0.82
        
        resultDescription = makeLabel(font: .systemFont(ofSize: 21, weight: .regular), accessibilityIdentifier: "resultDescriptionLabel")
        resultDescription.numberOfLines = 0
        resultDescription.textColor = UIColor.white.withAlphaComponent(0.9)
        
        restartButton = makeActionButton(title: "Начать заново", accessibilityIdentifier: "resultRestartButton")
        restartButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        contentStackView = UIStackView(arrangedSubviews: [resultLabel, resultDescription, restartButton])
        contentStackView.accessibilityIdentifier = "resultContentStackView"
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 22
        contentStackView.setCustomSpacing(26, after: resultLabel)
        contentStackView.setCustomSpacing(38, after: resultDescription)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        rootView.addSubview(resultCardView)
        resultCardView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            resultCardView.centerYAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.centerYAnchor),
            resultCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),
            resultCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -20),
            resultCardView.topAnchor.constraint(greaterThanOrEqualTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 48),
            resultCardView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -48),
            
            contentStackView.topAnchor.constraint(equalTo: resultCardView.topAnchor, constant: 34),
            contentStackView.leadingAnchor.constraint(equalTo: resultCardView.leadingAnchor, constant: 24),
            contentStackView.trailingAnchor.constraint(equalTo: resultCardView.trailingAnchor, constant: -24),
            contentStackView.bottomAnchor.constraint(equalTo: resultCardView.bottomAnchor, constant: -30),
            
            restartButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }
    
    private func makeLabel(font: UIFont, accessibilityIdentifier: String) -> UILabel {
        let label = UILabel()
        label.accessibilityIdentifier = accessibilityIdentifier
        label.textColor = .white
        label.font = font
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }
    
    private func makeActionButton(title: String, accessibilityIdentifier: String) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.backgroundColor = UIColor.white.withAlphaComponent(0.22)
        button.layer.cornerRadius = 22
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(0.5).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = 0.2
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
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
