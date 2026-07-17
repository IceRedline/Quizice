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

    func testLegacyAttemptArrayMigratesToBoundedAggregate() throws {
        let harness = makeHarness()
        let legacyAttempts = [
            StatisticsStore.Attempt(correctAnswers: 2, totalQuestions: 5),
            StatisticsStore.Attempt(correctAnswers: 4, totalQuestions: 4)
        ]
        harness.defaults.set(try JSONEncoder().encode(legacyAttempts), forKey: harness.key)

        XCTAssertEqual(
            harness.store.loadSummary(),
            StatisticsSummary(
                playedQuizzes: 2,
                correctAnswers: 6,
                totalQuestions: 9,
                bestCorrectAnswers: 4,
                bestTotalQuestions: 4
            )
        )

        let migratedData = try XCTUnwrap(harness.defaults.data(forKey: harness.key))
        XCTAssertThrowsError(try JSONDecoder().decode([StatisticsStore.Attempt].self, from: migratedData))
    }

    func testPreviousAggregateMigratesIntoIdempotentLegacySyncPayload() throws {
        let harness = makeHarness()
        let legacyJSON: [String: Int] = [
            "playedQuizzes": 3,
            "correctAnswers": 9,
            "totalQuestions": 15,
            "bestCorrectAnswers": 4,
            "bestTotalQuestions": 5
        ]
        harness.defaults.set(
            try JSONSerialization.data(withJSONObject: legacyJSON),
            forKey: harness.key
        )

        XCTAssertEqual(harness.store.loadSummary().playedQuizzes, 3)
        harness.store.activateAuthenticatedUser("user-1")
        let request = harness.store.makeSyncRequest(for: "user-1")
        let reloaded = StatisticsStore(userDefaults: harness.defaults, key: harness.key)

        XCTAssertEqual(request.legacySummary?.correctAnswers, 9)
        XCTAssertEqual(reloaded.makeSyncRequest(for: "user-1").migrationId, request.migrationId)
    }

    func testPendingAttemptKeepsStableIdentityAcrossStoreReload() {
        let harness = makeHarness()
        harness.store.recordAttempt(correctAnswers: 3, totalQuestions: 5)
        harness.store.activateAuthenticatedUser("user-1")

        let firstRequest = harness.store.makeSyncRequest(for: "user-1")
        let reloadedStore = StatisticsStore(userDefaults: harness.defaults, key: harness.key)
        let secondRequest = reloadedStore.makeSyncRequest(for: "user-1")

        XCTAssertEqual(firstRequest, secondRequest)
        XCTAssertEqual(firstRequest.attempts.count, 1)
    }

    func testGuestAttemptsMoveOnlyToSelectedAuthenticatedUser() {
        let harness = makeHarness()
        harness.store.recordAttempt(correctAnswers: 4, totalQuestions: 5)

        harness.store.activateAuthenticatedUser("user-a")
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 4)

        harness.store.activateGuest()
        XCTAssertEqual(harness.store.loadSummary(), .empty)
        harness.store.recordAttempt(correctAnswers: 1, totalQuestions: 5)
        harness.store.activateAuthenticatedUser("user-b")
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 1)

        harness.store.activateAuthenticatedUser("user-a")
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 4)
    }

    func testApplyingSyncResponseKeepsOnlyUnacknowledgedAttemptsPending() {
        let harness = makeHarness()
        harness.store.recordAttempt(correctAnswers: 4, totalQuestions: 5)
        harness.store.recordAttempt(correctAnswers: 2, totalQuestions: 5)
        harness.store.activateAuthenticatedUser("user-1")
        let request = harness.store.makeSyncRequest(for: "user-1")

        harness.store.applySyncResponse(
            StatisticsStore.SyncResponse(
                summary: StatisticsSummary(
                    playedQuizzes: 1,
                    correctAnswers: 4,
                    totalQuestions: 5,
                    bestCorrectAnswers: 4,
                    bestTotalQuestions: 5
                ),
                acceptedAttemptIds: [request.attempts[0].id],
                legacySummaryAccepted: true
            ),
            for: "user-1"
        )

        let remaining = harness.store.makeSyncRequest(for: "user-1")
        XCTAssertEqual(remaining.attempts.map(\.id), [request.attempts[1].id])
        XCTAssertEqual(harness.store.loadSummary().playedQuizzes, 2)
        XCTAssertEqual(harness.store.loadSummary().correctAnswers, 6)
    }

    func testRejectedLegacySummaryIsTerminalAndDoesNotRemainPending() throws {
        let harness = makeHarness()
        let legacyJSON: [String: Int] = [
            "playedQuizzes": 3,
            "correctAnswers": 9,
            "totalQuestions": 15,
            "bestCorrectAnswers": 4,
            "bestTotalQuestions": 5
        ]
        harness.defaults.set(
            try JSONSerialization.data(withJSONObject: legacyJSON),
            forKey: harness.key
        )
        _ = harness.store.loadSummary()
        harness.store.activateAuthenticatedUser("user-1")
        XCTAssertNotNil(harness.store.makeSyncRequest(for: "user-1").legacySummary)

        harness.store.applySyncResponse(
            StatisticsStore.SyncResponse(
                summary: .empty,
                acceptedAttemptIds: [],
                legacySummaryAccepted: false
            ),
            for: "user-1"
        )

        XCTAssertNil(harness.store.makeSyncRequest(for: "user-1").legacySummary)
        XCTAssertFalse(harness.store.hasPendingSync(for: "user-1"))
        XCTAssertEqual(harness.store.loadSummary(), .empty)
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
