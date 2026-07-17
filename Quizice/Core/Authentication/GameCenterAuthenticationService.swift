import Foundation
import UIKit

@MainActor
final class GameCenterAuthenticationService {
    private(set) var state: AuthSessionState = .initializing

    private let gameCenter: GameCenterAuthenticating
    private let api: AuthAPI
    private let sessionStore: SessionStoring
    private let statisticsStore: StatisticsStore
    private let bundleIdentifier: String
    private let now: () -> Date
    private let notificationCenter: NotificationCenter

    private var authenticationTask: Task<Void, Never>?
    private var synchronizationTask: Task<Void, Never>?
    private var pendingSyncObserver: NSObjectProtocol?
    private var currentTeamPlayerID: String?
    private var started = false

    init(
        gameCenter: GameCenterAuthenticating,
        api: AuthAPI,
        sessionStore: SessionStoring,
        statisticsStore: StatisticsStore = StatisticsStore(),
        bundleIdentifier: String,
        now: @escaping () -> Date = Date.init,
        notificationCenter: NotificationCenter = .default
    ) {
        self.gameCenter = gameCenter
        self.api = api
        self.sessionStore = sessionStore
        self.statisticsStore = statisticsStore
        self.bundleIdentifier = bundleIdentifier
        self.now = now
        self.notificationCenter = notificationCenter
        pendingSyncObserver = notificationCenter.addObserver(
            forName: .statisticsPendingSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.synchronizeStatistics()
            }
        }
    }

    deinit {
        if let pendingSyncObserver {
            notificationCenter.removeObserver(pendingSyncObserver)
        }
    }

    static func live(bundle: Bundle = .main) -> GameCenterAuthenticationService {
        let api: AuthAPI
        if let configuration = BackendConfiguration.load(bundle: bundle) {
            api = HTTPAuthAPI(configuration: configuration)
        } else {
            api = UnavailableAuthAPI()
        }
        return GameCenterAuthenticationService(
            gameCenter: GameCenterClient(),
            api: api,
            sessionStore: KeychainSessionStore(),
            bundleIdentifier: bundle.bundleIdentifier ?? "ru.avtabenskiy.Quizice"
        )
    }

    func start(present: @escaping (UIViewController) -> Void) {
        guard started == false else { return }
        started = true
        state = .initializing
        gameCenter.start(present: present) { [weak self] playerState in
            self?.handle(playerState)
        }
    }

    func retrySynchronization() {
        synchronizeStatistics()
    }

    private func handle(_ playerState: GameCenterPlayerState) {
        switch playerState {
        case let .authenticated(teamPlayerID):
            guard teamPlayerID.isEmpty == false else {
                enterGuestMode()
                return
            }
            if currentTeamPlayerID == teamPlayerID,
               case .authenticated = state {
                synchronizeStatistics()
                return
            }
            authenticationTask?.cancel()
            currentTeamPlayerID = teamPlayerID
            state = .authenticating
            authenticationTask = Task { [weak self] in
                await self?.restoreOrExchangeSession(for: teamPlayerID)
            }
        case .unavailable:
            enterGuestMode()
        }
    }

    private func restoreOrExchangeSession(for teamPlayerID: String) async {
        do {
            if let cachedSession = try sessionStore.load(), cachedSession.isValid(for: teamPlayerID, now: now()) {
                completeAuthentication(with: cachedSession)
                return
            }
            try? sessionStore.clear()
            let session = try await exchangeSession(for: teamPlayerID)
            try Task.checkCancellation()
            completeAuthentication(with: session)
        } catch is CancellationError {
            return
        } catch {
            guard currentTeamPlayerID == teamPlayerID else { return }
            enterGuestMode()
        }
    }

    private func exchangeSession(for teamPlayerID: String) async throws -> AuthSession {
        let identity = try await gameCenter.fetchIdentity(bundleIdentifier: bundleIdentifier)
        guard identity.teamPlayerId == teamPlayerID else {
            throw GameCenterAuthenticationError.playerChanged
        }
        let session = try await api.authenticate(identity: identity)
        guard session.teamPlayerID == teamPlayerID else {
            throw GameCenterAuthenticationError.playerChanged
        }
        try sessionStore.save(session)
        return session
    }

    private func completeAuthentication(with session: AuthSession) {
        guard currentTeamPlayerID == session.teamPlayerID else { return }
        statisticsStore.activateAuthenticatedUser(session.userID)
        state = .authenticated(userID: session.userID, teamPlayerID: session.teamPlayerID)
        synchronizeStatistics(using: session)
    }

    private func enterGuestMode() {
        authenticationTask?.cancel()
        synchronizationTask?.cancel()
        currentTeamPlayerID = nil
        try? sessionStore.clear()
        statisticsStore.activateGuest()
        state = .guest
    }

    private func synchronizeStatistics(using knownSession: AuthSession? = nil) {
        guard synchronizationTask == nil else { return }
        let storedSession = knownSession ?? (try? sessionStore.load()) ?? nil
        guard
            let session = storedSession,
            case let .authenticated(userID, teamPlayerID) = state,
            userID == session.userID,
            teamPlayerID == session.teamPlayerID
        else {
            return
        }

        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            let didSync = await self.performStatisticsSync(session: session, mayRefreshToken: true)
            self.synchronizationTask = nil
            if didSync, self.statisticsStore.hasPendingSync(for: session.userID) {
                self.synchronizeStatistics()
            }
        }
    }

    private func performStatisticsSync(session: AuthSession, mayRefreshToken: Bool) async -> Bool {
        let request = statisticsStore.makeSyncRequest(for: session.userID)
        do {
            let response = try await api.syncStatistics(
                request: request,
                accessToken: session.accessToken
            )
            statisticsStore.applySyncResponse(response, for: session.userID)
            return true
        } catch BackendAPIError.unauthorized where mayRefreshToken {
            do {
                let refreshed = try await exchangeSession(for: session.teamPlayerID)
                guard currentTeamPlayerID == refreshed.teamPlayerID else { return false }
                state = .authenticated(userID: refreshed.userID, teamPlayerID: refreshed.teamPlayerID)
                return await performStatisticsSync(session: refreshed, mayRefreshToken: false)
            } catch {
                enterGuestMode()
                return false
            }
        } catch BackendAPIError.unauthorized {
            enterGuestMode()
            return false
        } catch {
            // Keep the local outbox intact. Foregrounding or the next completed quiz retries it.
            return false
        }
    }
}

enum GameCenterAuthenticationError: Error, Equatable {
    case playerChanged
}
