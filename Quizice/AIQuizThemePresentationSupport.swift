import UIKit

struct AIThemeKeyboardStyle {
    let interfaceStyle: UIUserInterfaceStyle
    let doneButtonTintColor: UIColor

    init(appearance: AppAppearance) {
        interfaceStyle = appearance.resolvedInterfaceStyle
        switch appearance.designStyle {
        case .clean, .radar:
            doneButtonTintColor = appearance.accentColor
        case .classic:
            doneButtonTintColor = .systemBlue
        }
    }
}

struct AIQuizGenerationAlert: Identifiable, Equatable {
    enum Kind: String {
        case refusal
        case network
        case service
        case invalidQuiz
        case unavailable
    }

    let kind: Kind

    var id: String { kind.rawValue }

    var title: String {
        switch kind {
        case .refusal: return L10n.AITheme.Error.Refusal.title
        case .network: return L10n.AITheme.Error.Network.title
        case .service: return L10n.AITheme.Error.Service.title
        case .invalidQuiz: return L10n.AITheme.Error.InvalidQuiz.title
        case .unavailable: return L10n.AITheme.Error.Unavailable.title
        }
    }

    var message: String {
        switch kind {
        case .refusal: return L10n.AITheme.Error.Refusal.message
        case .network: return L10n.AITheme.Error.Network.message
        case .service: return L10n.AITheme.Error.Service.message
        case .invalidQuiz: return L10n.AITheme.Error.InvalidQuiz.message
        case .unavailable: return L10n.AITheme.Error.Unavailable.message
        }
    }

    var canRetry: Bool {
        switch kind {
        case .network, .service, .invalidQuiz: return true
        case .refusal, .unavailable: return false
        }
    }

    var shouldFocusPromptOnDismiss: Bool {
        kind == .refusal || kind == .invalidQuiz
    }

    init(error: Error) {
        guard let serviceError = error as? YandexAIQuizThemeServiceError else {
            kind = .unavailable
            return
        }

        switch serviceError {
        case .refused:
            kind = .refusal
        case let .network(code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut,
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                kind = .network
            default:
                kind = .service
            }
        case let .httpStatus(statusCode) where statusCode == 429 || statusCode >= 500:
            kind = .service
        case .generationStatus:
            kind = .service
        case .invalidResponseJSON, .missingOutputText, .invalidQuizJSON, .invalidContract:
            kind = .invalidQuiz
        case .unavailableInRelease, .missingAPIKey, .emptyPrompt, .requestEncodingFailed,
             .invalidHTTPResponse, .httpStatus:
            kind = .unavailable
        }
    }
}
