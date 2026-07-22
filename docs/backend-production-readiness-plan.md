# Backend production readiness: handoff-план

## Назначение и границы

Этот файл — отдельный handoff для команды backend. Он описывает изменения
развёрнутого сервиса Quizice, которые должны быть готовы **до публикации iOS-клиента**.
Backend-код не входит в текущую iOS-реализацию и в этом репозитории в рамках
текущей задачи не изменяется.

Production origin:

```text
https://bbav8b1v6032q53l8360.containers.yandexcloud.net
```

Base API URL, который получает iOS-клиент:

```text
https://bbav8b1v6032q53l8360.containers.yandexcloud.net/api
```

Все прикладные маршруты ниже начинаются с `/api/v1`. Существующие `/health` и
`/readiness` остаются вне `/api`.

Зафиксированные продуктовые решения:

- поддерживаемые локали: `ru`, `en`, `es`, `de`, `it`, `fr`; локаль обязательна,
  не определяется по заголовку и не имеет неявного English fallback;
- каталог и вопросы доступны гостям, AI-генерация — только пользователю с
  действительным Game Center bearer token;
- сервер возвращает локализованный каталог и выбирает вопросы из полного пула;
- выбор вопросов детерминирован обязательным `seed`; iOS создаёт новый seed для
  каждого replay;
- Feeling Lucky продолжает собираться локально в iOS и отдельный server endpoint
  для него не добавляется;
- маршруты авторизации и статистики сохраняются; их текущие wire-формы не
  переименовываются;
- любой неуспешный ответ использует единый `ErrorEnvelope`.

### Проверенный baseline сервера

OpenAPI развёрнутого сервиса проверен 2026-07-19. Сейчас контракт ещё не готов
для нового клиента:

- `GET /api/v1/themes` не принимает `locale` и возвращает bare array;
- `GET /api/v1/themes/{theme_id}/questions` не принимает `locale`/`seed` и
  возвращает bare array;
- `POST /api/v1/quizzes/generate` не требует bearer token, принимает только
  `topic`/`count` и возвращает bare array;
- framework validation (`422`) на части маршрутов возвращает `detail`, а не
  единый `ErrorEnvelope`.

Новый iOS-клиент намеренно должен fail closed на этом старом English-only
контракте: он принимает только новые envelopes и проверяет, что сервер дословно
вернул запрошенные `locale` и `seed`. Нельзя сохранять bare-array fallback,
подставлять `en` или игнорировать несовпадение echo-полей.

## Общий HTTP-контракт

- Request/response body: UTF-8 JSON, `Content-Type: application/json`.
- Имена полей: lower camel case, как в схемах ниже.
- Неизвестные request-поля отклоняются (`additionalProperties: false`).
- Время передаётся в RFC 3339 / ISO 8601 UTC с суффиксом `Z`, например
  `2026-07-19T08:30:00Z`; клиент принимает как целые, так и дробные секунды.
  Backend должен зафиксировать один канонический формат в OpenAPI и contract
  tests (предпочтительно целые секунды).
- `locale` — обязательная строка из `ru|en|es|de|it|fr`; значения наподобие
  `ru-RU`, другой регистр и отсутствующее значение дают `422`.
- Каждый ответ содержит server-generated `X-Request-Id`. В неуспешном ответе
  это же значение находится в `requestId`.
- Ответы не зависят от порядка чтения строк из БД, процесса/реплики сервиса или
  системного генератора случайных чисел.

Единственная форма любого `4xx`/`5xx`, включая validation, authentication,
rate limit, unknown route и необработанное исключение:

```json
{
  "requestId": "c61921c4-62df-4d3f-886b-b470672d831e",
  "code": "validation_failed",
  "message": "The request is invalid."
}
```

Правила `ErrorEnvelope`:

- все три поля обязательны и непусты;
- `requestId` — UUID, совпадающий с `X-Request-Id`;
- `code` — стабильный machine-readable `snake_case`; iOS локализует ошибку по
  коду и HTTP status, поэтому текст `message` не является UI-контрактом;
- `message` безопасен для клиента: без stack trace, SQL, provider response,
  секретов, Game Center identity, AI prompt/topic и текста вопросов;
- минимум поддерживаемых кодов: `validation_failed`, `unsupported_locale`,
  `unauthorized`, `theme_not_found`, `catalog_locale_unavailable`,
  `rate_limited`, `provider_unavailable`, `provider_invalid_response`,
  `internal_error`.

