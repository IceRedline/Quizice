import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeCollectionServicePresentationTests: HomeScreenVisualStateTestCase {
    func testCleanDarkThemeCardsRemainShadowless() {
        useDesignStyle(.clean)
        UserDefaults.standard.set(
            CleanColorSchemePreference.dark.rawValue,
            forKey: AppAppearanceStore.Keys.cleanColorScheme
        )
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let service = ThemesCollectionService()
        let themeCell = service.collectionView(
            makeThemeCollectionView(),
            cellForItemAt: IndexPath(item: 0, section: 0)
        )

        XCTAssertEqual(themeCell.layer.shadowOpacity, 0)
    }

    func testCompactStatisticsTitleShrinksAndLastItemOwnsBottomSpacing() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView(width: 320)
        let indexPath = IndexPath(item: 3, section: 0)
        let itemSize = service.collectionView(
            collectionView,
            layout: collectionView.collectionViewLayout,
            sizeForItemAt: indexPath
        )
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: indexPath)
        statisticsCell.frame = CGRect(origin: .zero, size: itemSize)
        statisticsCell.contentView.frame = statisticsCell.bounds
        statisticsCell.layoutIfNeeded()
        statisticsCell.contentView.layoutIfNeeded()

        let statisticsButton = try XCTUnwrap(
            statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton
        )
        let titleLabel = try XCTUnwrap(
            statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsTitleLabel") as? UILabel
        )
        let sectionInsets = service.collectionView(
            collectionView,
            layout: collectionView.collectionViewLayout,
            insetForSectionAt: 0
        )

        XCTAssertEqual(itemSize.height, 136)
        XCTAssertEqual(statisticsButton.frame.height, 112, accuracy: 0.5)
        XCTAssertEqual(statisticsCell.bounds.maxY - statisticsButton.frame.maxY, 24, accuracy: 0.5)
        XCTAssertEqual(sectionInsets.bottom, 0)
        XCTAssertEqual(titleLabel.numberOfLines, 1)
        XCTAssertTrue(titleLabel.adjustsFontSizeToFitWidth)
        XCTAssertEqual(titleLabel.minimumScaleFactor, 0.72, accuracy: 0.001)
        XCTAssertGreaterThan(titleLabel.bounds.width, 0)
    }

    func testCollectionServiceRendersEmptyStatisticsSummaryOnHomeCard() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let statisticsStore = makeStatisticsStore()
        let service = ThemesCollectionService(statisticsStore: statisticsStore)
        let collectionView = makeCollectionView()

        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        statisticsCell.frame = CGRect(x: 0, y: 0, width: 342, height: 136)
        statisticsCell.contentView.frame = statisticsCell.bounds
        statisticsCell.layoutIfNeeded()
        statisticsCell.contentView.layoutIfNeeded()
        let statisticsButton = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton)
        let statisticsTitleLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsTitleLabel") as? UILabel)
        let playedTitleLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsPlayedTitleLabel") as? UILabel)
        let playedValueLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsPlayedValueLabel") as? UILabel)
        let accuracyTitleLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsAccuracyTitleLabel") as? UILabel)
        let accuracyValueLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsAccuracyValueLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsDescriptionLabel") as? UILabel)

        XCTAssertEqual(playedTitleLabel.text, L10n.Home.statisticsPlayedShort)
        XCTAssertEqual(playedTitleLabel.numberOfLines, 1)
        XCTAssertEqual(playedValueLabel.text, "0")
        XCTAssertEqual(accuracyTitleLabel.text, L10n.Home.statisticsAccuracyShort)
        XCTAssertEqual(accuracyValueLabel.text, "0%")
        XCTAssertEqual(descriptionLabel.text, L10n.Home.statisticsDescription)
        XCTAssertEqual(descriptionLabel.numberOfLines, 2)
        XCTAssertTrue(statisticsTitleLabel.adjustsFontSizeToFitWidth)
        XCTAssertEqual(statisticsTitleLabel.minimumScaleFactor, 0.72, accuracy: 0.001)
        XCTAssertEqual(statisticsButton.frame.height, 112, accuracy: 0.5)
        XCTAssertEqual(statisticsCell.bounds.maxY - statisticsButton.frame.maxY, 24, accuracy: 0.5)
        let playedRowStack = try XCTUnwrap(playedTitleLabel.superview as? UIStackView)
        let accuracyRowStack = try XCTUnwrap(accuracyTitleLabel.superview as? UIStackView)
        let metricsStack = try XCTUnwrap(playedRowStack.superview as? UIStackView)
        XCTAssertTrue(playedRowStack === playedValueLabel.superview)
        XCTAssertTrue(accuracyRowStack === accuracyValueLabel.superview)
        XCTAssertTrue(metricsStack === accuracyRowStack.superview)
        XCTAssertLessThanOrEqual(
            playedTitleLabel.sizeThatFits(
                CGSize(width: .greatestFiniteMagnitude, height: playedTitleLabel.bounds.height)
            ).width,
            playedTitleLabel.bounds.width + 0.5
        )
        XCTAssertLessThanOrEqual(
            descriptionLabel.sizeThatFits(
                CGSize(width: descriptionLabel.bounds.width, height: .greatestFiniteMagnitude)
            ).height,
            descriptionLabel.bounds.height + 0.5
        )
        XCTAssertEqual(playedRowStack.axis, .horizontal)
        XCTAssertEqual(accuracyRowStack.axis, .horizontal)
        XCTAssertEqual(metricsStack.axis, .vertical)
        XCTAssertEqual(
            statisticsButton.accessibilityValue,
            L10n.Home.statisticsAccessibilityValue(playedQuizzes: 0, percentage: 0)
        )
    }

    func testCollectionServiceRendersRecordedStatisticsSummaryOnHomeCard() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let statisticsStore = makeStatisticsStore(attempts: [
            (correctAnswers: 3, totalQuestions: 5),
            (correctAnswers: 5, totalQuestions: 5)
        ])
        let service = ThemesCollectionService(statisticsStore: statisticsStore)
        let collectionView = makeCollectionView()

        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let statisticsButton = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton)
        let playedValueLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsPlayedValueLabel") as? UILabel)
        let accuracyValueLabel = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsAccuracyValueLabel") as? UILabel)

        XCTAssertEqual(playedValueLabel.text, "2")
        XCTAssertEqual(accuracyValueLabel.text, "80%")
        XCTAssertEqual(
            statisticsButton.accessibilityValue,
            L10n.Home.statisticsAccessibilityValue(playedQuizzes: 2, percentage: 80)
        )
    }

    func testCollectionServiceUsesRadarGreenThemeCardText() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()
        let themeCollectionView = makeThemeCollectionView()

        let themeCell = service.collectionView(themeCollectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-music") as? UIImageView)
        let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-music") as? UILabel)
        let aiThemeButton = try XCTUnwrap(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton)
        let statisticsButton = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton)
        let expectedImage = try XCTUnwrap(
            UIImage(systemName: "music.note.list")?.withRenderingMode(.alwaysTemplate)
        )

        XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
        assertColor(titleLabel.textColor, equals: assetColor("themeRadarGreen"))
        XCTAssertNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIGradientBorder"))
        assertColor(aiThemeButton.backgroundColor, equals: .clear)
        assertColor(
            UIColor(cgColor: aiThemeButton.layer.borderColor ?? UIColor.clear.cgColor),
            equals: assetColor("themeRadarGreen")
        )
        assertColor(
            UIColor(cgColor: aiThemeButton.layer.shadowColor ?? UIColor.clear.cgColor),
            equals: assetColor("themeRadarGreen")
        )
        XCTAssertEqual(aiThemeButton.layer.borderWidth, 1)
        XCTAssertGreaterThan(aiThemeButton.layer.shadowOpacity, 0)
        XCTAssertFalse(aiThemeButton.clipsToBounds)
        assertColor(statisticsButton.backgroundColor, equals: .clear)
    }

    func testCollectionServiceKeepsSelectionContractsForThemeStatisticsAndUnknownButtons() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let delegate = ThemeCollectionDelegateSpy()
        service.delegate = delegate

        let themeButton = UIButton(type: .custom)
        themeButton.accessibilityIdentifier = "music"
        let unknownButton = UIButton(type: .custom)
        unknownButton.accessibilityIdentifier = "Неизвестная тема"
        let aiThemeButton = UIButton(type: .system)
        aiThemeButton.accessibilityIdentifier = "homeCreateWithAIButton"
        let feelingLuckyButton = UIButton(type: .system)
        feelingLuckyButton.accessibilityIdentifier = "homeFeelingLuckyButton"
        let statisticsButton = UIButton(type: .system)
        statisticsButton.accessibilityIdentifier = "homeStatisticsCard"

        service.buttonTouchedUpInside(themeButton)
        service.buttonTouchedUpInside(unknownButton)
        service.aiThemeButtonTouchedUpInside(aiThemeButton)
        service.feelingLuckyButtonTouchedUpInside(feelingLuckyButton)
        service.statisticsButtonTouchedUpInside(statisticsButton)

        XCTAssertEqual(delegate.selectedThemeIDs, ["music"])
        XCTAssertEqual(delegate.aiThemeTapCount, 1)
        XCTAssertEqual(delegate.feelingLuckyTapCount, 1)
        XCTAssertEqual(delegate.statisticsTapCount, 1)
    }

    func testCollectionServiceKeepsStatisticsCardSafeWhenThemesAreEmpty() {
        QuizFactory.shared.themes = []
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 4)

        let viewportCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))

        XCTAssertTrue(viewportCell is ThemesViewportCollectionViewCell)
        XCTAssertNotNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton"))
        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }
}
