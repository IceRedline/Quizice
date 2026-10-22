# Quizice

### Quiz-game

A quiz app where you can train answering questions on different topics. 

Flexibile and scalable: it can be easily adapted to any topic, be it school tests, interview preparation simulators or just entertaining quizzes.

The quiz includes themes:
- Music
- Tech
- Culture
- Politics

<img width="2400" height="1300" alt="2400x1300" src="https://github.com/user-attachments/assets/d5ffd122-5723-430f-94a1-2d731f02bed4" />


> Swift, UIKit + SwiftUI, Coordinator-led MVP, unidirectional state, SwiftData

## App reference

[Как работает приложение](docs/app-reference.md) — сценарии, источники данных,
API, хранение и синхронизация, текущие ограничения и отдельный раздел
[отличий Debug](docs/app-reference.md#отличия-debug).

## SwiftLint

SwiftLint is integrated as an SPM build-tool plugin for both `Quizice` and
`QuiziceTests`. The shared rules live in `.swiftlint.yml` and run automatically
when either target is built. On first use, Xcode may ask you to trust and enable
the `SwiftLintBuildToolPlugin`.

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

## Build secrets

Credentials that must not appear in source control live in
`Configurations/Secrets.xcconfig`, which is git-ignored. Copy the template on
first checkout:

```bash
cp Configurations/Secrets.xcconfig.template Configurations/Secrets.xcconfig
# then fill in APPMETRICA_API_KEY and BACKEND_BASE_URL
```

Debug builds allow both variables to be empty: analytics stays disabled and the
client uses bundled catalog data. Release builds require `BACKEND_BASE_URL`
to be an HTTPS backend URL ending in `/api`, without credentials, query or
fragment. A build phase rejects missing, malformed and local backend addresses;
it does not contact the server. `APPMETRICA_API_KEY` remains optional.
In an xcconfig file, write the URL as `https:/$()/backend.example.com/api` so
the double slash is not parsed as a comment.

`Configurations/Shared.xcconfig` is the base configuration for the app target
and pulls in `Secrets.xcconfig` via an optional include; the project's build
settings no longer carry those values directly.

## Yandex AppMetrica

The app uses AppMetrica 6.4.0 for product analytics, sessions, crashes, and
sanitized operational errors. Advertising attribution, IDFA, location, user
profiles, and automatic revenue tracking are disabled.

1. Register the iOS app in AppMetrica and copy its API key from
   **Settings → Main**.
2. Paste the value into `APPMETRICA_API_KEY` in
   `Configurations/Secrets.xcconfig` (see **Build secrets** above).
3. Keep the same value for Debug and Release so local sessions and production
   sessions reach the same app.

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
AI theme IDs are never sent to analytics. The backend separately receives the
authenticated user ID, quiz progress and selected answers, and the AI prompt
when the user requests a generated quiz, to provide those features.

AppMetrica 6.4.0 provides its own Privacy Manifest. App Store Connect privacy
answers should still declare the diagnostics and other analytics data collected
by the SDK, as well as the linked user ID, gameplay content and other user
content sent to the backend for app functionality. The bundled privacy manifest
declares these backend data categories; App Store Connect privacy answers and
the published privacy policy need to be reviewed separately before release.
Because `AppMetricaAdSupport` is not linked, the app does not use
AppMetrica cross-app tracking and does not request ATT permission.

## Production backend

The app reads `BackendBaseURL` from the `BACKEND_BASE_URL` build setting,
which comes from `Configurations/Secrets.xcconfig` (see **Build secrets**).
Debug can still opt into `http://localhost:8000/api` from the developer menu;
normal Debug and Release builds use the deployed HTTPS API.

The client initially loads a matching cached backend catalog or bundled localized
data, then refreshes theme metadata during launch preparation. In backend catalog
mode, starting a quiz requests a seeded question batch and requires a valid
response; a failed request does not fall back to bundled questions. Cached
backend metadata alone does not make quizzes available offline. See the
[app reference](docs/app-reference.md#каталог-и-offline) for the exact loading rules.

Release AI generation goes through the backend. It requires a valid backend
session obtained through Game Center and sends the bearer token stored in
Keychain. Debug Simulator uses the direct AI service; Debug on a device can opt
into it with a local key (see [Debug differences](docs/app-reference.md#отличия-debug)).
Production provider credentials remain server-side. The required server
contract, rollout order, tests, and performance targets are documented in
[`docs/backend-production-readiness-plan.md`](docs/backend-production-readiness-plan.md).

`LiveBackendContractTests` are opt-in so ordinary unit-test runs never depend on
the network. Set `QUIZICE_RUN_LIVE_BACKEND_TESTS=1` in the test scheme to run
them. The latency smoke reports first/median/p95/max timings without using an
unstable developer connection as a release threshold. Set `QUIZICE_LIVE_BACKEND_URL`
to an alternate API base URL ending in `/api`; health and readiness then use
that same origin. Invalid overrides fail instead of falling back to production.
The two `testFuture...`
cases are rollout gates for the new response envelopes and guest AI `401`.

CI also compiles Release with a reserved, non-routable example backend URL to
exercise the production build path without service credentials or network probes.
Validate the configuration gate locally with
`python3 scripts/tests/test-release-configuration.py`.
