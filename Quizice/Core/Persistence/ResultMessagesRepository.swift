import CryptoKit
import Foundation

final class ResultMessagesRepository: ResultMessageProviding, @unchecked Sendable {
    static let shared = ResultMessagesRepository.live()
    static let freshnessInterval: TimeInterval = 86_400

    private struct CacheEntry: Codable {
        let catalog: BackendResultMessagesResponse
        let etag: String?
        let checkedAt: Date
    }

    private let api: ResultMessagesAPI?
    private let directory: URL
    private let now: () -> Date
    private let lock = NSLock()
    private var entries: [String: CacheEntry] = [:]
    private var loadedLocales: Set<String> = []
    private var inFlight: [String: Task<Void, Never>] = [:]
    private var lastMessages: [String: String] = [:]
    private var localizationObserver: NSObjectProtocol?

    init(api: ResultMessagesAPI?, directory: URL, now: @escaping () -> Date = Date.init) {
        self.api = api
        self.directory = directory
        self.now = now
    }

    deinit {
        if let localizationObserver { NotificationCenter.default.removeObserver(localizationObserver) }
    }

    static func live() -> ResultMessagesRepository {
        let isTesting = NSClassFromString("XCTestCase") != nil
            || ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        let configuration = isTesting ? nil : BackendConfiguration.load()
        let scope = SHA256.hash(data: Data((configuration?.baseURL.absoluteString ?? "local").utf8))
            .map { String(format: "%02x", $0) }.joined()
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return ResultMessagesRepository(
            api: configuration.map { HTTPResultMessagesAPI(configuration: $0) },
            directory: directory.appendingPathComponent("Quizice/result-messages/\(scope)", isDirectory: true)
        )
    }

    /// Called once by application composition, independently of launch preparation and authentication.
    func start() {
        if localizationObserver == nil {
            localizationObserver = NotificationCenter.default.addObserver(
                forName: .appLocalizationDidChange, object: nil, queue: .main
            ) { [weak self] _ in self?.refreshInBackground() }
        }
        refreshInBackground()
    }

    func refreshInBackground() {
        let locale = AppLocalizationStore.shared.resolvedLanguageCode
        Task { await refreshIfNeeded(locale: locale) }
    }

    func refreshIfNeeded(locale identifier: String) async {
        let locale = Self.normalizedLocale(identifier)
        let task: Task<Void, Never>? = lock.withLock {
            if let task = inFlight[locale] { return task }
            let entry = entryLocked(locale: locale)
            if let entry, now().timeIntervalSince(entry.checkedAt) < Self.freshnessInterval { return nil }
            guard let api else { return nil }
            let task = Task {
                await self.refresh(locale: locale, entry: entry, api: api)
                self.lock.withLock { self.inFlight[locale] = nil }
            }
            inFlight[locale] = task
            return task
        }
        await task?.value
    }

    func message(for category: ResultMessageCategory, locale identifier: String) -> String? {
        let locale = Self.normalizedLocale(identifier)
        return lock.withLock {
            guard let phrases = entryLocked(locale: locale)?.catalog.messages[category.rawValue],
                  !phrases.isEmpty else { return nil }
            let key = "\(locale).\(category.rawValue)"
            let candidates = phrases.count > 1 ? phrases.filter { $0 != lastMessages[key] } : phrases
            let phrase = candidates.randomElement()
            lastMessages[key] = phrase
            return phrase
        }
    }

    private func refresh(locale: String, entry: CacheEntry?, api: ResultMessagesAPI) async {
        do {
            var response = try await api.fetchResultMessages(locale: locale, etag: entry?.etag)
            if case .notModified = response, entry == nil {
                response = try await api.fetchResultMessages(locale: locale, etag: nil)
            }
            let updated: CacheEntry
            switch response {
            case let .modified(catalog, etag):
                guard catalog.locale == locale, !catalog.usableMessages.isEmpty else { return }
                updated = CacheEntry(
                    catalog: BackendResultMessagesResponse(locale: locale, messages: catalog.usableMessages),
                    etag: etag, checkedAt: now()
                )
            case let .notModified(etag):
                guard let entry else { return }
                updated = CacheEntry(catalog: entry.catalog, etag: etag ?? entry.etag, checkedAt: now())
            }
            lock.withLock {
                entries[locale] = updated
                do {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                    try JSONEncoder().encode(updated).write(to: fileURL(locale: locale), options: .atomic)
                } catch {
                    AppLog.persistence.error("Result messages cache persistence failed")
                }
            }
        } catch {
            // Keep stale same-language content. The presenter supplies bundled text if unavailable.
        }
    }

    private func entryLocked(locale: String) -> CacheEntry? {
        if loadedLocales.insert(locale).inserted,
           let data = try? Data(contentsOf: fileURL(locale: locale)),
           let entry = try? JSONDecoder().decode(CacheEntry.self, from: data),
           entry.catalog.locale == locale, !entry.catalog.usableMessages.isEmpty {
            entries[locale] = CacheEntry(
                catalog: BackendResultMessagesResponse(locale: locale, messages: entry.catalog.usableMessages),
                etag: entry.etag, checkedAt: entry.checkedAt
            )
        }
        return entries[locale]
    }

    private func fileURL(locale: String) -> URL {
        directory.appendingPathComponent("\(locale).json")
    }

    private static func normalizedLocale(_ identifier: String) -> String {
        AppLocalizationStore.resolveSystemLanguageCode(preferredLanguages: [identifier])
    }
}
