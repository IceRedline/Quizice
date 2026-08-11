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
#if DEBUG
    private var devAuthenticationProvider: AuthenticationProvider?
#endif

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
            let httpAPI = HTTPAuthAPI(
                configuration: configuration,
                metrics: AppMetricaAnalyticsTracker.shared
            )
            api = httpAPI
        } else {
            api = UnavailableAuthAPI()
        }
        let service = GameCenterAuthenticationService(
            gameCenter: GameCenterClient(),
            api: api,
            sessionStore: KeychainSessionStore(),
            bundleIdentifier: bundle.bundleIdentifier ?? "ru.avtabenskiy.Quizice",
            aiQuizAccessStore: .shared
        )
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let enabled = ["1", "true", "yes"].contains(
            environment["DEV_AUTH_ENABLED"]?.lowercased() ?? ""
        )
        if enabled,
           let configuration = BackendConfiguration.load(bundle: bundle),
           let secret = environment["DEV_AUTH_SECRET"] {
            service.devAuthenticationProvider = DevAuthenticationProvider(
                api: HTTPAuthAPI(
                    configuration: configuration,
                    metrics: AppMetricaAnalyticsTracker.shared
                ),
                developerUserIDStore: KeychainDeveloperUserIDStore(),
                secret: secret
            )
        }
#endif
        return service
    }

    func start(present: @escaping (UIViewController) -> Void) {
        guard started == false else { return }
        started = true
        state = .initializing
        aiQuizAccessStore.update(isAuthenticated: false)
#if DEBUG
        if let devAuthenticationProvider {
            beginDevAuthentication(using: devAuthenticationProvider)
            return
        }
#endif
        gameCenter.start(present: present) { [weak self] playerState in
            self?.handle(playerState)
        }
    }

#if DEBUG
    private func beginDevAuthentication(using provider: AuthenticationProvider) {
        authenticationTask?.cancel()
        let attemptID = UUID()
        authenticationAttemptID = attemptID
        state = .authenticating
        authenticationTask = Task { [weak self] in
            guard let self else { return }
            do {
                if let cached = self.loadStoredSession(),
                   cached.teamPlayerID.hasPrefix("dev:"),
                   cached.expiresAt > self.now() {
                    self.currentTeamPlayerID = cached.teamPlayerID
                    self.completeAuthentication(
                        with: cached,
                        attemptID: attemptID,
                        statisticsMayRefreshToken: false
                    )
                    return
                }
                self.clearStoredSession()
                let session = try await provider.authenticate()
                try Task.checkCancellation()
                try self.sessionStore.save(session)
                self.currentTeamPlayerID = session.teamPlayerID
                self.completeAuthentication(
                    with: session,
                    attemptID: attemptID,
                    statisticsMayRefreshToken: false
                )
            } catch is CancellationError {
                return
            } catch {
                AppLog.auth.error(
                    "DEBUG dev authentication failed: \(String(describing: error), privacy: .public)"
                )
                self.enterGuestMode()
            }
        }
    }
#endif

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
        // Reading the cached session is a best-effort operation. A broken
        // Keychain (e.g. after a restore-from-backup or a user reset) must
        // not force a legitimate Game Center player into guest mode — fall
        // through to a fresh exchange instead.
        if allowsCachedSession,
           let cachedSession = loadStoredSession(),
           cachedSession.isValid(for: teamPlayerID, now: now()) {
            completeAuthentication(
                with: cachedSession,
                attemptID: attemptID,
                statisticsMayRefreshToken: statisticsMayRefreshToken
            )
            return
        }
        clearStoredSession()

        do {
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
        notificationCenter.post(name: .backendAuthenticationEstablished, object: nil)
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
        clearStoredSession()
        statisticsStore.activateGuest()
        state = .guest
        aiQuizAccessStore.update(isAuthenticated: false)
    }

    private func synchronizeStatistics(
        using knownSession: AuthSession? = nil,
        mayRefreshToken: Bool = true
    ) {
        guard synchronizationTask == nil else { return }
        let storedSession = knownSession ?? loadStoredSession()
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
#if DEBUG
        if let devAuthenticationProvider {
            clearStoredSession()
            beginDevAuthentication(using: devAuthenticationProvider)
            return
        }
#endif
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
        clearStoredSession()
        beginAuthentication(
            for: teamPlayerID,
            allowsCachedSession: false,
            statisticsMayRefreshToken: statisticsMayRefreshToken
        )
    }

    /// Delete the Keychain session and record failures so operations teams see
    /// them. Swallowing errors silently made prior incidents hard to diagnose:
    /// the app kept running with a stale token that could not be cleared.
    private func clearStoredSession() {
        do {
            try sessionStore.clear()
        } catch {
            AppLog.auth.error(
                "Failed to clear stored session: \(String(describing: error), privacy: .public)"
            )
        }
    }

    private func loadStoredSession() -> AuthSession? {
        do {
            return try sessionStore.load()
        } catch {
            AppLog.auth.error(
                "Failed to load stored session: \(String(describing: error), privacy: .public)"
            )
            return nil
        }
    }
}

enum GameCenterAuthenticationError: Error, Equatable {
    case playerChanged
}
