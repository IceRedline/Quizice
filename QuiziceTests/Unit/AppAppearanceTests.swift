import UIKit
import XCTest
@testable import Quizice

@MainActor
final class AppAppearanceTests: XCTestCase {
    override func tearDown() {
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testAllDesignStylesResolveExpectedSurfaceFamilies() {
        let clean = SnapshotSupport.appearance(designStyle: .clean, cleanColorScheme: .light)
        let radar = SnapshotSupport.appearance(designStyle: .radar)
        let pixel = SnapshotSupport.appearance(designStyle: .pixel)
        let classic = SnapshotSupport.appearance(designStyle: .classic)

        XCTAssertEqual(clean.designStyle, .clean)
        XCTAssertEqual(clean.resolvedInterfaceStyle, .light)
        XCTAssertEqual(clean.card.cornerRadius, 30)
        XCTAssertEqual(clean.primaryButton.cornerRadius, 24)

        XCTAssertEqual(radar.designStyle, .radar)
        XCTAssertEqual(radar.resolvedInterfaceStyle, .dark)
        XCTAssertEqual(radar.row.cornerRadius, 8)
        XCTAssertEqual(radar.themeCardCornerRadius, 10)

        XCTAssertEqual(pixel.designStyle, .pixel)
        XCTAssertEqual(pixel.card.cornerRadius, 0)
        XCTAssertEqual(pixel.themeCardBorderWidth, 3)

        XCTAssertEqual(classic.designStyle, .classic)
        XCTAssertEqual(classic.resolvedInterfaceStyle, .dark)
        XCTAssertEqual(classic.backgroundImageName, "backgroundImage")
    }

    func testCleanSystemModeResolvesFromTraitCollection() {
        let lightAppearance = AppAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .system,
            traitCollection: UITraitCollection(userInterfaceStyle: .light)
        )
        let darkAppearance = AppAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .system,
            traitCollection: UITraitCollection(userInterfaceStyle: .dark)
        )

        XCTAssertEqual(lightAppearance.resolvedInterfaceStyle, .unspecified)
        XCTAssertEqual(darkAppearance.resolvedInterfaceStyle, .unspecified)
        XCTAssertFalse(lightAppearance.backgroundColor.isEqual(darkAppearance.backgroundColor))
        XCTAssertFalse(lightAppearance.card.backgroundColor.isEqual(darkAppearance.card.backgroundColor))
    }

    func testThemeCardStylingDiffersByDesignStyle() {
        let baseColor = UIColor.systemBlue
        let clean = SnapshotSupport.appearance(designStyle: .clean)
        let cleanDark = SnapshotSupport.appearance(designStyle: .clean, cleanColorScheme: .dark)
        let radar = SnapshotSupport.appearance(designStyle: .radar)
        let classic = SnapshotSupport.appearance(designStyle: .classic)

        XCTAssertTrue(clean.themeCardBackground(baseColor: baseColor).isEqual(clean.card.backgroundColor))
        XCTAssertTrue(clean.themeCardTextColor(baseColor: baseColor).isEqual(clean.surfaceTextColor))
        XCTAssertEqual(clean.themeCardShadow.opacity, 0)
        XCTAssertGreaterThan(cleanDark.themeCardShadow.opacity, 0)
        XCTAssertTrue(radar.themeCardTextColor(baseColor: baseColor).isEqual(radar.accentColor))
        XCTAssertFalse(classic.themeCardBackground(baseColor: baseColor).isEqual(baseColor))
    }

    func testApplySurfaceAndActionAppearanceMutatesUIKitControls() {
        let appearance = SnapshotSupport.appearance(designStyle: .clean)
        let view = UIView()
        let button = UIButton(type: .system)

        view.applySurfaceStyle(appearance.card)
        button.applyActionAppearance(appearance.primaryButton, appearance: appearance)

        XCTAssertTrue(view.backgroundColor?.isEqual(appearance.card.backgroundColor) ?? false)
        XCTAssertEqual(view.layer.cornerRadius, appearance.card.cornerRadius)
        XCTAssertEqual(view.layer.borderWidth, appearance.card.borderWidth)
        XCTAssertTrue(button.backgroundColor?.isEqual(appearance.primaryButton.backgroundColor) ?? false)
        XCTAssertTrue(button.titleColor(for: .normal)?.isEqual(appearance.screenTextColor) ?? false)
        XCTAssertTrue(button.titleColor(for: .disabled)?.isEqual(appearance.disabledTextColor) ?? false)
    }

    func testStoreIgnoresRepeatedWritesAndRejectsPixelAsUserSelectableStyle() {
        let suiteName = "AppAppearanceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let notificationCenter = NotificationCenter()
        let store = AppAppearanceStore(userDefaults: defaults, notificationCenter: notificationCenter)
        var notificationCount = 0
        let observer = notificationCenter.addObserver(
            forName: .appAppearanceDidChange,
            object: store,
            queue: nil
        ) { _ in
            notificationCount += 1
        }

        store.designStyle = .clean
        store.designStyle = .clean
        store.designStyle = .pixel

        XCTAssertEqual(notificationCount, 2)
        XCTAssertEqual(store.designStyle, .classic)
        XCTAssertFalse(AppDesignStyle.pixel.isSelectable)
        notificationCenter.removeObserver(observer)
        defaults.removePersistentDomain(forName: suiteName)
    }
}
