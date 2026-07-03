import UIKit
#if DEBUG
import SwiftUI
#endif

final class StatisticsViewController: UIViewController {
    private enum Content {
        static let backgroundImageName = "backgroundImage"
        static let percentageSuffix = "%"
    }
    
    private enum AccessibilityID {
        static let rootView = "statisticsScreen"
        static let backButton = "statisticsBackButton"
        static let titleLabel = "statisticsTitleLabel"
        static let subtitleLabel = "statisticsSubtitleLabel"
        static let summaryCardView = "statisticsSummaryCardView"
        static let emptyStateLabel = "statisticsEmptyStateLabel"
        static let rowsStackView = "statisticsRowsStackView"
        
        static let playedQuizzesRow = "statisticsPlayedQuizzes"
        static let playedQuizzesValueLabel = "statisticsPlayedQuizzesValueLabel"
        static let correctAnswersRow = "statisticsCorrectAnswers"
        static let correctAnswersValueLabel = "statisticsCorrectAnswersValueLabel"
        static let percentageRow = "statisticsPercentage"
        static let percentageValueLabel = "statisticsPercentageValueLabel"
        static let bestResultRow = "statisticsBestResult"
        static let bestResultValueLabel = "statisticsBestResultValueLabel"
    }
    
    private enum Layout {
        static let backButtonTopInset: CGFloat = 16
        static let backButtonLeadingInset: CGFloat = 20
        static let backButtonMinimumWidth: CGFloat = 72
        static let backButtonHeight: CGFloat = 40
        static let titleTopSpacing: CGFloat = 26
        static let titleHorizontalInset: CGFloat = 24
        static let subtitleTopSpacing: CGFloat = 10
        static let subtitleHorizontalInset: CGFloat = 30
        static let cardTopSpacing: CGFloat = 28
        static let cardHorizontalInset: CGFloat = 24
        static let cardBottomMaximumInset: CGFloat = 32
        static let emptyStateTopInset: CGFloat = 24
        static let emptyStateHorizontalInset: CGFloat = 22
        static let rowsTopSpacing: CGFloat = 20
        static let rowsHorizontalInset: CGFloat = 18
        static let rowsBottomInset: CGFloat = 22
        static let rowsStackSpacing: CGFloat = 14
        
        static let rowMinimumHeight: CGFloat = 78
        static let rowHorizontalInset: CGFloat = 18
        static let rowTitleToValueSpacing: CGFloat = 12
        static let rowValueMinimumWidth: CGFloat = 76
    }
    
    private enum Typography {
        static let backButtonFontSize: CGFloat = 17
        static let titleFontSize: CGFloat = 36
        static let subtitleFontSize: CGFloat = 18
        static let emptyStateFontSize: CGFloat = 17
        static let rowTitleFontSize: CGFloat = 17
        static let rowValueFontSize: CGFloat = 28
        static let unlimitedNumberOfLines = 0
        static let rowValueMinimumScaleFactor: CGFloat = 0.75
    }
    
    private enum Appearance {
        static let backButtonBackgroundAlpha: CGFloat = 0.16
        static let backButtonCornerRadius: CGFloat = 20
        static let backButtonBorderWidth: CGFloat = 1
        static let backButtonBorderAlpha: CGFloat = 0.24
        
        static let subtitleTextAlpha: CGFloat = 0.82
        static let cardBackgroundAlpha: CGFloat = 0.14
        static let cardCornerRadius: CGFloat = 30
        static let cardBorderWidth: CGFloat = 1
        static let cardBorderAlpha: CGFloat = 0.28
        static let cardShadowOpacity: Float = 0.22
        static let cardShadowRadius: CGFloat = 18
        static let cardShadowOffset = CGSize(width: 0, height: 10)
        static let emptyStateTextAlpha: CGFloat = 0.86
        
