import XCTest
@testable import Quizice

@MainActor
final class AppAppearanceStorePersistenceTests: XCTestCase {
    private var userDefaults: UserDefaults!
    private var notificationCenter: NotificationCenter!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "AppAppearanceStorePersistenceTests-\(UUID().uuidString)"
        userDefaults = UserDefaults(suiteName: suiteName)
        userDefaults.removePersistentDomain(forName: suiteName)
        notificationCenter = NotificationCenter()
    }

    override func tearDown() {
        userDefaults.removePersistentDomain(forName: suiteName)
        userDefaults = nil
        notificationCenter = nil
        suiteName = nil
        super.tearDown()
    }

    func testRegisterInitialDefaultsPopulatesDefaultStyles() {
        let store = makeStore()

        store.registerInitialDefaults()

        XCTAssertEqual(store.designStyle, AppDesignStyle.defaultStyle)
        XCTAssertEqual(store.cleanColorSchemePreference, .system)
        XCTAssertEqual(store.backgroundStyle, AppBackgroundStyle.defaultStyle)
    }

    func testDesignStyleRoundTripsThroughUserDefaults() {
        let store = makeStore()
        store.registerInitialDefaults()

        store.designStyle = .radar

        XCTAssertEqual(store.designStyle, .radar)
        XCTAssertEqual(
            userDefaults.string(forKey: AppAppearanceStore.Keys.designStyle),
            AppDesignStyle.radar.rawValue
        )

        let reopened = AppAppearanceStore(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter
        )
        XCTAssertEqual(reopened.designStyle, .radar)
    }

    func testCleanColorSchemePreferenceRoundTripsThroughUserDefaults() {
        let store = makeStore()
        store.registerInitialDefaults()

        store.cleanColorSchemePreference = .dark

        XCTAssertEqual(store.cleanColorSchemePreference, .dark)

        let reopened = AppAppearanceStore(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter
        )
        XCTAssertEqual(reopened.cleanColorSchemePreference, .dark)
    }

    func testBackgroundStyleRoundTripsThroughUserDefaults() {
        let store = makeStore()
        store.registerInitialDefaults()

        store.backgroundStyle = .legacySlate

        XCTAssertEqual(store.backgroundStyle, .legacySlate)

        let reopened = AppAppearanceStore(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter
        )
        XCTAssertEqual(reopened.backgroundStyle, .legacySlate)
    }

    func testChangingDesignStylePostsAppearanceChangedNotification() {
        let store = makeStore()
        store.registerInitialDefaults()
        var receivedCount = 0
        let observer = notificationCenter.addObserver(
            forName: .appAppearanceDidChange,
            object: store,
            queue: nil
        ) { _ in receivedCount += 1 }

        store.designStyle = .radar

        XCTAssertEqual(receivedCount, 1)
        notificationCenter.removeObserver(observer)
    }

    func testSettingSameDesignStyleDoesNotEmitNotification() {
        let store = makeStore()
        store.registerInitialDefaults()
        store.designStyle = .radar
        var receivedCount = 0
        let observer = notificationCenter.addObserver(
            forName: .appAppearanceDidChange,
            object: store,
            queue: nil
        ) { _ in receivedCount += 1 }

        store.designStyle = .radar

        XCTAssertEqual(receivedCount, 0)
        notificationCenter.removeObserver(observer)
    }

    func testUnknownDesignStyleRawValueFallsBackToDefault() {
        userDefaults.set("gibberish", forKey: AppAppearanceStore.Keys.designStyle)
        let store = makeStore()

        XCTAssertEqual(store.designStyle, AppDesignStyle.defaultStyle)
    }

    private func makeStore() -> AppAppearanceStore {
        AppAppearanceStore(
            userDefaults: userDefaults,
            notificationCenter: notificationCenter
        )
    }
}
