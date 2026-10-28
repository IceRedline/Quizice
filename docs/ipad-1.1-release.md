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
