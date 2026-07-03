import XCTest
@testable import Quizice

@MainActor
final class HomeScreenVisualStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetQuizFactory()
    }

    override func tearDown() {
        resetQuizFactory()
        super.tearDown()
    }

    func testHomeScreenExposesObservableLayoutAnchors() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeActionButtonsStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeExitButton"))
    }

    func testHomeShellUsesPolishedActionStackStyling() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let stackView = viewController.view.descendant(withAccessibilityIdentifier: "homeActionButtonsStackView") as? UIStackView
        let feelingLuckyButton = viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        let exitButton = viewController.view.descendant(withAccessibilityIdentifier: "homeExitButton") as? UIButton

        XCTAssertEqual(stackView?.axis, .vertical)
        XCTAssertEqual(stackView?.spacing, 12)
        XCTAssertEqual(stackView?.arrangedSubviews.first, feelingLuckyButton)
        XCTAssertEqual(stackView?.arrangedSubviews.last, exitButton)
        XCTAssertEqual(feelingLuckyButton?.layer.cornerRadius, 22)
        XCTAssertGreaterThan(feelingLuckyButton?.layer.shadowOpacity ?? 0, 0)
        XCTAssertEqual(exitButton?.layer.cornerRadius, 20)
        XCTAssertEqual(exitButton?.layer.borderWidth, 1)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
        XCTAssertFalse(stackView?.hasAmbiguousLayout ?? true)
    }

    func testHomeScreenShowsUnavailableCopyWhenThemesAreEmpty() {
        QuizFactory.shared.themes = []

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let label = viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel") as? UILabel
        XCTAssertEqual(label?.text, "Темы пока недоступны")
    }

    func testCollectionServiceKeepsStatisticsCardAfterThemeItems() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка"), makeTheme(name: "Технологии")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 3)

        let firstThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let secondThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))

        XCTAssertNotNil(firstThemeCell.contentView.descendant(withAccessibilityIdentifier: "Музыка"))
        XCTAssertNotNil(secondThemeCell.contentView.descendant(withAccessibilityIdentifier: "Технологии"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    func testCollectionServiceKeepsStatisticsCardSafeWhenThemesAreEmpty() {
        QuizFactory.shared.themes = []
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 1)

        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))

        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    private func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "themeCell")
        return collectionView
    }

    private func makeTheme(name: String) -> QuizTheme {
        QuizTheme(theme: name, themeDescription: "Synthetic home-screen test theme", questions: [])
    }

    private func resetQuizFactory() {
        QuizFactory.shared.themes = nil
        QuizFactory.shared.chosenTheme = nil
        QuizFactory.shared.questionsCount = 5
        QuizFactory.shared.startup1st = false
    }
}

private extension UIView {
    func descendant(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier {
            return self
        }

        for subview in subviews {
            if let match = subview.descendant(withAccessibilityIdentifier: identifier) {
                return match
            }
        }

        return nil
    }
}
