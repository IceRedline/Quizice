import SwiftUI
import UIKit
import XCTest
import SnapshotTesting
@testable import Quizice

@MainActor
final class SwiftUISnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .light)
    }

    override func tearDown() {
        SnapshotSupport.tearDown()
        super.tearDown()
    }

    func testSettingsViewSnapshot() {
        let viewController = makeHostingController(rootView: QuizSettingsView())

        SnapshotSupport.assertScreen(viewController, named: "clean-settings")
    }

    func testClassicSettingsCompactPortraitSnapshot() {
        SnapshotSupport.setUp(designStyle: .classic)
        let viewController = makeHostingController(rootView: QuizSettingsView())

        SnapshotSupport.assertScreen(
            viewController,
            named: "classic-settings-iphone-se",
            device: .iPhone8
        )
    }

    func testFakeLaunchScreenSnapshot() {
        SnapshotSupport.setUp(designStyle: .classic)
        let viewController = makeHostingController(
            rootView: FakeLaunchScreenView(
                appearance: SnapshotSupport.appearance(designStyle: .classic),
                holdDuration: 60
            )
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "fake-launch-screen",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testRadarFakeLaunchScreenSnapshot() {
        SnapshotSupport.setUp(designStyle: .radar, cleanColorScheme: .dark)
        let viewController = makeHostingController(
            rootView: FakeLaunchScreenView(
                appearance: SnapshotSupport.appearance(
                    designStyle: .radar,
                    cleanColorScheme: .dark
                ),
                holdDuration: 60
            )
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "radar-fake-launch-screen",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testCleanLightFakeLaunchScreenSnapshot() {
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .light)
        let viewController = makeHostingController(
            rootView: FakeLaunchScreenView(
                appearance: SnapshotSupport.appearance(
                    designStyle: .clean,
                    cleanColorScheme: .light
                ),
                holdDuration: 60
            )
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "clean-light-fake-launch-screen",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    func testCleanDarkFakeLaunchScreenSnapshot() {
        SnapshotSupport.setUp(designStyle: .clean, cleanColorScheme: .dark)
        let viewController = makeHostingController(
            rootView: FakeLaunchScreenView(
                appearance: SnapshotSupport.appearance(
                    designStyle: .clean,
                    cleanColorScheme: .dark
                ),
                holdDuration: 60
            )
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "clean-dark-fake-launch-screen",
            device: SnapshotSupport.iPhone17Pro
        )
    }

    private func makeHostingController<Content: View>(rootView: Content) -> UIHostingController<Content> {
        let viewController = UIHostingController(rootView: rootView)
        viewController.loadViewIfNeeded()
        viewController.view.overrideUserInterfaceStyle = AppAppearanceStore.shared
            .appearance(compatibleWith: viewController.traitCollection)
            .resolvedInterfaceStyle
        return viewController
    }
}
