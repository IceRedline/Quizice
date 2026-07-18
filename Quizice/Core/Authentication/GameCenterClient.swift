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

        player.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let viewController {
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
        let (publicKeyURL, signature, salt, timestamp) = try await player.fetchItemsForIdentityVerificationSignature()
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
