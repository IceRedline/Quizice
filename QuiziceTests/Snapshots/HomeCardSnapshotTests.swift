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

    func testAIThemeActionCardSnapshot() {
        let cell = SnapshotSupport.makeCollectionCell(item: 2, themes: themes, designStyle: .clean)

        SnapshotSupport.assertComponent(
            cell.contentView,
            named: "clean-ai-theme-card",
            size: CGSize(width: 390, height: 140)
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
}
