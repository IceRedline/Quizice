import XCTest
@testable import Quizice

final class OutboxTestIsolationTests: XCTestCase {
    func testLiveOutboxInXCTestHasNoAccountAndKeepsExplicitEventsLocal() async {
        let outbox = PersistentQuestionAnswerOutbox.live()
        let event = QuestionAnswerEvent(
            eventId: UUID(),
            questionId: "test-isolation-question",
            questionVersion: 1,
            locale: "en",
            answer: "answer",
            answeredAt: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertNil(outbox.currentUserID)
        XCTAssertTrue(outbox.pendingEvents().isEmpty)
        outbox.enqueue(event, for: "test-isolation-user")
        await outbox.synchronize()

        // A test-host startup must never upload using an account left in Keychain.
        XCTAssertEqual(outbox.pendingEvents().map(\.eventId), [event.eventId])
        let nextOutbox = PersistentQuestionAnswerOutbox.live()
        XCTAssertNil(nextOutbox.currentUserID)
        XCTAssertTrue(nextOutbox.pendingEvents().isEmpty)
    }
}

extension OutboxTestIsolationTests {
    func testDeletingAccountRemovesPendingRejectedAndCorruptCopiesButKeepsOtherOwners() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("outbox.json")
        let backup = file.appendingPathExtension("corrupt-old")
        try Data("private damaged answers".utf8).write(to: backup)
        let removed = QuestionAnswerEvent(eventId: UUID(), questionId: "deleted", questionVersion: 1,
                                         locale: "en", answer: "A", answeredAt: Date())
        let kept = QuestionAnswerEvent(eventId: UUID(), questionId: "kept", questionVersion: 1,
                                      locale: "en", answer: "B", answeredAt: Date())
        let owned = PersistentQuestionAnswerOutbox.OwnedEvent(userID: "A", event: removed)
        struct PersistedTestState: Encodable {
            let pending: [PersistentQuestionAnswerOutbox.OwnedEvent]
            let rejected: [PersistentQuestionAnswerOutbox.RejectedEvent]
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(PersistedTestState(pending: [owned, .init(userID: "B", event: kept)],
            rejected: [.init(ownedEvent: owned, status: 422, code: "invalid")])).write(to: file)
        let outbox = PersistentQuestionAnswerOutbox(api: nil, fileURL: file,
            automaticallySynchronizesOnEnqueue: false, sessionProvider: {
                AuthSession(userID: "A", accessToken: "token", expiresAt: .distantFuture, teamPlayerID: "A")
            })

        try outbox.eraseData(for: "A")
        outbox.enqueue(removed, for: "A") // A late quiz completion must not recreate the queue.

        XCTAssertNil(outbox.currentUserID)
        XCTAssertEqual(outbox.pendingEvents().map(\.eventId), [kept.eventId])
        XCTAssertTrue(outbox.rejectedEvents().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: backup.path))
        let reopened = PersistentQuestionAnswerOutbox(api: nil, fileURL: file,
            automaticallySynchronizesOnEnqueue: false, sessionProvider: { nil })
        XCTAssertEqual(reopened.pendingEvents().map(\.eventId), [kept.eventId])
        XCTAssertTrue(reopened.rejectedEvents().isEmpty)
    }

    func testCorruptOutboxIsPreservedAndDoesNotBlockNewAnswers() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("outbox.json")
        let damaged = Data([0xff, 0x00, 0x01])
        try damaged.write(to: file)
        let outbox = PersistentQuestionAnswerOutbox(api: nil, fileURL: file,
            automaticallySynchronizesOnEnqueue: false, sessionProvider: { nil })
        let event = QuestionAnswerEvent(eventId: UUID(), questionId: "music:1", questionVersion: 1,
                                        locale: "en", answer: "A", answeredAt: Date())
        outbox.enqueue(event, for: "A")
        XCTAssertEqual(outbox.pendingEvents().map(\.eventId), [event.eventId])
        let quarantined = try FileManager.default.contentsOfDirectory(at: directory,
            includingPropertiesForKeys: nil).filter { $0.lastPathComponent.hasPrefix("outbox.json.corrupt-") }
        XCTAssertEqual(quarantined.count, 1)
        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(quarantined.first)), damaged)
        let reopened = PersistentQuestionAnswerOutbox(api: nil, fileURL: file,
            automaticallySynchronizesOnEnqueue: false, sessionProvider: { nil })
        XCTAssertEqual(reopened.pendingEvents().map(\.eventId), [event.eventId])
    }
}