## Точные endpoint-схемы

### `POST /api/v1/auth/game-center`

Публичный маршрут. Существующий Game Center verification и срок жизни сессии
не меняются. После истечения `expiresAt` или ответа `401` клиент повторно
получает Game Center identity; отдельный refresh endpoint не добавляется.

Request:

```json
{
  "teamPlayerId": "T:_player-id",
  "bundleId": "ru.avtabenskiy.Quizice",
  "publicKeyUrl": "https://static.gc.apple.com/public-key/gc-prod-5.cer",
  "signature": "base64-signature",
  "salt": "base64-salt",
  "timestamp": "1784450000000"
}
```

Все шесть string-полей обязательны и непусты. `publicKeyUrl` должен пройти
текущую безопасную Apple URL/host validation; backend не делает произвольный
server-side fetch по URL пользователя.

Success — `200`:

```json
{
  "userId": "6f3e6c93-6046-4cb7-aec2-e708f30f0f33",
  "accessToken": "opaque-bearer-token",
  "expiresAt": "2026-07-20T08:30:00Z"
}
```

`userId`, `accessToken`, `expiresAt` обязательны; `userId` стабилен для
верифицированного `teamPlayerId`. Неверная identity возвращает `401` с
`code: "unauthorized"`; malformed body — `422` с `ErrorEnvelope`.

### `GET /api/v1/themes?locale={locale}`

Маршрут доступен без авторизации. `locale` обязателен.

Success — `200`:

```json
{
  "locale": "ru",
  "themes": [
    {
      "id": "music",
      "name": "Музыка",
      "description": "Вопросы о треках, артистах и музыкальных эпохах."
    }
  ]
}
```

Точная response-схема:

- `locale`: обязательный canonical language code, равный query-параметру;
- `themes`: непустой array;
- каждый элемент содержит только обязательные непустые `id`, `name`,
  `description`;
- `id` не локализуется и стабилен между версиями/локалями; v1 содержит
  `music`, `technology`, `history_culture`, `politics_business`;
- порядок тем стабилен и одинаков во всех локалях;
- `name` и `description` полностью переведены на запрошенную локаль.

Если локализованный каталог неполон, сервер не возвращает English fallback и не
смешивает языки: ответ `503`, `code: "catalog_locale_unavailable"`. Неподдерживаемая
или отсутствующая локаль: `422`, `code: "unsupported_locale"`.

### `GET /api/v1/themes/{theme_id}/questions`

Маршрут доступен без авторизации. Все query-параметры обязательны:

```text
?count=10&locale=ru&seed=550e8400-e29b-41d4-a716-446655440000
```

- `count`: integer, только `5`, `10` или `15`;
- `locale`: `ru|en|es|de|it|fr`;
- `seed`: canonical UUID string. Пустое/невалидное значение не заменяется
  server-generated seed и даёт `422`;
- `theme_id`: один из IDs, полученных из `/themes`.

Success — `200`:

```json
{
  "locale": "ru",
  "seed": "550e8400-e29b-41d4-a716-446655440000",
  "questions": [
    {
      "question": "Кто написал «Лунную сонату»?",
      "answers": [
        "Вольфганг Амадей Моцарт",
        "Людвиг ван Бетховен",
        "Пётр Ильич Чайковский",
        "Иоганн Себастьян Бах"
      ],
      "correctAnswer": "Людвиг ван Бетховен"
    }
  ]
}
```

Точная response-схема:

- `locale` и `seed` обязательны и дословно равны request-параметрам;
- `questions.count == count`;
- `question`: непустая строка, максимум 500 символов;
- `answers`: ровно четыре непустые попарно разные строки, каждая максимум 300
  символов;
- `correctAnswer`: точное case-sensitive совпадение с одним из `answers`;
- вопросы в одном ответе уникальны;
- видимый текст полностью соответствует запрошенной локали;
- public response не содержит внутренних `questionId`.

Неизвестная тема: `404`, `code: "theme_not_found"`. Невалидный query: `422`.
Неполный локализованный пул: `503`, `code: "catalog_locale_unavailable"`.

#### Полные пулы и детерминированный выбор

Backend импортирует весь текущий локализованный каталог, а не только первые
5/10/15 записей. Для каждой из шести локалей минимальный v1 dataset одинаков:

| Theme ID | Вопросов в каждой локали |
| --- | ---: |
| `music` | 82 |
| `technology` | 86 |
| `history_culture` | 101 |
| `politics_business` | 107 |

