import Foundation

/// Resolve an ambiguous deletion after its bearer expires without permitting
/// automatic account creation or replacing the original retry credential.
@MainActor
enum AccountDeletionRecovery {
    static func confirmDeletion(
        receipt: AccountDeletionStateStore.Record,
        api: AuthAPI,
        gameCenter: GameCenterAuthenticating,
        bundleIdentifier: String,
        isCurrentIdentity: () -> Bool
    ) async throws {
        guard isCurrentIdentity() else { throw GameCenterAuthenticationError.playerChanged }
        let identity = try await gameCenter.fetchIdentity(bundleIdentifier: bundleIdentifier)
        try Task.checkCancellation()
        guard identity.teamPlayerId == receipt.teamPlayerID, isCurrentIdentity() else {
            throw GameCenterAuthenticationError.playerChanged
        }
        let session: AuthSession
        do {
            // The normal endpoint rejects a verified deleted identity with
            // account_deleted. Only the explicit Create action may send true.
            session = try await api.authenticate(identity: identity)
        } catch let BackendAPIError.httpStatus(status, envelope)
            where status == 409 && envelope?.code.lowercased() == "account_deleted" {
            try Task.checkCancellation()
            guard isCurrentIdentity() else { throw GameCenterAuthenticationError.playerChanged }
            return
        }
        try Task.checkCancellation()
        guard isCurrentIdentity() else { throw GameCenterAuthenticationError.playerChanged }
        guard session.teamPlayerID == receipt.teamPlayerID, session.userID == receipt.userID else {
            throw BackendAPIError.contractViolation
        }
        // Keep the original Keychain credential: a delayed first request may
        // commit a receipt tied to its digest. A later retry can use it, or a
        // fresh verified account_deleted response can confirm any completed delete.
        try await api.deleteAccount(accessToken: session.accessToken, idempotencyKey: receipt.idempotencyKey)
        try Task.checkCancellation()
    }
}
