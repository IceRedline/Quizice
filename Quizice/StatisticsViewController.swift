//
//  StatisticsViewController.swift
//  Quizice
//
//  Created by GSD on 03.07.2026.
//

import UIKit

final class StatisticsViewController: UIViewController {
    private let statisticsStore: StatisticsStore

    private let backButton = UIButton(type: .system)
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let summaryCardView = UIView()
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
        rootView.accessibilityLabel = L10n.Statistics.accessibilityLabel
        view = rootView
        configureProgrammaticSubviews(in: rootView)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = L10n.Statistics.title
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        render(summary: statisticsStore.loadSummary())
    }

    private func configureProgrammaticSubviews(in rootView: UIView) {
        backButton.setTitle(L10n.Common.back, for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        backButton.backgroundColor = UIColor.white.withAlphaComponent(0.16)
        backButton.layer.cornerRadius = 20
        backButton.layer.borderWidth = 1
        backButton.layer.borderColor = UIColor.white.withAlphaComponent(0.24).cgColor
        backButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 18, bottom: 10, right: 18)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.accessibilityIdentifier = "statisticsBackButton"
        backButton.accessibilityLabel = L10n.Common.back
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)

        titleLabel.text = L10n.Statistics.title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 36, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityIdentifier = "statisticsTitleLabel"
        titleLabel.accessibilityLabel = L10n.Statistics.title

        subtitleLabel.text = L10n.Statistics.subtitleWithStats
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.82)
        subtitleLabel.font = .systemFont(ofSize: 18, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isAccessibilityElement = true
        subtitleLabel.accessibilityIdentifier = "statisticsSubtitleLabel"

        summaryCardView.backgroundColor = UIColor.white.withAlphaComponent(0.14)
        summaryCardView.layer.cornerRadius = 30
        summaryCardView.layer.borderWidth = 1
        summaryCardView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
        summaryCardView.layer.shadowColor = UIColor.black.cgColor
        summaryCardView.layer.shadowOpacity = 0.22
        summaryCardView.layer.shadowRadius = 18
        summaryCardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        summaryCardView.translatesAutoresizingMaskIntoConstraints = false
        summaryCardView.accessibilityIdentifier = "statisticsSummaryCardView"

        emptyStateLabel.text = L10n.Statistics.emptyStateText
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        emptyStateLabel.font = .systemFont(ofSize: 17, weight: .regular)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isAccessibilityElement = true
        emptyStateLabel.accessibilityIdentifier = "statisticsEmptyStateLabel"
        emptyStateLabel.accessibilityLabel = L10n.Statistics.emptyStateAccessibilityLabel

        stackView.axis = .vertical
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.accessibilityIdentifier = "statisticsRowsStackView"

        let playedQuizzesRow = makeStatisticRow(
            title: L10n.Statistics.playedQuizzes,
            valueLabel: playedQuizzesValueLabel,
            rowAccessibilityIdentifier: "statisticsPlayedQuizzes",
            valueAccessibilityIdentifier: "statisticsPlayedQuizzesValueLabel"
        )
        let correctAnswersRow = makeStatisticRow(
            title: L10n.Statistics.correctAnswers,
            valueLabel: correctAnswersValueLabel,
            rowAccessibilityIdentifier: "statisticsCorrectAnswers",
            valueAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel"
        )
        let percentageRow = makeStatisticRow(
            title: L10n.Statistics.percentage,
            valueLabel: percentageValueLabel,
            rowAccessibilityIdentifier: "statisticsPercentage",
            valueAccessibilityIdentifier: "statisticsPercentageValueLabel"
        )
        let bestResultRow = makeStatisticRow(
            title: L10n.Statistics.bestResult,
            valueLabel: bestResultValueLabel,
            rowAccessibilityIdentifier: "statisticsBestResult",
            valueAccessibilityIdentifier: "statisticsBestResultValueLabel"
        )

        [playedQuizzesRow, correctAnswersRow, percentageRow, bestResultRow].forEach(stackView.addArrangedSubview)
        [emptyStateLabel, stackView].forEach(summaryCardView.addSubview)
        [backButton, titleLabel, subtitleLabel, summaryCardView].forEach(rootView.addSubview)

        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 16),
            backButton.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 20),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 26),
            titleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            subtitleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 30),
            subtitleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -30),

            summaryCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 28),
            summaryCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: 24),
            summaryCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -24),
            summaryCardView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -32),

            emptyStateLabel.topAnchor.constraint(equalTo: summaryCardView.topAnchor, constant: 24),
            emptyStateLabel.leadingAnchor.constraint(equalTo: summaryCardView.leadingAnchor, constant: 22),
            emptyStateLabel.trailingAnchor.constraint(equalTo: summaryCardView.trailingAnchor, constant: -22),

            stackView.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: summaryCardView.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: summaryCardView.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: summaryCardView.bottomAnchor, constant: -22)
        ])
    }

    @objc private func backButtonTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func makeStatisticRowWithIdentifier(
        accessibilityIdentifier: String
    ) -> String {
        return accessibilityIdentifier
    }

    private func makeStatisticRow(
        title: String,
        valueLabel: UILabel,
        rowAccessibilityIdentifier: String,
        valueAccessibilityIdentifier: String
    ) -> UIView {
        _ = makeStatisticRowWithIdentifier(accessibilityIdentifier: "statisticsPlayedQuizzes")
        _ = makeStatisticRowWithIdentifier(accessibilityIdentifier: "statisticsCorrectAnswers")
        _ = makeStatisticRowWithIdentifier(accessibilityIdentifier: "statisticsPercentage")
        _ = makeStatisticRowWithIdentifier(accessibilityIdentifier: "statisticsBestResult")

        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        containerView.layer.cornerRadius = 18
        containerView.layer.borderWidth = 1
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(0.22).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isAccessibilityElement = true
        containerView.accessibilityIdentifier = rowAccessibilityIdentifier

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(0.86)
        titleLabel.font = .systemFont(ofSize: 17, weight: .medium)
        titleLabel.numberOfLines = 0
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: 28, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = 0.75
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.accessibilityIdentifier = valueAccessibilityIdentifier

        [titleLabel, valueLabel].forEach(containerView.addSubview)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 78),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 18),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -12),

            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -18),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 76)
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
        subtitleLabel.text = summary.playedQuizzes > 0
            ? L10n.Statistics.subtitleWithStats
            : L10n.Statistics.subtitleEmpty

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
        stackView.arrangedSubviews[safe: 0]?.accessibilityLabel = L10n.Statistics.playedQuizzes
        stackView.arrangedSubviews[safe: 0]?.accessibilityValue = "\(playedQuizzes)"
        stackView.arrangedSubviews[safe: 1]?.accessibilityLabel = L10n.Statistics.correctAnswers
        stackView.arrangedSubviews[safe: 1]?.accessibilityValue = correctAnswersDisplay
        stackView.arrangedSubviews[safe: 2]?.accessibilityLabel = L10n.Statistics.percentage
        stackView.arrangedSubviews[safe: 2]?.accessibilityValue = percentageDisplay
        stackView.arrangedSubviews[safe: 3]?.accessibilityLabel = L10n.Statistics.bestResult
        stackView.arrangedSubviews[safe: 3]?.accessibilityValue = bestResultDisplay
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
