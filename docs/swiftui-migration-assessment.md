# SwiftUI migration assessment

## Decision

Do not rewrite Quizice wholesale. Keep the UIKit navigation and interactive-transition shell, then migrate leaf content to SwiftUI only where the replacement removes stateful layout code without weakening gestures, animation continuity, accessibility, or snapshot coverage.

The deployment target is iOS 18, so framework availability is not a constraint. The main constraint is behavioral parity: Home uses custom collection layouts, interruptible transitions, keyboard choreography, parallax/Core Motion, and two-sided card interactions that are already expressed directly in UIKit.

## What the size numbers mean

At the start of the refactor, presentation code accounted for approximately 14,232 of 18,503 production lines (about 77%). The Home cluster alone accounted for about 9,444 production lines; together with its 5,116 test lines, that area was approximately 14,560 lines. The reported "around 15,000 lines" cost of the redesigned home experience is therefore consistent with the repository.

This does not mean UIKit inherently requires 15,000 lines. The original Home implementation combined too many concerns:

- collection data source and layout;
- reducer/state transitions;
- AI request workflow and keyboard state;
- source-view snapshots and transition geometry;
- expanded-card content, appearance, and interactions;
- Core Motion/parallax behavior;
- restoration, analytics, routing, and accessibility.

Splitting those responsibilities reduces complexity regardless of rendering framework.

## Keep in UIKit

- the app coordinator and modal/navigation ownership;
- the Home collection shell and custom card layout;
- interactive and interruptible card transitions;
- gesture arbitration, rapid reversal, and transition cancellation;
- Core Motion/parallax integration;
- custom transitioning delegates and snapshot carriers.

These are the parts where UIKit exposes the behavior most directly and where the existing regression suite is strongest.

## Good SwiftUI candidates

Migrate in this order, measuring each step:

1. Result content: mostly declarative, low gesture risk.
2. Inline statistics rows and expanded theme-description content, hosted inside the existing UIKit transition carriers.
3. Other expanded-card inner content after the shared carrier boundary is stable.
4. Settings: already implemented in SwiftUI; keep it as the reference integration.
5. Home only as a separate prototype after the state store and effect boundaries are stable.

There are no standalone Description or Statistics screens left to migrate. A
leaf migration must preserve Home's inline expansion/collapse ownership, and AI
success must continue to route directly to Quiz Play without introducing an
intermediate setup screen.

The Quiz Question screen is a possible later candidate, but only after typography fitting, answer feedback timing, and accessibility contracts are preserved behind framework-independent collaborators.

## Acceptance gates for each migration

A SwiftUI replacement should ship only when it satisfies all of these gates:

- existing reducer and presenter tests remain unchanged;
- visual snapshots are intentionally re-recorded and reviewed, not silently updated;
- VoiceOver order, labels, Dynamic Type, contrast, and Reduce Motion behavior match or improve;
- interactive transitions remain interruptible and reversible;
- no new duplicated navigation or business state is introduced in a view;
- Instruments measurements show no material regression in launch, scrolling, animation hitches, memory, or energy use;
- the resulting implementation is materially smaller or easier to change.

## Prototype plan for Home

If a full SwiftUI Home is still desired, build it as a time-boxed prototype rather than replacing production code immediately. Feed it the same `HomeFeatureStore`, repository interfaces, and coordinator routes. Compare it with the UIKit implementation using the same fixtures and scenarios: normal setup expansion, inline statistics, direct AI-to-question handoff, AI prompt/keyboard, Reduce Motion, rapid reversal, restoration, and low-memory behavior.

Adopt it only if the prototype passes behavioral parity and performance gates. Otherwise, retain the hybrid approach: UIKit owns spatial interaction and SwiftUI owns declarative card content.
