import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeScreenVisualStateTests: XCTestCase {
    private var testWindows: [UIWindow] = []

    override func setUp() {
        super.setUp()
        AppLocalizationStore.shared.languagePreference = .russian
        resetQuizFactory()
        // Pin the clean color scheme so shadow/surface assertions are deterministic
        // regardless of the host simulator's system light/dark appearance.
        UserDefaults.standard.set(CleanColorSchemePreference.light.rawValue, forKey: AppAppearanceStore.Keys.cleanColorScheme)
    }

    override func tearDown() {
        testWindows = []
        resetQuizFactory()
        UserDefaults.standard.removeObject(forKey: AppLocalizationStore.Keys.language)
        super.tearDown()
    }

    func testHomeScreenExposesObservableLayoutAnchors() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton"))
    }

    func testCleanHomeHeaderUsesLeadingAlignment() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let headerStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView") as? UIStackView)
        let welcomeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel") as? UILabel)
        let logoImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView") as? UIImageView)
        let logoTextLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel") as? UILabel)
        let chooseThemeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel") as? UILabel)

        XCTAssertEqual(headerStackView.alignment, .leading)
        XCTAssertEqual(welcomeLabel.textAlignment, .left)
        XCTAssertTrue(logoImageView.isHidden)
        XCTAssertFalse(logoTextLabel.isHidden)
        XCTAssertEqual(logoTextLabel.text, "Quizice")
        XCTAssertEqual(logoTextLabel.textAlignment, .left)
        XCTAssertEqual(chooseThemeLabel.textAlignment, .left)
    }

    func testNonCleanHomeHeaderKeepsCenteredAlignment() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let headerStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView") as? UIStackView)
        let welcomeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel") as? UILabel)
        let logoImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView") as? UIImageView)
        let logoTextLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel") as? UILabel)
        let chooseThemeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel") as? UILabel)

        XCTAssertEqual(headerStackView.alignment, .center)
        XCTAssertEqual(welcomeLabel.textAlignment, .center)
        XCTAssertTrue(logoImageView.isHidden)
        XCTAssertFalse(logoTextLabel.isHidden)
        XCTAssertEqual(logoTextLabel.textAlignment, .center)
        XCTAssertEqual(chooseThemeLabel.textAlignment, .center)
    }

    func testClassicHomeHeaderUsesImageLogo() throws {
        UserDefaults.standard.set(AppDesignStyle.classic.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let logoImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView") as? UIImageView)
        let logoTextLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel") as? UILabel)

        XCTAssertFalse(logoImageView.isHidden)
        XCTAssertTrue(logoTextLabel.isHidden)
    }

    func testHomeCollectionDoesNotDelayButtonTouchDownEvents() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let collectionView = viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView

        XCTAssertEqual(collectionView?.delaysContentTouches, false)
    }

    func testHomeCollectionEnablesScrollOnlyWhenContentDoesNotFit() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

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
        let logoTextLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel"))
        let chooseThemeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel"))
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton"))

        XCTAssertEqual(welcomeLabel.alpha, 0)
        XCTAssertEqual(logoImageView.alpha, 0)
        XCTAssertEqual(logoTextLabel.alpha, 0)
        XCTAssertEqual(chooseThemeLabel.alpha, 0)
        XCTAssertEqual(collectionView.alpha, 0)
        XCTAssertEqual(settingsButton.alpha, 0)
    }

    func testHomeShellHasNoAmbiguousLayout() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testHomeSettingsButtonPresentsSettingsScreen() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton)

        XCTAssertNotNil(settingsButton.image(for: .normal))

        settingsButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showSettingsCallCount, 1)
    }

    func testHomeAIThemeButtonPresentsAIThemeCreationScreen() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView)
        collectionView.layoutIfNeeded()
        let createWithAIButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton)

        createWithAIButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showAIThemeCreationCallCount, 1)
    }

    func testHomeScreenShowsUnavailableCopyWhenThemesAreEmpty() {
        QuizFactory.shared.themes = []

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let label = viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel") as? UILabel
        XCTAssertEqual(label?.text, L10n.Home.unavailableThemes)
    }

    func testCollectionServiceKeepsActionCardsAfterThemeItems() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка"), makeTheme(name: "Технологии")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 5)

        let firstThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let secondThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 4, section: 0))

        XCTAssertNotNil(firstThemeCell.contentView.descendant(withAccessibilityIdentifier: "music"))
        XCTAssertNotNil(secondThemeCell.contentView.descendant(withAccessibilityIdentifier: "technology"))
        XCTAssertNotNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton"))
        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    func testCollectionServiceUsesTwoColumnThemeCardsAndWideActionCards() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка"), makeTheme(name: "Технологии")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()
        let layout = collectionView.collectionViewLayout

        let themeSize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeSize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 2, section: 0))
        let feelingLuckySize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 3, section: 0))
        let statisticsSize = service.collectionView(collectionView, layout: layout, sizeForItemAt: IndexPath(item: 4, section: 0))
        let inset = service.collectionView(collectionView, layout: layout, insetForSectionAt: 0)
        let lineSpacing = service.collectionView(collectionView, layout: layout, minimumLineSpacingForSectionAt: 0)
        let interitemSpacing = service.collectionView(collectionView, layout: layout, minimumInteritemSpacingForSectionAt: 0)

        XCTAssertEqual(themeSize.width, 163)
        XCTAssertEqual(themeSize.height, 163)
        XCTAssertEqual(aiThemeSize.width, 342)
        XCTAssertEqual(aiThemeSize.height, 54)
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
        useDesignStyle(.clean)
        let themeAssets = [
            (themeID: "music", themeName: "Музыка", assetName: "theme_logo_music_clean", tintColorName: "themeMusicTint"),
            (themeID: "technology", themeName: "Технологии", assetName: "theme_logo_tech_clean", tintColorName: "themeTechnologyTint"),
            (themeID: "history_culture", themeName: "История и культура", assetName: "theme_logo_culture_clean", tintColorName: "themeCultureTint"),
            (themeID: "politics_business", themeName: "Политика и бизнес", assetName: "theme_logo_politics_clean", tintColorName: "themePoliticsTint")
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

            let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-\(themeAsset.themeID)") as? UIImageView)
            let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-\(themeAsset.themeID)") as? UILabel)
            let themeButton = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: themeAsset.themeID) as? UIButton)
            let expectedImage = try XCTUnwrap(UIImage(named: themeAsset.assetName))
            let tintColor = try XCTUnwrap(UIColor(named: themeAsset.tintColorName))

            XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
            XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
            XCTAssertEqual(titleLabel.text, themeAsset.themeName)
            XCTAssertEqual(titleLabel.textAlignment, .center)
            XCTAssertEqual(titleLabel.numberOfLines, 2)
            XCTAssertEqual(titleLabel.lineBreakMode, .byWordWrapping)
            XCTAssertFalse(titleLabel.adjustsFontSizeToFitWidth)
            assertColor(themeButton.backgroundColor, equals: assetColor("themeWhite"))
            assertColor(titleLabel.textColor, equals: assetColor("themeCleanSurfaceText"))
            assertColor(UIColor(cgColor: themeButton.layer.borderColor ?? UIColor.clear.cgColor), equals: tintColor.withAlphaComponent(0.75))
            XCTAssertEqual(themeButton.layer.borderWidth, 2)
            XCTAssertGreaterThanOrEqual(imageView.frame.height, 86)
            XCTAssertLessThan(imageView.frame.minY, titleLabel.frame.minY)
            XCTAssertLessThanOrEqual(imageView.frame.maxY, titleLabel.frame.minY)
            XCTAssertEqual(titleLabel.frame.height, 56, accuracy: 0.5)
            XCTAssertEqual(titleLabel.frame.maxY, themeCell.bounds.maxY - 6, accuracy: 0.5)

            let fittingSize = CGSize(width: titleLabel.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            let requiredTitleHeight = titleLabel.sizeThatFits(fittingSize).height
            XCTAssertLessThanOrEqual(requiredTitleHeight, titleLabel.bounds.height + 0.5)
        }
    }

    func testCollectionServiceAppliesPolishedCardStylingWithoutChangingIdentifiers() {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let themeButton = themeCell.contentView.descendant(withAccessibilityIdentifier: "music") as? UIButton
        let aiThemeButton = aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton
        let aiThemeBetaBadge = aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIBetaBadge") as? UILabel
        let aiThemeGradientBorder = aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIGradientBorder")
        let feelingLuckyButton = feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        let statisticsButton = statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton
        let themeTitleLabel = themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-music") as? UILabel

        XCTAssertEqual(themeButton?.accessibilityLabel, L10n.ThemeCard.accessibilityLabel(themeName: "Музыка"))
        XCTAssertEqual(themeTitleLabel?.text, "Музыка")
        XCTAssertEqual(themeButton?.layer.cornerRadius, 28)
        XCTAssertEqual(themeButton?.layer.borderWidth, 2)
        XCTAssertTrue(themeButton?.clipsToBounds ?? false)
        XCTAssertGreaterThan(themeCell.layer.shadowOpacity, 0)
        XCTAssertEqual(aiThemeButton?.accessibilityLabel, L10n.Home.createWithAI)
        XCTAssertEqual(aiThemeButton?.layer.cornerRadius, 22)
        assertColor(aiThemeButton?.backgroundColor, equals: assetColor("themeWhite"))
        XCTAssertEqual(aiThemeButton?.layer.borderWidth, 0)
        XCTAssertTrue(aiThemeButton?.clipsToBounds ?? false)
        XCTAssertEqual(aiThemeBetaBadge?.text, L10n.Home.createWithAIBetaBadge)
        XCTAssertEqual(aiThemeBetaBadge?.layer.cornerRadius, 11)
        XCTAssertEqual(aiThemeBetaBadge?.layer.borderWidth, 1)
        XCTAssertTrue(aiThemeBetaBadge?.clipsToBounds ?? false)
        XCTAssertTrue(aiThemeGradientBorder?.layer.sublayers?.first is CAGradientLayer)
        XCTAssertGreaterThanOrEqual(aiThemeCell.layer.shadowOpacity, 0)
        XCTAssertEqual(feelingLuckyButton?.accessibilityLabel, L10n.Home.feelingLucky)
        XCTAssertEqual(feelingLuckyButton?.layer.cornerRadius, 22)
        assertColor(feelingLuckyButton?.backgroundColor, equals: assetColor("themeWhite"))
        assertColor(
            UIColor(cgColor: feelingLuckyButton?.layer.borderColor ?? UIColor.clear.cgColor),
            equals: assetColor("themeCleanScreenText").withAlphaComponent(0.18)
        )
        XCTAssertEqual(feelingLuckyButton?.layer.borderWidth, 1)
        XCTAssertTrue(feelingLuckyButton?.clipsToBounds ?? false)
        XCTAssertGreaterThanOrEqual(feelingLuckyCell.layer.shadowOpacity, 0)
        XCTAssertEqual(statisticsButton?.accessibilityLabel, L10n.Home.statisticsAccessibilityLabel)
        XCTAssertEqual(statisticsButton?.layer.cornerRadius, 22)
        assertColor(statisticsButton?.backgroundColor, equals: assetColor("themeWhite"))
        assertColor(
            UIColor(cgColor: statisticsButton?.layer.borderColor ?? UIColor.clear.cgColor),
            equals: assetColor("themeCleanScreenText").withAlphaComponent(0.18)
        )
        XCTAssertEqual(statisticsButton?.layer.borderWidth, 1)
        XCTAssertTrue(statisticsButton?.clipsToBounds ?? false)
        XCTAssertGreaterThanOrEqual(statisticsCell.layer.shadowOpacity, 0)
    }

    func testCollectionServiceUsesRadarGreenThemeCardText() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()

        let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-music") as? UIImageView)
        let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-music") as? UILabel)
        let statisticsButton = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton)
        let expectedImage = try XCTUnwrap(UIImage(named: "theme_logo_music_radar"))

        XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
        assertColor(titleLabel.textColor, equals: assetColor("themeRadarGreen"))
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

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 3)

        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))

        XCTAssertNotNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton"))
        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    func testMockAIQuizThemeServiceTrimsPromptAndReturnsEmptyQuestions() async throws {
        let service = MockAIQuizThemeService()
        let locale = Locale(identifier: "ru")

        let theme = try await service.generateQuizTheme(for: "  Космос  \n", locale: locale)

        XCTAssertEqual(service.generatedPrompts, ["Космос"])
        XCTAssertEqual(service.generatedLocaleIdentifiers, ["ru"])
        XCTAssertEqual(theme.theme, "Космос")
        XCTAssertEqual(theme.themeDescription, "AI generated quiz placeholder")
        XCTAssertTrue(theme.questions.isEmpty)
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
        let id: String
        switch name {
        case "Музыка":
            id = "music"
        case "Технологии":
            id = "technology"
        case "История", "История и культура":
            id = "history_culture"
        case "Политика", "Политика и бизнес":
            id = "politics_business"
        default:
            id = name
        }
        return QuizTheme(id: id, theme: name, themeDescription: "Synthetic home-screen test theme", questions: [])
    }

    private func useDesignStyle(_ designStyle: AppDesignStyle) {
        UserDefaults.standard.set(designStyle.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
    }

    private func resetQuizFactory() {
        QuizFactory.shared.themes = nil
        QuizFactory.shared.chosenTheme = nil
        QuizFactory.shared.questionsCount = 5
        QuizFactory.shared.startup1st = false
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.cleanColorScheme)
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

    private func assetColor(_ name: String) -> UIColor {
        UIColor(named: name) ?? .clear
    }
}

