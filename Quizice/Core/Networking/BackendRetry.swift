import Foundation

// Small retry-with-backoff helper for backend operations that can afford to
// wait for a transient failure to clear. Intentionally minimal: no jitter
// tuning knobs, no per-error retry counts. Callers decide which errors are
// worth retrying via the `isRetryable` predicate. Errors flagged as
// non-retryable are re-thrown immediately, keeping unauthorized/contract
// failures on their fast path.
enum BackendRetry {
    static let defaultBaseDelay: UInt64 = 300_000_000
    static let defaultMaxAttempts = 3

    static func withExponentialBackoff<Value>(
        maxAttempts: Int = defaultMaxAttempts,
        baseDelay: UInt64 = defaultBaseDelay,
        isRetryable: (Error) -> Bool,
        operation: () async throws -> Value
    ) async throws -> Value {
        precondition(maxAttempts > 0, "maxAttempts must be positive")
        var attempt = 0
        while true {
            attempt += 1
            do {
                return try await operation()
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if attempt >= maxAttempts || !isRetryable(error) {
                    throw error
                }
                let delayNanoseconds = baseDelay << (attempt - 1)
                let jitter = UInt64.random(in: 0...(baseDelay / 4))
                try await Task.sleep(nanoseconds: delayNanoseconds + jitter)
                try Task.checkCancellation()
            }
        }
    }
}
