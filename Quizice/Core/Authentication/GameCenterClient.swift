import GameKit
import UIKit

@MainActor
final class GameCenterClient: GameCenterAuthenticating {
    private let player: GKLocalPlayer
    private let notificationCenter: NotificationCenter
    private var authenticationObserver: NSObjectProtocol?
    private var stateChanged: ((GameCenterPlayerState) -> Void)?

    init(
        player: GKLocalPlayer = .local,
        notificationCenter: NotificationCenter = .default
    ) {
        self.player = player
        self.notificationCenter = notificationCenter
    }

    deinit {
        if let authenticationObserver {
            notificationCenter.removeObserver(authenticationObserver)
        }
    }

    func start(
        present: @escaping (UIViewController) -> Void,
        stateChanged: @escaping (GameCenterPlayerState) -> Void
    ) {
        self.stateChanged = stateChanged
        AppLog.auth.notice("[Auth] Starting Game Center authentication")
        if authenticationObserver == nil {
            authenticationObserver = notificationCenter.addObserver(
                forName: NSNotification.Name.GKPlayerAuthenticationDidChangeNotificationName,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.publishCurrentState()
                }
            }
        }

        player.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    let diagnostic = error as NSError
                    AppLog.auth.error(
                        "[Auth] Game Center callback failed: domain=\(diagnostic.domain, privacy: .public) code=\(diagnostic.code)"
                    )
                }
                if let viewController {
                    AppLog.auth.notice("[Auth] Presenting Game Center sign-in")
                    present(viewController)
                    return
                }
                self.publishCurrentState()
            }
        }
    }

    func fetchIdentity(bundleIdentifier: String) async throws -> GameCenterIdentity {
        guard player.isAuthenticated, player.teamPlayerID.isEmpty == false else {
            throw GameCenterClientError.notAuthenticated
        }
        AppLog.auth.notice("[Auth] Requesting Game Center identity signature")
        let (publicKeyURL, signature, salt, timestamp): (URL, Data, Data, UInt64)
        do {
            (publicKeyURL, signature, salt, timestamp) = try await player.fetchItemsForIdentityVerificationSignature()
        } catch {
            let diagnostic = error as NSError
            AppLog.auth.error(
                "[Auth] Game Center identity signature failed: domain=\(diagnostic.domain, privacy: .public) code=\(diagnostic.code)"
            )
            throw error
        }
        AppLog.auth.notice("[Auth] Game Center identity signature received")
        return GameCenterIdentity(
            teamPlayerId: player.teamPlayerID,
            bundleId: bundleIdentifier,
            publicKeyUrl: publicKeyURL.absoluteString,
            signature: signature.base64EncodedString(),
            salt: salt.base64EncodedString(),
            timestamp: String(timestamp)
        )
    }

    private func publishCurrentState() {
        let isAuthenticated = player.isAuthenticated
        let hasTeamPlayerID = !player.teamPlayerID.isEmpty
        AppLog.auth.notice(
            "[Auth] Game Center state: authenticated=\(isAuthenticated) hasTeamPlayerID=\(hasTeamPlayerID)"
        )
        if player.isAuthenticated, player.teamPlayerID.isEmpty == false {
            stateChanged?(.authenticated(teamPlayerID: player.teamPlayerID))
        } else {
            stateChanged?(.unavailable)
        }
    }
}

enum GameCenterClientError: Error, Equatable {
    case notAuthenticated
}
