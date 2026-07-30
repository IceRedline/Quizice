import XCTest
@testable import Quizice

@MainActor
final class AuthServiceKeychainRecoveryTests: XCTestCase {
    func testCorruptedLoadStillEntersGuestOnUnavailableGameCenter() async {
        let harness = makeHarness()
        harness.sessionStore.throwOnLoad = true

        harness.service.start { _ in }
        harness.gameCenter.emit(.unavailable)

        await waitUntil { harness.service.state == .guest }
        XCTAssertTrue(harness.api.authenticatedIdentities.isEmpty)
        XCTAssertFalse(harness.aiAccess.isAIQuizAvailable)
    }

    func testCorruptedClearDoesNotCrashWhenFallingBackToGuest() async {
        let harness = makeHarness()
        harness.sessionStore.throwOnClear = true

        harness.service.start { _ in }
        harness.gameCenter.emit(.unavailable)

        // If clear() crashed, the state transition below would never happen.
        await waitUntil { harness.service.state == .guest }
        XCTAssertTrue(harness.api.authenticatedIdentities.isEmpty)
    }

    func testCorruptedLoadDuringAuthenticatedStartReExchangesSession() async {
        let harness = makeHarness()
        // Session store cannot return the cached session. The service must
        // fall through to a fresh backend exchange rather than crashing.
        harness.sessionStore.throwOnLoad = true

        harness.service.start { _ in }
        harness.gameCenter.emit(.authenticated(teamPlayerID: "team-1"))

        await waitUntil {
            harness.service.state == .authenticated(userID: "user-1", teamPlayerID: "team-1")
        }
        XCTAssertEqual(harness.api.authenticatedIdentities.count, 1)
    }

    private func makeHarness() -> (
        service: GameCenterAuthenticationService,
        gameCenter: FakeGameCenterClient,
        api: FakeAuthAPI,
        sessionStore: ThrowingSessionStore,
        statistics: StatisticsStore,
        notificationCenter: NotificationCenter,
        aiAccess: AIQuizAccessStore
    ) {
        let suiteName = "AuthServiceKeychainRecoveryTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let notificationCenter = NotificationCenter()
        let statistics = StatisticsStore(
            userDefaults: defaults,
            key: "attempts",
            notificationCenter: notificationCenter
        )
        let gameCenter = FakeGameCenterClient()
        let api = FakeAuthAPI()
        let sessionStore = ThrowingSessionStore()
        let aiAccess = AIQuizAccessStore()
        let service = GameCenterAuthenticationService(
            gameCenter: gameCenter,
            api: api,
            sessionStore: sessionStore,
            statisticsStore: statistics,
            bundleIdentifier: "ru.tabenskii.Quizice",
            now: { Date(timeIntervalSince1970: 1_000) },
            notificationCenter: notificationCenter,
            aiQuizAccessStore: aiAccess
        )
        return (
            service,
            gameCenter,
            api,
            sessionStore,
            statistics,
            notificationCenter,
            aiAccess
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 3,
        _ condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Condition did not become true within \(timeout)s")
    }
}

private struct KeychainStubError: Error { }

@MainActor
final class ThrowingSessionStore: SessionStoring {
    var session: AuthSession?
    var throwOnLoad = false
    var throwOnSave = false
    var throwOnClear = false

    func load() throws -> AuthSession? {
        if throwOnLoad { throw KeychainStubError() }
        return session
    }

    func save(_ newSession: AuthSession) throws {
        if throwOnSave { throw KeychainStubError() }
        session = newSession
    }

    func clear() throws {
        if throwOnClear { throw KeychainStubError() }
        session = nil
    }
}
