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
    private let aiQuizAccessStore: AIQuizAccessStore

    private var authenticationTask: Task<Void, Never>?
    private var authenticationAttemptID: UUID?
    private var synchronizationTask: Task<Void, Never>?
    private var synchronizationAttemptID: UUID?
    private var pendingSyncObserver: NSObjectProtocol?
    private var authenticationInvalidationObserver: NSObjectProtocol?
    private var currentTeamPlayerID: String?
    private var started = false

    init(
        gameCenter: GameCenterAuthenticating,
        api: AuthAPI,
        sessionStore: SessionStoring,
        statisticsStore: StatisticsStore = StatisticsStore(),
        bundleIdentifier: String,
        now: @escaping () -> Date = Date.init,
        notificationCenter: NotificationCenter = .default,
        aiQuizAccessStore: AIQuizAccessStore = AIQuizAccessStore()
    ) {
        self.gameCenter = gameCenter
        self.api = api
        self.sessionStore = sessionStore
        self.statisticsStore = statisticsStore
        self.bundleIdentifier = bundleIdentifier
        self.now = now
        self.notificationCenter = notificationCenter
        self.aiQuizAccessStore = aiQuizAccessStore
        pendingSyncObserver = notificationCenter.addObserver(
            forName: .statisticsPendingSync,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.synchronizeStatistics()
            }
        }
        authenticationInvalidationObserver = notificationCenter.addObserver(
            forName: .backendAuthenticationInvalidated,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleBackendAuthenticationInvalidation()
            }
        }
    }

    deinit {
        if let pendingSyncObserver {
            notificationCenter.removeObserver(pendingSyncObserver)
        }
        if let authenticationInvalidationObserver {
            notificationCenter.removeObserver(authenticationInvalidationObserver)
        }
    }

    static func live(bundle: Bundle = .main) -> GameCenterAuthenticationService {
        let api: AuthAPI
        if let configuration = BackendConfiguration.load(bundle: bundle) {
            api = HTTPAuthAPI(
                configuration: configuration,
                metrics: AppMetricaAnalyticsTracker.shared
            )
        } else {
            api = UnavailableAuthAPI()
        }
        return GameCenterAuthenticationService(
            gameCenter: GameCenterClient(),
            api: api,
            sessionStore: KeychainSessionStore(),
            bundleIdentifier: bundle.bundleIdentifier ?? "ru.avtabenskiy.Quizice",
            aiQuizAccessStore: .shared
        )
    }

    func start(present: @escaping (UIViewController) -> Void) {
        guard started == false else { return }
        started = true
        state = .initializing
        aiQuizAccessStore.update(isAuthenticated: false)
        gameCenter.start(present: present) { [weak self] playerState in
            self?.handle(playerState)
        }
    }

    func retrySynchronization() {
        if case .guest = state, let teamPlayerID = currentTeamPlayerID {
            forceRefreshSession(
                for: teamPlayerID,
                statisticsMayRefreshToken: true
            )
            return
        }
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
            beginAuthentication(
                for: teamPlayerID,
                allowsCachedSession: true,
                statisticsMayRefreshToken: true
            )
        case .unavailable:
            enterGuestMode()
        }
    }

    private func beginAuthentication(
        for teamPlayerID: String,
        allowsCachedSession: Bool,
        statisticsMayRefreshToken: Bool
    ) {
        authenticationTask?.cancel()
        let attemptID = UUID()
        authenticationAttemptID = attemptID
        currentTeamPlayerID = teamPlayerID
        state = .authenticating
        aiQuizAccessStore.update(isAuthenticated: false)
        authenticationTask = Task { [weak self] in
            await self?.restoreOrExchangeSession(
                for: teamPlayerID,
                allowsCachedSession: allowsCachedSession,
                statisticsMayRefreshToken: statisticsMayRefreshToken,
                attemptID: attemptID
            )
        }
    }

    private func restoreOrExchangeSession(
        for teamPlayerID: String,
        allowsCachedSession: Bool,
        statisticsMayRefreshToken: Bool,
        attemptID: UUID
    ) async {
        do {
            if allowsCachedSession,
               let cachedSession = try sessionStore.load(),
               cachedSession.isValid(for: teamPlayerID, now: now()) {
                completeAuthentication(
                    with: cachedSession,
                    attemptID: attemptID,
                    statisticsMayRefreshToken: statisticsMayRefreshToken
                )
                return
            }
            try? sessionStore.clear()
            let session = try await exchangeSession(
                for: teamPlayerID,
                attemptID: attemptID
            )
            try Task.checkCancellation()
            completeAuthentication(
                with: session,
                attemptID: attemptID,
                statisticsMayRefreshToken: statisticsMayRefreshToken
            )
        } catch is CancellationError {
            return
        } catch is GameCenterAuthenticationError {
            guard
                currentTeamPlayerID == teamPlayerID,
                authenticationAttemptID == attemptID
            else { return }
            enterGuestMode()
        } catch {
            guard
                currentTeamPlayerID == teamPlayerID,
                authenticationAttemptID == attemptID
            else { return }
            enterGuestMode(preservingGameCenterPlayer: true)
        }
    }

    private func exchangeSession(
        for teamPlayerID: String,
        attemptID: UUID
    ) async throws -> AuthSession {
        let identity = try await gameCenter.fetchIdentity(bundleIdentifier: bundleIdentifier)
        try Task.checkCancellation()
        guard
            identity.teamPlayerId == teamPlayerID,
            currentTeamPlayerID == teamPlayerID,
            authenticationAttemptID == attemptID
        else {
            throw GameCenterAuthenticationError.playerChanged
        }
        let session = try await api.authenticate(identity: identity)
        try Task.checkCancellation()
        guard
            session.teamPlayerID == teamPlayerID,
            currentTeamPlayerID == teamPlayerID,
            authenticationAttemptID == attemptID
        else {
            throw GameCenterAuthenticationError.playerChanged
        }
        try sessionStore.save(session)
        return session
    }

    private func completeAuthentication(
        with session: AuthSession,
        attemptID: UUID,
        statisticsMayRefreshToken: Bool
    ) {
        guard
            currentTeamPlayerID == session.teamPlayerID,
            authenticationAttemptID == attemptID
        else { return }
        authenticationAttemptID = nil
        authenticationTask = nil
        statisticsStore.activateAuthenticatedUser(session.userID)
        state = .authenticated(userID: session.userID, teamPlayerID: session.teamPlayerID)
        aiQuizAccessStore.update(isAuthenticated: true)
        synchronizeStatistics(
            using: session,
            mayRefreshToken: statisticsMayRefreshToken
        )
    }

    private func enterGuestMode(preservingGameCenterPlayer: Bool = false) {
        authenticationTask?.cancel()
        authenticationTask = nil
        authenticationAttemptID = nil
        synchronizationTask?.cancel()
        synchronizationTask = nil
        synchronizationAttemptID = nil
        if preservingGameCenterPlayer == false {
            currentTeamPlayerID = nil
        }
        try? sessionStore.clear()
        statisticsStore.activateGuest()
        state = .guest
        aiQuizAccessStore.update(isAuthenticated: false)
    }

    private func synchronizeStatistics(
        using knownSession: AuthSession? = nil,
        mayRefreshToken: Bool = true
    ) {
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

        let attemptID = UUID()
        synchronizationAttemptID = attemptID
        synchronizationTask = Task { [weak self] in
            guard let self else { return }
            let didSync = await self.performStatisticsSync(
                session: session,
                mayRefreshToken: mayRefreshToken
            )
            guard self.synchronizationAttemptID == attemptID else { return }
            self.synchronizationTask = nil
            self.synchronizationAttemptID = nil
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
            forceRefreshSession(
                for: session.teamPlayerID,
                statisticsMayRefreshToken: false
            )
            return false
        } catch BackendAPIError.unauthorized {
            enterGuestMode()
            return false
        } catch {
            // Keep the local outbox intact. Foregrounding or the next completed quiz retries it.
            return false
        }
    }

    private func handleBackendAuthenticationInvalidation() {
        guard let teamPlayerID = currentTeamPlayerID else {
            enterGuestMode()
            return
        }
        forceRefreshSession(
            for: teamPlayerID,
            statisticsMayRefreshToken: true
        )
    }

    private func forceRefreshSession(
        for teamPlayerID: String,
        statisticsMayRefreshToken: Bool
    ) {
        guard currentTeamPlayerID == teamPlayerID else { return }
        if state == .authenticating, authenticationTask != nil {
            return
        }
        synchronizationTask?.cancel()
        synchronizationTask = nil
        synchronizationAttemptID = nil
        try? sessionStore.clear()
        beginAuthentication(
            for: teamPlayerID,
            allowsCachedSession: false,
            statisticsMayRefreshToken: statisticsMayRefreshToken
        )
    }
}

enum GameCenterAuthenticationError: Error, Equatable {
    case playerChanged
}
