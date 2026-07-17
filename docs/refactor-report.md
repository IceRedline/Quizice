# Refactor report

## Outcome

The refactor converted the repository from broad root-level `Models` and
`Services` buckets into feature-first ownership, split every oversized Swift
source and test file, and made state, routing, session, catalog, and persistence
boundaries explicit without changing the product flow.

| Metric | Baseline | Final |
| --- | ---: | ---: |
| Production Swift files | 44 | 94 |
| Test Swift files | 22 | 53 |
| Largest production file | 3,604 lines | 589 lines |
| Largest test file | 3,679 lines | 635 lines |
| Swift files above 700 lines | 13 | 0 |
| XCTest cases | 366 | 367 |

The production line count is intentionally almost unchanged: the work removed
monolithic ownership rather than hiding complexity by deleting behavior. New
collaborators and protocols add a small amount of boundary code while making
individual files and responsibilities substantially smaller.

## Structural changes

- Application lifecycle, composition, and navigation live in `App`.
- Reusable adapters and infrastructure live in `Core`.
- Framework-independent entities, policies, and ports live in `Domain`.
- Home, AI Quiz, Quiz Description, Quiz Play, Quiz Result, Settings, and
  Statistics own their code under `Features`.
- Tests mirror feature ownership, with shared harnesses in `Support` and rendered
  regression suites in `Snapshots`.
- Xcode groups and source-build membership match the physical tree.

## Architecture changes

- `QuizFlowCoordinator` remains the single navigation/composition boundary and
  now exposes narrow route protocols to each feature.
- The linear quiz flow remains MVP; the interaction-heavy Home screen uses
  `HomeFeatureStore` as its unidirectional state mutation boundary.
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

## Verification

- all 367 XCTest cases pass on the pinned iPhone 16e / iOS 26.2 simulator;
- all 6 targeted iOS 18.6 smoke tests pass on iPhone 16;
- the S01-S04 project verifiers pass, including the 700-line source guard,
  Xcode source membership, data preservation, snapshot markers, and the 80%
  application line-coverage gate (87.98% in the final run);
- all Swift sources pass frontend parsing, the project plist is valid, and the
  working diff has no whitespace errors.

## Deliberate follow-ups

`QuizFactory` remains a compatibility alias/forwarder for older tests and
previews. It can be removed after those callers use isolated repository and
session fixtures. Home still needs a dedicated interactor/effect runner to move
AI, restoration, and routing orchestration out of `QuizViewController`. The
full-screen Statistics route is tested but dormant because Home currently uses
an inline statistics card; product design should either wire or remove it.

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
