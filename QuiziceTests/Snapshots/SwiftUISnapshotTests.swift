import SwiftUI
import UIKit
import XCTest
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
        let viewController = UIHostingController(rootView: QuizSettingsView())

        SnapshotSupport.assertScreen(viewController, named: "clean-settings")
    }

    func testAIThemeCreationViewSnapshot() {
        let viewController = UIHostingController(
            rootView: QuizAIThemeCreationView(service: MockAIQuizThemeService())
        )

        SnapshotSupport.assertScreen(viewController, named: "clean-ai-theme-creation")
    }
}
