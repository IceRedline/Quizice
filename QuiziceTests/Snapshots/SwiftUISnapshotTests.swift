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

    func testAIThemeCreationViewSnapshot() {
        let viewController = makeHostingController(
            rootView: QuizAIThemeCreationView(service: MockAIQuizThemeService())
        )

        SnapshotSupport.assertScreen(viewController, named: "clean-ai-theme-creation")
    }

    func testAIThemeCreationCompactSnapshot() {
        let viewController = makeHostingController(
            rootView: QuizAIThemeCreationView(service: MockAIQuizThemeService())
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "clean-ai-theme-creation-iphone-se",
            device: .iPhone8
        )
    }

    func testAIThemeCreationAccessibilitySnapshot() {
        let viewController = makeHostingController(
            rootView: QuizAIThemeCreationView(service: MockAIQuizThemeService())
        )

        SnapshotSupport.assertScreen(
            viewController,
            named: "clean-ai-theme-creation-accessibility-xxxl",
            contentSizeCategory: .accessibilityExtraExtraExtraLarge
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
