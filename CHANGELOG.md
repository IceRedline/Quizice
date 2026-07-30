# Changelog

All notable changes to Quizice are recorded here. Dates are in ISO-8601. The
project follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- Local `Configurations/Secrets.xcconfig` for `APPMETRICA_API_KEY` and
  `BACKEND_BASE_URL`; both are pulled through `Shared.xcconfig` and no longer
  live in `project.pbxproj`. A `.template` file is checked in for onboarding.
- `Info.plist` declares `ITSAppUsesNonExemptEncryption = false` so App Store
  submissions do not prompt for an encryption compliance answer.
- `PrivacyInfo.xcprivacy` declares AppMetrica-collected data types
  (ProductInteraction, CrashData, PerformanceData, OtherDiagnosticData) as
  not-linked, not-used-for-tracking.
- `BackendRetry.withExponentialBackoff` helper. Applied to statistics sync so
  transient network errors and 5xx responses no longer drop background writes.
- `CHANGELOG.md` (this file).

### Changed
- `QuizSessionStore` now serialises reads and writes through an `NSLock`.
  The transient quiz selection is accessed from the coordinator's async tasks
  and from UIKit callbacks; the previous unsynchronised storage risked data
  races when replay finished on a background executor.
- `ThemeCatalogRepository.refreshBackendCatalog` and
  `synchronizeThemePreferences` wrap post-await mutations in `MainActor.run`.
  This closes the crash where the backend continuation resumed off-main and
  the `onCatalogReplaced` callback mutated UI-observed state.
- `BackendAIQuizThemeService.requestTimeout` reduced from 90 s to 30 s. The
  previous value degraded UX and encouraged keep-alive drain.
- `BackendContentAPI` and `BackendAIQuizThemeService` refuse response bodies
  above 10 MB before JSON decoding, and reject non-JSON 200 responses (WAF
  or captive portal interception) instead of returning a decoding error.
- `GameCenterAuthenticationService` and `BackendAIQuizThemeService` now log
  Keychain failures via `AppLog.auth` instead of silently ignoring them with
  `try?`.
- `QuizQuestionPresenter` cancels its timer in `deinit`. Exiting a quiz mid
  question no longer leaves a repeating timer running until the interval
  elapses.
- `ThemeCatalogRepository` removes its localisation observer in `deinit`.
- `OnboardingPhysicsStage.layoutSubviews` skips scene rebuilds for sub-8pt
  changes, avoiding layout thrashing on rotation.
- Coordinator AI replay drops responses whose language no longer matches the
  active locale after generation completes, matching the existing behaviour
  of the catalog and random replay paths.
- Home theme card titles use `.byTruncatingTail` line break mode so long
  AI-generated names show an ellipsis instead of a silent cut.
- Test target bundle identifier corrected from `ru.avtabenskiy.QuiziceTests`
  to `ru.tabenskii.QuiziceTests`.
- `.swiftlint.yml` gained correctness (`force_cast`, `force_try`,
  `unused_optional_binding`, etc.) and style hygiene rules on top of the
  original six.

### Removed
- Dead localisation key `result.restart` from all six `.lproj/Localizable.strings`.

### Security
- Rotate any credentials that appeared in `project.pbxproj` before this
  release: they were committed publicly. AppMetrica keys and Yandex Cloud
  container URLs pulled from the old commits should be considered leaked.

## Notes for App Store submission
- Deployment target: iOS 18.0.
- Encryption exemption declared in `Info.plist`.
- AppMetrica 6.4.0 ships its own privacy manifest and no advertising or
  IDFA modules are linked; App Store Connect privacy answers should mirror
  the declarations in `PrivacyInfo.xcprivacy`.
- Game Center capability is required; guest mode still works for read-only
  play and bundled content, but AI generation refuses without a valid
  authenticated session.
