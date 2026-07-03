import XCTest
@testable import Quizice

final class StatisticsStoreTests: XCTestCase {
    private var suiteNames: [String] = []

    override func tearDown() {
        for suiteName in suiteNames {
            UserDefaults.standard.removePersistentDomain(forName: suiteName)
        }
        suiteNames.removeAll()
        super.tearDown()
    }

    func testFirstRunLoadSummaryReturnsEmpty() {
        let harness = makeHarness()

        XCTAssertEqual(harness.store.loadSummary(), .empty)
        XCTAssertNil(harness.defaults.data(forKey: harness.key))
    }

    func testRecordAttemptPersistsValidAttempts() {
        let harness = makeHarness()

        harness.store.recordAttempt(correctAnswers: 3, totalQuestions: 5)
        harness.store.recordAttempt(correctAnswers: 4, totalQuestions: 4)

        let summary = harness.store.loadSummary()
        XCTAssertEqual(summary.playedQuizzes, 2)
        XCTAssertEqual(summary.correctAnswers, 7)
        XCTAssertEqual(summary.totalQuestions, 9)
        XCTAssertEqual(summary.percentage, 78)
        XCTAssertEqual(summary.bestCorrectAnswers, 4)
        XCTAssertEqual(summary.bestTotalQuestions, 4)
        XCTAssertNotNil(harness.defaults.data(forKey: harness.key))
    }

    func testRecordAttemptIgnoresNonPositiveTotals() {
        let harness = makeHarness()

        harness.store.recordAttempt(correctAnswers: 2, totalQuestions: 0)
        harness.store.recordAttempt(correctAnswers: 2, totalQuestions: -3)

        XCTAssertEqual(harness.store.loadSummary(), .empty)
        XCTAssertNil(harness.defaults.data(forKey: harness.key))
    }

    func testRecordAttemptSanitizesCorrectAnswersOutsideValidRange() {
        let harness = makeHarness()

        harness.store.recordAttempt(correctAnswers: -2, totalQuestions: 5)
        harness.store.recordAttempt(correctAnswers: 8, totalQuestions: 5)

        let summary = harness.store.loadSummary()
        XCTAssertEqual(summary.playedQuizzes, 2)
        XCTAssertEqual(summary.correctAnswers, 5)
        XCTAssertEqual(summary.totalQuestions, 10)
        XCTAssertEqual(summary.percentage, 50)
        XCTAssertEqual(summary.bestCorrectAnswers, 5)
        XCTAssertEqual(summary.bestTotalQuestions, 5)
    }

    func testLoadSummaryReturnsEmptyForCorruptPersistedBytesAndRemovesKey() {
        let harness = makeHarness()
        harness.defaults.set(Data("not-json".utf8), forKey: harness.key)

        XCTAssertEqual(harness.store.loadSummary(), .empty)
        XCTAssertNil(harness.defaults.data(forKey: harness.key))
    }

    func testLoadSummaryReturnsEmptyAndRemovesKeyForMalformedAttemptPayload() throws {
        let harness = makeHarness()
        let malformed = [["correctAnswers": 1]]
        let data = try JSONSerialization.data(withJSONObject: malformed)
        harness.defaults.set(data, forKey: harness.key)

        XCTAssertEqual(harness.store.loadSummary(), .empty)
        XCTAssertNil(harness.defaults.data(forKey: harness.key))
    }

    private func makeHarness(
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> (store: StatisticsStore, defaults: UserDefaults, key: String) {
        let suiteName = "ru.avtabenskiy.QuiziceTests.StatisticsStoreTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        UserDefaults.standard.removePersistentDomain(forName: suiteName)

        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Expected isolated UserDefaults suite to be created", file: file, line: line)
            let fallback = UserDefaults.standard
            let key = "statistics-test-\(UUID().uuidString)"
            return (StatisticsStore(userDefaults: fallback, key: key), fallback, key)
        }

        let key = "statistics-test-\(UUID().uuidString)"
        return (StatisticsStore(userDefaults: defaults, key: key), defaults, key)
    }
}
