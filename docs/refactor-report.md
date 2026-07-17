# Refactor report

## Outcome

The refactor converted the repository from broad root-level `Models` and
`Services` buckets into feature-first ownership, split every oversized Swift
source and test file, and made state, routing, session, catalog, and persistence
boundaries explicit while simplifying the intended product flow: setup and
statistics stay inline on Home, and successful AI generation opens Quiz Play
directly.

| Metric | Baseline | Final |
| --- | ---: | ---: |
| Production Swift files | 44 | 87 |
| Test Swift files | 22 | 50 |
| Largest production file | 3,604 lines | 589 lines |
| Largest test file | 3,679 lines | 609 lines |
| Swift files above 700 lines | 13 | 0 |
| XCTest methods | 366 | 344 |

These counts come from the final integrated tree and Xcode target membership.
This pass intentionally removes the standalone Description/Statistics
controllers and their controller-only tests while retaining the shared inline
statistics presentation model.

## Structural changes

- Application lifecycle, composition, and navigation live in `App`.
- Reusable adapters and infrastructure live in `Core`.
- Framework-independent entities, policies, and ports live in `Domain`.
- Home owns quiz setup and inline statistics; AI Quiz, Quiz Play, Quiz Result,
  and Settings own their remaining feature code under `Features`.
- Tests mirror feature ownership, with shared harnesses in `Support` and rendered
  regression suites in `Snapshots`.
- Xcode groups and source-build membership match the physical tree.

## Architecture changes

- `QuizFlowCoordinator` remains the single navigation/composition boundary and
  now exposes narrow route protocols to each feature.
- The Question/Result flow remains MVP; the interaction-heavy Home screen uses
  `HomeFeatureStore` as its unidirectional state mutation boundary.
- Catalog description/question-count setup and statistics are expanded inline
  in Home. The obsolete standalone controllers and coordinator routes are gone.
- Successful AI generation updates the session and routes directly to Quiz Play,
  without a Description controller hop.
- `ThemeCatalogRepository` owns the durable localized catalog, while
  `QuizSessionStore` owns transient selection and quiz configuration.
- Shared statistics persistence lives in `Core/Persistence`, removing the former
  Core-to-Statistics-feature dependency.
- SwiftData records are private to `Core/Persistence` and map to plain domain
  models.
- Keychain access is behind `KeychainClient`, allowing entitlement-free tests.
- Shared reversible card-transition behavior is owned by
  `TwoSidedCardTransitionDriver` instead of being duplicated across cards.

## Correctness fixes found during refactoring

- Result routing now injects the coordinator's session instead of silently
  falling back to the global session.
- Home reset goes through the reducer/store and cancels in-flight effects.
- Catalog replacement invalidates transient session state through an explicit
  composition callback instead of a persistence-to-session dependency.
- Theme repositories expose catalog data as read-only at the feature protocol
  boundary.
- AI completion can no longer enter the removed Description route; it records
  quiz-start analytics and performs the same direct Question handoff as other
  immediate-start paths.

## Verification

- all 344 XCTest methods pass on the pinned iPhone 16e / iOS 26.2 simulator;
- six targeted compatibility smoke tests pass on iPhone 16 / iOS 18.6;
- the S01-S04 project verifiers pass, including the 700-line source guard,
  Xcode source membership, data preservation, snapshot markers, and the 80%
  application line-coverage gate (87.87% in the final run);
- all Swift sources pass frontend parsing, the project plist is valid, and the
  working diff has no whitespace errors.

## Deliberate follow-ups

`QuizFactory` remains a compatibility alias/forwarder for older tests and
previews. It can be removed after those callers use isolated repository and
session fixtures. Home still needs a dedicated interactor/effect runner to move
AI, restoration, and routing orchestration out of `QuizViewController`. The
dormant full-screen Description and Statistics routes are no longer follow-up
debt: they and their controller-only tests were removed in this pass.

The catalog database contains derived bundled data. A compatibility smoke test
confirmed that SwiftData opens the old `QuizTheme`/`QuizQuestion` schema after
the record rename, removes the obsolete records, and exposes an empty new store;
`ThemeCatalogRepository` then repopulates it because the catalog is empty even
when the content hash is unchanged. Promote that manual compatibility smoke to a
fixture-backed upgrade test before catalog data becomes user-authored or the
schema gains non-derived state.

The single XCTest target and mutable URL-loading test double are suitable later
build-time/parallelization improvements, but neither is an application
architecture blocker.

See [Architecture review](architecture-review.md) for the target model and
[SwiftUI migration assessment](swiftui-migration-assessment.md) for the UI
framework decision.
