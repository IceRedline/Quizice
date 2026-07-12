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
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton"))
    }

    func testHomeHeaderUsesSingleLeadingMotivationPrompt() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let headerStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView") as? UIStackView)
        let motivationLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel)

        XCTAssertEqual(headerStackView.alignment, .leading)
        XCTAssertTrue(motivationLabel.isDescendant(of: headerStackView))
        XCTAssertEqual(motivationLabel.textAlignment, .left)
        XCTAssertTrue(L10n.Home.motivationPrompts.contains(motivationLabel.text ?? ""))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeWelcomeLabel"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoImageView"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeLogoTextLabel"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeChooseThemeLabel"))
    }

    func testNonCleanHomeHeaderAlsoUsesLeadingAlignment() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let headerStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView") as? UIStackView)
        let motivationLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel)

        XCTAssertEqual(headerStackView.alignment, .leading)
        XCTAssertEqual(motivationLabel.textAlignment, .left)
    }

    func testHomeCollectionCanCancelButtonTouchesForScrolling() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = QuizViewController()
        viewController.loadViewIfNeeded()

        let collectionView = viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView

        XCTAssertEqual(collectionView?.delaysContentTouches, true)
        XCTAssertEqual(collectionView?.canCancelContentTouches, true)
        XCTAssertEqual(collectionView?.contentInsetAdjustmentBehavior, .never)
        XCTAssertEqual(collectionView?.touchesShouldCancel(in: UIButton(type: .system)), true)
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

    func testHomeMotivationLabelFadesAsCollectionScrollsUp() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура"),
            makeTheme(name: "Политика и бизнес")
        ]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 430))
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView)
        let motivationLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel)
        let blurredTextImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationBlurredImageView") as? UIImageView)
        let topInset = collectionView.adjustedContentInset.top

        XCTAssertGreaterThan(topInset, 0)
        XCTAssertEqual(motivationLabel.alpha, 1)
        XCTAssertEqual(blurredTextImageView.alpha, 0)

        collectionView.contentOffset.y = -topInset + 18
        collectionView.delegate?.scrollViewDidScroll?(collectionView)

        XCTAssertEqual(motivationLabel.alpha, 0.75, accuracy: 0.001)
        XCTAssertGreaterThan(blurredTextImageView.alpha, 0.8)
        XCTAssertNotNil(blurredTextImageView.image)

        collectionView.contentOffset.y = -topInset + 36
        collectionView.delegate?.scrollViewDidScroll?(collectionView)

        XCTAssertEqual(motivationLabel.alpha, 0.5, accuracy: 0.001)
        XCTAssertGreaterThan(blurredTextImageView.alpha, 0.8)
        XCTAssertNotNil(blurredTextImageView.image)

        collectionView.contentOffset.y = -topInset + 72
        collectionView.delegate?.scrollViewDidScroll?(collectionView)

        XCTAssertEqual(motivationLabel.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(blurredTextImageView.alpha, 0, accuracy: 0.001)
    }

    func testHomeMotivationGlowSurvivesReturningFromTheme() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура"),
            makeTheme(name: "Политика и бизнес")
        ]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 430))
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView)
        let motivationLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel)
        let blurredTextImageView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationBlurredImageView") as? UIImageView)
        let topInset = collectionView.adjustedContentInset.top

        collectionView.contentOffset.y = -topInset + 18
        collectionView.delegate?.scrollViewDidScroll?(collectionView)
        let titleBeforeReturn = motivationLabel.text
        let glowAlphaBeforeReturn = blurredTextImageView.alpha
        XCTAssertNotNil(blurredTextImageView.image)

        viewController.viewWillAppear(false)

        XCTAssertEqual(motivationLabel.text, titleBeforeReturn)
        XCTAssertEqual(blurredTextImageView.alpha, glowAlphaBeforeReturn, accuracy: 0.001)
        XCTAssertNotNil(blurredTextImageView.image)
    }

    func testHomeCollectionIsLayeredAboveMotivationHeader() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии")
        ]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 430))
        let headerStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView"))
        let screenStackView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeScreenStackView"))
        let headerIndex = try XCTUnwrap(viewController.view.subviews.firstIndex(of: headerStackView))
        let screenIndex = try XCTUnwrap(viewController.view.subviews.firstIndex(of: screenStackView))

        XCTAssertLessThan(headerIndex, screenIndex)
        XCTAssertLessThan(headerStackView.layer.zPosition, screenStackView.layer.zPosition)
    }

    func testHomeScreenIsVisibleAndInteractiveBeforeFirstRenderedFrame() throws {
        QuizFactory.shared.startup1st = true

        let viewController = QuizViewController()
        viewController.loadView()

        let motivationLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel"))
        let collectionView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView"))
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton)

        XCTAssertGreaterThan(motivationLabel.alpha, 0)
        XCTAssertGreaterThan(collectionView.alpha, 0)
        XCTAssertGreaterThan(settingsButton.alpha, 0)
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertTrue(settingsButton.isUserInteractionEnabled)
        XCTAssertTrue(settingsButton.isEnabled)
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

    func testRadarSettingsSurfaceStaysBehindGearArtwork() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton)
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))
        let imageView = try XCTUnwrap(settingsButton.imageView)
        let surfaceIndex = try XCTUnwrap(settingsButton.subviews.firstIndex(of: visualSurface))
        let imageIndex = try XCTUnwrap(settingsButton.subviews.firstIndex(of: imageView))

        XCTAssertLessThan(surfaceIndex, imageIndex)
        XCTAssertNotNil(settingsButton.image(for: .normal))
        XCTAssertEqual(settingsButton.bounds.size, CGSize(width: 44, height: 44))
        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
    }

    func testClassicSettingsSurfaceIsCircular() throws {
        UserDefaults.standard.set(AppDesignStyle.classic.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))

        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
        XCTAssertEqual(visualSurface.layer.cornerRadius, visualSurface.bounds.height / 2, accuracy: 0.001)
        XCTAssertEqual(visualSurface.layer.cornerCurve, .circular)
    }

    func testCleanSettingsSurfaceIsCircular() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 375, height: 667))
        let visualSurface = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsVisualSurface"))

        XCTAssertEqual(visualSurface.bounds.size, CGSize(width: 36, height: 36))
        XCTAssertEqual(visualSurface.layer.cornerRadius, visualSurface.bounds.height / 2, accuracy: 0.001)
        XCTAssertEqual(visualSurface.layer.cornerCurve, .circular)
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

        let label = viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel
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
        XCTAssertEqual(statisticsSize.height, 136)
        XCTAssertEqual(inset.left, 24)
        XCTAssertEqual(inset.right, 24)
        XCTAssertEqual(inset.bottom, 0)
        XCTAssertEqual(lineSpacing, 16)
        XCTAssertEqual(interitemSpacing, 16)
    }

    func testCollectionServiceThemeCardShowsImageAboveThemeTitle() throws {
        useDesignStyle(.clean)
        let themeAssets = [
            (themeID: "music", themeName: "Музыка", symbolName: "music.note.square.stack", fallbackSymbolName: "music.note", tintColorName: "themeMusicTint"),
            (themeID: "technology", themeName: "Технологии", symbolName: "gamecontroller", fallbackSymbolName: "gamecontroller", tintColorName: "themeTechnologyTint"),
            (themeID: "history_culture", themeName: "История и культура", symbolName: "theatermasks", fallbackSymbolName: "theatermasks.fill", tintColorName: "themeCultureTint"),
            (themeID: "politics_business", themeName: "Политика и бизнес", symbolName: "building.columns", fallbackSymbolName: "building.columns.fill", tintColorName: "themePoliticsTint")
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
            let expectedSymbolImage = UIImage(systemName: themeAsset.symbolName) ?? UIImage(systemName: themeAsset.fallbackSymbolName)
            let expectedImage = try XCTUnwrap(expectedSymbolImage?.withRenderingMode(.alwaysTemplate))
            let tintColor = try XCTUnwrap(UIColor(named: themeAsset.tintColorName))

            XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
            XCTAssertEqual(imageView.image?.renderingMode, .alwaysTemplate)
            XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
            assertColor(imageView.tintColor, equals: tintColor.withAlphaComponent(0.75))
            XCTAssertEqual(imageView.transform.a, 0.70, accuracy: 0.01)
            XCTAssertEqual(imageView.transform.d, 0.70, accuracy: 0.01)
            XCTAssertEqual(titleLabel.text, themeAsset.themeName)
            XCTAssertEqual(titleLabel.textAlignment, .center)
            XCTAssertEqual(titleLabel.numberOfLines, 2)
            XCTAssertEqual(titleLabel.lineBreakMode, .byWordWrapping)
            assertColor(themeButton.backgroundColor, equals: assetColor("themeWhite"))
            assertColor(titleLabel.textColor, equals: assetColor("themeCleanSurfaceText"))
            assertColor(UIColor(cgColor: themeButton.layer.borderColor ?? UIColor.clear.cgColor), equals: tintColor.withAlphaComponent(0.75))
            XCTAssertEqual(themeButton.layer.borderWidth, 2)
            XCTAssertGreaterThanOrEqual(imageView.bounds.height, 80)
            XCTAssertLessThan(imageView.frame.minY, titleLabel.frame.minY)
            XCTAssertLessThanOrEqual(imageView.frame.maxY, titleLabel.frame.minY)
            XCTAssertEqual(titleLabel.frame.height, 56, accuracy: 0.5)
            XCTAssertEqual(titleLabel.frame.maxY, themeCell.bounds.maxY - 6, accuracy: 0.5)

            let fittingSize = CGSize(width: titleLabel.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            let requiredTitleHeight = titleLabel.sizeThatFits(fittingSize).height
            XCTAssertLessThanOrEqual(requiredTitleHeight, titleLabel.bounds.height + 0.5)
        }
    }

    func testCompactRadarThemeTitleShrinksAcrossTwoLinesWithoutTruncation() throws {
        useDesignStyle(.radar)
        let theme = makeTheme(name: "История Древнего Рима")
        QuizFactory.shared.themes = [theme]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView(width: 320)
        let indexPath = IndexPath(item: 0, section: 0)
        let itemSize = service.collectionView(
            collectionView,
            layout: collectionView.collectionViewLayout,
            sizeForItemAt: indexPath
        )
        let themeCell = service.collectionView(collectionView, cellForItemAt: indexPath)
        themeCell.frame = CGRect(origin: .zero, size: itemSize)
        themeCell.contentView.frame = themeCell.bounds
        themeCell.layoutIfNeeded()
        themeCell.contentView.layoutIfNeeded()

        let titleIdentifier = "\(ThemesCollectionService.Content.themeTitleAccessibilityIDPrefix)-\(theme.stableID)"
        let titleLabel = try XCTUnwrap(
            themeCell.contentView.descendant(withAccessibilityIdentifier: titleIdentifier) as? UILabel
        )
        let baseFont = AppAppearanceStore.shared
            .appearance(compatibleWith: collectionView.traitCollection)
            .typography
            .font(size: 18, weight: .semibold)
        let requiredHeight = (titleLabel.text! as NSString).boundingRect(
            with: CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleLabel.font!],
            context: nil
        ).height

        XCTAssertLessThan(titleLabel.font.pointSize, baseFont.pointSize)
        XCTAssertGreaterThanOrEqual(titleLabel.font.pointSize, baseFont.pointSize * 0.72 - 0.1)
        XCTAssertLessThanOrEqual(ceil(requiredHeight), ceil(titleLabel.bounds.height) + 0.5)
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
        XCTAssertEqual(themeCell.layer.shadowOpacity, 0)
        XCTAssertEqual(aiThemeButton?.accessibilityLabel, L10n.Home.createWithAI)
        XCTAssertEqual(aiThemeButton?.layer.cornerRadius, 27)
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

    func testCleanDarkThemeCardsKeepTheirDepthShadow() {
        useDesignStyle(.clean)
        UserDefaults.standard.set(
            CleanColorSchemePreference.dark.rawValue,
            forKey: AppAppearanceStore.Keys.cleanColorScheme
        )
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let service = ThemesCollectionService()
        let themeCell = service.collectionView(makeCollectionView(), cellForItemAt: IndexPath(item: 0, section: 0))

        XCTAssertGreaterThan(themeCell.layer.shadowOpacity, 0)
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
            playedTitleLabel.sizeThatFits(CGSize(width: .greatestFiniteMagnitude, height: playedTitleLabel.bounds.height)).width,
            playedTitleLabel.bounds.width + 0.5
        )
        XCTAssertLessThanOrEqual(
            descriptionLabel.sizeThatFits(CGSize(width: descriptionLabel.bounds.width, height: .greatestFiniteMagnitude)).height,
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

        let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))
        let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-music") as? UIImageView)
        let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-music") as? UILabel)
        let aiThemeButton = try XCTUnwrap(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton") as? UIButton)
        let statisticsButton = try XCTUnwrap(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard") as? UIButton)
        let expectedImage = try XCTUnwrap(UIImage(named: "theme_logo_music_radar"))

        XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
        assertColor(titleLabel.textColor, equals: assetColor("themeRadarGreen"))
        XCTAssertNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIGradientBorder"))
        assertColor(aiThemeButton.backgroundColor, equals: .clear)
        assertColor(UIColor(cgColor: aiThemeButton.layer.borderColor ?? UIColor.clear.cgColor), equals: assetColor("themeRadarGreen"))
        assertColor(UIColor(cgColor: aiThemeButton.layer.shadowColor ?? UIColor.clear.cgColor), equals: assetColor("themeRadarGreen"))
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

        let theme = try await service.generateQuizTheme(
            configuration: AIQuizGenerationConfiguration(
                theme: "  Космос  \n",
                questionCount: 10,
                difficulty: .hard,
                locale: locale
            )
        )

        XCTAssertEqual(service.generatedConfigurations.map(\.theme), ["Космос"])
        XCTAssertEqual(service.generatedConfigurations.map(\.questionCount), [10])
        XCTAssertEqual(service.generatedConfigurations.map(\.difficulty), [.hard])
        XCTAssertEqual(service.generatedConfigurations.map(\.locale.identifier), ["ru"])
        XCTAssertEqual(theme.theme, "Космос")
        XCTAssertEqual(theme.themeDescription, "AI generated quiz placeholder")
        XCTAssertTrue(theme.questions.isEmpty)
    }

    private func makeCollectionView(width: CGFloat = 390) -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        let collectionView = UICollectionView(
            frame: CGRect(x: 0, y: 0, width: width, height: 700),
            collectionViewLayout: layout
        )
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

    private func makeStatisticsStore(
        attempts: [(correctAnswers: Int, totalQuestions: Int)] = []
    ) -> StatisticsStore {
        let suiteName = "ru.avtabenskiy.QuiziceTests.HomeScreenVisualStateTests.\(UUID().uuidString)"
        guard let userDefaults = UserDefaults(suiteName: suiteName) else {
            let key = "home-statistics-test-\(UUID().uuidString)"
            let store = StatisticsStore(userDefaults: .standard, key: key)
            attempts.forEach { store.recordAttempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions) }
            return store
        }

        userDefaults.removePersistentDomain(forName: suiteName)
        let store = StatisticsStore(userDefaults: userDefaults, key: "home-statistics-test")
        attempts.forEach { store.recordAttempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions) }
        return store
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

    func themesCollectionDidScroll(_ scrollView: UIScrollView) {}

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
    private(set) var replayQuizCallCount = 0
    private(set) var returnToThemesCallCount = 0

    func showDescription() { showDescriptionCallCount += 1 }
    func showQuestion() { showQuestionCallCount += 1 }
    func showResult(_ result: QuizResultState) { showResultCallCount += 1 }
    func showStatistics() { showStatisticsCallCount += 1 }
    func showAIThemeCreation() { showAIThemeCreationCallCount += 1 }
    func showSettings() { showSettingsCallCount += 1 }
    func closeDescription() { closeDescriptionCallCount += 1 }
    func closeStatistics() { closeStatisticsCallCount += 1 }
    func closeQuestion() { closeQuestionCallCount += 1 }
    func replayQuiz() { replayQuizCallCount += 1 }
    func returnToThemes() { returnToThemesCallCount += 1 }
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
