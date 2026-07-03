//
//  StatisticsViewController.swift
//  Quizice
//
//  Created by GSD on 03.07.2026.
//

import UIKit

final class StatisticsViewController: UIViewController {
    private let statisticsStore: StatisticsStore

    private let titleLabel = UILabel()
    private let emptyStateLabel = UILabel()
    private let stackView = UIStackView()
    private let playedQuizzesValueLabel = UILabel()
    private let correctAnswersValueLabel = UILabel()
    private let percentageValueLabel = UILabel()
    private let bestResultValueLabel = UILabel()

    init(statisticsStore: StatisticsStore = StatisticsStore()) {
        self.statisticsStore = statisticsStore
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        return nil
    }

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: "backgroundImage") ?? UIImage())
        rootView.accessibilityIdentifier = "statisticsScreen"
        rootView.accessibilityLabel = "Экран общей статистики"
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Статистика"
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render(summary: statisticsStore.loadSummary())
    }

    private func configureProgrammaticSubviews(in rootView: UIView) {
        titleLabel.text = "Статистика"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 34, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityIdentifier = "statisticsTitleLabel"
        titleLabel.accessibilityLabel = "Статистика"

        emptyStateLabel.text = "Пройдите первую викторину, чтобы увидеть общую статистику."
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        emptyStateLabel.font = .systemFont(ofSize: 17, weight: .regular)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isAccessibilityElement = true
        emptyStateLabel.accessibilityIdentifier = "statisticsEmptyStateLabel"
        emptyStateLabel.accessibilityLabel = "Пока нет завершённых викторин. Пройдите первую викторину, чтобы увидеть общую статистику."

        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false

        let playedQuizzesRow = makeStatisticRow(
            title: "Пройдено викторин",
            valueLabel: playedQuizzesValueLabel,
            accessibilityIdentifier: "statisticsPlayedQuizzes"
        )
        let correctAnswersRow = makeStatisticRow(
            title: "Правильных ответов",
            valueLabel: correctAnswersValueLabel,
            accessibilityIdentifier: "statisticsCorrectAnswers"
        )
        let percentageRow = makeStatisticRow(
            title: "Процент правильных",
            valueLabel: percentageValueLabel,
            accessibilityIdentifier: "statisticsPercentage"
        )
        let bestResultRow = makeStatisticRow(
            title: "Лучший результат",
            valueLabel: bestResultValueLabel,
            accessibilityIdentifier: "statisticsBestResult"
        )

        [playedQuizzesRow, correctAnswersRow, percentageRow, bestResultRow].forEach(stackView.addArrangedSubview)
        [titleLabel, emptyStateLabel, stackView].forEach(rootView.addSubview)

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 56),
            titleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),

            emptyStateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            emptyStateLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 32),
            emptyStateLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -32),

            stackView.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 28),
            stackView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -32)
        ])
    }

    private func makeStatisticRow(title: String, valueLabel: UILabel, accessibilityIdentifier: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        containerView.layer.cornerRadius = 18
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isAccessibilityElement = true
        containerView.accessibilityIdentifier = accessibilityIdentifier

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.translatesAutoresizingMaskIntoConstraints = false

        [titleLabel, valueLabel].forEach(containerView.addSubview)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 78),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -12),

            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor)
        ])

        return containerView
    }

    private func render(summary: StatisticsSummary) {
        let correctAnswersDisplay = "\(summary.correctAnswers)/\(summary.totalQuestions)"
        let percentageDisplay = "\(summary.percentage)%"

        playedQuizzesValueLabel.text = "\(summary.playedQuizzes)"
        correctAnswersValueLabel.text = correctAnswersDisplay
        percentageValueLabel.text = percentageDisplay
        bestResultValueLabel.text = summary.bestResultDisplay
        emptyStateLabel.isHidden = summary.playedQuizzes > 0

        updateAccessibility(
            playedQuizzes: summary.playedQuizzes,
            correctAnswersDisplay: correctAnswersDisplay,
            percentageDisplay: percentageDisplay,
            bestResultDisplay: summary.bestResultDisplay
        )
    }

    private func updateAccessibility(
        playedQuizzes: Int,
        correctAnswersDisplay: String,
        percentageDisplay: String,
        bestResultDisplay: String
    ) {
        stackView.arrangedSubviews[safe: 0]?.accessibilityLabel = "Пройдено викторин"
        stackView.arrangedSubviews[safe: 0]?.accessibilityValue = "\(playedQuizzes)"
        stackView.arrangedSubviews[safe: 1]?.accessibilityLabel = "Правильных ответов"
        stackView.arrangedSubviews[safe: 1]?.accessibilityValue = correctAnswersDisplay
        stackView.arrangedSubviews[safe: 2]?.accessibilityLabel = "Процент правильных"
        stackView.arrangedSubviews[safe: 2]?.accessibilityValue = percentageDisplay
        stackView.arrangedSubviews[safe: 3]?.accessibilityLabel = "Лучший результат"
        stackView.arrangedSubviews[safe: 3]?.accessibilityValue = bestResultDisplay
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
