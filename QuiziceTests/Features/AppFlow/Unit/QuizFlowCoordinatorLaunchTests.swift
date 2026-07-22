import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
final class QuizFlowCoordinatorLaunchTests: QuizFlowCoordinatorTestCase {
    func testDebugSimulatorAIRuntimeUsesDirectServiceWithoutBackendAccess() {
        let backendAccess = BackendAIQuizAccessStub(isAvailable: false)

        let dependencies = AIQuizRuntimeDependencies.resolve(
            usesDirectAI: true,
            backendConfiguration: BackendConfiguration(
                baseURL: URL(string: "https://example.com/api")!
            ),
            backendAccessProvider: backendAccess,
            directAPIKeyProvider: { "test-api-key" },
            directUnauthorizedHandler: {}
        )

        XCTAssertTrue(dependencies.accessProvider.isAIQuizAvailable)
        XCTAssertTrue(dependencies.themeService is YandexAIQuizThemeService)
        XCTAssertFalse(backendAccess.isAIQuizAvailable)
    }

    func testDeviceAIRuntimePreservesBackendAccessAndUsesBackendService() {
        let backendAccess = BackendAIQuizAccessStub(isAvailable: false)

        let dependencies = AIQuizRuntimeDependencies.resolve(
            usesDirectAI: false,
            backendConfiguration: BackendConfiguration(
                baseURL: URL(string: "https://example.com/api")!
            ),
            backendAccessProvider: backendAccess,
            directAPIKeyProvider: {
                XCTFail("Device path must not read a direct API key")
                return nil
            },
            directUnauthorizedHandler: {
                XCTFail("Device path must not manage a direct API key")
            }
        )

        XCTAssertTrue(dependencies.accessProvider === backendAccess)
        XCTAssertTrue(dependencies.themeService is BackendAIQuizThemeService)
        XCTAssertFalse(dependencies.accessProvider.isAIQuizAvailable)
    }

    func testStartInstallsHomeControllerAsNavigationRoot() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let navigationController = RoutingNavigationControllerSpy()
        let session = RoutingSession()
        let coordinator = QuizFlowCoordinator(
            window: window,
            navigationController: navigationController,
            themeRepository: RoutingThemeRepository(themes: []),
            session: session
        )

        coordinator.start()

