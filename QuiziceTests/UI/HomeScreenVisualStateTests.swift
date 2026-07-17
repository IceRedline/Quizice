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
        UserDefaults.standard.set(AppDesignStyle.classic.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.set(AppBackgroundStyle.defaultStyle.rawValue, forKey: AppAppearanceStore.Keys.backgroundStyle)
    }

    override func tearDown() {
        testWindows = []
        resetQuizFactory()
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.cleanColorScheme)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.backgroundStyle)
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
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeBackgroundStyleButton"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeDebugInterfaceButton"))
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
#if DEBUG
        XCTAssertFalse(settingsButton.showsMenuAsPrimaryAction)
        XCTAssertNotNil(settingsButton.menu)
#endif

        settingsButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showSettingsCallCount, 1)
    }

    func testHomeSettingsDebugMenuContainsBackgroundPresets() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )

#if DEBUG
        let menu = try XCTUnwrap(settingsButton.menu)
        let interfaceAction = try XCTUnwrap(menu.children.first as? UIAction)
        let backgroundMenu = try XCTUnwrap(menu.children.last as? UIMenu)
        let backgroundActions = backgroundMenu.children.compactMap { $0 as? UIAction }

        XCTAssertEqual(interfaceAction.title, "Hide UI")
        XCTAssertEqual(backgroundMenu.title, L10n.Home.backgroundStyleSwitcher)
        XCTAssertEqual(backgroundActions.count, AppBackgroundStyle.allCases.count)
        XCTAssertEqual(backgroundActions.map(\.title), AppBackgroundStyle.allCases.map(\.title))
        XCTAssertEqual(AppAppearanceStore.shared.backgroundStyle, .slate5x5)
        XCTAssertEqual(backgroundActions.filter { $0.state == .on }.map(\.title), [AppBackgroundStyle.slate5x5.title])
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "appBackgroundView"))

        XCTAssertNotNil(backgroundActions.first { $0.title == AppBackgroundStyle.slate4x4.title })
        viewController.selectBackgroundStyle(.slate4x4)

        XCTAssertEqual(AppAppearanceStore.shared.backgroundStyle, .slate4x4)
        let updatedBackgroundMenu = try XCTUnwrap(settingsButton.menu?.children.last as? UIMenu)
        let updatedBackgroundActions = updatedBackgroundMenu.children.compactMap { $0 as? UIAction }
        XCTAssertEqual(
            updatedBackgroundActions.filter { $0.state == .on }.map(\.title),
            [AppBackgroundStyle.slate4x4.title]
        )
#else
        XCTAssertNil(settingsButton.menu)
#endif
    }

    func testHomeSettingsDebugMenuHidesAndRestoresInterface() throws {
#if DEBUG
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )
        let headerStackView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView")
        )
        let screenStackView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeScreenStackView")
        )
        XCTAssertNotNil(settingsButton.menu?.children.first as? UIAction)

        viewController.toggleDebugInterfaceVisibility()

        XCTAssertTrue(headerStackView.isHidden)
        XCTAssertTrue(screenStackView.isHidden)
        XCTAssertFalse(settingsButton.isHidden)
        XCTAssertTrue(settingsButton.isEnabled)
        settingsButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.showSettingsCallCount, 1)

        let showAction = try XCTUnwrap(settingsButton.menu?.children.first as? UIAction)
        XCTAssertEqual(showAction.title, "Show UI")
        viewController.toggleDebugInterfaceVisibility()

        XCTAssertFalse(headerStackView.isHidden)
        XCTAssertFalse(screenStackView.isHidden)
#endif
    }

    func testHomeHasNoSeparateDebugButtonsOrInactiveBackgroundMenu() throws {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))

        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeBackgroundStyleButton"))
        XCTAssertNil(viewController.view.descendant(withAccessibilityIdentifier: "homeDebugInterfaceButton"))
#if DEBUG
        let settingsButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton") as? UIButton
        )
        XCTAssertTrue(settingsButton.menu?.children.compactMap { $0 as? UIMenu }.isEmpty == true)
