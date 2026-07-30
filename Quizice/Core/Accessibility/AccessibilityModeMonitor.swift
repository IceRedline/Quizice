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
