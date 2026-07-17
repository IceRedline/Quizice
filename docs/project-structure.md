# Project structure

Quizice uses feature-first ownership. Production files follow this layout:

```text
Quizice/
  App/                         application and scene composition
  Core/
    Analytics/
    Authentication/
    DesignSystem/
    Logging/
    Localization/
    Persistence/
    Session/
  Domain/                      framework-independent models, rules, and ports
  Features/
    Home/
    QuizDescription/
    QuizPlay/
    QuizResult/
    Statistics/
    AIQuiz/
    Settings/
  Resources/
```

Tests mirror feature ownership under `QuiziceTests/Features`; shared harnesses live
in `QuiziceTests/Support`, and cross-feature rendered artifacts stay in
`QuiziceTests/Snapshots`.

Dependency direction is `App -> Features -> Domain/Core`. `Domain` has no UIKit,
SwiftUI, SwiftData, GameKit, analytics-SDK, or networking imports. Persistent
SwiftData records are mapped to domain models inside `Core/Persistence`.

Feature code should receive repository, session, analytics, and routing ports from
the application composition boundary. Default live dependencies remain available
for UIKit previews and source compatibility, but state ownership is split:
`ThemeCatalogRepository` owns the durable catalog and `QuizSessionStore` owns the
transient quiz selection and configuration. `QuizFactory` is now only a temporary
compatibility alias/forwarder.

Every physical move must be reflected in the Xcode project. Swift files are capped
at 700 lines by the S04 verifier; the limit is a guardrail, and files should split
earlier whenever they gain multiple reasons to change.