        static let rowBackgroundAlpha: CGFloat = 0.12
        static let rowCornerRadius: CGFloat = 18
        static let rowBorderWidth: CGFloat = 1
        static let rowBorderAlpha: CGFloat = 0.22
        static let rowTitleTextAlpha: CGFloat = 0.86
    }
    
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
    
    private var playedQuizzesRow: UIView!
    private var correctAnswersRow: UIView!
    private var percentageRow: UIView!
    private var bestResultRow: UIView!

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
        rootView.backgroundColor = UIColor(patternImage: UIImage(named: Content.backgroundImageName) ?? UIImage())
        rootView.accessibilityIdentifier = AccessibilityID.rootView
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
        configureBackButton()
        configureTitleLabel()
        configureSubtitleLabel()
        configureSummaryCard()
        configureEmptyStateLabel()
        configureRowsStack()
        configureStatisticRows()
        addSubviews(to: rootView)
        activateLayoutConstraints(in: rootView)
    }
    
    private func configureBackButton() {
        backButton.setTitle(L10n.Common.back, for: .normal)
        backButton.setTitleColor(.white, for: .normal)
        backButton.titleLabel?.font = .systemFont(ofSize: Typography.backButtonFontSize, weight: .semibold)
        backButton.backgroundColor = UIColor.white.withAlphaComponent(Appearance.backButtonBackgroundAlpha)
        backButton.layer.cornerRadius = Appearance.backButtonCornerRadius
        backButton.layer.borderWidth = Appearance.backButtonBorderWidth
        backButton.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.backButtonBorderAlpha).cgColor
        backButton.translatesAutoresizingMaskIntoConstraints = false
        backButton.accessibilityIdentifier = AccessibilityID.backButton
        backButton.accessibilityLabel = L10n.Common.back
        backButton.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
    }
    
    private func configureTitleLabel() {
        titleLabel.text = L10n.Statistics.title
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: Typography.titleFontSize, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.isAccessibilityElement = true
        titleLabel.accessibilityIdentifier = AccessibilityID.titleLabel
        titleLabel.accessibilityLabel = L10n.Statistics.title
    }
    
    private func configureSubtitleLabel() {
        subtitleLabel.text = L10n.Statistics.subtitleWithStats
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(Appearance.subtitleTextAlpha)
        subtitleLabel.font = .systemFont(ofSize: Typography.subtitleFontSize, weight: .medium)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = Typography.unlimitedNumberOfLines
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.isAccessibilityElement = true
        subtitleLabel.accessibilityIdentifier = AccessibilityID.subtitleLabel
    }
    
    private func configureSummaryCard() {
        summaryCardView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.cardBackgroundAlpha)
        summaryCardView.layer.cornerRadius = Appearance.cardCornerRadius
        summaryCardView.layer.borderWidth = Appearance.cardBorderWidth
        summaryCardView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.cardBorderAlpha).cgColor
        summaryCardView.layer.shadowColor = UIColor.black.cgColor
        summaryCardView.layer.shadowOpacity = Appearance.cardShadowOpacity
        summaryCardView.layer.shadowRadius = Appearance.cardShadowRadius
        summaryCardView.layer.shadowOffset = Appearance.cardShadowOffset
        summaryCardView.translatesAutoresizingMaskIntoConstraints = false
        summaryCardView.accessibilityIdentifier = AccessibilityID.summaryCardView
    }
    
    private func configureEmptyStateLabel() {
        emptyStateLabel.text = L10n.Statistics.emptyStateText
        emptyStateLabel.textColor = UIColor.white.withAlphaComponent(Appearance.emptyStateTextAlpha)
        emptyStateLabel.font = .systemFont(ofSize: Typography.emptyStateFontSize, weight: .regular)
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = Typography.unlimitedNumberOfLines
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyStateLabel.isAccessibilityElement = true
        emptyStateLabel.accessibilityIdentifier = AccessibilityID.emptyStateLabel
        emptyStateLabel.accessibilityLabel = L10n.Statistics.emptyStateAccessibilityLabel
    }
    
    private func configureRowsStack() {
        stackView.axis = .vertical
        stackView.spacing = Layout.rowsStackSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.accessibilityIdentifier = AccessibilityID.rowsStackView
    }
    
    private func configureStatisticRows() {
        playedQuizzesRow = makeStatisticRow(
            title: L10n.Statistics.playedQuizzes,
            valueLabel: playedQuizzesValueLabel,
            rowAccessibilityIdentifier: AccessibilityID.playedQuizzesRow,
            valueAccessibilityIdentifier: AccessibilityID.playedQuizzesValueLabel
        )
        correctAnswersRow = makeStatisticRow(
            title: L10n.Statistics.correctAnswers,
            valueLabel: correctAnswersValueLabel,
            rowAccessibilityIdentifier: AccessibilityID.correctAnswersRow,
            valueAccessibilityIdentifier: AccessibilityID.correctAnswersValueLabel
        )
        percentageRow = makeStatisticRow(
            title: L10n.Statistics.percentage,
            valueLabel: percentageValueLabel,
            rowAccessibilityIdentifier: AccessibilityID.percentageRow,
            valueAccessibilityIdentifier: AccessibilityID.percentageValueLabel
        )
        bestResultRow = makeStatisticRow(
            title: L10n.Statistics.bestResult,
            valueLabel: bestResultValueLabel,
            rowAccessibilityIdentifier: AccessibilityID.bestResultRow,
            valueAccessibilityIdentifier: AccessibilityID.bestResultValueLabel
        )
        
        [playedQuizzesRow, correctAnswersRow, percentageRow, bestResultRow].forEach(stackView.addArrangedSubview)
    }
    
    private func addSubviews(to rootView: UIView) {
        [emptyStateLabel, stackView].forEach(summaryCardView.addSubview)
        [backButton, titleLabel, subtitleLabel, summaryCardView].forEach(rootView.addSubview)
    }
    
    private func activateLayoutConstraints(in rootView: UIView) {
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: Layout.backButtonTopInset),
            backButton.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.backButtonLeadingInset),
            backButton.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.backButtonMinimumWidth),
            backButton.heightAnchor.constraint(equalToConstant: Layout.backButtonHeight),

            titleLabel.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: Layout.titleTopSpacing),
            titleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.titleHorizontalInset),
            titleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.titleHorizontalInset),

            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: Layout.subtitleTopSpacing),
            subtitleLabel.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.subtitleHorizontalInset),
            subtitleLabel.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.subtitleHorizontalInset),

            summaryCardView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: Layout.cardTopSpacing),
            summaryCardView.leadingAnchor.constraint(equalTo: rootView.leadingAnchor, constant: Layout.cardHorizontalInset),
            summaryCardView.trailingAnchor.constraint(equalTo: rootView.trailingAnchor, constant: -Layout.cardHorizontalInset),
            summaryCardView.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -Layout.cardBottomMaximumInset),

            emptyStateLabel.topAnchor.constraint(equalTo: summaryCardView.topAnchor, constant: Layout.emptyStateTopInset),
            emptyStateLabel.leadingAnchor.constraint(equalTo: summaryCardView.leadingAnchor, constant: Layout.emptyStateHorizontalInset),
            emptyStateLabel.trailingAnchor.constraint(equalTo: summaryCardView.trailingAnchor, constant: -Layout.emptyStateHorizontalInset),

            stackView.topAnchor.constraint(equalTo: emptyStateLabel.bottomAnchor, constant: Layout.rowsTopSpacing),
            stackView.leadingAnchor.constraint(equalTo: summaryCardView.leadingAnchor, constant: Layout.rowsHorizontalInset),
            stackView.trailingAnchor.constraint(equalTo: summaryCardView.trailingAnchor, constant: -Layout.rowsHorizontalInset),
            stackView.bottomAnchor.constraint(equalTo: summaryCardView.bottomAnchor, constant: -Layout.rowsBottomInset)
        ])
    }

    @objc private func backButtonTapped() {
        if let navigationController {
            navigationController.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    private func makeStatisticRow(
        title: String,
        valueLabel: UILabel,
        rowAccessibilityIdentifier: String,
        valueAccessibilityIdentifier: String
    ) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.white.withAlphaComponent(Appearance.rowBackgroundAlpha)
        containerView.layer.cornerRadius = Appearance.rowCornerRadius
        containerView.layer.borderWidth = Appearance.rowBorderWidth
        containerView.layer.borderColor = UIColor.white.withAlphaComponent(Appearance.rowBorderAlpha).cgColor
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.isAccessibilityElement = true
        containerView.accessibilityIdentifier = rowAccessibilityIdentifier

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = UIColor.white.withAlphaComponent(Appearance.rowTitleTextAlpha)
        titleLabel.font = .systemFont(ofSize: Typography.rowTitleFontSize, weight: .medium)
        titleLabel.numberOfLines = Typography.unlimitedNumberOfLines
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        valueLabel.textColor = .white
        valueLabel.font = .systemFont(ofSize: Typography.rowValueFontSize, weight: .bold)
        valueLabel.textAlignment = .right
        valueLabel.adjustsFontSizeToFitWidth = true
        valueLabel.minimumScaleFactor = Typography.rowValueMinimumScaleFactor
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.accessibilityIdentifier = valueAccessibilityIdentifier

        [titleLabel, valueLabel].forEach(containerView.addSubview)

        NSLayoutConstraint.activate([
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowMinimumHeight),

            titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: Layout.rowHorizontalInset),
            titleLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: valueLabel.leadingAnchor, constant: -Layout.rowTitleToValueSpacing),

            valueLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -Layout.rowHorizontalInset),
            valueLabel.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            valueLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: Layout.rowValueMinimumWidth)
        ])

        return containerView
    }

    private func render(summary: StatisticsSummary) {
        let correctAnswersDisplay = "\(summary.correctAnswers)/\(summary.totalQuestions)"
        let percentageDisplay = "\(summary.percentage)\(Content.percentageSuffix)"

        playedQuizzesValueLabel.text = "\(summary.playedQuizzes)"
        correctAnswersValueLabel.text = correctAnswersDisplay
        percentageValueLabel.text = percentageDisplay
        bestResultValueLabel.text = summary.bestResultDisplay
        emptyStateLabel.isHidden = summary.playedQuizzes > .zero
        subtitleLabel.text = summary.playedQuizzes > .zero ? L10n.Statistics.subtitleWithStats : L10n.Statistics.subtitleEmpty

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
        playedQuizzesRow.accessibilityLabel = L10n.Statistics.playedQuizzes
        playedQuizzesRow.accessibilityValue = "\(playedQuizzes)"
        correctAnswersRow.accessibilityLabel = L10n.Statistics.correctAnswers
        correctAnswersRow.accessibilityValue = correctAnswersDisplay
        percentageRow.accessibilityLabel = L10n.Statistics.percentage
        percentageRow.accessibilityValue = percentageDisplay
        bestResultRow.accessibilityLabel = L10n.Statistics.bestResult
        bestResultRow.accessibilityValue = bestResultDisplay
    }
}

#if DEBUG
#Preview("Statistics") {
    let suiteName = "quizice.preview.statistics"
    let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    userDefaults.removePersistentDomain(forName: suiteName)

    let store = StatisticsStore(userDefaults: userDefaults, key: "preview.attempts")
    store.recordAttempt(correctAnswers: 8, totalQuestions: 10)
    store.recordAttempt(correctAnswers: 4, totalQuestions: 5)
    store.recordAttempt(correctAnswers: 6, totalQuestions: 10)

    let viewController = StatisticsViewController(statisticsStore: store)
    viewController.loadViewIfNeeded()
    viewController.viewWillAppear(false)
    return viewController
}
#endif