Внутри backend каждый вопрос получает неизменяемый `questionId`, общий для его
переводов. При первом импорте текущих синхронных locale-файлов IDs назначаются
как `{themeId}:{fourDigitOrdinal}`, например `music:0001`; затем эти IDs
сохраняются при редактировании и перестановке контента.

Выбор реализуется без runtime RNG:

1. взять полный валидный пул для `(themeId, locale)`;
2. для каждого вопроса вычислить
   `SHA-256(locale + "\u0000" + themeId + "\u0000" + seed + "\u0000" + questionId)`;
3. отсортировать по hash ascending, затем по `questionId` как tie-breaker;
4. вернуть первые `count` вопросов в этом порядке.

При неизменном dataset одинаковые `(themeId, count, locale, seed)` всегда дают
байт-в-байт одинаковые `locale`, `seed` и ordered questions на любой реплике и
после рестарта. Новый replay в iOS обязан использовать новый UUID seed; сервер
не кэширует один seed как «последний» и не обещает, что две разные seeds никогда
случайно не дадут одинаковое множество.

### `POST /api/v1/quizzes/generate`

Маршрут доступен **только** с `Authorization: Bearer <accessToken>`. Отсутствующий,
просроченный или неверный token возвращает `401`/`unauthorized` до обращения к
AI provider. Гостю AI недоступен.

Request:

```json
{
  "topic": "История космических программ",
  "count": 10,
  "locale": "ru",
  "difficulty": "medium"
}
```

Точная request-схема:

- `topic`: trimmed non-empty string длиной `1...120`; это данные, не инструкция;
- `count`: `5|10|15`;
- `locale`: `ru|en|es|de|it|fr`;
- `difficulty`: `easy|medium|hard`;
- все четыре поля обязательны, дополнительные поля запрещены.

App-facing response основан на `docs/yandex-ai-quiz-schema.json`, а не на
provider-specific envelope.

Success — `200`:

```json
{
  "locale": "ru",
  "status": "success",
  "message": "",
  "theme": "Космические программы",
  "themeDescription": "Квиз об истории освоения космоса.",
  "questions": [
    {
      "question": "Как назывался первый искусственный спутник Земли?",
      "answers": ["Спутник-1", "Восток-1", "Луна-2", "Союз-1"],
      "correctAnswer": "Спутник-1",
      "explanation": ""
    }
  ]
}
```

Для `status: "success"`:

- `locale` дословно равен request locale;
- `message == ""`;
- `theme` и `themeDescription` непусты и локализованы;
- `questions.count == count`;
- каждый вопрос соответствует ограничениям catalog question; `explanation`
  обязателен и в v1 всегда равен пустой строке.

Безопасный policy/content refusal — также `200`, чтобы отличать ожидаемый отказ
модели от отказа инфраструктуры:

```json
{
  "locale": "ru",
  "status": "refused",
  "message": "The requested topic cannot be used to create a quiz.",
  "theme": "",
  "themeDescription": "",
  "questions": []
}
```

Для `status: "refused"` обязательны пустые `theme`, `themeDescription`,
`questions` и безопасный `message` длиной `1...500` символов. Ответ не включает provider payload,
prompt, moderation detail или внутреннюю причину. Malformed request — `422`;
provider timeout/unavailable — `503`; structurally invalid provider output —
`502`; каждый из них использует `ErrorEnvelope`.

Provider API key хранится только в server-side secret storage. Backend передаёт
AI Studio значения `topic`, `count`, `locale`, `difficulty`, применяет
`docs/yandex-ai-quiz-prompt.md`, валидирует итог против JSON Schema и повторно
проверяет count, четыре уникальных ответа и принадлежность `correctAnswer`.
Provider timeout — 30 секунд; после timeout клиент получает `503` без частичного
квиза.

#### Rate limits AI

Distributed sliding-window limit применяется по verified `userId` на всех
репликах:

- не более 2 запросов за любые 60 секунд;
- не более 10 запросов за любые 60 минут.

Запрос учитывается после auth и структурной validation, но до provider call;
provider error и policy refusal также расходуют лимит. При превышении любого
окна backend не вызывает provider и возвращает `429`:

```json
{
  "requestId": "c61921c4-62df-4d3f-886b-b470672d831e",
  "code": "rate_limited",
  "message": "AI quiz generation rate limit exceeded."
}
```

