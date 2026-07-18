import Foundation
import OSLog

enum AppLog {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.quizice.app"

    static let persistence = Logger(subsystem: subsystem, category: "persistence")
    static let content = Logger(subsystem: subsystem, category: "content")
    static let quiz = Logger(subsystem: subsystem, category: "quiz")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let analytics = Logger(subsystem: subsystem, category: "analytics")
    static let auth = Logger(subsystem: subsystem, category: "auth")
}
