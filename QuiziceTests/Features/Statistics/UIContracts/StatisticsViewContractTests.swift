import XCTest
@testable import Quizice

@MainActor
final class StatisticsViewContractTests: CrossScreenVisualTestCase {
    func testStatisticsScreenExposesPolishedEmptyStateAndSafeRows() throws {
        let harness = makeStatisticsHarness()
        let viewController = StatisticsViewController(statisticsStore: harness.store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsScreen"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsTitleLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSubtitleLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsRowsStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        let emptyStateLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsEmptyStateLabel") as? UILabel)
        let playedRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzes"))
        let correctRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers"))
        let percentageRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentage"))
        let bestResultRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResult"))
        let playedValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzesValueLabel") as? UILabel)
        let correctValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel") as? UILabel)
        let percentageValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentageValueLabel") as? UILabel)
        let bestResultValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResultValueLabel") as? UILabel)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton") as? UIButton)

        XCTAssertFalse(emptyStateLabel.isHidden)
        XCTAssertEqual(playedValueLabel.text, "0")
        XCTAssertEqual(correctValueLabel.text, "0/0")
        XCTAssertEqual(percentageValueLabel.text, "0%")
        XCTAssertEqual(bestResultValueLabel.text, "0/0")
        XCTAssertEqual(playedRow.accessibilityValue, "0")
        XCTAssertEqual(correctRow.accessibilityValue, "0/0")
        XCTAssertEqual(percentageRow.accessibilityValue, "0%")
        XCTAssertEqual(bestResultRow.accessibilityValue, "0/0")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertNotNil(backButton.image(for: .normal))
        XCTAssertEqual(backButton.accessibilityLabel, L10n.Common.back)
        XCTAssertGreaterThanOrEqual(backButton.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(backButton.bounds.height, 44)
        XCTAssertEqual(backButton.layer.cornerRadius, 22)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testStatisticsScreenRendersRecordedSummaryAndHidesEmptyCopy() throws {
        let harness = makeStatisticsHarness()
        harness.store.recordAttempt(correctAnswers: 3, totalQuestions: 5)
        harness.store.recordAttempt(correctAnswers: 5, totalQuestions: 5)

        let viewController = StatisticsViewController(statisticsStore: harness.store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)

        let emptyStateLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsEmptyStateLabel") as? UILabel)
        let playedRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzes"))
        let correctRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers"))
        let percentageRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentage"))
        let bestResultRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResult"))
        let playedValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzesValueLabel") as? UILabel)
        let correctValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel") as? UILabel)
        let percentageValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentageValueLabel") as? UILabel)
        let bestResultValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResultValueLabel") as? UILabel)

        XCTAssertTrue(emptyStateLabel.isHidden)
        XCTAssertEqual(playedValueLabel.text, "2")
        XCTAssertEqual(correctValueLabel.text, "8/10")
        XCTAssertEqual(percentageValueLabel.text, "80%")
        XCTAssertEqual(bestResultValueLabel.text, "5/5")
        XCTAssertEqual(playedRow.accessibilityValue, "2")
        XCTAssertEqual(correctRow.accessibilityValue, "8/10")
        XCTAssertEqual(percentageRow.accessibilityValue, "80%")
        XCTAssertEqual(bestResultRow.accessibilityValue, "5/5")
    }

    func testStatisticsCorrectAnswersValueStaysFullyVisibleForLargeHistory() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        let harness = makeStatisticsHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suiteName) }

        for _ in 0..<10 {
            harness.store.recordAttempt(correctAnswers: 5, totalQuestions: 5)
        }
        for _ in 0..<24 {
            harness.store.recordAttempt(correctAnswers: 1, totalQuestions: 5)
        }
        for _ in 0..<19 {
            harness.store.recordAttempt(correctAnswers: 0, totalQuestions: 5)
        }

        for width in [CGFloat(402), CGFloat(320)] {
            let viewController = StatisticsViewController(statisticsStore: harness.store)
            viewController.loadViewIfNeeded()
            viewController.view.frame = CGRect(x: 0, y: 0, width: width, height: 874)
            viewController.viewWillAppear(false)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            let correctRow = try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers")
            )
            let correctValueLabel = try XCTUnwrap(
                viewController.view.descendant(
                    withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel"
                ) as? UILabel
            )
            let titleLabel = try XCTUnwrap(
                correctRow.subviews.compactMap { $0 as? UILabel }.first { $0 !== correctValueLabel }
            )
            let requiredValueWidth = ceil(
                ("74/265" as NSString).size(withAttributes: [.font: correctValueLabel.font!]).width
            )
            let valueFrame = correctValueLabel.convert(correctValueLabel.bounds, to: correctRow)

            XCTAssertEqual(correctValueLabel.text, "74/265")
            XCTAssertEqual(correctRow.accessibilityValue, "74/265")
            XCTAssertTrue(correctValueLabel.adjustsFontSizeToFitWidth)
            XCTAssertEqual(correctValueLabel.minimumScaleFactor, 0.75, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(correctValueLabel.bounds.width + 0.5, requiredValueWidth)
            XCTAssertGreaterThan(
                correctValueLabel.contentCompressionResistancePriority(for: .horizontal).rawValue,
                titleLabel.contentCompressionResistancePriority(for: .horizontal).rawValue
            )
            XCTAssertTrue(correctRow.bounds.insetBy(dx: -0.5, dy: -0.5).contains(valueFrame))
        }
    }
}
