//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

final class QuizDescriptionViewController: UIViewController, QuizDescriptionViewControllerProtocol {
    
    @IBOutlet weak var themeNameLabel: UILabel!
    @IBOutlet weak var themeDescriptionLabel: UILabel!
    @IBOutlet weak var numberOfQuestionsPickerView: UIPickerView!
    
    private var startButton: UIButton!
    private var backButton: UIButton!
    
    var presenter: QuizDescriptionPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presenter?.configurePickerView(numberOfQuestionsPickerView)
        presenter?.viewDidLoad()
        
        numberOfQuestionsPickerView.setValue(UIColor.white, forKey: "textColor")
    }
    
    func updateLabels(themeName: String, themeDescription: String) {
        themeNameLabel.text = themeName
        themeDescriptionLabel.text = themeDescription
    }
    
    func configurePresenter(_ presenter: QuizDescriptionPresenterProtocol) {
        self.presenter = presenter
        self.presenter?.view = self
    }
    
    private func configureProgrammaticSubviews(in rootView: UIView) {
        themeNameLabel = makeLabel(font: .systemFont(ofSize: 34, weight: .bold))
        themeDescriptionLabel = makeLabel(font: .systemFont(ofSize: 20, weight: .regular))
        themeDescriptionLabel.numberOfLines = 0
        
        numberOfQuestionsPickerView = UIPickerView()
        numberOfQuestionsPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        startButton = makeActionButton(title: "Начать")
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        
        backButton = makeActionButton(title: "Назад")
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        [themeNameLabel, themeDescriptionLabel, numberOfQuestionsPickerView, startButton, backButton].forEach(rootView.addSubview)
        
        NSLayoutConstraint.activate([
            themeNameLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 56),
            themeNameLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            themeNameLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            
            themeDescriptionLabel.topAnchor.constraint(equalTo: themeNameLabel.bottomAnchor, constant: 28),
            themeDescriptionLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 32),
            themeDescriptionLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -32),
            
            numberOfQuestionsPickerView.topAnchor.constraint(equalTo: themeDescriptionLabel.bottomAnchor, constant: 28),
            numberOfQuestionsPickerView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            numberOfQuestionsPickerView.widthAnchor.constraint(equalTo: rootView.widthAnchor, multiplier: 0.7),
            numberOfQuestionsPickerView.heightAnchor.constraint(equalToConstant: 140),
            
            startButton.topAnchor.constraint(greaterThanOrEqualTo: numberOfQuestionsPickerView.bottomAnchor, constant: 36),
            startButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 220),
            startButton.heightAnchor.constraint(equalToConstant: 52),
            
            backButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 16),
            backButton.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 220),
            backButton.heightAnchor.constraint(equalToConstant: 52),
            backButton.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -32)
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
    
    @objc private func startButtonTapped() {
        presenter?.saveNumberOfQuestions(chosenRow: numberOfQuestionsPickerView.selectedRow(inComponent: 0))
        
        let viewController = QuizQuestionViewController()
        viewController.modalPresentationStyle = .fullScreen
        present(viewController, animated: true)
    }
    
    @objc private func backButtonTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}
