import UIKit
import XCTest
@testable import Quizice

@MainActor
final class ComponentSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SnapshotSupport.setUp()
    }

    override func tearDown() {
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testPrimaryButtonsAcrossDesignStyles() {
        for style in AppDesignStyle.settingsOrder {
            let appearance = SnapshotSupport.appearance(designStyle: style)
            let button = SnapshotSupport.makeActionButton(
                title: "Начать",
                style: appearance.primaryButton,
                appearance: appearance,
                textColor: appearance.accentForegroundColor
            )

            SnapshotSupport.assertComponent(
                button,
                named: "\(style.rawValue)-primary",
                backgroundAppearance: appearance
            )
        }
    }

    func testSecondaryButtonsAcrossDesignStyles() {
        for style in AppDesignStyle.settingsOrder {
            let appearance = SnapshotSupport.appearance(designStyle: style)
            let button = SnapshotSupport.makeActionButton(
                title: "Назад",
                style: appearance.secondaryButton,
                appearance: appearance
            )

            SnapshotSupport.assertComponent(
                button,
                named: "\(style.rawValue)-secondary",
                backgroundAppearance: appearance
            )
        }
    }

    func testCleanLightAndDarkPrimaryButtons() {
        for scheme in [CleanColorSchemePreference.light, .dark] {
            let appearance = SnapshotSupport.appearance(designStyle: .clean, cleanColorScheme: scheme)
            let button = SnapshotSupport.makeActionButton(
                title: "Продолжить",
                style: appearance.primaryButton,
                appearance: appearance,
                textColor: appearance.accentForegroundColor
            )

            SnapshotSupport.assertComponent(
                button,
                named: "clean-\(scheme.rawValue)-primary",
                backgroundAppearance: appearance
            )
        }
    }

    func testDisabledButtonState() {
        let appearance = SnapshotSupport.appearance(designStyle: .clean, cleanColorScheme: .light)
        let button = SnapshotSupport.makeActionButton(
            title: "Недоступно",
            style: appearance.secondaryButton,
            appearance: appearance
        )
        button.isEnabled = false

        SnapshotSupport.assertComponent(
            button,
            named: "clean-disabled",
            backgroundAppearance: appearance
        )
    }
}
