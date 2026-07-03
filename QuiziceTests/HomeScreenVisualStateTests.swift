import XCTest
@testable import Quizice

@MainActor
final class HomeScreenVisualStateTests: XCTestCase {
    private var testWindows: [UIWindow] = []

    override func setUp() {
        super.setUp()
        resetQuizFactory()
    }

    override func tearDown() {
        testWindows = []
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

    func testHomeCollectionDoesNotDelayButtonTouchDownEvents() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let collectionView = viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView

        XCTAssertEqual(collectionView?.delaysContentTouches, false)
    }

    func testHomeCollectionEnablesScrollOnlyWhenContentDoesNotFit() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура"),
            makeTheme(name: "Политика")
        ]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))

        let collectionView = viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView
        XCTAssertEqual(collectionView?.isScrollEnabled, false)
        XCTAssertEqual(collectionView?.alwaysBounceVertical, false)
        XCTAssertEqual(collectionView?.bounces, false)

        let compactViewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 430))
        let compactCollectionView = compactViewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView

        XCTAssertEqual(compactCollectionView?.isScrollEnabled, true)
        XCTAssertEqual(compactCollectionView?.alwaysBounceVertical, true)
        XCTAssertEqual(compactCollectionView?.bounces, true)
    }

    func testHomeScreenHidesStartupAnimatedViewsBeforeFirstRenderedFrame() throws {
        QuizFactory.shared.startup1st = true

        let viewController = QuizViewController()
        viewController.loadView()

        let welcomeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel"))
        let logoImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView"))
        let chooseThemeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel"))
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))

        XCTAssertEqual(welcomeLabel.alpha, 0)
        XCTAssertEqual(logoImageView.alpha, 0)
        XCTAssertEqual(chooseThemeLabel.alpha, 0)
        XCTAssertEqual(collectionView.alpha, 0)
    }

    func testHomeShellKeepsExitButtonHiddenOutsideCollection() {
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
        XCTAssertTrue(stackView?.isHidden ?? false)
        XCTAssertTrue(exitButton?.isHidden ?? false)
        XCTAssertEqual(exitButton?.layer.cornerRadius, 22)
        XCTAssertEqual(exitButton?.layer.borderWidth, 0)
        XCTAssertGreaterThan(exitButton?.layer.shadowOpacity ?? 0, 0)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
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
        XCTAssertEqual(inset.bottom, 0)
        XCTAssertEqual(lineSpacing, 16)
        XCTAssertEqual(interitemSpacing, 16)
    }

    func testCollectionServiceThemeCardShowsImageAboveThemeTitle() throws {
        let themeAssets = [
            (themeName: "Музыка", displayTitle: "Музыка", assetName: "theme_logo_music", tintColorName: "themeMusicTint"),
            (themeName: "Технологии", displayTitle: "Технологии", assetName: "theme_logo_tech.png", tintColorName: "themeTechnologyTint"),
            (themeName: "История и культура", displayTitle: "Культура и история", assetName: "theme_logo_culture.png", tintColorName: "themeCultureTint"),
            (themeName: "Политика", displayTitle: "Политика и бизнес", assetName: "theme_logo_politics", tintColorName: "themePoliticsTint")
        ]
        QuizFactory.shared.themes = themeAssets.map { makeTheme(name: $0.themeName) }
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        for (index, themeAsset) in themeAssets.enumerated() {
            let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: index, section: 0))
            themeCell.frame = CGRect(x: 0, y: 0, width: 163, height: 163)
            themeCell.contentView.frame = themeCell.bounds
            themeCell.layoutIfNeeded()
            themeCell.contentView.layoutIfNeeded()

            let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-\(themeAsset.themeName)") as? UIImageView)
            let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-\(themeAsset.themeName)") as? UILabel)
            let themeButton = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: themeAsset.themeName) as? UIButton)
            let expectedImage = try XCTUnwrap(UIImage(named: themeAsset.assetName))
            let tintColor = try XCTUnwrap(UIColor(named: themeAsset.tintColorName))

            XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
            XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
            XCTAssertEqual(titleLabel.text, themeAsset.displayTitle)
            XCTAssertEqual(titleLabel.textAlignment, .center)
            XCTAssertEqual(titleLabel.numberOfLines, 2)
            assertColor(themeButton.backgroundColor, equals: tintColor.withAlphaComponent(0.20))
            assertColor(UIColor(cgColor: themeButton.layer.borderColor ?? UIColor.clear.cgColor), equals: tintColor.withAlphaComponent(0.45))
            XCTAssertGreaterThanOrEqual(imageView.frame.height, 94)
            XCTAssertLessThan(imageView.frame.minY, titleLabel.frame.minY)
            XCTAssertLessThanOrEqual(imageView.frame.maxY, titleLabel.frame.minY)
            XCTAssertEqual(titleLabel.frame.height, 48, accuracy: 0.5)
            XCTAssertEqual(titleLabel.frame.maxY, themeCell.bounds.maxY - 6, accuracy: 0.5)
        }
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
        let themeTitleLabel = themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-Музыка") as? UILabel

        XCTAssertEqual(themeButton?.accessibilityLabel, "Музыка, тема викторины")
        XCTAssertEqual(themeTitleLabel?.text, "Музыка")
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

    private func makeHomeViewController(in frame: CGRect) -> QuizViewController {
        let viewController = QuizViewController()
        let window = UIWindow(frame: frame)
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        return viewController
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

    private func assertColor(_ actual: UIColor?, equals expected: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("Expected color, got nil", file: file, line: line)
            return
        }

        let traitCollection = UITraitCollection(userInterfaceStyle: .light)
        let actualColor = actual.resolvedColor(with: traitCollection)
        let expectedColor = expected.resolvedColor(with: traitCollection)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0

        XCTAssertTrue(actualColor.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha), file: file, line: line)
        XCTAssertTrue(expectedColor.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha), file: file, line: line)
        XCTAssertEqual(actualRed, expectedRed, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, expectedGreen, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, expectedBlue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualAlpha, expectedAlpha, accuracy: 0.001, file: file, line: line)
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
