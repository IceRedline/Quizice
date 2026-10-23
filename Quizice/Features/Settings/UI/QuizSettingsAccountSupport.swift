import SwiftUI

@MainActor
final class SettingsAccountModel: ObservableObject {
    enum Operation: Equatable { case deleting, creating }
    enum Outcome: Equatable {
        case deleted, created, deletionFailed, creationFailed
        case cleanupRequired, sessionExpired, unavailable
    }

    @Published private(set) var operation: Operation?
    @Published private(set) var canDelete = false
    @Published private(set) var canCreate = false
    private let manager: (any AccountManaging)?

    var isBusy: Bool { operation != nil }

    init(manager: (any AccountManaging)?) {
        self.manager = manager
        refreshAvailability()
    }

    func refreshAvailability() {
        canDelete = manager?.accountDeletionAvailable == true
        canCreate = manager?.canCreateAccount == true
    }

    func deleteAccount() async -> Outcome? {
        guard !isBusy else { return nil }
        guard let manager, manager.accountDeletionAvailable else {
            refreshAvailability()
            return .unavailable
        }
        operation = .deleting
        defer {
            operation = nil
            refreshAvailability()
        }
        do {
            try await manager.deleteAccount()
            return .deleted
        } catch AccountDeletionError.localCleanupFailed {
            return .cleanupRequired
        } catch AccountDeletionError.sessionExpired {
            return .sessionExpired
        } catch AccountDeletionError.unavailable {
            return .unavailable
        } catch {
            return .deletionFailed
        }
    }

    func createAccount() async -> Outcome? {
        guard !isBusy else { return nil }
        guard let manager, manager.canCreateAccount else {
            refreshAvailability()
            return .unavailable
        }
        operation = .creating
        defer {
            operation = nil
            refreshAvailability()
        }
        do {
            try await manager.createAccount()
            return .created
        } catch {
            return .creationFailed
        }
    }
}

extension QuizSettingsView {
    enum SettingsAlert: Identifiable {
        case restart(String)
        case feedback
        case deleteAccount, accountDeleted, deletionFailed, cleanupRequired, sessionExpired
        case createAccount, accountCreated, creationFailed, accountUnavailable, privacyUnavailable

        var id: String {
            switch self {
            case let .restart(title): return "restart-\(title)"
            case .feedback: return "feedback"
            case .deleteAccount: return "deleteAccount"
            case .accountDeleted: return "accountDeleted"
            case .deletionFailed: return "deletionFailed"
            case .cleanupRequired: return "cleanupRequired"
            case .sessionExpired: return "sessionExpired"
            case .createAccount: return "createAccount"
            case .accountCreated: return "accountCreated"
            case .creationFailed: return "creationFailed"
            case .accountUnavailable: return "accountUnavailable"
            case .privacyUnavailable: return "privacyUnavailable"
            }
        }

        var title: String {
            switch self {
            case .restart: return L10n.Settings.restartRequiredTitle
            case .feedback: return L10n.Settings.feedback
            case .deleteAccount: return L10n.Settings.Account.deleteConfirmationTitle
            case .accountDeleted: return L10n.Settings.Account.deletedTitle
            case .deletionFailed: return L10n.Settings.Account.deletionFailedTitle
            case .cleanupRequired: return L10n.Settings.Account.cleanupRequiredTitle
            case .sessionExpired: return L10n.Settings.Account.sessionExpiredTitle
            case .createAccount: return L10n.Settings.Account.createConfirmationTitle
            case .accountCreated: return L10n.Settings.Account.createdTitle
            case .creationFailed: return L10n.Settings.Account.creationFailedTitle
            case .accountUnavailable: return L10n.Settings.Account.unavailableTitle
            case .privacyUnavailable: return L10n.Settings.privacyUnavailableTitle
            }
        }

        var message: String {
            switch self {
            case let .restart(title): return L10n.Settings.restartRequiredMessage(selection: title)
            case .feedback: return L10n.Settings.feedbackUnavailableMessage
            case .deleteAccount: return L10n.Settings.Account.deleteConfirmationMessage
            case .accountDeleted: return L10n.Settings.Account.deletedMessage
            case .deletionFailed: return L10n.Settings.Account.deletionFailedMessage
            case .cleanupRequired: return L10n.Settings.Account.cleanupRequiredMessage
            case .sessionExpired: return L10n.Settings.Account.sessionExpiredMessage
            case .createAccount: return L10n.Settings.Account.createConfirmationMessage
            case .accountCreated: return L10n.Settings.Account.createdMessage
            case .creationFailed: return L10n.Settings.Account.creationFailedMessage
            case .accountUnavailable: return L10n.Settings.Account.unavailableMessage
            case .privacyUnavailable: return L10n.Settings.privacyUnavailableMessage
            }
        }
    }

