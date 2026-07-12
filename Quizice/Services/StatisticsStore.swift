//
//  StatisticsStore.swift
//  Quizice
//
//  Created by GSD on 03.07.2026.
//

import Foundation

extension Notification.Name {
    static let statisticsPendingSync = Notification.Name("quizice.statistics.pending-sync")
}

final class StatisticsStore {
    struct Attempt: Codable, Equatable {
        let correctAnswers: Int
        let totalQuestions: Int

        init(correctAnswers: Int, totalQuestions: Int) {
            self.correctAnswers = correctAnswers
            self.totalQuestions = totalQuestions
        }
    }

    struct PendingAttempt: Codable, Equatable {
        let id: String
        let correctAnswers: Int
        let totalQuestions: Int
        let completedAt: Date
    }

    struct SyncRequest: Codable, Equatable {
        let migrationId: String
        let legacySummary: StatisticsSummary?
        let attempts: [PendingAttempt]
    }

    struct SyncResponse: Codable, Equatable {
        let summary: StatisticsSummary
        let acceptedAttemptIds: [String]
        let legacySummaryAccepted: Bool
    }

    private struct PersistedSummary: Codable {
        let playedQuizzes: Int
        let correctAnswers: Int
        let totalQuestions: Int
        let bestCorrectAnswers: Int
        let bestTotalQuestions: Int

        var summary: StatisticsSummary {
            StatisticsSummary(
                playedQuizzes: max(playedQuizzes, 0),
                correctAnswers: max(correctAnswers, 0),
                totalQuestions: max(totalQuestions, 0),
                bestCorrectAnswers: max(bestCorrectAnswers, 0),
                bestTotalQuestions: max(bestTotalQuestions, 0)
            )
        }
    }

    private struct PersistedState: Codable {
        var baseline: StatisticsSummary
        var pendingAttempts: [PendingAttempt]
        var legacySummary: StatisticsSummary?
        var migrationId: String

        static func empty(migrationId: String) -> PersistedState {
            PersistedState(
                baseline: .empty,
                pendingAttempts: [],
                legacySummary: nil,
                migrationId: migrationId
            )
        }

        var hasLocalContent: Bool {
            baseline != .empty || legacySummary != nil || pendingAttempts.isEmpty == false
        }
    }

    private let userDefaults: UserDefaults
    private let key: String
    private let notificationCenter: NotificationCenter
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let idGenerator: () -> String
    private let dateProvider: () -> Date

    private var activePrincipalKey: String { "\(key).active-user" }

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "quizice.statistics.attempts",
        notificationCenter: NotificationCenter = .default,
        idGenerator: @escaping () -> String = { UUID().uuidString },
        dateProvider: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.key = key
        self.notificationCenter = notificationCenter
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    func recordAttempt(correctAnswers: Int, totalQuestions: Int) {
        guard let attempt = Self.sanitizedAttempt(
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions
        ) else {
            return
        }

        let principal = activeUserID
        var state = loadState(for: principal)
        state.pendingAttempts.append(
            PendingAttempt(
                id: idGenerator(),
                correctAnswers: attempt.correctAnswers,
                totalQuestions: attempt.totalQuestions,
                completedAt: dateProvider()
            )
        )
        save(state: state, for: principal)
        notificationCenter.post(name: .statisticsPendingSync, object: nil)
    }

    func loadSummary() -> StatisticsSummary {
        Self.visibleSummary(for: loadState(for: activeUserID))
    }

    /// Moves the local guest outbox into the authenticated user's isolated cache.
    /// Existing caches belonging to other users remain untouched.
    func activateAuthenticatedUser(_ userID: String) {
        let normalizedUserID = userID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedUserID.isEmpty == false else { return }

        var userState = loadState(for: normalizedUserID)
        let guestState = loadState(for: nil)
        if guestState.hasLocalContent {
            userState.pendingAttempts = Self.uniqueAttempts(
                userState.pendingAttempts + guestState.pendingAttempts
            )
            if let guestLegacy = guestState.legacySummary {
                if let existingLegacy = userState.legacySummary {
                    userState.legacySummary = Self.merging(existingLegacy, guestLegacy)
                } else {
                    userState.legacySummary = guestLegacy
                    userState.migrationId = guestState.migrationId
                }
            }
            save(state: userState, for: normalizedUserID)
            save(state: .empty(migrationId: idGenerator()), for: nil)
        }

        userDefaults.set(normalizedUserID, forKey: activePrincipalKey)
    }

    func activateGuest() {
        userDefaults.removeObject(forKey: activePrincipalKey)
    }

    func makeSyncRequest(for userID: String) -> SyncRequest {
        let state = loadState(for: userID)
        return SyncRequest(
            migrationId: state.migrationId,
            legacySummary: state.legacySummary,
            attempts: state.pendingAttempts
        )
    }

    func hasPendingSync(for userID: String) -> Bool {
        let state = loadState(for: userID)
        return state.legacySummary != nil || state.pendingAttempts.isEmpty == false
    }

