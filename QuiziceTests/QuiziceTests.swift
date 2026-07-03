import XCTest
@testable import Quizice

final class QuiziceTests: XCTestCase {
    func testQuiziceModuleLoads() {
        XCTAssertNotNil(Bundle.main.bundleIdentifier)
        XCTAssertNotNil(AppDelegate.self)
    }
}
