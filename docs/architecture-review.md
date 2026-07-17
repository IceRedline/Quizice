# Architecture review

## Baseline

The project started as a flat UIKit application with most production files directly under `Quizice/`, plus broad `Models/` and `Services/` buckets. Screen construction and navigation already followed an MVP-style flow, but ownership was inconsistent:

- `QuizFlowCoordinator` owned most navigation;
- Description, Question, and Result used presenter protocols;
- Home mixed view layout, collection ownership, reducers, asynchronous AI work, motion, transition snapshots, and routing in one controller;
- Statistics loaded persistence directly;
- Settings was a standalone SwiftUI view;
- `QuizFactory` combined catalog persistence and transient quiz-session state;
- many dependencies were reached through `.shared` from presentation code.

Calling this codebase simply MVP, MVVM, or MVC would hide those differences. The most accurate baseline is **Coordinator + partial MVP + feature-local state reducers**.

## Target

Quizice now uses **Coordinator-led MVP with unidirectional state for interaction-heavy features**:

- the coordinator is the composition and navigation boundary;
- linear-flow view controllers own UIKit lifecycle/rendering and forward user intents to presenters or routes;
- presenters transform quiz/session data for the linear quiz flow;
- feature stores/reducers own explicit state machines where interactions can be interrupted or reversed;
- repositories own durable catalog data;
- session stores own transient quiz selection and configuration;
- external-I/O services expose protocols at feature boundaries; small deterministic local stores may remain concrete;
- SwiftUI views receive service dependencies from the composition boundary; view-local preferences may still use `@AppStorage`.

This is intentionally not a forced conversion to one fashionable acronym. A reducer is a better fit for Home's reversible card and AI-request state, while the small linear Description/Question/Result flow remains clear as MVP. Both styles share the same dependency and routing rules.

## Module ownership

```text
App
  Lifecycle        UIKit application/scene entry points
  Launch           launch overlay presentation
  Navigation       coordinator and route contracts
  Debug            debug-only environment configuration

Core
  Analytics        analytics ports and adapters
  Authentication   Game Center and secure-session adapters
  DesignSystem     appearance and reusable interaction primitives
  Localization     localization store and generated accessors
  Logging          subsystem loggers
  Persistence      catalog/statistics storage and SwiftData adapters
  Session          transient quiz session

Domain
  Quiz             quiz entities and policies
  Statistics       statistics value types
  Repositories     domain-facing repository protocols

Features
  Home
  QuizDescription
  QuizPlay
  QuizResult
  Statistics
  AIQuiz
  Settings
```

The dependency direction is `App -> Features -> Domain/Core`. `Domain` does not depend on UIKit, SwiftUI, SwiftData, GameKit, or concrete analytics/network implementations.

## State ownership

`HomeFeatureStore` is the single mutation boundary for `HomeThemeCardState` and `HomeAIThemeCardState`. UIKit extensions read state and send actions; they no longer invoke reducers directly. Rendering and animation remain in the view layer, while transition decisions remain deterministic and unit-testable.

`QuizSessionStore` owns the selected theme, requested question count, and startup flag. `ThemeCatalogRepository` owns localized catalog loading and SwiftData persistence. The `QuizFactory` type alias and forwarding conformance are compatibility shims for existing tests and previews; new feature code should inject `ThemeRepository` and `QuizSessionManaging` separately.

Domain quiz models no longer carry SwiftData annotations. `SwiftDataThemeStore`
owns private persistence records and maps them to domain objects, so persistence
schema decisions cannot leak into presenters, reducers, or feature views.

## File boundaries

The 700-line limit is a guardrail, not a target. A file should still be split earlier when it has multiple reasons to change. Large UIKit types use cohesive extensions such as Layout, Appearance, Actions, Presentation, and Transitions, while reusable behavior is extracted into collaborators whenever it has its own state or policy. A type is not considered small merely because its extensions live in separate files.

The verification script rejects any Swift source or test file above 700 lines.

## Testing boundaries

Tests are grouped next to feature ownership (`Features/<Feature>/Unit`, `UIContracts`, or `Tests` for Home's mixed interaction contracts) with shared harnesses in `QuiziceTests/Support`. Snapshot suites remain in `Snapshots` because they are cross-feature artifacts tied to a fixed simulator/runtime.

The current test target deliberately mixes unit, UI-contract, and snapshot tests for now. A later build-time optimization may split those into separate targets, but doing so is not required for architectural correctness and would change CI/scheme behavior.

## Follow-up debt

The refactor preserves source compatibility, so some test and preview code still reaches `QuizFactory.shared`. Remove the compatibility shim only after those callers are migrated to isolated repositories and sessions.

Home is now split into bounded files and collaborators, with reducer-backed state, but `QuizViewController` still coordinates AI effects, restoration, and routing across its extensions. The next architecture step is a feature interactor/effect runner; it should be extracted behavior-by-behavior behind the existing regression suite rather than combined with a UI rewrite. Settings can similarly wrap its `@AppStorage` preferences in an injected store if non-view consumers appear.

`StatisticsViewController` and its coordinator route are retained and tested, but the current Home experience presents inline expanded statistics instead of calling that full-screen route. Product design should either wire the full-screen variant intentionally or remove it as dormant code. The mutable URL-loading test double should also become instance-scoped before parallel test execution is enabled.

These are bounded follow-ups rather than reasons to rewrite the UI or introduce separate Swift packages prematurely. Package extraction becomes useful when a domain/core boundary has independent consumers or build benefits; folder boundaries are sufficient for the current application size.