Ответ `429` содержит `Retry-After` в целых секундах до ближайшего разрешённого
запроса. Счётчик должен работать между процессами/репликами и не храниться только
в памяти контейнера.

### `POST /api/v1/me/statistics/sync`

Маршрут и wire-форма сохраняются. Требуется bearer token; статистика всегда
изолирована по `userId` из token, а не по полю request.

Request:

```json
{
  "migrationId": "73A5325D-3F70-4B67-B729-4716D9BA1FD4",
  "legacySummary": {
    "playedQuizzes": 2,
    "correctAnswers": 14,
    "totalQuestions": 20,
    "bestCorrectAnswers": 8,
    "bestTotalQuestions": 10
  },
  "attempts": [
    {
      "id": "F5A37285-D684-4598-8A88-410582D240E8",
      "correctAnswers": 4,
      "totalQuestions": 5,
      "completedAt": "2026-07-19T08:30:00Z"
    }
  ]
}
```

- `migrationId`: обязательная непустая строка, максимум 256;
- `legacySummary`: nullable/optional; принимается не более одного раза для пары
  `(userId, migrationId)`;
- `attempts`: обязательный array, **максимум 100 элементов за один request**;
- `attempt.id`: непустая строка до 256, идемпотентный ключ внутри user;
- `totalQuestions`: `5|10|15`; `0 <= correctAnswers <= totalQuestions`;
- все summary integers неотрицательны, `correctAnswers <= totalQuestions`,
  `bestCorrectAnswers <= bestTotalQuestions`.

Success — `200`:

```json
{
  "summary": {
    "playedQuizzes": 3,
    "correctAnswers": 18,
    "totalQuestions": 25,
    "bestCorrectAnswers": 8,
    "bestTotalQuestions": 10
  },
  "acceptedAttemptIds": ["F5A37285-D684-4598-8A88-410582D240E8"],
  "legacySummaryAccepted": true
}
```

Повторная отправка уже записанного attempt не меняет aggregate, но его ID снова
входит в `acceptedAttemptIds`, чтобы iOS мог очистить outbox. Одновременные
запросы с одинаковыми IDs атомарны. `summary` — authoritative aggregate после
обработки всего batch. Более 100 attempts и нарушение числовых инвариантов дают
`422`/`validation_failed`; частичного commit при validation error нет.

## Backend-реализация и данные

- Обновить DTO/OpenAPI так, чтобы опубликованная схема дословно отражала все
  request/response envelopes, enums, лимиты строк, `maxItems: 100`, security и
  error responses выше.
- Заменить стандартные FastAPI validation/404/500 bodies общими exception
  handlers, формирующими `ErrorEnvelope` и `X-Request-Id`.
- Импортировать шесть полных locale datasets; добавить startup/readiness check,
  который запрещает ready-состояние при отсутствующей теме, переводе, стабильном
  question ID или при пуле меньше 15 валидных вопросов.
- Не логировать bearer tokens, подпись/salt Game Center, AI topic/prompt,
  provider body, вопросы и ответы. В structured logs оставить `requestId`, route,
  status, duration, user hash для защищённых маршрутов, locale, count и общий
  error code.
- Добавить метрики request count/error count/duration по route/status, AI
  provider duration/refusal/timeout/rate-limit и DB duration. Не использовать
  `locale`, `seed`, topic или user ID как high-cardinality metric labels.

## Тесты и критерии производительности

### Contract и unit tests в CI

Обязательные автоматические проверки backend:

1. OpenAPI snapshot и contract tests для каждого success/error примера из этого
   документа; `422`, `404`, `401`, `429`, `500` имеют только `ErrorEnvelope`.
2. Параметризованные catalog tests по всем шести локалям: четыре стабильных theme
   IDs, полные counts `82/86/101/107`, непустые переводы, отсутствие English
   fallback, четыре уникальных ответа и валидный correct answer.
3. Determinism tests: одинаковая матрица `(themeId, count, locale, seed)` на
   разных процессах возвращает одинаковый ordered JSON; разные test seeds
   выбирают вопросы из полного пула; echo `locale`/`seed` точен.
4. AI tests с provider stub: auth выполняется до provider; гость/expired token
   получает `401` и zero provider calls; success/refused/schema violation,
   timeout и все locale/difficulty/count combinations соответствуют контракту.
