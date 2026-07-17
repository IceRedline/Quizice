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
- linear-flow Quiz Play and Result view controllers own UIKit lifecycle/rendering and forward user intents to presenters or routes;
- presenters transform quiz/session data for the active Question/Result flow;
- feature stores/reducers own explicit state machines where interactions can be interrupted or reversed;
- repositories own durable catalog data;
- session stores own transient quiz selection and configuration;
- external-I/O services expose protocols at feature boundaries; small deterministic local stores may remain concrete;
- SwiftUI views receive service dependencies from the composition boundary; view-local preferences may still use `@AppStorage`.

This is intentionally not a forced conversion to one fashionable acronym. A reducer is a better fit for Home's reversible setup, inline statistics, and AI-request state, while the small linear Question/Result flow remains clear as MVP. Both styles share the same dependency and routing rules.

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
  QuizPlay
  QuizResult
  AIQuiz
  Settings
```

The dependency direction is `App -> Features -> Domain/Core`. `Domain` does not depend on UIKit, SwiftUI, SwiftData, GameKit, or concrete analytics/network implementations.

## State ownership

`HomeFeatureStore` is the single mutation boundary for `HomeThemeCardState` and `HomeAIThemeCardState`. UIKit extensions read state and send actions; they no longer invoke reducers directly. Rendering and animation remain in the view layer, while transition decisions remain deterministic and unit-testable.

Home owns both quiz setup and statistics presentation. Catalog descriptions and
question-count selection live on the expanded two-sided theme card. The compact
statistics card expands into `ExpandedStatisticsCardView` over the same Home
backdrop and collapses through the Home reducer. Neither flow has a dormant
coordinator route. Successful AI generation records the generated theme and
question count, emits quiz-start analytics, and hands off directly to Quiz Play.

`QuizSessionStore` owns the selected theme, requested question count, and startup flag. `ThemeCatalogRepository` owns localized catalog loading and SwiftData persistence. The `QuizFactory` type alias and forwarding conformance are compatibility shims for existing tests and previews; new feature code should inject `ThemeRepository` and `QuizSessionManaging` separately.

Domain quiz models no longer carry SwiftData annotations. `SwiftDataThemeStore`
owns private persistence records and maps them to domain objects, so persistence
schema decisions cannot leak into presenters, reducers, or feature views.

## File boundaries

The 700-line limit is a guardrail, not a target. A file should still be split earlier when it has multiple reasons to change. Large UIKit types use cohesive extensions such as Layout, Appearance, Actions, Presentation, and Transitions, while reusable behavior is extracted into collaborators whenever it has its own state or policy. A type is not considered small merely because its extensions live in separate files.

The verification script rejects any Swift source or test file above 700 lines.

## Testing boundaries

Tests are grouped next to feature ownership (`Features/<Feature>/Unit`, `UIContracts`, or `Tests` for Home's mixed interaction contracts) with shared harnesses in `QuiziceTests/Support`. Inline setup/statistics behavior is covered through Home reducer, interaction, collection, and transition contracts rather than retired standalone-controller suites. Snapshot suites remain in `Snapshots` because they are cross-feature artifacts tied to a fixed simulator/runtime.

The current test target deliberately mixes unit, UI-contract, and snapshot tests for now. A later build-time optimization may split those into separate targets, but doing so is not required for architectural correctness and would change CI/scheme behavior.

## Follow-up debt

The refactor preserves source compatibility, so some test and preview code still reaches `QuizFactory.shared`. Remove the compatibility shim only after those callers are migrated to isolated repositories and sessions.

Home is now split into bounded files and collaborators, with reducer-backed state, but `QuizViewController` still coordinates AI effects, restoration, and routing across its extensions. The next architecture step is a feature interactor/effect runner; it should be extracted behavior-by-behavior behind the existing regression suite rather than combined with a UI rewrite. Settings can similarly wrap its `@AppStorage` preferences in an injected store if non-view consumers appear.

The former standalone Description and Statistics controllers, routes, and their controller-only suites have been removed. The remaining mutable URL-loading test double should become instance-scoped before parallel test execution is enabled.

These are bounded follow-ups rather than reasons to rewrite the UI or introduce separate Swift packages prematurely. Package extraction becomes useful when a domain/core boundary has independent consumers or build benefits; folder boundaries are sufficient for the current application size.
