//
//  StatisticsStore.swift
//  Quizice
//
//  Created by GSD on 03.07.2026.
//

import Foundation

final class StatisticsStore {
    struct Attempt: Codable, Equatable {
        let correctAnswers: Int
        let totalQuestions: Int

        init(correctAnswers: Int, totalQuestions: Int) {
            self.correctAnswers = correctAnswers
            self.totalQuestions = totalQuestions
        }
    }

    private let userDefaults: UserDefaults
    private let key: String
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(userDefaults: UserDefaults = .standard, key: String = "quizice.statistics.attempts") {
        self.userDefaults = userDefaults
        self.key = key
    }

    func recordAttempt(correctAnswers: Int, totalQuestions: Int) {
        guard let attempt = sanitizedAttempt(correctAnswers: correctAnswers, totalQuestions: totalQuestions) else {
            return
        }

        var attempts = loadAttempts()
        attempts.append(attempt)
        save(attempts: attempts)
    }

    func loadSummary() -> StatisticsSummary {
        let attempts = loadAttempts()
        guard attempts.isEmpty == false else { return .empty }
        return Self.summary(from: attempts)
    }

    static func summary(from attempts: [Attempt]) -> StatisticsSummary {
        let sanitizedAttempts = attempts.compactMap {
            sanitizedAttempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions)
        }

        guard sanitizedAttempts.isEmpty == false else { return .empty }

        let playedQuizzes = sanitizedAttempts.count
        let correctAnswers = sanitizedAttempts.reduce(0) { $0 + $1.correctAnswers }
        let totalQuestions = sanitizedAttempts.reduce(0) { $0 + $1.totalQuestions }
        let bestAttempt = sanitizedAttempts.max { lhs, rhs in
            let lhsPercentage = Double(lhs.correctAnswers) / Double(lhs.totalQuestions)
            let rhsPercentage = Double(rhs.correctAnswers) / Double(rhs.totalQuestions)

            if lhsPercentage == rhsPercentage {
                if lhs.correctAnswers == rhs.correctAnswers {
                    return lhs.totalQuestions > rhs.totalQuestions
                }
                return lhs.correctAnswers < rhs.correctAnswers
            }

            return lhsPercentage < rhsPercentage
        }

        return StatisticsSummary(
            playedQuizzes: playedQuizzes,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            bestCorrectAnswers: bestAttempt?.correctAnswers ?? 0,
            bestTotalQuestions: bestAttempt?.totalQuestions ?? 0
        )
    }

    private func loadAttempts() -> [Attempt] {
        guard let data = userDefaults.data(forKey: key) else { return [] }

        do {
            return try decoder.decode([Attempt].self, from: data)
        } catch {
            userDefaults.removeObject(forKey: key)
            return []
        }
    }

    private func save(attempts: [Attempt]) {
        guard let data = try? encoder.encode(attempts) else { return }
        userDefaults.set(data, forKey: key)
    }

    private func sanitizedAttempt(correctAnswers: Int, totalQuestions: Int) -> Attempt? {
        Self.sanitizedAttempt(correctAnswers: correctAnswers, totalQuestions: totalQuestions)
    }

    private static func sanitizedAttempt(correctAnswers: Int, totalQuestions: Int) -> Attempt? {
        guard totalQuestions > 0 else { return nil }
        let sanitizedTotal = max(totalQuestions, 0)
        let sanitizedCorrect = min(max(correctAnswers, 0), sanitizedTotal)
        return Attempt(correctAnswers: sanitizedCorrect, totalQuestions: sanitizedTotal)
    }
}
