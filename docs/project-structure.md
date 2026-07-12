# Project structure

The project is being migrated incrementally to feature-first ownership. New files should follow this layout:

```text
Quizice/
  App/                         application and scene composition
  Core/
    Analytics/
    DesignSystem/
    Localization/
    Persistence/
  Domain/                      shared quiz models and rules
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

Dependency direction is `App -> Features -> Domain/Core`. Feature code must not reach through `QuizFactory.shared` when a dependency can be passed through an initializer. `QuizFactory` owns catalog loading and persistence; `QuizSessionStore` owns transient quiz selection and progress configuration. The compatibility forwarding properties on `QuizFactory` exist only while older tests and previews are migrated.

Files should move physically only together with their Xcode project references. Avoid large cosmetic moves in the same change as behavior changes; move one feature at a time so history and snapshot regressions remain reviewable.
