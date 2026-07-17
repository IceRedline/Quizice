//
//  AppDelegate.swift
//  Quizice
//
//  Created by Артем Табенский on 21.03.2025.
//

import UIKit
import SwiftData

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    var modelContainer: ModelContainer?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        AppMetricaAnalyticsTracker.shared.activate()
        modelContainer = makeModelContainer()
        if let modelContainer {
            QuizFactory.shared.setModelContext(modelContainer.mainContext)
        }
        return true
    }

    /// Attempts to build a persistent SwiftData container and, if that fails
    /// (e.g. an incompatible store on disk), falls back to an in-memory one so
    /// the app still launches in a degraded but usable state instead of crashing.
    private func makeModelContainer() -> ModelContainer? {
        let schema = Schema([QuizTheme.self, QuizQuestion.self])
        do {
            return try ModelContainer(for: schema)
        } catch {
            AppLog.persistence.error("Persistent ModelContainer creation failed: \(error, privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .persistentStore)
        }

        do {
            let inMemoryConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            return try ModelContainer(for: schema, configurations: inMemoryConfiguration)
        } catch {
            AppLog.persistence.error("In-memory ModelContainer creation failed: \(error, privacy: .public)")
            AppMetricaAnalyticsTracker.shared.reportOperationalError(error, context: .inMemoryStore)
            return nil
        }
    }
    
    // MARK: UISceneSession Lifecycle
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
    
}

import OSLog

/// Centralized logging so we never ship `print` calls to production.
enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.quizice.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let content = Logger(subsystem: subsystem, category: "content")
    static let quiz = Logger(subsystem: subsystem, category: "quiz")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    static let auth = Logger(subsystem: subsystem, category: "auth")
}
