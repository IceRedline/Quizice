import UIKit
import XCTest
@testable import Quizice

@MainActor
final class HomeCardSnapshotTests: XCTestCase {
    private let themes = [
        SnapshotSupport.makeTheme(id: "music", name: "Музыка"),
        SnapshotSupport.makeTheme(id: "technology", name: "Технологии")
    ]

    override func setUp() {
        super.setUp()
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .light)
    }

    override func tearDown() {
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testThemeCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 0, themes: themes, designStyle: .clean)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "clean-theme-card",
            size: CGSize(width: 220, height: 220)
        )
    }

    func testRadarLongThemeCompactCardSnapshot() {
        let longTheme = SnapshotSupport.makeTheme(id: "history_culture", name: "История и культура")
        let cell = SnapshotSupport.makeCollectionCell(
            item: 0,
            themes: [longTheme],
            designStyle: .radar,
            collectionWidth: 375
        )

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "radar-long-theme-iphone-se",
            size: CGSize(width: 220, height: 220),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .radar)
        )
    }

    func testAIThemeActionCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 2, themes: themes, designStyle: .clean)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "clean-ai-theme-card",
            size: CGSize(width: 390, height: 140)
        )
    }

    func testClassicAIThemeActionCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 2, themes: themes, designStyle: .classic)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "classic-ai-theme-card",
            size: CGSize(width: 390, height: 140),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .classic)
        )
    }

    func testRadarAIThemeActionCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 2, themes: themes, designStyle: .radar)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "radar-ai-theme-card",
            size: CGSize(width: 390, height: 140),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .radar)
        )
    }

    func testFeelingLuckyActionCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 3, themes: themes, designStyle: .radar)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "radar-feeling-lucky-card",
            size: CGSize(width: 390, height: 140),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .radar)
        )
    }

    func testStatisticsCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 4, themes: themes, designStyle: .classic)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "classic-statistics-card",
            size: CGSize(width: 390, height: 180),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .classic)
        )
    }

    func testCompactStatisticsCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(
            item: 4,
            themes: themes,
            designStyle: .clean,
            collectionWidth: 375
        )

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "clean-statistics-iphone-se",
            size: CGSize(width: 375, height: 180),
            backgroundAppearance: SnapshotSupport.appearance(designStyle: .clean)
        )
    }
}
