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

    private func makeHostingController<Content: View>(rootView: Content) -> UIHostingController<Content> {
        let viewController = UIHostingController(rootView: rootView)
        viewController.loadViewIfNeeded()
        AppAppearanceStore.shared
            .appearance(compatibleWith: viewController.traitCollection)
            .applyBackground(to: viewController.view)
        return viewController
    }
}
