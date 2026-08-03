import Foundation
import UIKit

/// Reports whether the user is running assistive technology that warrants
/// the app's accessibility-first mode (timer removed, per-attempt segregation
/// on the leaderboard).
///
/// Following the `QuizTimerClient` pattern from `QuizQuestionPresenter`: a
/// value-type client with closures, so tests can substitute `.stub(active:)`
/// without touching real UIKit state.
struct AccessibilityModeClient {
    /// Evaluated freshly on each call. Safe to call from any thread; the
    /// underlying `UIAccessibility.isVoiceOverRunning` / `isSwitchControlRunning`
    /// getters read a cached property populated on the main thread by UIKit
    /// and are documented as safe for cross-thread reads.
    var isActive: () -> Bool

    static let live = AccessibilityModeClient(
        isActive: {
            UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning
        }
    )

    static func stub(active: Bool) -> AccessibilityModeClient {
        AccessibilityModeClient(isActive: { active })
    }
}

/// Sequences VoiceOver announcements and focus moves so that later steps
/// wait for earlier ones to actually finish speaking, instead of racing them
/// on a fixed timer (which cuts off anything longer than the guessed delay).
///
/// Every entry point bumps a shared `generation` token. Any step still
/// waiting from a previous, superseded call checks its captured token against
/// the current one before doing anything — so starting a new announcement
/// (e.g. answering a question while the previous "question loaded" sequence
/// is still mid-flight) silently cancels the stale one instead of talking
/// over it.
enum VoiceOverAnnouncer {
    private static var generation = 0

    /// Speaks `messages` one at a time, only moving to the next one once
    /// VoiceOver reports it finished speaking the previous one.
    static func announce(_ messages: [String], completion: (() -> Void)? = nil) {
        generation += 1
        let token = generation

        guard UIAccessibility.isVoiceOverRunning else {
            completion?()
            return
        }

        let trimmedMessages = messages
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        speak(trimmedMessages, token: token, completion: completion)
    }

    /// Moves real VoiceOver focus to `element` (reading `label` as VoiceOver
    /// normally would) and waits an estimated amount of time for that speech
    /// to finish before calling `completion`. Use this — instead of
    /// `announce` — when the focus rectangle itself should end up on
    /// `element`, not just have its label spoken as an aside.
    static func focus(_ element: Any, label: String?, completion: (() -> Void)? = nil) {
        generation += 1
        let token = generation

        guard UIAccessibility.isVoiceOverRunning else {
            completion?()
            return
        }

        UIAccessibility.post(notification: .layoutChanged, argument: element)
        let delay = estimatedSpeechDuration(for: label ?? "")
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard token == generation else { return }
            completion?()
        }
    }

    private static func speak(
        _ messages: [String],
        token: Int,
        completion: (() -> Void)?
    ) {
        guard token == generation else { return }
        guard let first = messages.first else {
            completion?()
            return
        }

        var didAdvance = false
        var observer: NSObjectProtocol?
        let advance = {
            guard !didAdvance else { return }
            didAdvance = true
            if let observer {
                NotificationCenter.default.removeObserver(observer)
            }
            speak(Array(messages.dropFirst()), token: token, completion: completion)
        }

        observer = NotificationCenter.default.addObserver(
            forName: UIAccessibility.announcementDidFinishNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard token == generation else {
                if let observer {
                    NotificationCenter.default.removeObserver(observer)
                }
                return
            }
            let spokenMessage = notification.userInfo?[
                UIAccessibility.announcementStringValueUserInfoKey
            ] as? String
            guard spokenMessage == first else { return }
            advance()
        }

        // VoiceOver doesn't always fire the finish notification (e.g. the
        // user starts swiping mid-announcement, interrupting it). A timeout
        // keeps the chain from hanging forever in that case.
        let fallbackDelay = estimatedSpeechDuration(for: first) + 1.5
        DispatchQueue.main.asyncAfter(deadline: .now() + fallbackDelay, execute: advance)

        UIAccessibility.post(notification: .announcement, argument: first)
    }

    private static func estimatedSpeechDuration(for text: String) -> TimeInterval {
        let charactersPerSecond: Double = 16
        return max(0.6, Double(text.count) / charactersPerSecond)
    }
}