        XCTAssertTrue(window.rootViewController === navigationController)
        XCTAssertTrue(navigationController.viewControllers.first is QuizViewController)
        XCTAssertTrue(navigationController.isNavigationBarHidden)
    }

    func testLaunchOverlayPresenterInstallsAndRemovesFakeLaunchAboveRoot() throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UINavigationController(rootViewController: UIViewController())
        window.rootViewController = rootViewController
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .radar)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(in: window, appearance: appearance, holdDuration: 60)

        let overlayWindow = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )
        XCTAssertFalse(overlayWindow.isKeyWindow)
        XCTAssertEqual(overlayWindow.windowLevel.rawValue, window.windowLevel.rawValue + 1)
        let hostingController = try XCTUnwrap(
            overlayWindow.rootViewController as? UIHostingController<FakeLaunchScreenView>
        )
        XCTAssertEqual(hostingController.rootView.appearance.designStyle, .radar)
        assertColor(overlayWindow.backgroundColor, equals: .black)
        assertColor(hostingController.view.backgroundColor, equals: .black)
        XCTAssertTrue(rootViewController.view.accessibilityElementsHidden)
        XCTAssertEqual(rootViewController.children.count, 1)

        presenter.dismiss(animated: false)

        XCTAssertTrue(overlayWindow.isHidden)
        XCTAssertNil(overlayWindow.rootViewController)
        XCTAssertFalse(rootViewController.view.accessibilityElementsHidden)
        XCTAssertEqual(rootViewController.children.count, 1)
    }

    func testLaunchOverlayPresenterAutomaticallyRevealsHomeAndRestoresAccessibility() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        window.isHidden = false
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .radar)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(
            in: window,
            appearance: appearance,
            holdDuration: 0,
            motion: FakeLaunchMotion(logoZoomScale: 42, logoZoomDuration: 0.05)
        )

        let overlayWindow = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )
        let dismissalExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                overlayWindow.isHidden && overlayWindow.rootViewController == nil
            },
            object: nil
        )

        await fulfillment(of: [dismissalExpectation], timeout: 2)

        XCTAssertFalse(rootViewController.view.accessibilityElementsHidden)
    }

    func testFakeLaunchUsesCrossfadeCompletionWhenAnimationsAreDisabled() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let completionExpectation = expectation(description: "Fake launch completes without zoom")
        var completionStyle: FakeLaunchCompletionStyle?
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        let appearance = makeLaunchAppearance(designStyle: .classic)
        let rootView = FakeLaunchScreenView(
            appearance: appearance,
            holdDuration: 0,
            motion: FakeLaunchMotion(logoZoomScale: 42, logoZoomDuration: 0.01)
        ) { style in
            completionStyle = style
            completionExpectation.fulfill()
        }
        let viewController = UIHostingController(rootView: rootView)
        window.rootViewController = viewController
        window.isHidden = false
        defer {
            UIView.setAnimationsEnabled(animationsWereEnabled)
            window.isHidden = true
            window.rootViewController = nil
        }

        await fulfillment(of: [completionExpectation], timeout: 3)

        XCTAssertEqual(completionStyle, .crossfade)
    }

    func testStaleLaunchFadeDoesNotRemoveAReplacementOverlay() async throws {
        let windowScene = try XCTUnwrap(
            UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        )
        let window = UIWindow(windowScene: windowScene)
        let rootViewController = UIViewController()
        window.rootViewController = rootViewController
        let presenter = LaunchOverlayPresenter()
        let appearance = makeLaunchAppearance(designStyle: .classic)
        defer {
            presenter.dismiss(animated: false)
            window.isHidden = true
            window.rootViewController = nil
        }

        presenter.present(in: window, appearance: appearance, holdDuration: 60)
        let firstOverlay = try XCTUnwrap(
            windowScene.windows.first {
                $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
            }
        )

        presenter.dismiss()
        presenter.dismiss(animated: false)
        presenter.present(in: window, appearance: appearance, holdDuration: 60)

        let replacementOverlay = try XCTUnwrap(
            windowScene.windows.first {
                $0 !== firstOverlay
                    && $0.accessibilityIdentifier == LaunchOverlayPresenter.accessibilityIdentifier
                    && !$0.isHidden
            }
        )
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertFalse(replacementOverlay.isHidden)
        XCTAssertNotNil(replacementOverlay.rootViewController)
        XCTAssertTrue(rootViewController.view.accessibilityElementsHidden)
    }

    func testFakeLaunchVisualStyleMatchesSelectedDesignAndColorScheme() throws {
        let classicAppearance = makeLaunchAppearance(designStyle: .classic)
        let classicStyle = FakeLaunchVisualStyle(appearance: classicAppearance)
        XCTAssertEqual(classicStyle.markStyle, .classicImage)
        XCTAssertTrue(classicStyle.revealsAppBackground)
        XCTAssertNil(classicStyle.foregroundColor)
        assertColor(classicStyle.backgroundColor, equals: UIColor(hex: 0x111620))

        let radarAppearance = makeLaunchAppearance(designStyle: .radar)
        let radarStyle = FakeLaunchVisualStyle(appearance: radarAppearance)
        XCTAssertEqual(radarStyle.markStyle, .radarText)
        XCTAssertFalse(radarStyle.revealsAppBackground)
        assertColor(radarStyle.backgroundColor, equals: .black)
        assertColor(
            try XCTUnwrap(radarStyle.foregroundColor),
            equals: radarAppearance.accentColor
        )

        let cleanLightAppearance = makeLaunchAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .light
        )
        let cleanLightStyle = FakeLaunchVisualStyle(appearance: cleanLightAppearance)
        XCTAssertEqual(cleanLightStyle.markStyle, .cleanText)
        XCTAssertFalse(cleanLightStyle.revealsAppBackground)
        assertColor(cleanLightStyle.backgroundColor, equals: .white)
        assertColor(try XCTUnwrap(cleanLightStyle.foregroundColor), equals: .black)

        let cleanDarkAppearance = makeLaunchAppearance(
            designStyle: .clean,
            cleanColorSchemePreference: .dark
        )
        let cleanDarkStyle = FakeLaunchVisualStyle(appearance: cleanDarkAppearance)
        XCTAssertEqual(cleanDarkStyle.markStyle, .cleanText)
        XCTAssertFalse(cleanDarkStyle.revealsAppBackground)
        assertColor(cleanDarkStyle.backgroundColor, equals: .black)
        assertColor(try XCTUnwrap(cleanDarkStyle.foregroundColor), equals: .white)
    }

    func testLaunchStoryboardMatchesFakeLaunchBaseGeometryAndColor() throws {
        let viewController = try XCTUnwrap(
            UIStoryboard(name: "LaunchScreen", bundle: nil).instantiateInitialViewController()
        )
        let logoImageView = try XCTUnwrap(
            viewController.view.subviews.compactMap { $0 as? UIImageView }.first
        )
        let backgroundColor = try XCTUnwrap(viewController.view.backgroundColor)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        XCTAssertTrue(backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        XCTAssertEqual(red, 17.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(green, 22.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(blue, 32.0 / 255.0, accuracy: 0.000_001)
        XCTAssertEqual(alpha, 1, accuracy: 0.000_001)

        let pixelTolerance = 1 / UIScreen.main.scale
        for size in [
            CGSize(width: 320, height: 568),
            CGSize(width: 393, height: 852),
            CGSize(width: 600, height: 1_000)
        ] {
            viewController.view.frame = CGRect(origin: .zero, size: size)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            XCTAssertEqual(logoImageView.frame.midX, size.width / 2, accuracy: 0.01)
            XCTAssertEqual(logoImageView.frame.midY, size.height / 2, accuracy: 0.01)
            let expectedWidth = min(size.width * 0.7, 360)
            let expectedHeight = expectedWidth * 399 / 742
            XCTAssertEqual(logoImageView.frame.width, expectedWidth, accuracy: pixelTolerance)
            XCTAssertEqual(logoImageView.frame.height, expectedHeight, accuracy: pixelTolerance)
        }
    }
}
