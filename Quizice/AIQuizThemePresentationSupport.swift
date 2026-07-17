import SwiftUI
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

    var offersEditAction: Bool {
        canRetry || shouldFocusPromptOnDismiss
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
                 .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed,
                 .secureConnectionFailed, .serverCertificateHasBadDate,
                 .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
                 .serverCertificateNotYetValid, .clientCertificateRejected,
                 .clientCertificateRequired:
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

struct QuizAlertAction {
    enum Emphasis: Equatable {
        case primary
        case secondary
        case destructive

        func surfaceStyle(in appearance: AppAppearance) -> AppSurfaceStyle {
            switch self {
            case .primary:
                return appearance.primaryButton
            case .secondary:
                return appearance.secondaryButton
            case .destructive:
                let baseStyle = appearance.designStyle == .clean
                    ? appearance.primaryButton
                    : appearance.secondaryButton
                return AppSurfaceStyle(
                    backgroundColor: appearance.designStyle == .clean
                        ? tintColor(in: appearance)
                        : baseStyle.backgroundColor,
                    borderColor: tintColor(in: appearance),
                    borderWidth: max(baseStyle.borderWidth, 1),
                    cornerRadius: baseStyle.cornerRadius,
                    shadow: baseStyle.shadow
                )
            }
        }

        func textColor(in appearance: AppAppearance) -> UIColor {
            switch self {
            case .primary:
                return QuizThemeAccentStyle.primaryButtonTextColor(
                    themeID: nil,
                    appearance: appearance
                )
            case .secondary:
                return QuizThemeAccentStyle.secondaryButtonTextColor(
                    themeID: nil,
                    appearance: appearance
                )
            case .destructive:
                return appearance.designStyle == .clean ? .black : tintColor(in: appearance)
            }
        }

        func tintColor(in appearance: AppAppearance) -> UIColor {
            switch appearance.designStyle {
            case .classic:
                return .systemRed
            case .clean, .radar:
                return appearance.destructiveColor
            }
        }
    }

    let title: String
    let emphasis: Emphasis
    let accessibilityIdentifier: String
    let action: () -> Void
}

@MainActor
final class QuizAlertPresenter {
    typealias DismissViewController = @MainActor (
        UIViewController,
        Bool,
        @escaping () -> Void
    ) -> Void

    weak var presentingViewController: UIViewController?
    private(set) weak var alertViewController: UIViewController?
    private(set) var isDismissing = false
    private var animatesPresentation = true
    private let dismissViewController: DismissViewController

    init(
        dismissViewController: @escaping DismissViewController = { controller, animated, completion in
            controller.dismiss(animated: animated, completion: completion)
        }
    ) {
        self.dismissViewController = dismissViewController
    }

    @discardableResult
    func present<Content: View>(
        _ content: Content,
        appearance: AppAppearance,
        reduceMotion: Bool
    ) -> Bool {
        guard !isDismissing else { return false }
        if alertViewController != nil { return true }
        guard let presentingViewController,
              presentingViewController.viewIfLoaded?.window != nil,
              presentingViewController.transitionCoordinator == nil,
              presentingViewController.presentedViewController == nil
        else {
            return false
        }

        let controller = makeAlertViewController(content, appearance: appearance)
        animatesPresentation = !reduceMotion
        alertViewController = controller
        presentingViewController.present(controller, animated: animatesPresentation)
        return true
    }

    func dismiss(completion: @escaping () -> Void = {}) {
        guard !isDismissing else { return }
        guard let alertViewController else {
            completion()
            return
        }

        isDismissing = true
        alertViewController.view.isUserInteractionEnabled = false
        dismissViewController(alertViewController, animatesPresentation) { [weak self] in
            self?.alertViewController = nil
            self?.isDismissing = false
            completion()
        }
    }

    func makeAlertViewController<Content: View>(
        _ content: Content,
        appearance: AppAppearance
    ) -> UIViewController {
        let rootView = content
            .environment(\.appAppearance, appearance)
            .preferredColorScheme(appearance.swiftUIColorScheme)
        let controller = UIHostingController(rootView: rootView)
        controller.modalPresentationStyle = .overFullScreen
        controller.modalTransitionStyle = .crossDissolve
        controller.isModalInPresentation = true
        controller.view.backgroundColor = .clear
        controller.view.isOpaque = false
        controller.view.accessibilityViewIsModal = true
        return controller
    }
}

struct QuizAlertOverlay: View {
    private enum Layout {
        static let horizontalInset: CGFloat = 24
        static let verticalInset: CGFloat = 28
        static let maximumWidth: CGFloat = 350
        static let cardPadding: CGFloat = 24
        static let contentSpacing: CGFloat = 20
        static let textSpacing: CGFloat = 8
        static let actionSpacing: CGFloat = 10
        static let iconSize: CGFloat = 52
        static let buttonMinimumHeight: CGFloat = 50
        static let buttonHorizontalPadding: CGFloat = 16
        static let buttonVerticalPadding: CGFloat = 12
    }

    private enum AccessibilityID {
        static let dialog = "quizAlertDialog"
        static let title = "quizAlertTitle"
        static let message = "quizAlertMessage"
    }

    private struct KeyboardShortcutModifier: ViewModifier {
        let emphasis: QuizAlertAction.Emphasis

        @ViewBuilder
        func body(content: Content) -> some View {
            switch emphasis {
            case .primary:
                content.keyboardShortcut(.defaultAction)
            case .secondary:
                content.keyboardShortcut(.cancelAction)
            case .destructive:
                content
            }
        }
    }

    @Environment(\.appAppearance) private var appearance

    let title: String
    let message: String
    let systemImage: String
    let iconColor: UIColor
    let primaryAction: QuizAlertAction
    let secondaryAction: QuizAlertAction?
    let onEscape: () -> Void
    let onCardFrameChange: ((CGRect) -> Void)?

    init(
        title: String,
        message: String,
        systemImage: String,
        iconColor: UIColor,
        primaryAction: QuizAlertAction,
        secondaryAction: QuizAlertAction?,
        onEscape: @escaping () -> Void,
        onCardFrameChange: ((CGRect) -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.iconColor = iconColor
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.onEscape = onEscape
        self.onCardFrameChange = onCardFrameChange
    }

    var body: some View {
        GeometryReader { geometry in
            let safeVerticalInset = max(
                Layout.verticalInset,
                geometry.safeAreaInsets.top,
                geometry.safeAreaInsets.bottom
            )

            ZStack {
                Color.black
                    .opacity(appearance.dialogScrimOpacity)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: safeVerticalInset)

                        alertCard
                            .padding(.horizontal, Layout.horizontalInset)

                        Spacer(minLength: safeVerticalInset)
                    }
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .accessibilityElement(children: .contain)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private var alertCard: some View {
        let surface = appearance.dialogSurface

        return VStack(spacing: Layout.contentSpacing) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .font(appearance.typography.swiftUIFont(size: 22, weight: .semibold))
                .foregroundStyle(Color(uiColor: iconColor))
                .frame(width: Layout.iconSize, height: Layout.iconSize)
                .background(
                    Color(uiColor: appearance.iconButton.backgroundColor),
                    in: RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: appearance.iconButton.cornerRadius, style: .continuous)
                        .stroke(
                            Color(uiColor: appearance.iconButton.borderColor),
                            lineWidth: appearance.iconButton.borderWidth
                        )
                )
                .accessibilityHidden(true)

            VStack(spacing: Layout.textSpacing) {
                Text(title)
                    .font(appearance.typography.swiftUIFont(size: 22, weight: .bold))
                    .foregroundStyle(Color(uiColor: appearance.surfaceTextColor))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.title)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilitySortPriority(3)

                Text(message)
                    .font(appearance.typography.swiftUIFont(size: 16, weight: .regular))
                    .foregroundStyle(Color(uiColor: appearance.secondarySurfaceTextColor))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.message)
            }

            VStack(spacing: Layout.actionSpacing) {
                actionButton(primaryAction)
                if let secondaryAction {
                    actionButton(secondaryAction)
                }
            }
        }
        .padding(Layout.cardPadding)
        .frame(maxWidth: Layout.maximumWidth)
        .background(
            Color(uiColor: surface.backgroundColor),
            in: RoundedRectangle(cornerRadius: surface.cornerRadius, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: surface.cornerRadius, style: .continuous)
                .stroke(Color(uiColor: surface.borderColor), lineWidth: surface.borderWidth)
        )
        .shadow(
            color: Color(uiColor: surface.shadow.color).opacity(Double(surface.shadow.opacity)),
            radius: surface.shadow.radius,
            x: surface.shadow.offset.width,
            y: surface.shadow.offset.height
        )
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier(AccessibilityID.dialog)
        .accessibilityAction(.escape) { onEscape() }
        .onGeometryChange(for: CGRect.self) { geometry in
            geometry.frame(in: .global)
        } action: { frame in
            onCardFrameChange?(frame)
        }
    }

    private func actionButton(_ action: QuizAlertAction) -> some View {
        let style = action.emphasis.surfaceStyle(in: appearance)
        let textColor = action.emphasis.textColor(in: appearance)

        return Button(
            role: action.emphasis == .destructive ? .destructive : nil,
            action: action.action
        ) {
            Text(action.title)
                .font(appearance.typography.swiftUIFont(size: 17, weight: .semibold))
                .foregroundStyle(Color(uiColor: textColor))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Layout.buttonHorizontalPadding)
                .padding(.vertical, Layout.buttonVerticalPadding)
                .frame(maxWidth: .infinity, minHeight: Layout.buttonMinimumHeight)
                .background(
                    Color(uiColor: style.backgroundColor),
                    in: RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                        .stroke(Color(uiColor: style.borderColor), lineWidth: style.borderWidth)
                )
                .shadow(
                    color: Color(uiColor: style.shadow.color).opacity(Double(style.shadow.opacity)),
                    radius: style.shadow.radius,
                    x: style.shadow.offset.width,
                    y: style.shadow.offset.height
                )
        }
        .buttonStyle(QuizPressButtonStyle())
        .modifier(KeyboardShortcutModifier(emphasis: action.emphasis))
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}

extension AIQuizGenerationAlert.Kind {
    var systemImage: String {
        switch self {
        case .refusal: return "hand.raised.fill"
        case .network: return "wifi.slash"
        case .service: return "clock.fill"
        case .invalidQuiz: return "doc.text.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        }
    }

    func iconColor(in appearance: AppAppearance) -> UIColor {
        switch appearance.designStyle {
        case .radar:
            return appearance.accentColor
        case .classic:
            return appearance.screenTextColor
        case .clean:
            switch self {
            case .refusal, .unavailable:
                return appearance.destructiveColor
            case .network, .service, .invalidQuiz:
                return appearance.accentColor
            }
        }
    }
}