5. Distributed rate-limit tests с общим storage и несколькими app instances:
   3-й запрос за минуту и 11-й за час дают `429` + `Retry-After` и не вызывают
   provider.
6. Statistics tests: batch 0/1/100 принимается, 101 отклоняется целиком;
   duplicate/concurrent attempt идемпотентен; migration применяется один раз;
   aggregate и acknowledgements точны.
7. Integration tests с PostgreSQL: migrations, transaction rollback, session
   isolation между users, readiness при недоступной БД и locale dataset.

Любой провал этих тестов блокирует backend deploy.

### Load/latency tests

Запускать в staging на production-like размере контейнера и БД, отдельно
фиксируя cold start. Профиль без AI provider: 10 минут, 50 concurrent users,
смесь 40% themes, 40% questions, 15% statistics sync, 5% auth с verifier stub.
Целевые пороги на валидных запросах после warm-up:

- общий unexpected error rate `< 0.5%`;
- `GET /themes`: p95 `<= 300 ms`, p99 `<= 750 ms`;
- `GET /themes/{id}/questions`: p95 `<= 500 ms`, p99 `<= 1 s`;
- statistics sync: p95 `<= 750 ms`, p99 `<= 1.5 s`;
- auth с verifier stub: p95 `<= 750 ms`, p99 `<= 1.5 s`;
- первый cold request к themes/questions после scale-to-zero: `<= 2 s`, оставляя
  минимум 1 секунду запаса до клиентского bundled-fallback на отметке 3 секунды.

AI проверять отдельным сценарием, чтобы не расходовать production quota:

- provider stub с контролируемой задержкой, несколько authenticated users и
  нагрузка ниже per-user limits: backend overhead p95 `<= 250 ms`;
- staging smoke с реальным provider: 30 последовательных запросов по локалям и
  сложностям, end-to-end p95 `<= 25 s`, ни один request не превышает server
  timeout 30 секунд;
- сценарий превышения лимита подтверждает быстрый `429` p95 `<= 300 ms` и zero
  provider calls.

Результат load run (revision, дата, профиль, p50/p95/p99, error rate, cold start)
сохраняется как CI artifact и прикладывается к backend release. Production
получает только короткий smoke, не нагрузочный прогон.

## Rollout

1. Подготовить backward-compatible DB/content migration, stable question IDs,
   шесть полных переводов, distributed AI limiter и server-side AI credentials.
2. Реализовать контракт и tests в staging; опубликовать обновлённый OpenAPI.
3. Прогнать contract/unit/integration/load suites и сохранить отчёт. Не
   использовать production AI key в CI/load tests.
4. Развернуть новую backend revision **до iOS build/release**. Сначала проверить
   `/health` и `/readiness`, затем smoke всех endpoint-схем.
5. Production smoke обязан проверить: все шесть `/themes` locales; fixed seed
   дважды для каждой темы; разные seeds; AI `401` без token; один authenticated
   AI success/refusal; statistics idempotent retry; единый error envelope.
   Клиентский opt-in live smoke проверяет публичный контент, измеряет первый и
   warm-запросы и отдельно блокирует публично доступный AI; численные latency
   gates остаются в production-like backend load suite, а не в нестабильной
   сети разработчика.
6. После 30 минут без роста `5xx`, contract errors и latency SLO направить 100%
   трафика на новую revision и только затем разрешить iOS release.
7. После выхода iOS нельзя откатывать server на старые bare arrays/English-only
   ответы: такой rollback предсказуемо переводит клиент в fail-closed state.
   Исправления выпускаются roll-forward с сохранением нового wire-контракта.

## Definition of Done

Backend handoff завершён, когда одновременно выполнено следующее:

- production Base API — `/api`, а все пять маршрутов отвечают по точным схемам;
- catalog/questions полностью локализованы для `ru/en/es/de/it/fr`, без fallback,
  с полными пулами и стабильными IDs;
- сервер требует и echo-проверяемо возвращает `locale`/`seed`, deterministic
  selection подтверждён тестами;
- AI недоступен гостям, bearer auth и оба distributed rate limits работают,
  provider secret отсутствует в приложении и логах;
- `ErrorEnvelope(requestId, code, message)` используется для каждого non-2xx;
- лимит statistics batch `100`, идемпотентность и миграция документированы в
  OpenAPI и покрыты тестами;
- contract/unit/integration/load tests зелёные, latency thresholds соблюдены;
- backend revision развёрнута и прошла production smoke до выпуска iOS-клиента.
