# Backend: Accessibility Mode — план работ

## Контекст

Клиент iOS (Quizice) уже поддерживает Accessibility Mode. При активной ассистивной технологии (VoiceOver или Switch Control) в момент начала квиза юзер получает игру без таймера — 20-секундный отсчёт на вопрос отключается, ответ можно выбирать в любом темпе.

Каждая завершённая попытка помечается флагом `accessibilityMode: Bool` на клиенте и отправляется в существующем эндпойнте **`POST /v1/me/statistics/sync`**. Клиент прошился forward-compatible: если бэк отбрасывает или игнорирует новое поле, клиент не ломается — но и раздельного лидерборда для a11y-игроков не появится (все попытки продолжают попадать в один общий).

**Задача бэка:** принять поле, сохранить per-attempt, и разделить лидерборды/статистику на два трека — обычный и accessibility.

**Продуктовый смысл раздельного зачёта:** игра без таймера даёт неограниченное время на ответ — соревноваться в общем лидерборде с игроками с таймером было бы нечестно. Отдельный трек — способ дать доступную игру без «сливания» рейтингов.

## Что уже сделано на клиенте (ссылки для сверки контракта)

Если нужно посмотреть точный код клиента:

- `Quizice/Core/Persistence/StatisticsStore.swift` — структуры `PendingAttempt`, `SyncRequest`, `SyncResponse`
- `Quizice/Core/Authentication/HTTPAuthAPI.swift` — вызов `POST /v1/me/statistics/sync`
- `Quizice/Core/Accessibility/AccessibilityModeMonitor.swift` — детектор активной a11y (VO + Switch Control)
- `QuiziceTests/Unit/AuthServiceTests.swift:testLiveCamelCaseContractEncodesRequestsAndDecodesResponses` — контрактный тест с точной формой payload
- `QuiziceTests/Unit/StatisticsStoreTests.swift:testRecordAttemptPreservesAccessibilityModeInSyncPayload` — проверка сохранения флага per-attempt

## Изменения контракта

### Request: `POST /v1/me/statistics/sync`

Схема тела (изменение — новое поле `accessibilityMode` внутри каждого `attempts[]`):

```json
{
  "migrationId": "018f4f5e-...",
  "legacySummary": null,
  "attempts": [
    {
      "id": "018f4f5e-...",
      "correctAnswers": 3,
      "totalQuestions": 5,
      "completedAt": "2026-07-30T21:00:00Z",
      "accessibilityMode": false
    }
  ]
}
```

**Правила приёма:**

- `accessibilityMode` — обязательное поле у новых клиентов, `Bool`.
- Отсутствие поля (легаси-клиенты, ещё не обновились) → трактовать как `false`. НЕ отклонять запрос с `contract_violation`.
- Некорректный тип (строка, число, объект) → мягкая деградация до `false` + лог warning. Не отклонять запрос — иначе легаси-приложения зависнут в retry-циклах.
- Остальные поля (`id`, `correctAnswers`, `totalQuestions`, `completedAt`, `migrationId`) — контракт не меняется, все прежние валидации остаются.

### Response: `SyncResponse` — не меняется в этой итерации

```json
{
  "summary": { "playedQuizzes": 2, "correctAnswers": 7, ... },
  "acceptedAttemptIds": ["018f4f5e-..."],
  "legacySummaryAccepted": true
}
```

`summary` остаётся единым агрегатом по всем attempts юзера (без разбиения по режимам). Клиент показывает этот агрегат в персональной статистике на карточке Home. Если продукт захочет разделить и агрегат (например, «твоя точность в accessibility-режиме: X%») — это отдельная итерация, требует нового поля в ответе и UI-работы на клиенте.

## Модель данных

### Миграция БД

Добавить колонку в таблицу attempts (SQL-стиль; NoSQL-эквивалент — просто новое поле в документе):

```sql
ALTER TABLE attempts
  ADD COLUMN accessibility_mode BOOLEAN NOT NULL DEFAULT FALSE;

CREATE INDEX idx_attempts_user_a11y
  ON attempts (user_id, accessibility_mode, completed_at DESC);
```

- `DEFAULT FALSE` для существующих записей — до этой фичи ни один клиент не мог играть в a11y-режиме, так что backfill безопасен и корректен.
- Composite index `(user_id, accessibility_mode, completed_at)` нужен для двух самых частых запросов:
  - персональная выборка попыток одного юзера в одном режиме
  - топ-N по всем юзерам в одном режиме (если leaderboard хранит агрегаты — index может быть другим; см. ниже)

### Агрегаты (если есть)

Если у бэка есть предагрегированная таблица per-user summaries (типа `user_stats(user_id, played_quizzes, correct_answers, ...)`) — нужно завести ДВЕ строки на юзера: одну для `accessibility_mode=false`, вторую для `true`. То есть composite PK становится `(user_id, accessibility_mode)`.

Пересчёт агрегатов при приёме attempt: инкрементим ту строку, у которой `accessibility_mode` совпадает с флагом попытки.

## Логика лидербордов

Два независимых лидерборда:

1. **Regular leaderboard** — только попытки с `accessibility_mode = false`
2. **Accessibility leaderboard** — только попытки с `accessibility_mode = true`

Требования:

- Один и тот же юзер может присутствовать в обоих лидербордах (играл и с ассистивной техникой, и без) — это нормально, не дедуплицировать.
- Топ-N выборки, ранги, персональная позиция — считаются в каждом лидерборде независимо, никакого «объединённого» ранжирования.
- Если существует эндпойнт получения лидерборда (например `GET /v1/leaderboard`) — добавь query-параметр `?mode=regular|accessibility|combined`. `combined` — необязателен, добавь только если продукт явно попросит.
- Если у продукта пока лидерборда как API нет (только внутренние агрегаты) — просто заведи разделение в модели, эндпойнт добавите позже.

