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

Events cover screen views, theme selection, quiz start/answers/timeouts/exit/
completion, result actions, statistics, AI generation, and settings changes.
Question text, answer text, AI prompts, localized error messages, and generated
AI theme IDs are never sent.

AppMetrica 6.4.0 provides its own Privacy Manifest. App Store Connect privacy
answers should still declare the diagnostics and other analytics data collected
by the SDK. Because `AppMetricaAdSupport` is not linked, the app does not use
AppMetrica cross-app tracking and does not request ATT permission.

## Yandex AI Studio (Debug only)

The AI quiz generator calls the saved Yandex AI Studio agent only in Debug builds.

1. In Agent Atelier, set the agent response format to JSON Schema using
   [`docs/yandex-ai-quiz-schema.json`](docs/yandex-ai-quiz-schema.json).
   Use [`docs/yandex-ai-quiz-prompt.md`](docs/yandex-ai-quiz-prompt.md) as the
   agent instruction prompt.
   The agent input is a JSON string with `theme`, `locale`, `questionCount`, and
   `difficulty`. Supported question counts are 5, 10, and 15. Difficulty values
   are `easy` (common facts and direct wording), `medium` (moderate knowledge and
   plausible distractors), and `hard` (specialized details without trick
   questions). A successful response uses `status: "success"` and returns exactly
   `questionCount` questions. A policy refusal uses `status: "refused"`, a safe
   diagnostic `message`, empty theme fields, and an empty `questions` array.
2. [Create an AI Studio API key](https://aistudio.yandex.ru/docs/ru/ai-studio/operations/get-api-key.html)
   and keep it outside the repository.
3. In Xcode, open **Product → Scheme → Manage Schemes…**, duplicate `Quizice`
   as `Quizice Local`, and make sure the duplicate is not shared. Its file will
   live under the git-ignored `xcuserdata` directory.
4. Edit the local scheme, open **Run → Arguments**, and add the enabled
   environment variable `YANDEX_AI_API_KEY` with the API-key secret as its value.

The first Debug launch reads the key from the Xcode environment and stores it in
the device Keychain, so later Debug launches work without Xcode. The key is never
stored in source control. Release builds do not perform direct AI Studio calls;
use an authenticated backend proxy before enabling this feature in production.
