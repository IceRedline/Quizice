# Quizice 1.1 — iPad and multiple devices

UIKit continues to own navigation and interactive cards; the existing SwiftUI
surfaces remain hosted. Deployment target stays iOS/iPadOS 18. One scene supports
rotation, Split View and window resizing; opening multiple app windows and handing
off an unfinished round are outside this release.

## Layout

Use safe-area container width, never screen bounds or a device-model test.
Below 600 pt keep compact geometry; 600–899 pt uses three theme columns, 900+
uses four. Accessibility content sizes use one column. Home is centered within
1180 pt, expanded cards/results within 560 pt and questions within 640 pt on wide
windows (430 pt for compact cards). Short windows scroll without resetting a round.
Timer and Next remain accessible while question/answer content scrolls.

Resize settles a card transition at its requested logical endpoint. AI text,
requests and quiz state survive resizing. Floating keyboards only affect cards
when their rectangles intersect horizontally.

## Account data

Favorites are a single account-owned set across languages. The client uses
GET/PATCH /api/v2/me/favorites with stable mutation UUIDs and a persistent outbox;
there is no fallback to a full-list PUT. Statistics and answered-question progress
keep their existing idempotent event protocols. Language, appearance, audio and
repeat strategy remain device preferences.

Refresh on sign-in, foreground, return to Home, statistics opening and reconnect.
Visible cards update after synchronization. No continuous polling or live handoff.

The backend unions the six legacy locale sets once. Client migration displays the
union of local caches, but uploads only pending legacy choices as one additive
mutation. A newly completed guest selection is also additive. Old pending lists
have no baseline: their unconfirmed removals cannot be reconstructed, and migration
may restore a previously removed theme once. Clean old caches are never uploaded.
Old 1.0 clients retain full-replace behavior; conflict-safe merging requires 1.1
on both devices.

## Release sequence and acceptance

Deploy the AI concurrency fix and global favorites backend before distributing
1.1. Drain backend workers writing locale-only preferences before the one-time
union migration. Do not roll the backend back while v2 clients are in use.

CI includes iPad UI contracts, iPhone regression categories, visual snapshots and
Release compilation. New iPad images are under the ScreenSnapshotTests and
SwiftUISnapshotTests __Snapshots__ directories, named with ipad. They are review
images generated from deterministic sample data, not evidence of live Game Center.

Before App Store submission, exercise a physical iPhone and iPad with the same
Game Center account: independent sign-ins; concurrent rounds; offline favorites
and retry; Russian/English switches; visible refresh; account switch/deletion;
AI while the other device synchronizes. Check docked/floating/hardware keyboards,
rotation, short/narrow windows, VoiceOver, Dynamic Type and Reduce Motion. Capture
final App Store screenshots from the signed release build with production catalog.

Suggested release note (RU): «Quizice теперь поддерживает iPad. Играйте в удобном
окне, поворачивайте устройство и сохраняйте общий прогресс и избранные темы на
iPhone и iPad. Избранное теперь одинаковое на всех языках.»

Suggested release note (EN): “Quizice now supports iPad. Play in a resizable window
and keep your progress and favorite topics across iPhone and iPad. Favorites now
stay the same in every language.”

## Review stack and verified checks (2026-10-28)

Backend PRs are independent: [AI concurrency #39](https://github.com/tabenskii/Quizice-backend/pull/39)
and [global favorites #40](https://github.com/tabenskii/Quizice-backend/pull/40).
The six iOS PRs form a review stack, with each PR showing its own change:

1. [Layout policy #73](https://github.com/tabenskii/Quizice/pull/73) (plan PR 5).
2. [Home #74](https://github.com/tabenskii/Quizice/pull/74) (plan PR 6).
3. [Game and supporting screens #75](https://github.com/tabenskii/Quizice/pull/75) (plan PR 7).
4. [Favorites client #76](https://github.com/tabenskii/Quizice/pull/76) (plan PR 3).
5. [Account refresh #77](https://github.com/tabenskii/Quizice/pull/77) (plan PR 4).
6. [Universal target and release checks #78](https://github.com/tabenskii/Quizice/pull/78) (plan PR 8).

Merge/rebase in this order and retarget each following PR after its base is merged.
Deploy both backend changes before distributing the client. All PRs are drafts;
this implementation did not merge changes, deploy production or publish an app.

The final integrated source tree passed the following local checks:

| Check | Result |
|---|---|
| iOS unit category | 431 passed; 3 opt-in live backend tests skipped |
| UI category, iPad Pro 11 M4 / iOS 26.2 | 184 passed |
| UI category, iPhone SE 3 / iOS 26.2 | 184 passed |
| Snapshot category, iPhone 16e host / iOS 26.2 | 82 passed, including iPad fixtures |
| Combined app line coverage | 85.88%, above the existing 80% threshold |
| Static S01-S04 and Release simulator build | Passed |
| Backend unit/contract | 1,254 passed; 89.37% coverage |
| Global favorites PostgreSQL integration | 10 passed |
| Updated account-deletion PostgreSQL suite | 28 passed, including v1/v2 mutation races |

The three skipped client checks require `QUIZICE_RUN_LIVE_BACKEND_TESTS=1` and a
deployed backend. These results do not replace the physical-device and signed
App Store acceptance above. Final publishing version/build metadata and store
screenshots are set when preparing the signed release.