## Обратная совместимость

- **Легаси-клиенты (без поля в payload):** трактуй как `accessibilityMode: false`. Тест: старая версия iOS отправляет попытку без нового поля → attempt сохраняется, попадает в regular leaderboard, юзер не замечает изменений.
- **Легаси-attempts в БД (до миграции):** уже `false` из-за `DEFAULT FALSE` в миграции. Никакого дополнительного backfill не нужно.
- **JSON-парсер бэка:** если стоит в strict-mode (отклоняет неизвестные поля) — переведи в lenient для этой схемы. Мобильный клиент трактует `contract_violation` как терминальную ошибку сихронизации и попытка не попадёт в бэк на retry.

## Обсервабилити

Добавить метрику `attempts_synced_total{accessibility_mode="true|false"}` (Prometheus counter или эквивалент). Полезно для:

- **Оценки размера a11y-аудитории** — сколько попыток в accessibility-режиме приходит в день/неделю
- **Обнаружения аномалий** — если процент a11y-попыток внезапно взлетит до 50%+, это скорее всего баг на клиенте (детектор ассистивной техники сломался), а не реальный всплеск активности a11y-пользователей
- **Планирования продуктовых решений** — стоит ли инвестировать в отдельный UI accessibility-лидерборда, зависит от объёма трафика

Плюс алерт: если после деплоя за первый час не пришло ни одной attempt с `accessibility_mode=true` — это, скорее всего, ошибка в парсинге. У пользователя всегда есть шанс включить VO, вероятность нуля за час = близка к 0.

## Тесты, которые нужно добавить

### Contract / API tests

- `sync accepts new field, stores it: true` — payload с `accessibilityMode: true` → attempt сохранён с флагом, ответ содержит его `id` в `acceptedAttemptIds`
- `sync accepts new field, stores it: false` — payload с `accessibilityMode: false` → attempt сохранён, флаг = false
- `sync accepts legacy payload without field` — payload без `accessibilityMode` → attempt сохранён с default false, не отклоняется контрактом
- `sync accepts invalid field type gracefully` — payload с `accessibilityMode: "true"` (строка) → warning в логах, флаг = false, attempt сохранён (или явное 400 — задокументируй выбор в PR)
- `sync is idempotent for same attempt id across modes` — двойной sync того же attempt (с одинаковым `id`) с разным `accessibilityMode` → не создаёт дубликат, первое значение флага побеждает (или последнее — выбор поведения задокументируй)

### Leaderboard tests

- `user with only regular attempts appears only in regular leaderboard`
- `user with only accessibility attempts appears only in accessibility leaderboard`
- `user with mixed attempts appears in both leaderboards with correctly-scoped stats`
- `regular leaderboard excludes accessibility attempts from ranks and totals`
- `accessibility leaderboard excludes regular attempts from ranks and totals`

### Data model tests

- `existing attempts get default false after migration`
- `new attempt without accessibility_mode in DB defaults to false` (защита от прямых INSERT'ов, обходящих API)

## Порядок деплоя

Мобильный клиент уже forward-compatible — можно катить бэк независимо:

- **До релиза бэка**: клиент шлёт поле, бэк игнорирует, все попытки в общем лидерборде. Ничего не ломается, но фича не работает.
- **После релиза бэка**: клиент шлёт поле, бэк сохраняет и разделяет. Лидерборды разъезжаются.

Никакого feature-флага на бэке не нужно. Feature-флаг стоит добавить только если продукт хочет сначала собрать данные (метрики `attempts_synced_total`) без активации разделения лидербордов — тогда сохраняем `accessibility_mode` в БД, но лидерборды пока не разделяем.

Рекомендация: катить сразу с активным разделением. Пользовательская аудитория a11y обычно маленькая, риск заметных side-effects минимален.

## Что НЕ трогать

- **Формат `completedAt`** — клиент отсылает ISO-8601 UTC (`"2026-07-30T21:00:00Z"`). Не меняй парсинг даты.
- **Схему `SyncResponse`** — клиент привязан контрактным тестом (`AuthServiceTests.testLiveCamelCaseContractEncodesRequestsAndDecodesResponses`), любое изменение полей в ответе сломает клиента.
- **Идемпотентность по `attempt.id`** — если раньше повторный sync с тем же `id` не создавал дубликат, сохрани это. Клиент полагается на это свойство: он удаляет attempt из pending outbox только после того, как его `id` вернулся в `acceptedAttemptIds`.
- **Retry/backoff клиента** — клиент сам разбирается: экспоненциальный backoff на транспортных ошибках, терминальная остановка на `contract_violation`. Не пытайся кодировать retry-подсказки в ответе.

## Приёмка

Считаем backend-часть готовой, когда:

- [ ] Payload с `accessibilityMode: true/false/отсутствующий` корректно принимается и сохраняется
- [ ] Миграция БД выкачена, старые attempts имеют `false`
- [ ] Regular и accessibility лидерборды возвращают непересекающиеся ранкинги на mixed-user датасете
- [ ] Метрика `attempts_synced_total{accessibility_mode=…}` появилась в дашборде
- [ ] Все перечисленные тесты добавлены и проходят
- [ ] Contract test клиента (iOS `testLiveCamelCaseContractEncodesRequestsAndDecodesResponses`) продолжает проходить против нового бэка (проверить через staging-запрос)
