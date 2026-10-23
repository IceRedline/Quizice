import Foundation

extension GameCenterAuthenticationService {
    var authenticatedAccountID: String? {
        guard case let .authenticated(userID, _) = state else { return nil }
        return userID
    }

    var accountAccessState: AppAccountAccessState {
        if accountOperationInProgress { return .loading }
        switch state {
        case .initializing, .authenticating:
            return .loading
        case .authenticated:
            return .authenticated
        case .deletionPending:
            return .deletionPending
        case .guest:
            return canCreateAccount ? .deleted : .signInRequired
        }
    }
}
