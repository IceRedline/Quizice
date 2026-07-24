import SwiftUI
import XCTest
@testable import Quizice

@MainActor
final class HomeCollectionServiceTests: HomeScreenVisualStateTestCase {
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

        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 4)

        let viewportCell = service.collectionView(
            collectionView,
            cellForItemAt: IndexPath(item: 0, section: 0)
        ) as? ThemesViewportCollectionViewCell
        let themeCollectionView = viewportCell?.themesCollectionView
        let firstThemeCell = themeCollectionView.map {
            service.collectionView($0, cellForItemAt: IndexPath(item: 0, section: 0))
        }
        let secondThemeCell = themeCollectionView.map {
            service.collectionView($0, cellForItemAt: IndexPath(item: 1, section: 0))
        }
        let aiThemeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 1, section: 0))
        let feelingLuckyCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 2, section: 0))
        let statisticsCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: 3, section: 0))

        XCTAssertNotNil(firstThemeCell?.contentView.descendant(withAccessibilityIdentifier: "music"))
        XCTAssertNotNil(secondThemeCell?.contentView.descendant(withAccessibilityIdentifier: "technology"))
        XCTAssertNotNil(aiThemeCell.contentView.descendant(withAccessibilityIdentifier: "homeCreateWithAIButton"))
        XCTAssertNotNil(feelingLuckyCell.contentView.descendant(withAccessibilityIdentifier: "homeFeelingLuckyButton"))
        XCTAssertNotNil(statisticsCell.contentView.descendant(withAccessibilityIdentifier: "homeStatisticsCard"))
    }

    func testCollectionServiceMovesPreferredThemesFirstWithoutReorderingTheirPeers() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура"),
            makeTheme(name: "Политика и бизнес")
        ]
        let service = ThemesCollectionService(
            preferredThemeIDsProvider: { ["history_culture", "politics_business"] }
        )
        let collectionView = makeThemeCollectionView()

        let expectedThemeIDs = [
            "history_culture",
            "politics_business",
            "music",
            "technology"
        ]

        for (index, themeID) in expectedThemeIDs.enumerated() {
            let cell = service.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: index, section: 0)
            )
            XCTAssertNotNil(
                cell.contentView.descendant(withAccessibilityIdentifier: themeID)
            )
        }
    }

    func testCollectionServiceFallsBackToBackendFavoriteOrderWithoutLocalPreferences() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Политика и бизнес"),
            makeTheme(name: "История и культура", isFavorite: true),
            makeTheme(name: "Музыка", isFavorite: true),
            makeTheme(name: "Технологии")
        ]
        let service = ThemesCollectionService(preferredThemeIDsProvider: { nil })
        let collectionView = makeThemeCollectionView()
        let expectedThemeIDs = [
            "history_culture",
            "music",
            "politics_business",
            "technology"
        ]

        for (index, themeID) in expectedThemeIDs.enumerated() {
            let cell = service.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: index, section: 0)
            )
            XCTAssertNotNil(
                cell.contentView.descendant(withAccessibilityIdentifier: themeID)
            )
        }
    }

    func testExplicitEmptyLocalPreferencesDoNotRestoreBackendFavorites() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Политика и бизнес"),
            makeTheme(name: "История и культура", isFavorite: true),
            makeTheme(name: "Музыка", isFavorite: true)
        ]
        let service = ThemesCollectionService(preferredThemeIDsProvider: { [] })
        let collectionView = makeThemeCollectionView()
        let expectedThemeIDs = ["politics_business", "history_culture", "music"]

        for (index, themeID) in expectedThemeIDs.enumerated() {
            let cell = service.collectionView(
                collectionView,
                cellForItemAt: IndexPath(item: index, section: 0)
            )
            XCTAssertNotNil(
                cell.contentView.descendant(withAccessibilityIdentifier: themeID)
            )
        }
    }

    func testPreferredThemeReconfigurationUsesDisplayedIndex() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "Технологии"),
            makeTheme(name: "История и культура")
        ]
        let service = ThemesCollectionService(
            preferredThemeIDsProvider: { ["history_culture"] }
        )
        let collectionView = ReconfigureTrackingCollectionView(
            frame: CGRect(x: 0, y: 0, width: 390, height: 700),
            collectionViewLayout: UICollectionViewFlowLayout()
        )
        collectionView.accessibilityIdentifier =
            ThemesCollectionService.Content.themeCatalogAccessibilityID
        collectionView.register(
            ThemeCardCollectionViewCell.self,
            forCellWithReuseIdentifier: ThemeCardCollectionViewCell.reuseIdentifier
        )

        _ = service.collectionView(
            collectionView,
            cellForItemAt: IndexPath(item: 0, section: 0)
        )
        service.presentedThemeID = "history_culture"

        XCTAssertEqual(
            collectionView.reconfiguredIndexPaths.last,
            [IndexPath(item: 0, section: 0)]
        )
    }

    func testCollectionServiceKeepsFullBackendCatalogScrollable() throws {
        QuizFactory.shared.themes = (0..<14).map { makeTheme(name: "Theme \($0)") }
        let service = ThemesCollectionService(preferredThemeIDsProvider: { [] })
        let outerCollectionView = makeCollectionView()
        let viewportSize = service.collectionView(
            outerCollectionView,
            layout: outerCollectionView.collectionViewLayout,
            sizeForItemAt: IndexPath(item: 0, section: 0)
        )
        let viewportCell = try XCTUnwrap(
            service.collectionView(
                outerCollectionView,
                cellForItemAt: IndexPath(item: 0, section: 0)
            ) as? ThemesViewportCollectionViewCell
        )
        viewportCell.frame = CGRect(origin: .zero, size: viewportSize)
        viewportCell.contentView.frame = viewportCell.bounds
        viewportCell.layoutIfNeeded()
        viewportCell.contentView.layoutIfNeeded()
        let collectionView = viewportCell.themesCollectionView
        collectionView.layoutIfNeeded()

        XCTAssertEqual(service.collectionView(outerCollectionView, numberOfItemsInSection: 0), 4)
        XCTAssertEqual(service.collectionView(collectionView, numberOfItemsInSection: 0), 14)
        XCTAssertEqual(viewportSize.height, 304)
        XCTAssertGreaterThan(
            collectionView.collectionViewLayout.collectionViewContentSize.height,
            collectionView.bounds.height
        )
        let lastThemeCell = service.collectionView(
            collectionView,
            cellForItemAt: IndexPath(item: 13, section: 0)
        )
        XCTAssertNotNil(lastThemeCell.contentView.descendant(withAccessibilityIdentifier: "Theme 13"))
    }

    func testHomeScreenEnablesNativeScrollingForFullBackendCatalog() throws {
        QuizFactory.shared.themes = (0..<14).map { makeTheme(name: "Theme \($0)") }
        let viewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 390, height: 844)
        )
        viewController.view.layoutIfNeeded()
        let outerCollectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        let collectionView = try XCTUnwrap(
            viewController.view.descendant(
                withAccessibilityIdentifier: ThemesCollectionService.Content.themeCatalogAccessibilityID
            ) as? UICollectionView
        )

        XCTAssertTrue(collectionView.isScrollEnabled)
        XCTAssertTrue(collectionView.alwaysBounceVertical)
        XCTAssertEqual(collectionView.bounds.height, 304, accuracy: 0.5)
        XCTAssertGreaterThan(
            collectionView.collectionViewLayout.collectionViewContentSize.height,
            collectionView.bounds.height
        )
        XCTAssertTrue(outerCollectionView.contentSize.height > 0)

        let compactViewController = makeHomeViewController(
            in: CGRect(x: 0, y: 0, width: 375, height: 667)
        )
        compactViewController.view.layoutIfNeeded()
        let compactOuterCollectionView = try XCTUnwrap(
            compactViewController.view.descendant(
                withAccessibilityIdentifier: "homeThemesCollectionView"
            ) as? UICollectionView
        )
        let compactCatalogCollectionView = try XCTUnwrap(
            compactViewController.view.descendant(
                withAccessibilityIdentifier: ThemesCollectionService.Content.themeCatalogAccessibilityID
            ) as? UICollectionView
        )

        XCTAssertFalse(compactOuterCollectionView.isScrollEnabled)
        XCTAssertTrue(compactCatalogCollectionView.isScrollEnabled)
        XCTAssertGreaterThan(compactCatalogCollectionView.bounds.height, 224)
        XCTAssertLessThan(compactCatalogCollectionView.bounds.height, 304)
        XCTAssertGreaterThan(
            compactCatalogCollectionView.collectionViewLayout.collectionViewContentSize.height,
            compactCatalogCollectionView.bounds.height
        )
    }

    func testCollectionServiceUsesTwoColumnThemeCardsAndWideActionCards() {
        QuizFactory.shared.themes = [makeTheme(name: "Музыка"), makeTheme(name: "Технологии")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()
        let themeCollectionView = makeThemeCollectionView()
        let layout = themeCollectionView.collectionViewLayout

        let themeSize = service.collectionView(themeCollectionView, layout: layout, sizeForItemAt: IndexPath(item: 0, section: 0))
        let aiThemeSize = service.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: 1, section: 0))
        let feelingLuckySize = service.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: 2, section: 0))
        let statisticsSize = service.collectionView(collectionView, layout: collectionView.collectionViewLayout, sizeForItemAt: IndexPath(item: 3, section: 0))
        let inset = service.collectionView(collectionView, layout: layout, insetForSectionAt: 0)
        let lineSpacing = service.collectionView(collectionView, layout: layout, minimumLineSpacingForSectionAt: 0)
        let interitemSpacing = service.collectionView(collectionView, layout: layout, minimumInteritemSpacingForSectionAt: 0)

        XCTAssertEqual(themeSize.width, 163)
        XCTAssertEqual(themeSize.height, 64)
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

    func testCollectionServiceUsesOneSharedDynamicHeightPerThemeRow() {
        QuizFactory.shared.themes = [
            makeTheme(name: "Музыка"),
            makeTheme(name: "История Древнего Рима"),
            makeTheme(name: "Кино"),
            makeTheme(name: "Игры")
        ]
        let service = ThemesCollectionService()
        let collectionView = makeThemeCollectionView(width: 327)
        let layout = collectionView.collectionViewLayout

        let firstRowLeft = service.collectionView(
            collectionView,
            layout: layout,
            sizeForItemAt: IndexPath(item: 0, section: 0)
        )
        let firstRowRight = service.collectionView(
            collectionView,
            layout: layout,
            sizeForItemAt: IndexPath(item: 1, section: 0)
        )
        let secondRowLeft = service.collectionView(
            collectionView,
            layout: layout,
            sizeForItemAt: IndexPath(item: 2, section: 0)
        )
        let secondRowRight = service.collectionView(
            collectionView,
            layout: layout,
            sizeForItemAt: IndexPath(item: 3, section: 0)
        )

        XCTAssertEqual(firstRowLeft.height, firstRowRight.height)
        XCTAssertEqual(secondRowLeft.height, secondRowRight.height)
        XCTAssertGreaterThan(firstRowLeft.height, secondRowLeft.height)
        XCTAssertEqual(secondRowLeft.height, ThemeCardLayoutMetrics.singleLineHeight)
    }

    func testCollectionServiceThemeCardShowsHorizontalContentFromThemeMetadata() throws {
        useDesignStyle(.clean)
        let themeMetadata = [
            (themeID: "music", themeName: "Музыка", symbolName: "music.note.list", colorHex: "#FF8252"),
            (themeID: "technology", themeName: "Технологии", symbolName: "cpu.fill", colorHex: "#62A2E6"),
            (themeID: "history_culture", themeName: "История и культура", symbolName: "theatermask.and.paintbrush.fill", colorHex: "#8B5CF6"),
            (themeID: "politics_business", themeName: "Политика и бизнес", symbolName: "briefcase.fill", colorHex: "#F2C94C")
        ]
        QuizFactory.shared.themes = themeMetadata.map {
            makeTheme(name: $0.themeName, sfSymbolName: $0.symbolName, colorHex: $0.colorHex)
        }
        let service = ThemesCollectionService()
        let collectionView = makeThemeCollectionView()
        let appearance = AppAppearanceStore.shared.appearance(compatibleWith: collectionView.traitCollection)

        for (index, metadata) in themeMetadata.enumerated() {
            let itemSize = service.collectionView(
                collectionView,
                layout: collectionView.collectionViewLayout,
                sizeForItemAt: IndexPath(item: index, section: 0)
            )
            let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: index, section: 0))
            themeCell.frame = CGRect(origin: .zero, size: itemSize)
            themeCell.contentView.frame = themeCell.bounds
            themeCell.layoutIfNeeded()
            themeCell.contentView.layoutIfNeeded()

            let imageView = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeImageView-\(metadata.themeID)") as? UIImageView)
            let titleLabel = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: "homeThemeTitleLabel-\(metadata.themeID)") as? UILabel)
            let themeButton = try XCTUnwrap(themeCell.contentView.descendant(withAccessibilityIdentifier: metadata.themeID) as? UIButton)
            let expectedSymbolImage = UIImage(systemName: metadata.symbolName)
            let expectedImage = try XCTUnwrap(expectedSymbolImage?.withRenderingMode(.alwaysTemplate))
            let tintColor = try XCTUnwrap(ThemeVisualCatalog.color(from: metadata.colorHex))
            let borderColor = appearance.themeCardBorder(baseColor: tintColor)

            XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
            XCTAssertEqual(imageView.image?.renderingMode, .alwaysTemplate)
            XCTAssertEqual(imageView.contentMode, .scaleAspectFit)
            assertColor(imageView.tintColor, equals: borderColor)
            XCTAssertEqual(imageView.transform, .identity)
            XCTAssertEqual(titleLabel.text, metadata.themeName)
            XCTAssertEqual(titleLabel.textAlignment, .left)
            XCTAssertEqual(titleLabel.numberOfLines, ThemeCardLayoutMetrics.maximumTitleLines)
            XCTAssertEqual(titleLabel.lineBreakMode, .byWordWrapping)
            XCTAssertEqual(titleLabel.font.pointSize, ThemeCardLayoutMetrics.titleFontSize, accuracy: 0.01)
            assertColor(themeButton.backgroundColor, equals: assetColor("themeWhite"))
            assertColor(titleLabel.textColor, equals: assetColor("themeCleanSurfaceText"))
            assertColor(UIColor(cgColor: themeButton.layer.borderColor ?? UIColor.clear.cgColor), equals: borderColor)
            XCTAssertEqual(themeButton.layer.borderWidth, 2)
            let iconSlot = try XCTUnwrap(imageView.superview)
            XCTAssertLessThan(iconSlot.frame.maxX, titleLabel.frame.minX)
            XCTAssertEqual(iconSlot.center.y, titleLabel.center.y, accuracy: 0.5)
            XCTAssertEqual(
                iconSlot.bounds.size,
                CGSize(
                    width: ThemeCardLayoutMetrics.iconSize,
                    height: ThemeCardLayoutMetrics.iconSize
                )
            )

            let iconViews = imageView.superview?.subviews.compactMap { $0 as? UIImageView } ?? []
            XCTAssertEqual(iconViews.count, 2)
            let shadowView = try XCTUnwrap(iconViews.first { $0 !== imageView })
            XCTAssertEqual(shadowView.image?.pngData(), imageView.image?.pngData())
            XCTAssertEqual(shadowView.transform.ty, 3, accuracy: 0.01)
            XCTAssertEqual(shadowView.alpha, 0.26, accuracy: 0.01)
            assertColor(shadowView.tintColor, equals: .black)

            let fittingSize = CGSize(width: titleLabel.bounds.width, height: CGFloat.greatestFiniteMagnitude)
            let requiredTitleHeight = titleLabel.sizeThatFits(fittingSize).height
            XCTAssertLessThanOrEqual(requiredTitleHeight, titleLabel.bounds.height + 0.5)
        }
    }

    func testClassicThemeCardsUseMeaningfulTintedSFSymbols() throws {
        useDesignStyle(.classic)
        let themeMetadata = [
            (themeID: "music", themeName: "Музыка", symbolName: "music.note.list", colorHex: "#FF8252"),
            (themeID: "technology", themeName: "Технологии", symbolName: "cpu.fill", colorHex: "#62A2E6"),
            (themeID: "history_culture", themeName: "История и культура", symbolName: "theatermask.and.paintbrush.fill", colorHex: "#8B5CF6"),
            (themeID: "politics_business", themeName: "Политика и бизнес", symbolName: "briefcase.fill", colorHex: "#F2C94C")
        ]
        QuizFactory.shared.themes = themeMetadata.map {
            makeTheme(name: $0.themeName, sfSymbolName: $0.symbolName, colorHex: $0.colorHex)
        }
        let service = ThemesCollectionService()
        let collectionView = makeThemeCollectionView()

        for (index, metadata) in themeMetadata.enumerated() {
            let itemSize = service.collectionView(
                collectionView,
                layout: collectionView.collectionViewLayout,
                sizeForItemAt: IndexPath(item: index, section: 0)
            )
            let themeCell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: index, section: 0))
            let imageView = try XCTUnwrap(
                themeCell.contentView.descendant(
                    withAccessibilityIdentifier: "homeThemeImageView-\(metadata.themeID)"
                ) as? UIImageView
            )
            let expectedSymbolImage = UIImage(systemName: metadata.symbolName)
            let expectedImage = try XCTUnwrap(expectedSymbolImage?.withRenderingMode(.alwaysTemplate))
            let tintColor = try XCTUnwrap(ThemeVisualCatalog.color(from: metadata.colorHex))

            themeCell.frame = CGRect(origin: .zero, size: itemSize)
            themeCell.contentView.frame = themeCell.bounds
            themeCell.layoutIfNeeded()
            themeCell.contentView.layoutIfNeeded()

            XCTAssertEqual(imageView.image?.pngData(), expectedImage.pngData())
            XCTAssertEqual(imageView.image?.renderingMode, .alwaysTemplate)
            assertColor(imageView.tintColor, equals: tintColor)
            XCTAssertEqual(
                imageView.superview?.bounds.size,
                CGSize(
                    width: ThemeCardLayoutMetrics.iconSize,
                    height: ThemeCardLayoutMetrics.iconSize
                )
            )
            XCTAssertEqual(imageView.transform, .identity)

            let iconViews = imageView.superview?.subviews.compactMap { $0 as? UIImageView } ?? []
            XCTAssertEqual(iconViews.count, 2)
            let shadowView = try XCTUnwrap(iconViews.first { $0 !== imageView })
            XCTAssertEqual(shadowView.image?.pngData(), imageView.image?.pngData())
            XCTAssertEqual(shadowView.transform.ty, 3, accuracy: 0.01)
            XCTAssertEqual(shadowView.alpha, 0.26, accuracy: 0.01)
            assertColor(shadowView.tintColor, equals: .black)
        }
    }

    func testCompactRadarThemeTitleUsesDynamicHeightWithoutShrinking() throws {
        useDesignStyle(.radar)
        let theme = makeTheme(name: "История Древнего Рима")
        QuizFactory.shared.themes = [theme]
        let service = ThemesCollectionService()
        let collectionView = makeThemeCollectionView(width: 327)
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
            .font(size: ThemeCardLayoutMetrics.titleFontSize, weight: .semibold)
        let requiredHeight = (titleLabel.text! as NSString).boundingRect(
            with: CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: titleLabel.font!],
            context: nil
        ).height

        XCTAssertGreaterThan(itemSize.height, ThemeCardLayoutMetrics.singleLineHeight)
        XCTAssertEqual(titleLabel.font.pointSize, baseFont.pointSize, accuracy: 0.01)
        XCTAssertLessThanOrEqual(ceil(requiredHeight), ceil(titleLabel.bounds.height) + 0.5)
    }

    func testSingleWordThemeTitleStaysOnOneLineWithoutClipping() throws {
        useDesignStyle(.classic)
        let theme = makeTheme(name: "Технологии")
        QuizFactory.shared.themes = [theme]
        let service = ThemesCollectionService()
        let collectionView = makeThemeCollectionView(width: 342)
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
        let renderedWidth = (titleLabel.text! as NSString).size(
            withAttributes: [.font: titleLabel.font!]
        ).width

        XCTAssertEqual(itemSize.height, ThemeCardLayoutMetrics.singleLineHeight)
        XCTAssertEqual(titleLabel.font.pointSize, ThemeCardLayoutMetrics.titleFontSize, accuracy: 0.01)
        XCTAssertLessThanOrEqual(ceil(renderedWidth), floor(titleLabel.bounds.width))
    }

    func testCollectionServiceAppliesPolishedCardStylingWithoutChangingIdentifiers() {
        useDesignStyle(.clean)
        QuizFactory.shared.themes = [makeTheme(name: "Музыка")]
        let service = ThemesCollectionService()
        let collectionView = makeCollectionView()
        let themeCollectionView = makeThemeCollectionView()

        let themeCell = service.collectionView(themeCollectionView, cellForItemAt: IndexPath(item: 0, section: 0))
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
        let themeCell = service.collectionView(
            makeThemeCollectionView(),
            cellForItemAt: IndexPath(item: 0, section: 0)
        )

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

private final class ReconfigureTrackingCollectionView: UICollectionView {
    private(set) var reconfiguredIndexPaths: [[IndexPath]] = []

    override func reconfigureItems(at indexPaths: [IndexPath]) {
        reconfiguredIndexPaths.append(indexPaths)
    }
}