    func applySyncResponse(_ response: SyncResponse, for userID: String) {
        var state = loadState(for: userID)
        let acceptedIDs = Set(response.acceptedAttemptIds)
        state.baseline = response.summary
        state.pendingAttempts.removeAll { acceptedIDs.contains($0.id) }
        if response.legacySummaryAccepted {
            state.legacySummary = nil
        }
        save(state: state, for: userID)
    }

    static func summary(from attempts: [Attempt]) -> StatisticsSummary {
        let sanitizedAttempts = attempts.compactMap {
            sanitizedAttempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions)
        }

        guard sanitizedAttempts.isEmpty == false else { return .empty }

        let playedQuizzes = sanitizedAttempts.count
        let correctAnswers = sanitizedAttempts.reduce(0) { $0 + $1.correctAnswers }
        let totalQuestions = sanitizedAttempts.reduce(0) { $0 + $1.totalQuestions }
        let bestAttempt = sanitizedAttempts.max(by: isWorseAttempt)

        return StatisticsSummary(
            playedQuizzes: playedQuizzes,
            correctAnswers: correctAnswers,
            totalQuestions: totalQuestions,
            bestCorrectAnswers: bestAttempt?.correctAnswers ?? 0,
            bestTotalQuestions: bestAttempt?.totalQuestions ?? 0
        )
    }

    private var activeUserID: String? {
        guard let value = userDefaults.string(forKey: activePrincipalKey), value.isEmpty == false else {
            return nil
        }
        return value
    }

    private func storageKey(for userID: String?) -> String {
        guard let userID else { return key }
        let encoded = Data(userID.utf8)
            .base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return "\(key).user.\(encoded)"
    }

    private func loadState(for userID: String?) -> PersistedState {
        let storageKey = storageKey(for: userID)
        guard let data = userDefaults.data(forKey: storageKey) else {
            return .empty(migrationId: idGenerator())
        }

        if let state = try? decoder.decode(PersistedState.self, from: data) {
            return state
        }

        // Only the guest key can contain formats written by previous app versions.
        if userID == nil, let persisted = try? decoder.decode(PersistedSummary.self, from: data) {
            let state = PersistedState(
                baseline: .empty,
                pendingAttempts: [],
                legacySummary: persisted.summary,
                migrationId: idGenerator()
            )
            save(state: state, for: nil)
            return state
        }
        if userID == nil, let legacyAttempts = try? decoder.decode([Attempt].self, from: data) {
            let state = PersistedState(
                baseline: .empty,
                pendingAttempts: [],
                legacySummary: Self.summary(from: legacyAttempts),
                migrationId: idGenerator()
            )
            save(state: state, for: nil)
            return state
        }

        userDefaults.removeObject(forKey: storageKey)
        return .empty(migrationId: idGenerator())
    }

    private func save(state: PersistedState, for userID: String?) {
        let storageKey = storageKey(for: userID)
        guard state.hasLocalContent else {
            userDefaults.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? encoder.encode(state) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func visibleSummary(for state: PersistedState) -> StatisticsSummary {
        let pendingSummary = summary(
            from: state.pendingAttempts.map {
                Attempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions)
            }
        )
        var result = merging(state.baseline, pendingSummary)
        if let legacySummary = state.legacySummary {
            result = merging(result, legacySummary)
        }
        return result
    }

    private static func merging(_ lhs: StatisticsSummary, _ rhs: StatisticsSummary) -> StatisticsSummary {
        let best = [
            Attempt(correctAnswers: lhs.bestCorrectAnswers, totalQuestions: lhs.bestTotalQuestions),
            Attempt(correctAnswers: rhs.bestCorrectAnswers, totalQuestions: rhs.bestTotalQuestions)
        ]
            .compactMap { sanitizedAttempt(correctAnswers: $0.correctAnswers, totalQuestions: $0.totalQuestions) }
            .max(by: isWorseAttempt)

        return StatisticsSummary(
            playedQuizzes: lhs.playedQuizzes + rhs.playedQuizzes,
            correctAnswers: lhs.correctAnswers + rhs.correctAnswers,
            totalQuestions: lhs.totalQuestions + rhs.totalQuestions,
            bestCorrectAnswers: best?.correctAnswers ?? 0,
            bestTotalQuestions: best?.totalQuestions ?? 0
        )
    }

    private static func uniqueAttempts(_ attempts: [PendingAttempt]) -> [PendingAttempt] {
        var seen = Set<String>()
        return attempts.filter { seen.insert($0.id).inserted }
    }

    private static func isWorseAttempt(_ lhs: Attempt, _ rhs: Attempt) -> Bool {
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

    private static func sanitizedAttempt(correctAnswers: Int, totalQuestions: Int) -> Attempt? {
        guard totalQuestions > 0 else { return nil }
        let sanitizedTotal = max(totalQuestions, 0)
        let sanitizedCorrect = min(max(correctAnswers, 0), sanitizedTotal)
        return Attempt(correctAnswers: sanitizedCorrect, totalQuestions: sanitizedTotal)
    }
}
