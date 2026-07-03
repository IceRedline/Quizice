//
//  QuizDescriptionViewController.swift
//  My First App
//
//  Created by Артем Табенский on 02.10.2024.
//

import UIKit

final class QuizDescriptionViewController: UIViewController, QuizDescriptionViewControllerProtocol {
    
    private var scrollView: UIScrollView!
    private var contentCardView: UIView!
    private var contentStackView: UIStackView!
    private var themeNameLabel: UILabel!
    private var themeDescriptionLabel: UILabel!
    private var pickerCaptionLabel: UILabel!
    private var numberOfQuestionsPickerView: UIPickerView!
    
    private var startButton: UIButton!
    private var backButton: UIButton!
    
    var presenter: QuizDescriptionPresenterProtocol?
    
    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        rootView.accessibilityIdentifier = "descriptionRootView"
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
        scrollView = UIScrollView()
        scrollView.accessibilityIdentifier = "descriptionScrollView"
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        contentCardView = UIView()
        contentCardView.accessibilityIdentifier = "descriptionContentCardView"
        contentCardView.backgroundColor = UIColor.black.withAlphaComponent(0.26)
        contentCardView.layer.cornerRadius = 30
        contentCardView.layer.borderWidth = 1
        contentCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.18).cgColor
        contentCardView.layer.shadowColor = UIColor.black.cgColor
        contentCardView.layer.shadowOpacity = 0.22
        contentCardView.layer.shadowRadius = 16
        contentCardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        contentCardView.translatesAutoresizingMaskIntoConstraints = false
        
        themeNameLabel = makeLabel(font: .systemFont(ofSize: 34, weight: .bold), accessibilityIdentifier: "descriptionThemeNameLabel")
        themeNameLabel.numberOfLines = 0
        themeNameLabel.adjustsFontSizeToFitWidth = true
        themeNameLabel.minimumScaleFactor = 0.82
        
        themeDescriptionLabel = makeLabel(font: .systemFont(ofSize: 19, weight: .regular), accessibilityIdentifier: "descriptionTextLabel")
        themeDescriptionLabel.numberOfLines = 0
        themeDescriptionLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        
        pickerCaptionLabel = makeLabel(font: .systemFont(ofSize: 17, weight: .semibold), accessibilityIdentifier: "descriptionPickerCaptionLabel")
        pickerCaptionLabel.text = L10n.Description.questionCount
        pickerCaptionLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        
        numberOfQuestionsPickerView = UIPickerView()
        numberOfQuestionsPickerView.accessibilityIdentifier = "descriptionQuestionCountPicker"
        numberOfQuestionsPickerView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        numberOfQuestionsPickerView.layer.cornerRadius = 22
        numberOfQuestionsPickerView.layer.borderWidth = 1
        numberOfQuestionsPickerView.layer.borderColor = UIColor.white.withAlphaComponent(0.16).cgColor
        numberOfQuestionsPickerView.translatesAutoresizingMaskIntoConstraints = false
        
        startButton = makeActionButton(title: L10n.Common.start, accessibilityIdentifier: "descriptionStartButton", isPrimary: true)
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        
        backButton = makeActionButton(title: L10n.Common.back, accessibilityIdentifier: "descriptionBackButton", isPrimary: false)
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        
        contentStackView = UIStackView(arrangedSubviews: [
            themeNameLabel,
            themeDescriptionLabel,
            pickerCaptionLabel,
            numberOfQuestionsPickerView,
            startButton,
            backButton
        ])
        contentStackView.accessibilityIdentifier = "descriptionContentStackView"
        contentStackView.axis = .vertical
        contentStackView.alignment = .fill
        contentStackView.spacing = 18
        contentStackView.setCustomSpacing(24, after: themeNameLabel)
        contentStackView.setCustomSpacing(26, after: themeDescriptionLabel)
        contentStackView.setCustomSpacing(8, after: pickerCaptionLabel)
        contentStackView.setCustomSpacing(28, after: numberOfQuestionsPickerView)
        contentStackView.setCustomSpacing(12, after: startButton)
        contentStackView.translatesAutoresizingMaskIntoConstraints = false
        
        rootView.addSubview(scrollView)
        scrollView.addSubview(contentCardView)
        contentCardView.addSubview(contentStackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.bottomAnchor),
            
            contentCardView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 36),
            contentCardView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentCardView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
            contentCardView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentCardView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor, constant: -64),
            
            contentStackView.topAnchor.constraint(equalTo: contentCardView.topAnchor, constant: 28),
            contentStackView.leadingAnchor.constraint(equalTo: contentCardView.leadingAnchor, constant: 22),
            contentStackView.trailingAnchor.constraint(equalTo: contentCardView.trailingAnchor, constant: -22),
            contentStackView.bottomAnchor.constraint(lessThanOrEqualTo: contentCardView.bottomAnchor, constant: -26),
            
            numberOfQuestionsPickerView.heightAnchor.constraint(equalToConstant: 136),
            startButton.heightAnchor.constraint(equalToConstant: 54),
            backButton.heightAnchor.constraint(equalToConstant: 50),
            backButton.bottomAnchor.constraint(equalTo: contentCardView.bottomAnchor, constant: -26)
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
    
    private func makeActionButton(title: String, accessibilityIdentifier: String, isPrimary: Bool) -> UIButton {
        let button = UIButton(type: .system)
        button.accessibilityIdentifier = accessibilityIdentifier
        button.setTitle(title, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(UIColor.white.withAlphaComponent(0.45), for: .disabled)
        button.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        button.backgroundColor = isPrimary ? UIColor.white.withAlphaComponent(0.22) : UIColor.white.withAlphaComponent(0.12)
        button.layer.cornerRadius = isPrimary ? 22 : 20
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.white.withAlphaComponent(isPrimary ? 0.5 : 0.34).cgColor
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOpacity = isPrimary ? 0.2 : 0
        button.layer.shadowRadius = 10
        button.layer.shadowOffset = CGSize(width: 0, height: 6)
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
