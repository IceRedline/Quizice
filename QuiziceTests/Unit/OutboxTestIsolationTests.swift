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