#endif
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

    func testAIThemeCardExpandsInlineAboveFullScreenBackdropAndDisablesGrid() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )
        let initialScrollEnabled = collectionView.isScrollEnabled
        let initialContentOffset = collectionView.contentOffset

        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let backdrop = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )

        XCTAssertTrue(backdrop.superview === viewController.view)
        XCTAssertEqual(backdrop.frame, viewController.view.bounds)
        XCTAssertTrue(backdrop is UIVisualEffectView)
        XCTAssertNotNil((backdrop as? UIVisualEffectView)?.effect)
        XCTAssertTrue(card.superview === viewController.view)
        XCTAssertFalse(card.isDescendant(of: backdrop))
        XCTAssertGreaterThan(card.layer.zPosition, backdrop.layer.zPosition)
        XCTAssertTrue(card.accessibilityViewIsModal)
        let presentedSourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )
        XCTAssertTrue(presentedSourceButton.isHidden)
        XCTAssertFalse(presentedSourceButton.isEnabled)
        XCTAssertFalse(collectionView.isUserInteractionEnabled)
        XCTAssertFalse(collectionView.isScrollEnabled)
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCardTransition"
            )
        )
        XCTAssertEqual(router.showDescriptionCallCount, 0)
        XCTAssertEqual(router.showStatisticsCallCount, 0)

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        backdropDismissButton.sendActions(for: .touchUpInside)
        drainAnimations()

        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        let restoredSourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )
        XCTAssertFalse(restoredSourceButton.isHidden)
        XCTAssertTrue(restoredSourceButton.isEnabled)
        XCTAssertTrue(restoredSourceButton.isAccessibilityElement)
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertEqual(collectionView.isScrollEnabled, initialScrollEnabled)
        XCTAssertEqual(collectionView.contentOffset.x, initialContentOffset.x, accuracy: 0.001)
        XCTAssertEqual(collectionView.contentOffset.y, initialContentOffset.y, accuracy: 0.001)
        XCTAssertEqual(router.showDescriptionCallCount, 0)
        XCTAssertEqual(router.showStatisticsCallCount, 0)
    }

    func testAIThemeCardRequiresTrimmedPromptBeforeFlipAndHasNoParallax() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]

        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            cardReduceMotionProvider: { false },
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeCreateWithAIButton"
            ) as? UIButton
        )

        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedAIThemeCard"
            )
        )
        let promptEditor = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "aiThemePromptEditor") as? UITextView
        )
        let playButton = try XCTUnwrap(
            card.descendant(
                withAccessibilityIdentifier: "expandedAIThemeCardPlayButton"
            ) as? UIButton
        )
        let frontView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedAIThemeCardFrontView")
        )
        let backView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedAIThemeCardBackView")
        )

        XCTAssertFalse(playButton.isEnabled)
        XCTAssertFalse(frontView.isHidden)
        XCTAssertTrue(backView.isHidden)
        XCTAssertFalse(promptEditor.isScrollEnabled)

        promptEditor.text = " \n\t "
        promptEditor.delegate?.textViewDidChange?(promptEditor)

        XCTAssertFalse(playButton.isEnabled)

        promptEditor.text = "  Космос  \n"
        promptEditor.delegate?.textViewDidChange?(promptEditor)

        XCTAssertTrue(playButton.isEnabled)

        playButton.sendActions(for: .touchUpInside)
        drainAnimations()

        XCTAssertTrue(frontView.isHidden)
        XCTAssertFalse(backView.isHidden)
        XCTAssertFalse(backView.accessibilityElementsHidden)
        XCTAssertNil(
            card.descendant(
                withAccessibilityIdentifier: "expandedAIThemeCardParallaxCarrier"
            )
        )
        XCTAssertNil(
            card.descendant(
                withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier"
            )
        )
        XCTAssertNil(parallaxPanGestureRecognizer(in: card))
        XCTAssertFalse(
            (card.gestureRecognizers ?? []).contains { $0 is UIPanGestureRecognizer }
        )
        XCTAssertEqual(motionProvider.startCallCount, 0)
        XCTAssertFalse(motionProvider.isStarted)
    }

    func testStatisticsCardExpandsInlineTracksOnceAndRestoresTheGridWithoutQuizCancellation() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let statisticsStore = makeStatisticsStore(attempts: [
            (correctAnswers: 3, totalQuestions: 5),
            (correctAnswers: 5, totalQuestions: 5)
        ])
        let analytics = HomeAnalyticsTrackingSpy()
        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            statisticsStore: statisticsStore,
            analytics: analytics,
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)
        analytics.reset()

        let collectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        collectionView.layoutIfNeeded()
        let initialScrollEnabled = collectionView.isScrollEnabled
        let initialAlwaysBounceVertical = collectionView.alwaysBounceVertical
        let initialBounces = collectionView.bounces
        let initialContentOffset = collectionView.contentOffset
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeStatisticsCard"
            ) as? UIButton
        )

        sourceButton.sendActions(for: .touchUpInside)
        XCTAssertEqual(router.showStatisticsCallCount, 0)
        drainAnimations()

        let backdrop = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        let expandedCard = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedStatisticsCard"
            )
        )
        XCTAssertTrue(backdrop.superview === viewController.view)
        XCTAssertEqual(backdrop.frame, viewController.view.bounds)
        XCTAssertTrue(backdrop is UIVisualEffectView)
        XCTAssertNotNil((backdrop as? UIVisualEffectView)?.effect)
        XCTAssertTrue(expandedCard.superview === viewController.view)
        XCTAssertFalse(expandedCard.isDescendant(of: backdrop))
        XCTAssertGreaterThan(expandedCard.layer.zPosition, backdrop.layer.zPosition)
        XCTAssertTrue(expandedCard.accessibilityViewIsModal)
        XCTAssertTrue(sourceButton.isHidden)
        XCTAssertFalse(collectionView.isUserInteractionEnabled)
        XCTAssertFalse(collectionView.isScrollEnabled)
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedStatisticsCardTransition"
            )
        )
        XCTAssertFalse(
            (expandedCard.gestureRecognizers ?? []).contains { $0 is UIPanGestureRecognizer }
        )
        XCTAssertNil(parallaxPanGestureRecognizer(in: expandedCard))
        XCTAssertEqual(motionProvider.startCallCount, 0)
        XCTAssertFalse(motionProvider.isStarted)

        let expectedMetrics: [(id: String, title: String, value: String)] = [
            ("playedQuizzes", L10n.Statistics.playedQuizzes, "2"),
            ("correctAnswers", L10n.Statistics.correctAnswers, "8/10"),
            ("percentage", L10n.Statistics.percentage, "80%"),
            ("bestResult", L10n.Statistics.bestResult, "5/5")
        ]
        let metricRows = try expectedMetrics.map { expected in
            let row = try XCTUnwrap(
                viewController.view.descendant(
                    withAccessibilityIdentifier: "expandedStatisticsMetric-\(expected.id)"
                )
            )
            XCTAssertEqual(row.accessibilityLabel, expected.title)
            XCTAssertEqual(row.accessibilityValue, expected.value)
            return row
        }
        XCTAssertEqual(Set(metricRows.map { ObjectIdentifier($0) }).count, 4)
        XCTAssertTrue(
            try XCTUnwrap(
                viewController.view.descendant(
                    withAccessibilityIdentifier: "expandedStatisticsCardEmptyState"
                )
            ).isHidden
        )

        let inlineStatisticsEvents = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(inlineStatisticsEvents.map(\.name), ["screen_view", "statistics_viewed"])
        let statisticsScreenEvents = analytics.events.filter {
            $0.name == "screen_view" && $0.parameters["screen"] as? String == "statistics"
        }
        let statisticsViewedEvents = analytics.events.filter { $0.name == "statistics_viewed" }
        XCTAssertEqual(statisticsScreenEvents.count, 1)
        XCTAssertEqual(statisticsViewedEvents.count, 1)
        XCTAssertEqual(statisticsViewedEvents.first?.parameters["attempts_count"] as? Int, 2)
        XCTAssertEqual(statisticsViewedEvents.first?.parameters["total_questions"] as? Int, 10)
        XCTAssertEqual(statisticsViewedEvents.first?.parameters["accuracy_percent"] as? Int, 80)
        XCTAssertFalse(analytics.events.contains { $0.name == "quiz_setup_cancelled" })

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        backdropDismissButton.sendActions(for: .touchUpInside)
        drainAnimations()

        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop"
            )
        )
        XCTAssertNil(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedStatisticsCard"
            )
        )
        let restoredSourceButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeStatisticsCard"
            ) as? UIButton
        )
        XCTAssertFalse(restoredSourceButton.isHidden)
        XCTAssertTrue(restoredSourceButton.isUserInteractionEnabled)
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertEqual(collectionView.isScrollEnabled, initialScrollEnabled)
        XCTAssertEqual(collectionView.alwaysBounceVertical, initialAlwaysBounceVertical)
        XCTAssertEqual(collectionView.bounces, initialBounces)
        XCTAssertEqual(collectionView.contentOffset.x, initialContentOffset.x, accuracy: 0.001)
        XCTAssertEqual(collectionView.contentOffset.y, initialContentOffset.y, accuracy: 0.001)
        XCTAssertEqual(router.showStatisticsCallCount, 0)
        let eventsAfterCollapse = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(eventsAfterCollapse.map(\.name), ["screen_view", "statistics_viewed"])
        XCTAssertFalse(analytics.events.contains { $0.name == "quiz_setup_cancelled" })
    }

    func testCatalogThemeExpandsInlineAboveFullScreenBlurAndClosesBackToGrid() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeThemesCollectionView") as? UICollectionView
        )
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        let sourceCell = try XCTUnwrap(
            collectionView.visibleCells
                .compactMap { $0 as? ThemeCardCollectionViewCell }
                .first(where: { $0.actionButton === sourceButton })
        )
        let sourceFrame = sourceButton.convert(sourceButton.bounds, to: viewController.view)
        let expectedSourceShadowPath = UIBezierPath(
            roundedRect: sourceButton.frame,
            cornerRadius: sourceButton.layer.cornerRadius
        ).cgPath
        XCTAssertEqual(sourceCell.layer.shadowPath, expectedSourceShadowPath)

        sourceButton.sendActions(for: .touchUpInside)

        let backdrop = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
        let card = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        let transitionView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        let transitionChrome = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransitionChrome")
        )
        let transitionIntensity = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransitionIntensity")
        )
        let sourceSnapshot = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardSourceSnapshot")
        )
        let sourceContentHost = try XCTUnwrap(sourceSnapshot.superview)
        let frontImageView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardFrontImageView"
            ) as? UIImageView
        )
        card.layoutIfNeeded()
        XCTAssertTrue(backdrop.superview === viewController.view)
        XCTAssertTrue(transitionView.superview === viewController.view)
        XCTAssertEqual(transitionChrome.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(transitionIntensity.alpha, 1, accuracy: 0.001)
        XCTAssertFalse(card.superview === viewController.view)
        XCTAssertTrue(sourceSnapshot.isDescendant(of: transitionView))
        XCTAssertEqual(sourceSnapshot.center.x, sourceContentHost.bounds.midX, accuracy: 0.001)
        XCTAssertEqual(sourceSnapshot.center.y, sourceContentHost.bounds.midY, accuracy: 0.001)
        XCTAssertEqual(sourceSnapshot.bounds.size, sourceFrame.size)
        XCTAssertGreaterThan(card.bounds.width, sourceSnapshot.bounds.width)
        XCTAssertGreaterThan(card.bounds.height, sourceSnapshot.bounds.height)
        XCTAssertTrue(CGAffineTransformIsIdentity(card.transform))
        XCTAssertEqual(backdrop.frame, viewController.view.bounds)
        XCTAssertLessThan(backdrop.layer.zPosition, transitionView.layer.zPosition)
        XCTAssertTrue(backdrop is UIVisualEffectView)
        XCTAssertFalse(collectionView.isUserInteractionEnabled)
        XCTAssertTrue(sourceButton.isHidden)
        XCTAssertTrue(card.accessibilityViewIsModal)
        XCTAssertEqual(frontImageView.contentMode, .scaleAspectFit)
        XCTAssertGreaterThan(frontImageView.image?.size.width ?? 0, 0)
        XCTAssertTrue(
            viewController.view.descendant(withAccessibilityIdentifier: "homeHeaderStackView")?.accessibilityElementsHidden == true
        )
        XCTAssertTrue(
            viewController.view.descendant(withAccessibilityIdentifier: "homeScreenStackView")?.accessibilityElementsHidden == true
        )
        XCTAssertTrue(
            viewController.view.descendant(withAccessibilityIdentifier: "homeSettingsButton")?.accessibilityElementsHidden == true
        )
        XCTAssertEqual(router.showDescriptionCallCount, 0)

        let targetCardFrame = card.convert(card.bounds, to: viewController.view)
        drainAnimations(0.08)
        XCTAssertEqual(sourceSnapshot.bounds.size, sourceFrame.size)
        XCTAssertEqual(card.bounds.size, targetCardFrame.size)
        XCTAssertTrue(CGAffineTransformIsIdentity(card.transform))

        drainAnimations()
        viewController.view.layoutIfNeeded()
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        XCTAssertTrue(card.superview === viewController.view)
        XCTAssertEqual(sourceSnapshot.bounds.size, sourceFrame.size)
        XCTAssertTrue(sourceSnapshot.isHidden)
        XCTAssertGreaterThan(frontImageView.bounds.width, 100)
        XCTAssertGreaterThan(frontImageView.bounds.height, 100)
        XCTAssertNotNil((backdrop as? UIVisualEffectView)?.effect)
        XCTAssertTrue(viewController.cardSlideTransitionSourceView === card)

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        backdropDismissButton.sendActions(for: .touchUpInside)

        let collapsingTransition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        let collapsingChrome = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransitionChrome")
        )
        let collapsingIntensity = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransitionIntensity")
        )
        XCTAssertTrue(collapsingTransition.superview === viewController.view)
        XCTAssertEqual(collapsingChrome.alpha, 1, accuracy: 0.001)
        XCTAssertEqual(collapsingIntensity.alpha, 0, accuracy: 0.001)
        XCTAssertEqual(collapsingTransition.layer.shadowPath, sourceCell.layer.shadowPath)
        let collapsingSourceSnapshot = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardSourceSnapshot"
            )
        )
        XCTAssertEqual(collapsingSourceSnapshot.bounds.size, sourceFrame.size)
        XCTAssertFalse(collapsingSourceSnapshot.isHidden)
        XCTAssertFalse(card.superview === viewController.view)
        drainAnimations()

        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        XCTAssertTrue(collectionView.isUserInteractionEnabled)
        XCTAssertFalse(
            try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton).isHidden
        )
    }

    func testExpandedClassicArtworkPreservesTheSourceImageAspectRatio() throws {
        useDesignStyle(.classic)
        QuizFactory.shared.themes = [makeTheme(name: "Технологии", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "technology") as? UIButton
        )
        let sourceImageView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemeImageView-technology"
            ) as? UIImageView
        )
        let sourceImage = try XCTUnwrap(sourceImageView.image)
        let sourceAspectRatio = sourceImage.size.width / sourceImage.size.height
        XCTAssertGreaterThan(abs(sourceAspectRatio - 1), 0.01)

        sourceButton.sendActions(for: .touchUpInside)

        let expandedImageView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardFrontImageView"
            ) as? UIImageView
        )
        let expandedImage = try XCTUnwrap(expandedImageView.image)
        let expandedAspectRatio = expandedImage.size.width / expandedImage.size.height

        XCTAssertEqual(expandedImageView.contentMode, .scaleAspectFit)
        XCTAssertEqual(expandedAspectRatio, sourceAspectRatio, accuracy: 0.001)
    }

    func testCollapseRefreshesSourceContentAfterAppearanceChanges() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        AppAppearanceStore.shared.designStyle = .radar
        viewController.view.layoutIfNeeded()

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        backdropDismissButton.sendActions(for: .touchUpInside)

        let refreshedSourceContent = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardSourceSnapshot"
            )
        )
        let refreshedImageView = try XCTUnwrap(
            refreshedSourceContent.subviews.compactMap { $0 as? UIImageView }.first
        )
        let expectedRadarImage = try XCTUnwrap(UIImage(named: "theme_logo_music_radar"))

        XCTAssertEqual(refreshedImageView.image?.pngData(), expectedRadarImage.pngData())
        drainAnimations()
    }

    func testExpandAndCollapseReverseInFlightUsingTheSameTransitionView() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)

        let expandingTransition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        let expandingSurface = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardTransitionSurfaceButton"
            ) as? UIButton
        )
        let expandingBackdrop = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        XCTAssertFalse(expandingTransition.isUserInteractionEnabled)
        XCTAssertTrue(expandingSurface.superview === viewController.view)

        expandingBackdrop.sendActions(for: .touchUpInside)
        XCTAssertTrue(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardTransition"
            ) === expandingTransition
        )
        drainAnimations()
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        XCTAssertFalse(
            try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
            ).isHidden
        )

        let refreshedSourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        refreshedSourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        let expandedCard = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        let expandedCardFrame = expandedCard.convert(expandedCard.bounds, to: viewController.view)
        backdropDismissButton.sendActions(for: .touchUpInside)
        let collapsingTransition = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        let collapsingSurface = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardTransitionSurfaceButton"
            ) as? UIButton
        )

        let visibleFrame = collapsingTransition.layer.presentation()?.frame ?? expandedCardFrame
        let sourceFrame = refreshedSourceButton.convert(refreshedSourceButton.bounds, to: viewController.view)
        let candidatePoints = [
            CGPoint(x: visibleFrame.minX + 12, y: visibleFrame.minY + 12),
            CGPoint(x: visibleFrame.maxX - 12, y: visibleFrame.minY + 12),
            CGPoint(x: visibleFrame.minX + 12, y: visibleFrame.maxY - 12),
            CGPoint(x: visibleFrame.maxX - 12, y: visibleFrame.maxY - 12)
        ]
        let visiblePointOutsideSource = try XCTUnwrap(
            candidatePoints.first {
                viewController.view.bounds.contains($0) && !sourceFrame.contains($0)
            }
        )
        let hitControl = try XCTUnwrap(
            viewController.view.hitTest(visiblePointOutsideSource, with: nil) as? UIControl
        )
        XCTAssertTrue(hitControl === collapsingSurface)
        hitControl.sendActions(for: .touchUpInside)
        XCTAssertTrue(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardTransition"
            ) === collapsingTransition
        )
        drainAnimations()
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardTransition")
        )
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
    }

    func testReducedMotionExpansionCanReverseFromVisibleSourceSurface() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = QuizViewController(cardReduceMotionProvider: { true })
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        backdropDismissButton.sendActions(for: .touchUpInside)
        drainAnimations(0.24)

        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        XCTAssertFalse(
            try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
            ).isHidden
        )
    }

    func testExpandedThemeCardUsesReducedTransparencyBackdropAndReducedMotionCrossfade() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = QuizViewController(
            cardReduceMotionProvider: { true },
            cardReduceTransparencyProvider: { true }
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations(0.22)

        let backdrop = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
        XCTAssertFalse(backdrop is UIVisualEffectView)
        XCTAssertEqual(backdrop.alpha, 1, accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(backdrop.backgroundColor?.cgColor.alpha ?? 0, 0.95)

        let front = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontView")
        )
        let back = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let rotatingCarrier = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(CATransform3DIsIdentity(front.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(back.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        drainAnimations(0.22)
        XCTAssertTrue(front.isHidden)
        XCTAssertFalse(back.isHidden)
        XCTAssertTrue(CATransform3DIsIdentity(front.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(back.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
    }

    func testExpandedThemeExpansionUsesIndependentArtworkAndTitleDepth() throws {
        let card = ExpandedThemeCardView(frame: CGRect(x: 0, y: 0, width: 350, height: 518))
        card.reduceMotionProvider = { false }
        card.configure(
            theme: makeTheme(name: "Музыка", questionCount: 5),
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            availableQuestionCounts: [5],
            selectedQuestionCount: 5
        )
        card.layoutIfNeeded()

        let artworkDepth = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontArtworkDepth")
        )
        let titleDepth = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontTitleDepth")
        )
        let sourceGeometry = HomeThemeCardContentGeometry(
            containerSize: CGSize(width: 163, height: 163),
            imageCenter: CGPoint(x: 81.5, y: 54),
            titleCenter: CGPoint(x: 81.5, y: 132)
        )

        card.setTransitionContentProgress(0, sourceGeometry: sourceGeometry)

        XCTAssertEqual(artworkDepth.transform.a, 0.94, accuracy: 0.000_001)
        XCTAssertEqual(artworkDepth.transform.d, 0.94, accuracy: 0.000_001)
        XCTAssertEqual(titleDepth.transform.a, 0.985, accuracy: 0.000_001)
        XCTAssertEqual(titleDepth.transform.d, 0.985, accuracy: 0.000_001)
        XCTAssertNotEqual(artworkDepth.transform.ty, 0)
        XCTAssertNotEqual(titleDepth.transform.ty, 0)

        card.setTransitionContentProgress(1, sourceGeometry: sourceGeometry)

        XCTAssertTrue(artworkDepth.transform.isIdentity)
        XCTAssertTrue(titleDepth.transform.isIdentity)
    }

    func testExpandedThemeInjectedDevicePoseTiltsWholeCardWithoutDetachingFrontContent() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            cardReduceMotionProvider: { false },
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCard"
            ) as? ExpandedThemeCardView
        )
        let parallaxCarrier = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier"
            )
        )
        let frontImage = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardFrontImageView"
            )
        )
        let frontTitle = card.frontFocusView
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardInfoButton"
            ) as? UIButton
        )
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardCloseButton"
            ) as? UIButton
        )
        let rotatingCarrier = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier"
            )
        )

        XCTAssertGreaterThanOrEqual(motionProvider.startCallCount, 1)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        motionProvider.send(HomeThemeCardParallaxInput(x: 0.5, y: -0.25))

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(closeButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        motionProvider.send(.zero)

        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(closeButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
    }

    func testExpandedThemeMotionProviderStaysActiveAcrossFlipAndBackThenStopsOnRemoval() throws {
        let motionProvider = HomeThemeCardMotionProviderFake()
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView

        card.setParallaxPresentationPhase(.front)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertTrue(motionProvider.isStarted)

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.75, y: 0.5))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        let frontPoseTransform = parallaxCarrier.layer.transform

        card.setParallaxPresentationPhase(.flipping)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                parallaxCarrier.layer.transform,
                frontPoseTransform
            )
        )

        var completedFace: HomeThemeCardFace?
        card.setFace(.back, animated: true) { face in
            completedFace = face
            card.setParallaxPresentationPhase(.back)
        }
        let flippingCarrierTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: 0.4, y: 0.3))

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertFalse(
            CATransform3DEqualToTransform(
                parallaxCarrier.layer.transform,
                frontPoseTransform
            )
        )
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                flippingCarrierTransform
            )
        )
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertNil(completedFace)

        drainAnimations(0.34)

        XCTAssertEqual(completedFace, .back)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertEqual(motionProvider.stopCallCount, 0)
        XCTAssertTrue(motionProvider.isStarted)
        let backFlipTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.2, y: -0.6))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.removeFromSuperview()
        XCTAssertEqual(motionProvider.stopCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
    }

    func testExpandedThemeFrontPanTiltsRigidCardAndSpringsBackToIdentity() throws {
        let motionProvider = HomeThemeCardMotionProviderFake(isAvailable: false)
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView
        let infoButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )

        card.setParallaxPresentationPhase(.front)
        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 72, y: -84),
            velocity: .zero
        )

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))

        card.handleFrontParallaxPan(
            state: .ended,
            translation: CGPoint(x: 72, y: -84),
            velocity: CGPoint(x: 180, y: -120)
        )
        drainAnimations(0.45)

        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(infoButton.transform.isIdentity)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
    }

    func testExpandedThemeBackDeviceMotionAndPanBothTiltWholeCard() throws {
        let motionProvider = HomeThemeCardMotionProviderFake()
        let card = makeHostedExpandedThemeCard(motionProvider: motionProvider)
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let rotatingCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let frontTitle = card.frontFocusView

        card.setParallaxPresentationPhase(.front)
        XCTAssertEqual(motionProvider.startCallCount, 1)
        card.setParallaxPresentationPhase(.flipping)
        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        let backFlipTransform = rotatingCarrier.layer.transform

        motionProvider.send(HomeThemeCardParallaxInput(x: -0.5, y: 0.25))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        XCTAssertEqual(motionProvider.stopCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)

        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 112, y: -40),
            velocity: .zero
        )
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
        XCTAssertTrue(
            CATransform3DEqualToTransform(
                rotatingCarrier.layer.transform,
                backFlipTransform
            )
        )

        card.handleFrontParallaxPan(
            state: .ended,
            translation: CGPoint(x: 112, y: -40),
            velocity: CGPoint(x: 150, y: -80)
        )
        drainAnimations(0.45)

        XCTAssertEqual(motionProvider.startCallCount, 2)
        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
        XCTAssertTrue(frontTitle.transform.isIdentity)
    }

    func testExpandedThemeParallaxPanLeavesBackScrollAndControlsInteractive() throws {
        let card = makeHostedExpandedThemeCard(
            motionProvider: HomeThemeCardMotionProviderFake(isAvailable: false)
        )
        card.setParallaxPresentationPhase(.front)

        let parallaxPan = try XCTUnwrap(
            parallaxPanGestureRecognizer(in: card)
        )
        let infoButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        let closeButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        let descriptionScrollView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView
        )
        let descriptionLabel = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel
        )
        let backTitleLabel = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel
        )
        let backSurfaceButton = try XCTUnwrap(
            card.descendant(
                withAccessibilityIdentifier: "expandedThemeCardBackSurfaceButton"
            ) as? UIButton
        )
        let backFaceView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let backTap = try XCTUnwrap(
            backFaceView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first
        )
        let questionCountControl = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UISegmentedControl
        )
        let startButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        let backButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )

        XCTAssertTrue(parallaxPan.cancelsTouchesInView)
        XCTAssertFalse(parallaxPan.delaysTouchesBegan)
        XCTAssertEqual(parallaxPan.maximumNumberOfTouches, 1)
        XCTAssertTrue(parallaxPan.isEnabled)
        XCTAssertTrue(hitView(in: card, for: infoButton)?.isDescendant(of: infoButton) == true)
        XCTAssertTrue(hitView(in: card, for: closeButton)?.isDescendant(of: closeButton) == true)
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)

        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        card.layoutIfNeeded()

        var selectedQuestionCount: Int?
        var startCallCount = 0
        var backCallCount = 0
        card.onQuestionCountChanged = { selectedQuestionCount = $0 }
        card.onStart = { startCallCount += 1 }
        card.onBack = { backCallCount += 1 }

        XCTAssertTrue(parallaxPan.isEnabled)
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)
        XCTAssertTrue(descriptionScrollView.isDirectionalLockEnabled)
        XCTAssertFalse(parallaxPan === descriptionScrollView.panGestureRecognizer)
        XCTAssertTrue(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: descriptionScrollView.panGestureRecognizer
            )
        )
        XCTAssertTrue(
            card.gestureRecognizer(
                descriptionScrollView.panGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: parallaxPan
            )
        )
        XCTAssertFalse(
            card.gestureRecognizer(
                backTap,
                shouldRecognizeSimultaneouslyWith: parallaxPan
            )
        )
        XCTAssertFalse(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: backTap
            )
        )
        XCTAssertTrue(questionCountControl.isEnabled)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
        XCTAssertTrue(card.gestureRecognizerShouldBegin(parallaxPan))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: descriptionScrollView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: descriptionLabel))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: questionCountControl))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: startButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backTitleLabel))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backSurfaceButton))
        let questionCountHitView = try XCTUnwrap(hitView(in: card, for: questionCountControl))
        let startHitView = try XCTUnwrap(hitView(in: card, for: startButton))
        let backHitView = try XCTUnwrap(hitView(in: card, for: backButton))
        XCTAssertTrue(questionCountHitView.isDescendant(of: questionCountControl))
        XCTAssertTrue(startHitView.isDescendant(of: startButton))
        XCTAssertTrue(backHitView.isDescendant(of: backButton))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: questionCountHitView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: startHitView))
        XCTAssertTrue(card.allowsParallaxPan(startingAt: backHitView))

        questionCountControl.selectedSegmentIndex = 0
        questionCountControl.sendActions(for: .valueChanged)
        startButton.sendActions(for: .touchUpInside)
        backButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(selectedQuestionCount, 5)
        XCTAssertEqual(startCallCount, 1)
        XCTAssertEqual(backCallCount, 1)
    }

    func testExpandedThemeBackCenterSupportsVerticalTiltAndDescriptionScrollTogether() throws {
        let card = makeHostedExpandedThemeCard(
            motionProvider: HomeThemeCardMotionProviderFake(isAvailable: false)
        )
        let longDescription = Array(
            repeating: "A deliberately long theme description that must scroll vertically.",
            count: 24
        ).joined(separator: " ")
        card.configure(
            theme: makeTheme(
                name: "Музыка",
                questionCount: 5,
                description: longDescription
            ),
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            availableQuestionCounts: [5],
            selectedQuestionCount: 5
        )
        card.setFace(.back, animated: false)
        card.setParallaxPresentationPhase(.back)
        card.layoutIfNeeded()

        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let parallaxPan = try XCTUnwrap(parallaxPanGestureRecognizer(in: card))
        let descriptionScrollView = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView
        )
        let centerInCard = descriptionScrollView.convert(
            CGPoint(
                x: descriptionScrollView.bounds.midX,
                y: descriptionScrollView.bounds.midY
            ),
            to: card
        )
        let centerHitView = try XCTUnwrap(card.hitTest(centerInCard, with: nil))

        XCTAssertGreaterThan(
            descriptionScrollView.contentSize.height,
            descriptionScrollView.bounds.height
        )
        XCTAssertTrue(
            centerHitView === descriptionScrollView ||
                centerHitView.isDescendant(of: descriptionScrollView)
        )
        XCTAssertTrue(card.allowsParallaxPan(startingAt: centerHitView))
        XCTAssertTrue(
            card.gestureRecognizer(
                parallaxPan,
                shouldRecognizeSimultaneouslyWith: descriptionScrollView.panGestureRecognizer
            )
        )

        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 0, y: 72),
            velocity: CGPoint(x: 0, y: 180)
        )

        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(descriptionScrollView.isScrollEnabled)
        XCTAssertTrue(descriptionScrollView.panGestureRecognizer.isEnabled)

        card.handleFrontParallaxPan(
            state: .cancelled,
            translation: CGPoint(x: 0, y: 72),
            velocity: .zero
        )
        drainAnimations(0.45)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
    }

    func testExpandedThemeStartStopsBackMotionBeforeRoutingAndIgnoresRepeatedStart() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let motionProvider = HomeThemeCardMotionProviderFake()
        let viewController = QuizViewController(
            cardReduceMotionProvider: { false },
            cardDeviceParallaxEnabledProvider: { true },
            cardMotionProvider: motionProvider
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)

        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let infoButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardInfoButton"
            ) as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let card = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCard"
            ) as? ExpandedThemeCardView
        )
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let parallaxPan = try XCTUnwrap(parallaxPanGestureRecognizer(in: card))
        let startButton = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )

        XCTAssertTrue(motionProvider.isStarted)
        XCTAssertTrue(parallaxPan.isEnabled)
        motionProvider.send(HomeThemeCardParallaxInput(x: 0.6, y: -0.4))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))

        var providerWasStoppedBeforeRouting: Bool?
        var panWasDisabledBeforeRouting: Bool?
        router.onShowQuestion = {
            providerWasStoppedBeforeRouting = !motionProvider.isStarted &&
                motionProvider.stopCallCount > 0
            panWasDisabledBeforeRouting = !parallaxPan.isEnabled
        }

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(providerWasStoppedBeforeRouting, true)
        XCTAssertEqual(panWasDisabledBeforeRouting, true)
        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertFalse(card.isUserInteractionEnabled)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertFalse(motionProvider.isStarted)
    }

    func testExpandedThemeReduceMotionBlocksProviderAndDragThenRuntimeToggleNeutralizesPose() throws {
        var reduceMotion = true
        let motionProvider = HomeThemeCardMotionProviderFake()
        let card = makeHostedExpandedThemeCard(
            motionProvider: motionProvider,
            reduceMotionProvider: { reduceMotion }
        )
        let parallaxCarrier = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardParallaxCarrier")
        )
        let frontImage = try XCTUnwrap(
            card.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontImageView")
        )
        let parallaxPan = try XCTUnwrap(
            parallaxPanGestureRecognizer(in: card)
        )

        card.setParallaxPresentationPhase(.front)

        XCTAssertEqual(motionProvider.startCallCount, 0)
        XCTAssertFalse(parallaxPan.isEnabled)
        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: 100, y: 100),
            velocity: .zero
        )
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)

        reduceMotion = false
        NotificationCenter.default.post(
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        XCTAssertEqual(motionProvider.startCallCount, 1)
        XCTAssertTrue(parallaxPan.isEnabled)

        motionProvider.send(HomeThemeCardParallaxInput(x: 0.8, y: -0.6))
        XCTAssertFalse(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)

        reduceMotion = true
        NotificationCenter.default.post(
            name: UIAccessibility.reduceMotionStatusDidChangeNotification,
            object: nil
        )
        XCTAssertEqual(motionProvider.stopCallCount, 1)
        XCTAssertFalse(parallaxPan.isEnabled)
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)

        card.handleFrontParallaxPan(state: .began, translation: .zero, velocity: .zero)
        card.handleFrontParallaxPan(
            state: .changed,
            translation: CGPoint(x: -100, y: -100),
            velocity: .zero
        )
        XCTAssertTrue(CATransform3DIsIdentity(parallaxCarrier.layer.transform))
        XCTAssertTrue(frontImage.transform.isIdentity)
    }

    func testExpandedThemeFlipUsesOneTransformCarrierForBothPlanes() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let card = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        let rotatingCarrier = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardRotatingCarrier")
        )
        let shadowProxy = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardShadowProxy")
        )
        let frontPlane = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontPlane")
        )
        let backPlane = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackPlane")
        )
        let perspectiveStage = try XCTUnwrap(rotatingCarrier.superview)
        let front = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontView")
        )
        let back = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )

        XCTAssertTrue(frontPlane.superview === rotatingCarrier)
        XCTAssertTrue(backPlane.superview === rotatingCarrier)
        XCTAssertTrue(frontPlane.isDescendant(of: rotatingCarrier))
        XCTAssertTrue(backPlane.isDescendant(of: rotatingCarrier))
        XCTAssertTrue(rotatingCarrier.layer is CATransformLayer)
        XCTAssertTrue(shadowProxy.superview === perspectiveStage)
        XCTAssertNotNil(shadowProxy.layer.shadowPath)
        XCTAssertFalse(frontPlane.layer.isDoubleSided)
        XCTAssertFalse(backPlane.layer.isDoubleSided)
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(frontPlane.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(backPlane.layer.transform))
        XCTAssertFalse(front.accessibilityElementsHidden)
        XCTAssertTrue(back.accessibilityElementsHidden)

        infoButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(CATransform3DIsIdentity(card.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(shadowProxy.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(frontPlane.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(backPlane.layer.transform))
        XCTAssertLessThan(perspectiveStage.layer.sublayerTransform.m34, 0)
        XCTAssertTrue(CATransform3DIsIdentity(front.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(back.layer.transform))
        XCTAssertFalse(front.accessibilityElementsHidden)
        XCTAssertTrue(back.accessibilityElementsHidden)

        drainAnimations(0.34)
        XCTAssertTrue(CATransform3DIsIdentity(card.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(frontPlane.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(backPlane.layer.transform))
        XCTAssertTrue(frontPlane.isHidden)
        XCTAssertFalse(backPlane.isHidden)
        XCTAssertTrue(front.isHidden)
        XCTAssertFalse(back.isHidden)
        XCTAssertTrue(front.accessibilityElementsHidden)
        XCTAssertFalse(back.accessibilityElementsHidden)

        let backButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )
        backButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(CATransform3DIsIdentity(card.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(frontPlane.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(backPlane.layer.transform))
        XCTAssertLessThan(perspectiveStage.layer.sublayerTransform.m34, 0)
        XCTAssertTrue(CATransform3DIsIdentity(front.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(back.layer.transform))
        XCTAssertTrue(front.accessibilityElementsHidden)
        XCTAssertFalse(back.accessibilityElementsHidden)

        drainAnimations(0.34)
        XCTAssertTrue(CATransform3DIsIdentity(card.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(rotatingCarrier.layer.transform))
        XCTAssertTrue(CATransform3DIsIdentity(frontPlane.layer.transform))
        XCTAssertFalse(CATransform3DIsIdentity(backPlane.layer.transform))
        XCTAssertFalse(frontPlane.isHidden)
        XCTAssertTrue(backPlane.isHidden)
        XCTAssertFalse(front.isHidden)
        XCTAssertTrue(back.isHidden)
        XCTAssertFalse(front.accessibilityElementsHidden)
        XCTAssertTrue(back.accessibilityElementsHidden)
    }

    func testExpandedThemeFlipReversesInFlightWithoutIgnoringRapidTaps() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let front = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontView")
        )
        let back = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        let interactionOverlay = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFlipInteractionOverlay") as? UIButton
        )

        infoButton.sendActions(for: .touchUpInside)
        XCTAssertFalse(interactionOverlay.isHidden)
        interactionOverlay.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        XCTAssertFalse(front.isHidden)
        XCTAssertTrue(back.isHidden)

        infoButton.sendActions(for: .touchUpInside)
        interactionOverlay.sendActions(for: .touchUpInside)
        interactionOverlay.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        XCTAssertTrue(front.isHidden)
        XCTAssertFalse(back.isHidden)
    }

    func testExpandedThemeSurfaceTapsUseFaceActionsWithoutStealingControls() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let card = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        let frontSurfaceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontSurfaceButton") as? UIButton
        )
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        let titleDepthView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "expandedThemeCardFrontTitleDepth"
            )
        )

        XCTAssertTrue(card.hitTest(CGPoint(x: card.bounds.midX, y: card.bounds.midY), with: nil) === frontSurfaceButton)
        let titleCenter = titleDepthView.convert(
            CGPoint(x: titleDepthView.bounds.midX, y: titleDepthView.bounds.midY),
            to: card
        )
        XCTAssertTrue(card.hitTest(titleCenter, with: nil) === frontSurfaceButton)
        XCTAssertTrue(hitView(in: card, for: infoButton)?.isDescendant(of: infoButton) == true)
        XCTAssertTrue(hitView(in: card, for: closeButton)?.isDescendant(of: closeButton) == true)

        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let backSurfaceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackSurfaceButton") as? UIButton
        )
        let backButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )
        let questionCountControl = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UISegmentedControl
        )
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        let descriptionScrollView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView
        )
        let backFaceView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
        )
        let backTapGestureRecognizer = try XCTUnwrap(
            backFaceView.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first
        )

        XCTAssertTrue(
            card.hitTest(CGPoint(x: card.bounds.maxX - 8, y: card.bounds.midY), with: nil) === backSurfaceButton
        )
        XCTAssertTrue(hitView(in: card, for: backButton)?.isDescendant(of: backButton) == true)
        XCTAssertTrue(hitView(in: card, for: questionCountControl)?.isDescendant(of: questionCountControl) == true)
        XCTAssertTrue(hitView(in: card, for: startButton)?.isDescendant(of: startButton) == true)
        XCTAssertFalse(
            try XCTUnwrap(card as? ExpandedThemeCardView).gestureRecognizer(
                backTapGestureRecognizer,
                shouldRecognizeSimultaneouslyWith: descriptionScrollView.panGestureRecognizer
            )
        )

        backSurfaceButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        XCTAssertFalse(
            try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardFrontView")
            ).isHidden
        )

        frontSurfaceButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        XCTAssertFalse(
            try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardBackView")
            ).isHidden
        )

        let backdropDismissButton = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeExpandedThemeCardBackdropDismissButton"
            ) as? UIButton
        )
        let outsidePoint = CGPoint(x: 4, y: 4)
        let outsideHitView = try XCTUnwrap(viewController.view.hitTest(outsidePoint, with: nil))
        XCTAssertTrue(
            outsideHitView === backdropDismissButton || outsideHitView.isDescendant(of: backdropDismissButton),
            "Expected the backdrop dismiss button, hit \(type(of: outsideHitView)) " +
                "with id \(outsideHitView.accessibilityIdentifier ?? "nil")"
        )
        backdropDismissButton.sendActions(for: .touchUpInside)
        drainAnimations()
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
    }

    func testExpandedThemeBackSelectsCountAndStartsOnlyOnce() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let router = HomeRouterSpy()
        viewController.router = router
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()

        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let questionCountControl = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UISegmentedControl
        )
        questionCountControl.selectedSegmentIndex = 1
        questionCountControl.sendActions(for: .valueChanged)
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )

        startButton.sendActions(for: .touchUpInside)
        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(QuizFactory.shared.questionsCount, 10)
        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertEqual(router.showDescriptionCallCount, 0)

        viewController.viewWillAppear(false)
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCard")
        )
        XCTAssertFalse(
            try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton).isHidden
        )
    }

    func testExpandedThemeAnalyticsTracksCancellationAndSelectedCountStart() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let analytics = HomeAnalyticsTrackingSpy()
        let viewController = QuizViewController(
            analytics: analytics,
            cardReduceMotionProvider: { true }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)
        analytics.reset()

        var sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations(0.22)
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        closeButton.sendActions(for: .touchUpInside)
        let eventsBeforeCollapseCompletion = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(eventsBeforeCollapseCompletion.map(\.name), ["theme_selected"])
        drainAnimations(0.22)

        let cancellationEvents = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(
            cancellationEvents.map(\.name),
            ["theme_selected", "quiz_setup_cancelled"]
        )
        guard cancellationEvents.count == 2 else { return }
        XCTAssertEqual(cancellationEvents[0].parameters["selection_method"] as? String, "manual")
        XCTAssertEqual(cancellationEvents[0].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(cancellationEvents[1].parameters["theme_id"] as? String, "music")
        XCTAssertFalse(
            cancellationEvents.contains {
                $0.name == "screen_view" && $0.parameters["screen"] as? String == "quiz_description"
            }
        )

        analytics.reset()
        sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations(0.22)
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.22)
        let questionCountControl = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UISegmentedControl
        )
        questionCountControl.selectedSegmentIndex = 1
        questionCountControl.sendActions(for: .valueChanged)
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        startButton.sendActions(for: .touchUpInside)

        let startEvents = analytics.events.filter { event in
            !(event.name == "screen_view" && event.parameters["screen"] as? String == "home")
        }
        XCTAssertEqual(
            startEvents.map(\.name),
            ["theme_selected", "theme_card_flipped", "screen_view", "quiz_started"]
        )
        guard startEvents.count == 4 else { return }
        XCTAssertEqual(startEvents[0].parameters["selection_method"] as? String, "manual")
        XCTAssertEqual(startEvents[1].parameters["visible_face"] as? String, "back")
        XCTAssertEqual(startEvents[1].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(startEvents[2].parameters["screen"] as? String, "quiz_description")
        XCTAssertEqual(startEvents[3].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(startEvents[3].parameters["question_count"] as? Int, 10)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyStartsFiveQuestionsWithoutDescription() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        QuizFactory.shared.questionsCount = 15

        let viewController = QuizViewController(randomThemeIDProvider: { _ in "music" })
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)
        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
        XCTAssertEqual(router.showDescriptionCallCount, 0)
    }

    func testFeelingLuckyAnalyticsTracksRandomFiveQuestionStart() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]
        let analytics = HomeAnalyticsTrackingSpy()
        let viewController = QuizViewController(
            analytics: analytics,
            randomThemeIDProvider: { _ in "music" }
        )
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        drainAnimations(0.01)
        analytics.reset()

        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )
        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(analytics.events.map(\.name), ["theme_selected", "quiz_started"])
        guard analytics.events.count == 2 else { return }
        XCTAssertEqual(analytics.events[0].parameters["selection_method"] as? String, "random")
        XCTAssertEqual(analytics.events[0].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(analytics.events[1].parameters["theme_id"] as? String, "music")
        XCTAssertEqual(analytics.events[1].parameters["question_count"] as? Int, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyOffersOnlyThemesThatCanSupplyFiveQuestions() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка", questionCount: 4),
            makeTheme(name: "Технологии", questionCount: 5)
        ]
        var offeredThemeIDs: [String] = []
        let viewController = QuizViewController(randomThemeIDProvider: { themes in
            offeredThemeIDs = themes.map(\.stableID)
            return themes.first?.stableID
        })
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(offeredThemeIDs, ["technology"])
        XCTAssertEqual(QuizFactory.shared.chosenTheme?.themeID, "technology")
        XCTAssertEqual(QuizFactory.shared.questionsCount, 5)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testFeelingLuckyRejectsProviderResultOutsideEligibleThemes() throws {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка", questionCount: 4),
            makeTheme(name: "Технологии", questionCount: 5)
        ]
        let viewController = QuizViewController(randomThemeIDProvider: { _ in "music" })
        let router = HomeRouterSpy()
        viewController.router = router
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        let luckyButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton") as? UIButton
        )

        luckyButton.sendActions(for: .touchUpInside)

        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(router.showQuestionCallCount, 0)
        let motivationLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "homeMotivationLabel") as? UILabel
        )
        XCTAssertEqual(motivationLabel.text, L10n.Question.unavailableMessage)
    }

    func testAppearanceRefreshDuringFlipCompletesReducerAndAllowsClose() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 15)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )

        infoButton.sendActions(for: .touchUpInside)
        viewController.applyLocalizedStrings()
        drainAnimations(0.34)

        let backButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton
        )
        backButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)
        let closeButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardCloseButton") as? UIButton
        )
        closeButton.sendActions(for: .touchUpInside)
        drainAnimations()

        XCTAssertNil(
            viewController.view.descendant(withAccessibilityIdentifier: "homeExpandedThemeCardBackdrop")
        )
    }

    func testExpandedThemeBackDisablesStartWhenNoSupportedCountIsAvailable() throws {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка", questionCount: 4)]

        let viewController = makeHomeViewController(in: CGRect(x: 0, y: 0, width: 390, height: 844))
        let sourceButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "music") as? UIButton
        )
        sourceButton.sendActions(for: .touchUpInside)
        drainAnimations()
        let infoButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardInfoButton") as? UIButton
        )
        infoButton.sendActions(for: .touchUpInside)
        drainAnimations(0.34)

        let unavailableLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "expandedThemeCardUnavailableLabel") as? UILabel
        )
        let startButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton
        )
        XCTAssertFalse(unavailableLabel.isHidden)
        XCTAssertEqual(unavailableLabel.text, L10n.Question.unavailableMessage)
        XCTAssertFalse(startButton.isEnabled)
    }

    func testThemeCardPrepareForReuseRestoresVisibleInteractiveState() {
        let cell = ThemeCardCollectionViewCell(frame: CGRect(x: 0, y: 0, width: 160, height: 160))
        let theme = makeTheme(name: "Музыка", questionCount: 5)
        let appearance = AppAppearanceStore.shared.appearance(compatibleWith: .current)
        cell.configure(theme: theme, appearance: appearance, isSourceHidden: true)

        XCTAssertTrue(cell.actionButton.isHidden)
        XCTAssertFalse(cell.actionButton.isUserInteractionEnabled)
        XCTAssertEqual(cell.layer.shadowOpacity, 0)

        cell.prepareForReuse()

        XCTAssertFalse(cell.actionButton.isHidden)
        XCTAssertTrue(cell.actionButton.isUserInteractionEnabled)
        XCTAssertNil(cell.actionButton.accessibilityIdentifier)
        XCTAssertEqual(cell.actionButton.transform, .identity)
        XCTAssertEqual(cell.actionButton.alpha, 1)
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
        collectionView.register(
            ThemeCardCollectionViewCell.self,
            forCellWithReuseIdentifier: ThemeCardCollectionViewCell.reuseIdentifier
        )
        collectionView.register(
            StatisticsCardCollectionViewCell.self,
            forCellWithReuseIdentifier: StatisticsCardCollectionViewCell.reuseIdentifier
        )
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

    private func makeHostedExpandedThemeCard(
        motionProvider: HomeThemeCardMotionProviding,
        reduceMotionProvider: @escaping () -> Bool = { false }
    ) -> ExpandedThemeCardView {
        let card = ExpandedThemeCardView(
            frame: CGRect(x: 20, y: 126, width: 350, height: 518)
        )
        card.reduceMotionProvider = reduceMotionProvider
        card.deviceParallaxEnabledProvider = { true }
        card.deviceMotionProvider = motionProvider
        card.configure(
            theme: makeTheme(name: "Музыка", questionCount: 5),
            appearance: SnapshotSupport.appearance(designStyle: .clean),
            availableQuestionCounts: [5],
            selectedQuestionCount: 5
        )

        let host = UIViewController()
        host.view.addSubview(card)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        window.layoutIfNeeded()
        testWindows.append(window)
        return card
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

    private func makeTheme(
        name: String,
        questionCount: Int = 0,
        description: String = "Synthetic home-screen test theme"
    ) -> QuizTheme {
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
        let questions = (0..<questionCount).map { index in
            QuizQuestion(
                question: "Synthetic question \(index)?",
                answers: ["A", "B", "C", "D"],
                correctAnswer: "A"
            )
        }
        return QuizTheme(
            id: id,
            theme: name,
            themeDescription: description,
            questions: questions
        )
    }

    private func hitView(in rootView: UIView, for control: UIControl) -> UIView? {
        let center = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
        return rootView.hitTest(control.convert(center, to: rootView), with: nil)
    }

    private func parallaxPanGestureRecognizer(in view: UIView) -> UIPanGestureRecognizer? {
        if let recognizer = view.gestureRecognizers?
            .compactMap({ $0 as? UIPanGestureRecognizer })
            .first(where: { $0.name?.contains("ParallaxPan") == true }) {
            return recognizer
        }

        return view.subviews.lazy.compactMap {
            self.parallaxPanGestureRecognizer(in: $0)
        }.first
    }

    private func drainAnimations(_ duration: TimeInterval = 0.4) {
        RunLoop.main.run(until: Date().addingTimeInterval(duration))
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
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.backgroundStyle)
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

private final class HomeThemeCardMotionProviderFake: HomeThemeCardMotionProviding {
    let isAvailable: Bool
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var isStarted = false

    private var receive: ((HomeThemeCardParallaxInput) -> Void)?

    init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    func start(receive: @escaping (HomeThemeCardParallaxInput) -> Void) {
        startCallCount += 1
        isStarted = true
        self.receive = receive
    }

    func stop() {
        stopCallCount += 1
        isStarted = false
        receive = nil
    }

    func send(_ input: HomeThemeCardParallaxInput) {
        receive?(input)
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

private final class HomeAnalyticsTrackingSpy: AnalyticsTracking {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }

    func reportOperationalError(_ error: Error, context: AnalyticsErrorContext) {}

    func reset() {
        events.removeAll()
    }
}

private final class HomeRouterSpy: QuizRouting {
    var onShowQuestion: (() -> Void)?

    private(set) var showDescriptionCallCount = 0
    private(set) var showQuestionCallCount = 0
    private(set) var showResultCallCount = 0
    private(set) var showStatisticsCallCount = 0
    private(set) var showSettingsCallCount = 0
    private(set) var closeDescriptionCallCount = 0
    private(set) var closeStatisticsCallCount = 0
    private(set) var closeQuestionCallCount = 0
    private(set) var replayQuizCallCount = 0
    private(set) var returnToThemesCallCount = 0

    func showDescription() { showDescriptionCallCount += 1 }
    func showQuestion() {
        onShowQuestion?()
        showQuestionCallCount += 1
    }
    func showResult(_ result: QuizResultState) { showResultCallCount += 1 }
    func showStatistics() { showStatisticsCallCount += 1 }
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
