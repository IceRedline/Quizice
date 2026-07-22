# Analytics taxonomy

Quizice sends product analytics through `AnalyticsTracking`. Event payloads must use only the typed values defined in `AnalyticsService.swift`.

Privacy rules:

- Never send question text, answer text, the AI prompt, localized theme names, or generated AI theme identifiers.
- Catalog themes use `theme_source=catalog` and a stable `theme_id`.
- AI themes use only `theme_source=ai`.
- Unknown context uses `theme_source=unknown`.
- Counts, durations, and percentages are clamped to valid non-negative ranges.

| Event | Owner | Parameters |
| --- | --- | --- |
| `screen_view` | Logical screen or inline surface exposure | `screen`, theme context when relevant |
| `theme_selected` | Accepted theme selection and card expansion | `selection_method`, theme context |
| `theme_card_flipped` | Completed home theme-card flip | `visible_face` (`front` or `back`), theme context |
| `quiz_setup_cancelled` | Completed quiz setup dismissal | theme context |
| `quiz_started` | Quiz start transition | `question_count`, theme context |
| `quiz_answered` | `QuizQuestionPresenter` | `question_index`, `total_questions`, `outcome`, theme context |
| `quiz_exit_requested` | Question screen | progress counters, theme context |
| `quiz_exit_cancelled` | Question screen | progress counters, theme context |
| `quiz_abandoned` | Question screen | progress counters, theme context |
| `quiz_completed` | `QuizQuestionPresenter` | score counters, `score_percent`, theme context |
| `quiz_result_action` | Result screen | `action`, theme context |
| `statistics_viewed` | Expanded inline Home statistics card | aggregate counters only |
| `ai_generation_started` | AI generation feature | locale, prompt length, count, difficulty |
| `ai_generation_succeeded` | AI generation feature | locale, count, difficulty, duration |
| `ai_generation_failed` | AI generation feature | locale, normalized error code, duration |
| `ai_generation_cancelled` | AI generation feature | locale, duration |
| `backend_request_completed` | Backend client after transport, decoding, and contract validation | operation, normalized result, duration, response size, optional HTTP status class |
| `setting_changed` | Settings feature | typed setting name and old/new enum raw values |
| `settings_action` | Settings feature | typed `profile` or `feedback` action |

Answer and completion events are idempotent: a question can emit at most one `quiz_answered`, and an attempt can emit at most one `quiz_completed`.

`theme_card_flipped` is emitted only after the requested face becomes visible. `visible_face` describes the resulting face, not the animation direction. The first completed flip to `back` exposes the inline quiz-description surface; expanding the inline statistics card exposes the statistics surface. Neither surface is a standalone navigation destination. Card animation progress itself is not tracked.

On successful AI generation, event order is `ai_generation_succeeded`,
`theme_selected` with `theme_source=ai`, then `quiz_started`; the app routes
directly to Quiz Play. Do not emit an intermediate Description `screen_view`.
