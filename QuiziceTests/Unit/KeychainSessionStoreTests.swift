import Foundation
import XCTest
@testable import Quizice

final class KeychainSessionStoreTests: XCTestCase {
    func testDeletionReceiptHidesCredentialFromNormalRequestsButPreservesRetryCredential() throws {
        let defaults = UserDefaults(suiteName: "KeychainDeletionTests.\(UUID())")!
        let deletionState = AccountDeletionStateStore(defaults: defaults)
        let store = KeychainSessionStore(client: InMemoryKeychainClient(), deletionStateStore: deletionState)
        let session = AuthSession(userID: "delete-me", accessToken: "secret", expiresAt: .distantFuture, teamPlayerID: "player")
        try store.save(session)
        deletionState.save(.init(userID: session.userID, teamPlayerID: session.teamPlayerID,
                                 idempotencyKey: UUID().uuidString, serverConfirmed: false, cleanupCompleted: false))
        XCTAssertNil(try store.load())
        XCTAssertEqual(try store.loadForAccountDeletion(), session)
        try store.clear()
        XCTAssertNil(try store.loadForAccountDeletion())
    }

    func testRoundTripAndClear() throws {
        let client = InMemoryKeychainClient()
        let store = KeychainSessionStore(
            service: "QuiziceTests.Auth.\(UUID().uuidString)",
            client: client
        )
        let session = AuthSession(
            userID: "user-1",
            accessToken: "secret",
            expiresAt: Date(timeIntervalSince1970: 2_000),
            teamPlayerID: "team-1"
        )
        try store.save(session)
        XCTAssertEqual(try store.load(), session)
        try store.clear()
        XCTAssertNil(try store.load())
    }
}

private final class InMemoryKeychainClient: KeychainClient {
    private var data: Data?

    func loadData(service: String, account: String) throws -> Data? {
        data
    }

    func saveData(_ data: Data, service: String, account: String) throws {
        self.data = data
    }

    func deleteData(service: String, account: String) throws {
        data = nil
    }
}
