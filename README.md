# Quizice

### Quiz-game

A quiz app where you can train answering questions on different topics. 

Flexibile and scalable: it can be easily adapted to any topic, be it school tests, interview preparation simulators or just entertaining quizzes.

The quiz includes themes:
- Music
- Tech
- Culture
- Politics

![Quizice Preview](https://github.com/user-attachments/assets/e84484ae-8833-4286-9b77-0fbf0b3b68fa)

> Swift, UIKit + SwiftUI, Coordinator-led MVP, unidirectional state, SwiftData

## Architecture

The source tree is organized by feature, with application composition in `App`,
shared infrastructure in `Core`, framework-independent models and contracts in
`Domain`, and screen ownership in `Features`. UIKit remains the navigation and
interaction shell; SwiftUI is used where declarative content has a clear size and
maintenance benefit.

- [Project structure](docs/project-structure.md)
- [Architecture review](docs/architecture-review.md)
- [Refactor report](docs/refactor-report.md)
- [SwiftUI migration assessment](docs/swiftui-migration-assessment.md)

## Yandex AppMetrica

The app uses AppMetrica 6.4.0 for product analytics, sessions, crashes, and
sanitized operational errors. Advertising attribution, IDFA, location, user
profiles, and automatic revenue tracking are disabled.

1. Register the iOS app in AppMetrica and copy its API key from
   **Settings → Main**.
2. In Xcode, select the `Quizice` target and open **Build Settings**.
3. Keep the user-defined `APPMETRICA_API_KEY` setting synchronized for Debug
   and Release so local sessions and production sessions reach the same app.

The value is substituted into the `AppMetricaAPIKey` entry in `Info.plist`.
An empty value or the placeholder leaves analytics disabled. XCTest and SwiftUI
Previews also skip SDK activation.

AppMetrica's verbose internal logging is disabled by default, including in
Debug builds. To troubleshoot the SDK itself, set the
`QUIZICE_APPMETRICA_VERBOSE_LOGS` environment variable to `1` in the Run scheme.
Normal Debug runs keep only Quizice's compact per-event log.

Events cover screen views, theme selection, quiz start/answers/timeouts/exit/
completion, result actions, statistics, AI generation, and settings changes.
Question text, answer text, AI prompts, localized error messages, and generated
AI theme IDs are never sent.

AppMetrica 6.4.0 provides its own Privacy Manifest. App Store Connect privacy
answers should still declare the diagnostics and other analytics data collected
by the SDK. Because `AppMetricaAdSupport` is not linked, the app does not use
AppMetrica cross-app tracking and does not request ATT permission.

## Production backend

The app reads `BackendBaseURL` from the `BACKEND_BASE_URL` build setting. Debug
can still opt into `http://localhost:8000/api` from the developer menu; normal
Debug and Release builds use the deployed HTTPS API.

Bundled localized quiz data remains the immediate offline fallback. The client
refreshes localized theme metadata in the background and requests a seeded
question batch when a quiz starts. Remote content is accepted only when the
backend echoes the requested locale and seed and the complete response passes
contract validation; otherwise the app starts from its bundled question pool.

AI generation always goes through the backend. It requires a valid Game Center
session and sends the bearer token stored in Keychain; guests never call the AI
provider. Provider credentials must remain server-side. The required server
contract, rollout order, tests, and performance targets are documented in
[`docs/backend-production-readiness-plan.md`](docs/backend-production-readiness-plan.md).

`LiveBackendContractTests` are opt-in so ordinary unit-test runs never depend on
the network. Set `QUIZICE_RUN_LIVE_BACKEND_TESTS=1` in the test scheme to run
them. The latency smoke reports first/median/p95/max timings without using an
unstable developer connection as a release threshold; the two `testFuture...`
cases are rollout gates for the new response envelopes and guest AI `401`.