    var profileSection: some View {
        SettingsSection(title: L10n.Settings.profileSectionTitle) {
            if account.canDelete || account.operation == .deleting {
                SettingsActionRow(
                    systemImage: "trash",
                    title: account.operation == .deleting ? L10n.Settings.Account.deleting : L10n.Settings.Account.delete,
                    subtitle: L10n.Settings.Account.deleteSubtitle,
                    isLoading: account.operation == .deleting
                ) {
                    activeAlert = .deleteAccount
                }
                .disabled(account.isBusy)
                .accessibilityIdentifier(AccessibilityID.deleteAccount)
            } else if account.canCreate || account.operation == .creating {
                SettingsActionRow(
                    systemImage: "person.crop.circle.badge.plus",
                    title: account.operation == .creating ? L10n.Settings.Account.creating : L10n.Settings.Account.create,
                    subtitle: L10n.Settings.Account.createSubtitle,
                    isLoading: account.operation == .creating
                ) {
                    activeAlert = .createAccount
                }
                .disabled(account.isBusy)
                .accessibilityIdentifier(AccessibilityID.createAccount)
            } else {
                SettingsRowHeader(
                    systemImage: "person.crop.circle",
                    title: L10n.Settings.Account.unavailableTitle,
                    subtitle: L10n.Settings.Account.unavailableMessage
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(AccessibilityID.accountUnavailable)
            }
        }
    }

    var supportSection: some View {
        SettingsSection(title: L10n.Settings.supportSectionTitle) {
            SettingsActionRow(
                systemImage: "hand.raised.fill",
                title: L10n.Settings.privacyPolicy,
                subtitle: L10n.Settings.privacyPolicySubtitle
            ) {
                guard let url = URL(string: "https://github.com/tabenskii/Quizice/blob/main/docs/privacy-policy.md") else { return }
                openURL(url) { accepted in
                    if !accepted { activeAlert = .privacyUnavailable }
                }
            }
            .accessibilityIdentifier(AccessibilityID.privacyPolicy)

            Divider()
                .background(Color(uiColor: appearance.card.borderColor))

            SettingsActionRow(
                systemImage: "star.bubble.fill",
                title: L10n.Settings.feedback,
                subtitle: L10n.Settings.feedbackSubtitle
            ) {
                analytics.track(.settingsAction(.feedback))
                activeAlert = .feedback
            }
        }
    }

    func makeAlert(_ alert: SettingsAlert) -> Alert {
        let title = Text(alert.title)
        let message = Text(alert.message)
        switch alert {
        case .deleteAccount:
            return Alert(title: title, message: message,
                         primaryButton: .destructive(Text(L10n.Settings.Account.delete), action: deleteAccount),
                         secondaryButton: .cancel(Text(L10n.Settings.Account.cancel)))
        case .createAccount:
            return Alert(title: title, message: message,
                         primaryButton: .default(Text(L10n.Settings.Account.create), action: createAccount),
                         secondaryButton: .cancel(Text(L10n.Settings.Account.cancel)))
        case .deletionFailed, .cleanupRequired:
            return Alert(title: title, message: message,
                         primaryButton: .default(Text(L10n.Settings.Account.retry), action: deleteAccount),
                         secondaryButton: .cancel(Text(L10n.Settings.Account.cancel)))
        case .creationFailed:
            return Alert(title: title, message: message,
                         primaryButton: .default(Text(L10n.Settings.Account.retry), action: createAccount),
                         secondaryButton: .cancel(Text(L10n.Settings.Account.cancel)))
        default:
            return Alert(title: title, message: message,
                         dismissButton: .default(Text(L10n.Settings.alertAction)))
        }
    }

    private func deleteAccount() {
        Task { @MainActor in
            guard let outcome = await account.deleteAccount() else { return }
            presentAccountOutcome(outcome)
        }
    }

    private func createAccount() {
        Task { @MainActor in
            guard let outcome = await account.createAccount() else { return }
            presentAccountOutcome(outcome)
        }
    }

    func presentAccountOutcome(_ outcome: SettingsAccountModel.Outcome) {
        switch outcome {
        case .deleted:
            activeAlert = nil
            onAccountDeleted()
        case .created: activeAlert = .accountCreated
        case .deletionFailed: activeAlert = .deletionFailed
        case .creationFailed: activeAlert = .creationFailed
        case .cleanupRequired: activeAlert = .cleanupRequired
        case .sessionExpired: activeAlert = .sessionExpired
        case .unavailable: activeAlert = .accountUnavailable
        }
        allowsPersonalizedRepeats = personalizedRepeatsAvailable()
    }

}