private final class ThemeCollectionDelegateSpy: ThemeCollectionDelegate {
    private(set) var selectedThemeIDs: [String] = []
    private(set) var aiThemeTapCount = 0
    private(set) var feelingLuckyTapCount = 0
    private(set) var statisticsTapCount = 0

    func themeButtonTouchedDown(_ sender: UIButton) {}

    func themeButtonTouchedUpInside(_ sender: UIButton, themeID: String) {
        selectedThemeIDs.append(themeID)
    }

    func themeButtonTouchedUpOutside(_ sender: UIButton) {}

    func aiThemeButtonTouchedUpInside(_ sender: UIButton) {
        aiThemeTapCount += 1
    }

    func feelingLuckyButtonTouchedUpInside(_ sender: UIButton) {
        feelingLuckyTapCount += 1
    }

    func statisticsButtonTouchedUpInside(_ sender: UIButton) {
        statisticsTapCount += 1
    }

}

private final class HomeRouterSpy: QuizRouting {
    private(set) var showDescriptionCallCount = 0
    private(set) var showQuestionCallCount = 0
    private(set) var showResultCallCount = 0
    private(set) var showStatisticsCallCount = 0
    private(set) var showAIThemeCreationCallCount = 0
    private(set) var showSettingsCallCount = 0
    private(set) var closeDescriptionCallCount = 0
    private(set) var closeStatisticsCallCount = 0
    private(set) var closeQuestionCallCount = 0
    private(set) var restartQuizCallCount = 0

    func showDescription() { showDescriptionCallCount += 1 }
    func showQuestion() { showQuestionCallCount += 1 }
    func showResult(_ result: QuizResultState) { showResultCallCount += 1 }
    func showStatistics() { showStatisticsCallCount += 1 }
    func showAIThemeCreation() { showAIThemeCreationCallCount += 1 }
    func showSettings() { showSettingsCallCount += 1 }
    func closeDescription() { closeDescriptionCallCount += 1 }
    func closeStatistics() { closeStatisticsCallCount += 1 }
    func closeQuestion() { closeQuestionCallCount += 1 }
    func restartQuiz() { restartQuizCallCount += 1 }
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
