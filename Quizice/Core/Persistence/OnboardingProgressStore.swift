import Foundation

protocol OnboardingProgressStoring: AnyObject {
    var needsOnboarding: Bool { get }
    var preferredThemeIDs: Set<String> { get }

    func complete(preferredThemeIDs: Set<String>)
}

final class OnboardingProgressStore: OnboardingProgressStoring {
    static let shared = OnboardingProgressStore()

    enum Keys {
        static let completedVersion = "quizice.onboarding.completedVersion"
        static let preferredThemeIDs = "quizice.onboarding.preferredThemeIDs"
    }

    static let currentVersion = 1

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var needsOnboarding: Bool {
        userDefaults.integer(forKey: Keys.completedVersion) < Self.currentVersion
    }

    var preferredThemeIDs: Set<String> {
        Set(userDefaults.stringArray(forKey: Keys.preferredThemeIDs) ?? [])
    }

    func complete(preferredThemeIDs: Set<String>) {
        userDefaults.set(preferredThemeIDs.sorted(), forKey: Keys.preferredThemeIDs)
        userDefaults.set(Self.currentVersion, forKey: Keys.completedVersion)
    }
}
