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
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeExitButton"))
    }

    func testHomeShellKeepsOnlyExitButtonOutsideCollection() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let stackView = viewController.view.descendant(withAccessibilityIdentifier: "homeActionButtonsStackView") as? UIStackView
        let exitButton = viewController.view.descendant(withAccessibilityIdentifier: "homeExitButton") as? UIButton

        XCTAssertEqual(stackView?.axis, .vertical)
        XCTAssertEqual(stackView?.arrangedSubviews.count, 1)
        XCTAssertEqual(stackView?.arrangedSubviews.first, exitButton)
        XCTAssertEqual(exitButton?.layer.cornerRadius, 22)
        XCTAssertEqual(exitButton?.layer.borderWidth, 0)
        XCTAssertGreaterThan(exitButton?.layer.shadowOpacity ?? 0, 0)
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

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 4)

        let firstThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let secondThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))

        XCTAssertNotNil(firstThemeCell.contentView.descendant(withAccessibilityIdentifier: "Музыка"))
        XCTAssertNotNil(secondThemeCell.contentView.descendant(withAccessibilityIdentifier: "Технологии"))
        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    func testCollectionServiceUsesTwoColumnThemeCardsAndWideStatisticsCard() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка"), makeTheme(name: "Технологии")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()
        let layout = collectionView.collectionViewLayout

        let themeSize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let feelingLuckySize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 2, section: 0))
        let statisticsSize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 3, section: 0))
        let inset = service.collectionView(collectionView, layout: layout, insetForSectionAt: 0)
        let lineSpacing = service.collectionView(collectionView, layout: layout, minimumLineSpacingForSectionAt: 0)
        let interitemSpacing = service.collectionView(collectionView, layout: layout, minimumInteritemSpacingForSectionAt: 0)

        XCTAssertEqual(themeSize.width, 163)
        XCTAssertEqual(themeSize.height, 163)
        XCTAssertEqual(feelingLuckySize.width, 342)
        XCTAssertEqual(feelingLuckySize.height, 54)
        XCTAssertEqual(statisticsSize.width, 342)
        XCTAssertEqual(statisticsSize.height, 112)
        XCTAssertEqual(inset.left, 24)
        XCTAssertEqual(inset.right, 24)
        XCTAssertEqual(inset.bottom, 32)
        XCTAssertEqual(lineSpacing, 16)
        XCTAssertEqual(interitemSpacing, 16)
    }

    func testCollectionServiceAppliesPolishedCardStylingWithoutChangingIdentifiers() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let themeButton = themeCell.contentView.descendant(withAccessibilityIdentifier: "Музыка") as? UIButton
        let feelingLuckyButton = feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        let statisticsButton = statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton

        XCTAssertEqual(themeButton?.accessibilityLabel, "Музыка, тема викторины")
        XCTAssertEqual(themeButton?.layer.cornerRadius, 28)
        XCTAssertEqual(themeButton?.layer.borderWidth, 1)
        XCTAssertTrue(themeButton?.clipsToBounds ?? false)
        XCTAssertGreaterThan(themeCell.layer.shadowOpacity, 0)
        XCTAssertEqual(feelingLuckyButton?.accessibilityLabel, "Мне повезет")
        XCTAssertEqual(feelingLuckyButton?.layer.cornerRadius, 20)
        XCTAssertEqual(feelingLuckyButton?.layer.borderWidth, 1)
        XCTAssertTrue(feelingLuckyButton?.clipsToBounds ?? false)
        XCTAssertGreaterThan(feelingLuckyCell.layer.shadowOpacity, 0)
        XCTAssertEqual(statisticsButton?.accessibilityLabel, "Общая статистика")
        XCTAssertEqual(statisticsButton?.layer.cornerRadius, 30)
        XCTAssertEqual(statisticsButton?.layer.borderWidth, 1)
        XCTAssertTrue(statisticsButton?.clipsToBounds ?? false)
        XCTAssertGreaterThan(statisticsCell.layer.shadowOpacity, 0)
    }

    func testCollectionServiceKeepsSelectionContractsForThemeStatisticsAndUnknownButtons() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let delegate = ThemeCollectionDelegateSpy()
        service.delegate = delegate

        let themeButton = UIButton(type: .custom)
        themeButton.accessibilityIdentifier = "Музыка"
        let unknownButton = UIButton(type: .custom)
        unknownButton.accessibilityIdentifier = "Неизвестная тема"
        let feelingLuckyButton = UIButton(type: .system)
        feelingLuckyButton.accessibilityIdentifier = "homeFeelingLuckyButton"
        let statisticsButton = UIButton(type: .system)
        statisticsButton.accessibilityIdentifier = "homeStatisticsCard"

        service.buttonTouchedUpInside(themeButton)
        service.buttonTouchedUpInside(unknownButton)
        service.feelingLuckyButtonTouchedUpInside(feelingLuckyButton)
        service.statisticsButtonTouchedUpInside(statisticsButton)

        XCTAssertEqual(delegate.selectedThemeNames, ["Музыка"])
        XCTAssertEqual(delegate.feelingLuckyTapCount, 1)
        XCTAssertEqual(delegate.statisticsTapCount, 1)
    }

    func testCollectionServiceKeepsStatisticsCardSafeWhenThemesAreEmpty() {
        QuizFactory.shared.themes = []
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 2)

        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))

        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
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

private final class ThemeCollectionDelegateSpy: ThemeCollectionDelegate {
    private(set) var selectedThemeNames: [String] = []
    private(set) var feelingLuckyTapCount = 0
    private(set) var statisticsTapCount = 0

    func themeButtonTouchedDown(_ sender: UIButton) {}

    func themeButtonTouchedUpInside(_ sender: UIButton, themeName: String) {
        selectedThemeNames.append(themeName)
    }

    func themeButtonTouchedUpOutside(_ sender: UIButton) {}

    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        feelingLuckyTapCount += 1
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        statisticsTapCount += 1
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
