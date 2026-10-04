# Полный аудит Quizice

Последующие исправления iOS и результаты их проверки описаны в [отдельном отчёте](client-audit-fixes-2026-10-04.md). Ниже сохранены исходные выводы аудита до исправлений.

Аудит от 4 октября 2026 года охватывает iOS-приложение, связанный сервер и админку. Главный вывод: отдельные компоненты хорошо покрыты тестами, но между ними расходятся контракты и правила владения состоянием. Из-за этого успешные локальные проверки не предотвращают потерю языка при импорте, сбои синхронизации статистики, списание AI-лимита без выдачи игры и зависание пользовательского сценария.

Это анализ текущего кода и локальных проверок, а не подтверждение состояния production. Исправления бизнес-логики, деплой и изменения рабочих баз в рамках аудита не выполнялись.

## Область и достоверность

| Часть | Проверенный checkout | Что проверено |
| --- | --- | --- |
| Quizice | `379469e` | Все слои приложения, тесты, конфигурации, локальные данные, аналитика, доступность |
| Quizice-backend | `52b0b40` | API, модели, авторизация, статистика, AI, квоты, CI, сборка и эксплуатационные файлы |
| Quizice-admin | `c7e968a` | Типы и запросы, импорт, каталог, деплой, доступность, Nginx, тесты и сборка |

Связанные репозитории находятся рядом с iOS-проектом. На момент первичной проверки рабочие деревья были чистыми. Ссылки ниже указывают на локальные исходники этих checkout.

**Уровни доказательности:** «воспроизведено» означает локальный запуск реального кода с изолированными зависимостями; «код» означает прослеженную цепочку вызовов и условий без полного UI-прогона сценария; «пробел» означает отсутствующую реализацию или проверку. P1 — закрыть до ближайшего выпуска; P2 — исправить в следующем цикле стабилизации; P3 — улучшение. P0 в проверенной области не подтверждено.

Облачная конфигурация, фактические production-логи, реальные Game Center/StoreKit-транзакции, серверные данные и App Store Connect не проверялись. Существующие документы о выпуске использовались как контекст, а не как доказательство актуального состояния сервиса.

## Результаты проверок

| Проверка | Результат |
| --- | --- |
| iOS S01–S04 static contracts | PASS |
| iOS unit, iPhone 17 Pro, iOS 26.5, Xcode 26.5 | 344 обнаружено: 341 PASS, 3 opt-in live-теста SKIP, 0 FAIL |
| iOS UI contracts, iPhone 16 Pro, iOS 18.6 | 137 PASS |
| iOS snapshots, iPhone 16e, iOS 26.2 | 68 PASS, эталоны не перезаписывались |
| Объединённое покрытие iOS | 86,24% строк, 23707 / 27488; порог проекта 80% пройден |
| iOS Release без backend URL и ключа аналитики | PASS, simulator build, подпись отключена; отсутствие обязательной конфигурации сборку не останавливает |
| Backend unit и contract | 789 PASS, 0 FAIL; combined line/branch coverage 90,14%, порог 85% пройден |
| Admin unit/component | 43 PASS; строки 94,58%, ветви 81,12% |
| Admin lint и production build | PASS в изолированной временной копии |
| Дополнительные admin regression-проверки | 2 ожидаемых FAIL: потеря полей импорта и смена ключа при повторе деплоя |
| Локализации iOS | 6 языков × 242 ключа; наборы ключей и printf-плейсхолдеры совпадают |
| Встроенный контент iOS | 4 темы, 376 вопросов на локаль; структура ответов валидна, найдены дубли и дефект объяснения |

В прогоне обнаружены все 549 существующих XCTest: 546 прошли, 3 явно пропущены. Это не XCUITest: UI contracts работают с созданными в тестах контроллерами и представлениями. Прогон покрывает iOS 18.6, 26.2 и 26.5 в разных категориях, но не является полной матрицей каждой категории на каждой версии.

[Объединённый xcresult](</Users/tabenskii/Desktop/Проектики/Quizice/DerivedData/Audit-2026-10-04/TestResults/combined.xcresult>). Временные воспроизведения админки и таймера выполнены вне исходных репозиториев.

## Приоритетные дефекты

### F01 P1 Нулевой первый результат ломает синхронизацию статистики

**Воспроизведено серверным сервисом с mock DB; клиентский отказ подтверждён валидатором.** Для нового пользователя игра 0/5 увеличивает `playedQuizzes` и `totalQuestions`, но оставляет лучший результат 0/0: сервер обновляет его только при строго большем числе правильных ответов. Сервер подтверждает ID попытки, а iOS отвергает весь ответ, потому что при сыгранной игре требует `bestTotalQuestions > 0`. Локальная очередь не очищается; повторная отправка сама проблему не исправляет, пока все результаты нулевые. Аналогичный случай возможен при переносе нулевой legacy-статистики.

Код: [statistics.py:47](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/statistics.py:47>), [statistics.py:89](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/statistics.py:89>), [HTTPAuthAPI.swift:332](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/HTTPAuthAPI.swift:332>).

**Исправление и критерий:** согласовать определение первого лучшего результата. Общий fixture для нового пользователя и попыток 0/5, 0/10, повторной отправки и legacy 0/N должен проходить серверную сериализацию и настоящий iOS decoder; очередь должна очищаться после первого успешного sync.

### F02 P1 Сервер списывает лимит за AI ответ который клиент отвергает

**Воспроизведено HTTP-запросом к локальному FastAPI с fake provider и quota.** Сервер допускает непустое `explanation` до 2000 символов, возвращает 200 и отмечает генерацию успешной для квоты. iOS требует строго пустую строку. Production generator не удаляет объяснение; просьба в prompt не обеспечивает контракт. Пользователь получает ошибку вместо игры и может повторно расходовать лимит.

Код: [quiz.py:100](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/models/quiz.py:100>), [quiz.py:73](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/api/quiz.py:73>), [BackendAIQuizThemeService.swift:415](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/AIQuiz/Data/BackendAIQuizThemeService.swift:415>).

**Исправление и критерий:** выбрать единый контракт объяснений, проверять его до списания. Один и тот же JSON с пустым и непустым объяснением должен давать согласованные результаты server/client; тест должен проверять и quota charge.

### F03 P1 Обновление избранного может заблокировать карточку и сломать повтор игры

**Код, цепочка независимо перепроверена.** Обычный sync предпочтений вызывает `onCatalogReplaced`, а AppDelegate обнуляет `session.chosenTheme`. Если карточка уже раскрыта, Start переводит reducer в `.launching`, после чего обработчик молча выходит из-за отсутствующей темы. В этом состоянии действия закрытия игнорируются. Если ответ sync пришёл во время игры, теряются метаданные темы, а Replay может открыть экран без вопросов.

Код: [ThemeCatalogRepository.swift:240](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:240>), [AppDelegate.swift:43](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/AppDelegate.swift:43>), [HomeThemeCardReducer.swift:328](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/State/HomeThemeCardReducer.swift:328>), [QuizViewController+ExpandedCardLayout.swift:9](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/Presentation/QuizViewController+ExpandedCardLayout.swift:9>), [QuizFlowCoordinator.swift:407](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Navigation/QuizFlowCoordinator.swift:407>).

**Исправление и критерий:** отделить обновление каталога/порядка от инвалидирования текущей игры; хранить неизменяемый снимок выбранного раунда. Delayed sync во время раскрытой карточки, игры и результатов не должен мешать Start, Close и Replay. Любой отказ запуска обязан возвращать reducer в доступное состояние.

### F04 P1 Импорт в админке молча меняет язык и свойства контента

**Воспроизведено дополнительным regression-тестом в временной копии admin.** Импорт и копирование JSON сохраняют только старый набор полей, отбрасывая `locale`, `difficulty`, `country`, `questionId`, `questionVersion`. Сервер подставляет `en`, `medium`, отсутствие страны и новые значения идентичности. Например, вопрос с `locale=ru`, `difficulty=hard`, `country=US` импортируется без этих параметров; русский текст может попасть в английский каталог, а связь переводов потеряться.

Код: [questionJson.ts:53](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/lib/questionJson.ts:53>), [questionJson.ts:97](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/lib/questionJson.ts:97>), [types.ts:30](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/types.ts:30>), [admin.py:100](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/models/admin.py:100>), [themes.py:15](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/data/themes.py:15>).

**Исправление и критерий:** синхронизировать формы, типы, импорт и экспорт с API. Round-trip export → import должен сохранять язык, сложность, страну и согласованную идентичность. Намеренное создание копии с новым ID должно быть отдельным явным действием. Проверить каждый из шести языков.

### F05 P2 Предпочтения тем не изолированы между аккаунтами

**Код.** Локальные favorites и pending-флаг разделены только по локали. Запрос sync использует текущий bearer; после ответа проверяется язык, но не пользователь. Несинхронизированный выбор аккаунта A может быть отправлен после входа B; запоздавший ответ A может примениться к состоянию B.

Код: [OnboardingProgressStore.swift:18](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/OnboardingProgressStore.swift:18>), [OnboardingProgressStore.swift:80](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/OnboardingProgressStore.swift:80>), [ThemeCatalogRepository.swift:215](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:215>).

**Исправление и критерий:** ключи хранения должны включать principal; запрос должен фиксировать userID и ревизию локального выбора. Проверить A → offline change → B, A → guest и смену аккаунта при незавершённом GET/PUT. Отдельно определить перенос гостевых предпочтений.

### F06 P2 Смена аккаунта оставляет окно записи статистики старому пользователю

**Код.** Начало новой Game Center-авторизации меняет auth-state, но оставляет активный principal StatisticsStore. Presenter новой игры фиксирует этот старый ID и использует его при завершении. Дополнительно старый in-flight sync может не дать запустить sync нового пользователя: guard отклоняет новый запуск, а завершение старого запроса не гарантирует повтор для нового principal.

Код: [GameCenterAuthenticationService.swift:207](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/GameCenterAuthenticationService.swift:207>), [GameCenterAuthenticationService.swift:349](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/GameCenterAuthenticationService.swift:349>), [QuizQuestionPresenter.swift:139](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:139>), [QuizQuestionPresenter.swift:263](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:263>).

**Исправление и критерий:** единая атомарная смена auth principal, отмена/изоляция старого sync, явное правило для игры в процессе входа. Тест: A → начало обмена B → новый раунд → завершение входа B → результат; данные не должны присваиваться A.

### F07 P2 Защита Game Center от повторного proof использует текст Base64

**Воспроизведено реальным verifier с тестовой RSA-подписью и MockTransport сертификата.** RSA проверяется по декодированным байтам, а replay hash — по исходной строке Base64. Два допустимых представления с разными незначащими pad bits дают одинаковую подпись и разные ключи повторного использования. Это обход одноразовости уже полученного proof в допустимом временном окне; самостоятельная подделка подписи чужого игрока не показана.

Код: [auth.py:49](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/auth.py:49>), [game_center.py:73](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/integrations/game_center.py:73>), [game_center.py:122](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/integrations/game_center.py:122>).

**Исправление и критерий:** вычислять replay identity по каноническим байтам или отклонять неканоническое кодирование. Эквивалентные представления одной подписи должны считаться повтором, второй обмен — отклоняться.

### F08 P2 Dev auth secret не скрывается в сетевых логах

**Код плюс проверка redaction в установленном Pulse.** Debug глобально включает Pulse и задаёт список скрываемых заголовков, в котором отсутствует `X-Dev-Auth-Secret`. Dev-auth отправляет секрет именно там. Он может сохраниться в локальном логе и попасть в экспорт диагностического файла. Утечка реального секрета за пределы устройства не проверялась.

Код: [AppDelegate.swift:15](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/AppDelegate.swift:15>), [HTTPAuthAPI.swift:73](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/HTTPAuthAPI.swift:73>).

**Исправление и критерий:** добавить заголовок в redaction; тестировать сохранённый/экспортированный лог с синтетическим секретом. Аналогично проверить prompt, input и answer-events, если их попадание в debug-логи нежелательно.

### F09 P2 Повтор деплоя после потерянного ответа создаёт новую операцию

**Воспроизведено regression-тестом admin.** UUID создаётся при каждом `mutationFn`. При таймауте пользователь повторяет тот же deploy с новым idempotency key; сервер распознаёт дубликаты только по старому ключу. Первый webhook мог уже быть принят, поэтому повтор может инициировать второй запуск. Текст интерфейса при этом обещает защиту от повторов.

Код: [DeploymentsPage.tsx:21](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/pages/DeploymentsPage.tsx:21>), [deployments.py:99](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/deployments.py:99>).

**Исправление и критерий:** хранить ключ на протяжении логической операции и использовать его повторно при неизвестном исходе; сверять историю/статус. Тестировать потерю ответа после фактического принятия webhook.

### F10 P2 Заголовки защиты админки теряются в Nginx location

**Код и официальная семантика Nginx.** `location /` и `/assets/` объявляют собственный `add_header Cache-Control`, поэтому заданные на уровне server `X-Frame-Options`, `X-Content-Type-Options` и остальные заголовки не наследуются. `always` этого правила не меняет. Текущий deployed reverse proxy не проверялся. [Правило наследования Nginx](https://nginx.org/en/docs/http/ngx_http_headers_module.html#add_header).

Код: [nginx.conf:13](</Users/tabenskii/Desktop/Проектики/Quizice-admin/nginx.conf:13>).

**Исправление и критерий:** общий include заголовков в обслуживающих location или другая совместимая конфигурация. Проверять реальные HTTP headers `/`, вложенного SPA URL, asset и 404 собранного образа.

### F11 P2 Месячный AI лимит отображается как временная ошибка сервиса

**Код.** Backend различает исчерпание месячной квоты и временный rate limit. iOS теряет error envelope, оставляет HTTP 429 и предлагает Retry как при сбое сервиса. Повтор не восстановит месячный лимит; пользователь не узнаёт причину ограничения. Серверная документация о готовом quota UI не соответствует этому checkout клиента.

Код: [BackendAIQuizThemeService.swift:220](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/AIQuiz/Data/BackendAIQuizThemeService.swift:220>), [AIQuizThemePresentationSupport.swift:94](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/AIQuiz/Presentation/AIQuizThemePresentationSupport.swift:94>), [AIQuizThemePresentationSupport.swift:143](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/AIQuiz/Presentation/AIQuizThemePresentationSupport.swift:143>), [AI_QUOTA.md:27](</Users/tabenskii/Desktop/Проектики/Quizice-backend/docs/AI_QUOTA.md:27>).

**Исправление и критерий:** декодировать machine-readable error code и сведения о лимите, если они есть в контракте. Разные UI-состояния для monthly exhausted, temporary 429, 503 и auth. Проверка должна использовать настоящий server error fixture.

### F12 P2 Ошибка запуска темы показывается под раскрытой карточкой

**Код, цепочка UI независимо перепроверена.** При offline/500/422 обработчик возвращает карточку на обратную сторону и пишет ошибку только в `motivationLabel`. Этот label находится в фоне под backdrop и исключён из accessibility tree. Spinner исчезает, но доступного объяснения причины рядом с Start нет; с Reduce Transparency фон практически закрыт.

Код: [QuizViewController+ExpandedCardLayout.swift:61](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/Presentation/QuizViewController+ExpandedCardLayout.swift:61>), [QuizViewController+CardPresentation.swift:29](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/Presentation/QuizViewController+CardPresentation.swift:29>), [QuizViewController+Restoration.swift:7](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/Presentation/QuizViewController+Restoration.swift:7>).

**Исправление и критерий:** ошибка и retry внутри карточки или доступный alert. UI-тест проверяет видимость и озвучивание сообщения, повтор без потери настроек и возможность закрытия.

### F13 P2 После выключения VoiceOver повтор может включить невидимый таймер

**Код.** Accessibility-раунд скрывает timer container. Replay переиспользует тот же контроллер и не восстанавливает видимость. Если на результатах выключить VoiceOver/Switch Control, новый presenter запускает countdown, который остаётся скрытым.

Код: [QuizQuestionViewController.swift:298](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/UI/QuizQuestionViewController.swift:298>), [QuizQuestionViewController.swift:356](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/UI/QuizQuestionViewController.swift:356>), [QuizQuestionPresenter.swift:71](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:71>).

**Исправление и критерий:** задавать полное состояние видимости при каждом начале игры. Проверить ON → OFF → Replay и OFF → ON → Replay, включая accessibility tree.

### F14 P2 Смена оформления стирает подсветку уже данного ответа

**Код.** В режиме системной темы переключение light/dark вызывает `applyAppearance`, который всем кнопкам безусловно назначает `.normal`. В answered-state исчезает correct/wrong feedback, хотя пользователь ещё не нажал Next.

Код: [UIKitAppearanceSupport.swift:95](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/DesignSystem/Appearance/UIKitAppearanceSupport.swift:95>), [QuizQuestionViewController.swift:418](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/UI/QuizQuestionViewController.swift:418>).

**Исправление и критерий:** внешний вид выводится из сохранённого состояния ответа. Проверить смену traits после correct, wrong и timeout.

### F15 P2 Двадцать секунд таймера зависят от работы run loop

**Воспроизведено Foundation-harness с production QuizTimerClient.** Timer создаётся в default mode; presenter вычитает фиксированные 0,02 секунды за callback. В другом run-loop mode за 0,3012 секунды прошло 0 callbacks, оставшееся время осталось 20. После возврата накопленная задержка не компенсируется. На iOS это затрагивает tracking/scroll и задержки main thread; полный жестовый сценарий отдельно не запускался.

Код: [QuizQuestionPresenter.swift:109](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:109>), [QuizQuestionPresenter.swift:372](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:372>), [SceneDelegate.swift:83](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/SceneDelegate.swift:83>).

**Исправление и критерий:** выбрать явную политику background/pause, считать остаток от monotonic deadline, отдельно обновлять UI. Проверить пропущенные ticks и lifecycle. Продолжение таймера под exit alert намеренно закреплено существующим тестом и не считается найденным багом.

### F16 P2 Настройка повторов обещает фильтр который не применяется

**Код.** Settings всегда разрешает Hide answered/Retry incorrect. У гостя и при истёкшем backend token режим молча превращается в Show all; bundled-путь также не фильтрует историю. UI продолжает показывать выбранный режим без ограничения. Локальное истечение токена может привести к анонимному запросу без 401, поэтому именно этот запрос не запустит восстановление авторизации.

Код: [QuizSettingsView.swift:278](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Settings/UI/QuizSettingsView.swift:278>), [BackendContentModels.swift:31](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Networking/BackendContentModels.swift:31>), [ThemeCatalogRepository.swift:538](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:538>), [ThemeCatalogRepository.swift:481](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:481>).

**Исправление и критерий:** показывать эффективный режим и необходимое действие для входа, либо реализовать локальную историю. Тестировать guest, expired token, bundled и authenticated backend отдельно.

### F17 P2 Заставка ждёт сетевые операции без общего бюджета

**Код.** Launch последовательно ждёт обновление каталога и синхронизацию предпочтений; базовый timeout запроса 15 секунд. Overlay закрывается только после подготовки, Game Center стартует после его закрытия. При медленном соединении доступ к уже имеющимся данным блокируется на время запросов. У двух выполняющихся запросов задержки складываются; точный предел зависит от сетевых условий и повторов.

Код: [QuizFlowCoordinator.swift:135](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Navigation/QuizFlowCoordinator.swift:135>), [LaunchOverlayPresenter.swift:73](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Launch/LaunchOverlayPresenter.swift:73>), [SceneDelegate.swift:43](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/SceneDelegate.swift:43>), [HTTPBackendContentAPI.swift:22](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Networking/HTTPBackendContentAPI.swift:22>).

**Исправление и критерий:** ограничить launch budget и открывать локальное состояние, завершать refresh в фоне. Тест медленного/зависшего транспорта должен ограничивать время до интерактивного Home.

### F18 P2 Аналитика не описывает повторные и укороченные игры

**Код.** Replay запускает новый раунд без `quiz_started`, но ответы и завершения учитываются. Начальный Start пишет запрошенное количество вопросов, хотя backend может вернуть меньше и приложение округлит фактический раунд вниз до поддерживаемого размера. Это искажает продуктовую воронку и сравнение раундов.

Код: [QuizFlowCoordinator.swift:556](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Navigation/QuizFlowCoordinator.swift:556>), [QuizQuestionPresenter.swift:263](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/QuizPlay/Presentation/QuizQuestionPresenter.swift:263>), [QuizViewController+ExpandedCardLayout.swift:43](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Home/Presentation/QuizViewController+ExpandedCardLayout.swift:43>), [ThemeCatalogRepository.swift:337](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:337>).

**Исправление и критерий:** отправлять start из единой точки создания раунда с фактическим количеством. Для initial/replay должна быть одна согласованная цепочка start → answers → complete/exit.

### F19 P2 Обычный XCTest может использовать настоящую очередь ответов

**Код; нежелательные live-запросы намеренно не воспроизводились.** AppDelegate запускает shared answer outbox, а его live factory не отключается в XCTest. Используются стандартный каталог приложения и Keychain. На симуляторе с существующей сессией и pending events тестовый host может синхронизировать их с настоящим backend, несмотря на отключение других live dependencies.

Код: [AppDelegate.swift:49](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/AppDelegate.swift:49>), [QuestionAnswerOutbox.swift:90](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/QuestionAnswerOutbox.swift:90>), [SceneDelegate.swift:20](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/SceneDelegate.swift:20>).

**Исправление и критерий:** тестовый composition root с отдельным storage, Keychain namespace и запрещённым live transport. Отдельный тест запуска host с заранее подготовленной синтетической очередью должен доказывать отсутствие внешних запросов.

### F20 P2 Выпуск не требует корректной конфигурации API

**Код и проверки сборки.** iOS использует optional Secrets и при отсутствии URL выбирает bundled content и unavailable auth/AI. Release simulator build с явно пустыми `BACKEND_BASE_URL` и `APPMETRICA_API_KEY` успешно завершился; в готовом Info.plist оба значения пустые. Admin production build без `VITE_ADMIN_API_URL` использует `http://localhost:8000`, то есть компьютер пользователя; такая сборка тоже успешно прошла. Допустимый локальный режим не отделён от обязательных условий выпуска.

Код: [Shared.xcconfig:9](</Users/tabenskii/Desktop/Проектики/Quizice/Configurations/Shared.xcconfig:9>), [BackendConfiguration.swift:29](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/BackendConfiguration.swift:29>), [AIQuizRuntimeDependencies.swift:58](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/AIQuizRuntimeDependencies.swift:58>), [client.ts:16](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/api/client.ts:16>), [Dockerfile:6](</Users/tabenskii/Desktop/Проектики/Quizice-admin/Dockerfile:6>).

**Исправление и критерий:** production/archive gate на HTTPS endpoint и согласованное окружение; dev/offline режим оставить явным. Проверять собранные Info.plist и frontend bundle, не только исходные env-файлы.

### F21 P2 Backend образ собирается не из проверенного набора зависимостей

**Код.** Quality job CI устанавливает зависимости по `uv.lock`, но Dockerfile не копирует lock и делает `pip install . uvicorn`. Диапазоны из pyproject разрешаются заново; uvicorn устанавливается отдельно без закрепления версии. Повторная сборка того же commit может отличаться от quality-среды. Docker integration job тоже есть и проверяет построенный образ, но не делает последующую пересборку воспроизводимой.

Код: [Dockerfile:9](</Users/tabenskii/Desktop/Проектики/Quizice-backend/Dockerfile:9>), [pyproject.toml:11](</Users/tabenskii/Desktop/Проектики/Quizice-backend/pyproject.toml:11>), [backend-ci.yml:34](</Users/tabenskii/Desktop/Проектики/Quizice-backend/.github/workflows/backend-ci.yml:34>).

**Исправление и критерий:** установка runtime из lock, включая server package; проверка перечня версий в финальном образе и reproducible build policy. Уязвимость конкретной версии этим аудитом не установлена.

### F22 P2 Админка поддерживает только старые четыре темы

**Код.** Dropdown формы и фильтры содержат четыре hardcoded темы при четырнадцати на сервере. Обычный UI не позволяет выбрать остальные десять для создания/фильтрации. Также отсутствуют полноценные параметры языка, сложности и страны, что осложняет обслуживание локализованного каталога.

Код: [QuestionsPage.tsx:13](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/pages/QuestionsPage.tsx:13>), [themes.py:18](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/data/themes.py:18>).

**Исправление и критерий:** получать список тем из API, отражать все контентные измерения. Новая серверная тема должна появляться без пересборки admin; язык должен быть виден до редактирования.

### F23 P3 Встроенный контент содержит дубли и сломанное объяснение

**Воспроизведено проверкой всех JSON.** В каждой из шести локалей повторены вопросы о «Божественной комедии» и базовом доходе; shuffled выбор не удаляет одинаковые тексты, поэтому одна игра может повторить вопрос. В русском объяснении есть фраза «вышел в Satisfaction году». Валидность четырёх ответов не обеспечивает смысловую корректность материала.

Код: [data.json:59](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/ru.lproj/data.json:59>), [data.json:2139](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/en.lproj/data.json:2139>), [data.json:2887](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/en.lproj/data.json:2887>), [data.json:3381](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/en.lproj/data.json:3381>), [data.json:3865](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/en.lproj/data.json:3865>), [ThemeCatalogRepository.swift:491](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/ThemeCatalogRepository.swift:491>).

**Исправление и критерий:** проверка нормализованной уникальности, редакционная ревизия спорных/устаревающих фактов и общая идентичность вопросов между локалями. Фактчекинг всех 376 вопросов на язык в этом аудите не выполнялся.

### F24 P2 Удаление старых operational данных зависит от нового деплоя

**Код.** Удаление истёкших admin sessions и error events старше настроенного retention вызывается только из `prepare-deploy`. Lifespan API не вызывает очистку; отдельной prune-команды и расписания в репозитории нет. При редких деплоях ошибки сохраняются дольше заявленного периода. Истёкшие сессии от этого не становятся валидными — проблема в хранении, а не в обходе expiry.

Код: [maintenance.py:232](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/maintenance.py:232>), [admin_auth.py:301](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/admin_auth.py:301>), [main.py:53](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/main.py:53>), [ADMIN_API.md:94](</Users/tabenskii/Desktop/Проектики/Quizice-backend/docs/ADMIN_API.md:94>).

**Исправление и критерий:** идемпотентная scheduled maintenance, метрика последней успешной очистки и тест работы без деплоя. Внешнее расписание не проверено; документацию про pruning at startup привести в соответствие с реализацией.

## Пробелы продукта и проверки выпуска

| Область | Текущее состояние и последствия | Что необходимо закрыть |
| --- | --- | --- |
| Подписка | Purchase и Restore показывают Coming Soon; paywall использует локальные $1.99, 5/15 вопросов и ×20 генераций | Реальные Product/price/purchase/restore, согласованное серверное entitlement, cancel/pending/refund/expiry. До этого убрать обещание доступной покупки |
| Production AI и StoreKit | Debug Simulator принудительно идёт в direct AI; Debug entitlement использует ручной флаг | Release-подобные simulator/staging сценарии через настоящий composition path и StoreKit test configuration |
| Offline | После перехода на backend metadata cache не содержит вопросов; отсутствие сети блокирует новый раунд | Явно выбрать продуктовый контракт: downloaded packs/кеш вопросных пачек либо понятная недоступность и retry. Это существующий дизайн, не неожиданная регрессия |
| Сложность локальных вопросов | Bundled path меняет difficulty-метаданные, но не фильтрует материал | Локальные difficulty labels/filter либо скрытие неподдерживаемого выбора |
| Восстановление игры | Session в памяти; после termination нет возврата к незавершённой игре | Решить, нужен ли resume; если нужен — snapshot раунда, версия схемы, дедлайн и owner |
| Вход и ошибки auth | AI-auth alert не предлагает полноценного восстановления входа; guest fallback мало объяснён | Явный статус сессии и действие входа/повтора, различение GC unavailable и backend unavailable |
| Статистика | Есть агрегаты, нет истории игр и разбора ошибок | Согласовать, что нужно продукту; не считать отсутствующие экраны регрессиями |
| Настройки | Profile/feedback остаются заглушками | Реальные действия или удаление недоступных элементов |
| Админка и клавиатура | Drawer без полного управления focus; часть строк открывается только click | Focus trap/restore, Escape, доступные button/link для деталей; keyboard E2E |

Опорный код: [QuizFlowCoordinator.swift:204](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Navigation/QuizFlowCoordinator.swift:204>), [SubscriptionPaywallView.swift:70](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Subscription/UI/SubscriptionPaywallView.swift:70>), [SubscriptionPaywallView.swift:99](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Features/Subscription/UI/SubscriptionPaywallView.swift:99>), [AIQuizRuntimeDependencies.swift:15](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/AIQuizRuntimeDependencies.swift:15>), [QuizSessionStore.swift:16](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Session/QuizSessionStore.swift:16>), [ui.tsx:67](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/components/ui.tsx:67>).

## Хранение безопасность и эксплуатация

**Кеш каталога заменяется двумя сохранениями.** `SwiftDataThemeStore.replaceThemes` сначала сохраняет удаление старого каталога, затем вставляет новый; ошибки только логируются, rollback отсутствует. При сбое второго save старый кеш уже потерян. Каталог восстанавливаемый, поэтому это отдельный пробел устойчивости, а не подтверждённая потеря пользовательской статистики. Нужны атомарная замена и failure-injection тест. [SwiftDataThemeStore.swift:177](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/SwiftDataThemeStore.swift:177>).

**Восстановление повреждённых очередей не оформлено.** Повреждённый JSON answer outbox не декодируется; enqueue затем также не может прочитать состояние, а персонализированный fetch ждёт синхронизацию. Для guest-owned/rejected events нет явной политики очистки. StatisticsStore при недекодируемом состоянии удаляет запись. Нужны quarantine/сохранение оригинала, ограничение роста, диагностика и тесты восстановления. Умышленное повреждение рабочих данных не выполнялось. [QuestionAnswerOutbox.swift:218](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/QuestionAnswerOutbox.swift:218>), [StatisticsStore.swift:279](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Persistence/StatisticsStore.swift:279>).

**Privacy manifest требует сверки с фактическими потоками данных.** Сейчас он перечисляет unlinked interactions/diagnostics, тогда как backend принимает teamPlayerId и ответы, связанные с пользовательской сессией. Следует проверить User ID, связность прогресса, тексты AI-запросов, retention и пользовательское удаление данных. Проверка App Store Connect и юридический вывод не выполнялись. Apple отдельно описывает [privacy для scoped Game Center identifiers](https://developer.apple.com/documentation/gamekit/protecting-the-player-s-privacy-using-scoped-identifiers) и [описание собираемых типов в manifest](https://developer.apple.com/documentation/technotes/tn3184-adding-data-collection-details-to-your-privacy-manifest). [PrivacyInfo.xcprivacy:9](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/PrivacyInfo.xcprivacy:9>), [AuthModels.swift:91](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/Core/Authentication/AuthModels.swift:91>).

**Admin через прямой Yandex Serverless endpoint требует отдельной проверки.** Player API использует `X-Quizice-Authorization` из-за обработки стандартного Authorization платформой; admin всё ещё отправляет Authorization и принимает HTTPBearer. Если admin обращается через тот же прямой endpoint, обход для player его не покрывает. Это условный риск развертывания: актуальный admin origin и прокси не проверены. Проверить login → authenticated `/me` на staging с реальной транспортной схемой. [client.ts:56](</Users/tabenskii/Desktop/Проектики/Quizice-admin/src/api/client.ts:56>), [admin.py:51](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/api/admin.py:51>), [bearer.py:47](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/api/bearer.py:47>).

**Месячная AI квота не заменяет лимит попыток.** В runtime видны месячный счётчик успешных генераций и сериализация запросов пользователя. Отказы/invalid provider output не тратят месячный allowance, но могут стоить денег у провайдера. Нужен отдельный предел частоты/параллелизма попыток и мониторинг расходов. Наличие внешнего WAF/rate limit не проверялось. [ai_quota.py:37](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/ai_quota.py:37>).

**Наблюдаемость сосредоточена на accessibility statistics.** В проверенных Prometheus assets есть метрики синхронизации попыток и три профильных alert. В репозитории нет проверяемого пути доставки production-уведомлений; README оставляет collector и routing отдельной задачей. Нужны подтверждённые SLI/alerts для ошибок и задержек auth/catalog/AI, отказов sync, quota/provider cost, а также получатель уведомлений. Наличие внешних dashboards и alerts не установлено. [metrics.py:15](</Users/tabenskii/Desktop/Проектики/Quizice-backend/src/quizice/services/metrics.py:15>), [alerts.yml:1](</Users/tabenskii/Desktop/Проектики/Quizice-backend/ops/prometheus/alerts.yml:1>), [README.md:509](</Users/tabenskii/Desktop/Проектики/Quizice-backend/README.md:509>).

**Backup и восстановление требуют эксплуатационного доказательства.** Деплой учитывает опасность отката после миграции, но файлы репозитория не подтверждают активный backup/PITR и успешный restore drill. Зафиксировать RPO/RTO, владельца восстановления и провести восстановление из копии в изолированный стенд. Сам production backup этим аудитом не оценён.

## Почему существующие тесты пропускают эти ошибки

Большое количество тестов и 86,24% покрытия подтверждают исполнение кода, но не согласованность нескольких приложений. iOS, backend и admin поддерживают самостоятельные DTO/fixtures. В случае `explanation` тесты разных сторон закрепляют несовместимое поведение. Многие state-тесты получают fake repository и не подключают callback AppDelegate, который обнуляет живую session.

У iOS один unit-test target; test-host заменяет настоящий root пустым UIViewController. CI собирает Debug; backend live tests включаются вручную. Поэтому CI не доказывает цепочку launch → Game Center → backend session → каталог → вопросы → answer events → завершение → stats sync → replay. [SceneDelegate.swift:20](</Users/tabenskii/Desktop/Проектики/Quizice/Quizice/App/Lifecycle/SceneDelegate.swift:20>), [ios-tests.yml:46](</Users/tabenskii/Desktop/Проектики/Quizice/.github/workflows/ios-tests.yml:46>), [LiveBackendContractTests.swift:99](</Users/tabenskii/Desktop/Проектики/Quizice/QuiziceTests/Unit/LiveBackendContractTests.swift:99>).

Backend unit/contract запускаются без настоящей PostgreSQL. В этом прогоне `services/ai_quota.py` имеет 46,7% покрытия; транзакционная `reserve` проверяется другим integration-набором, который локально не запускался. Backend CI содержит отдельную Docker/PostgreSQL integration job, поэтому это ограничение данного аудита, а не утверждение об отсутствии интеграционных тестов. Не запускались также реальные Game Center, AI provider и production endpoints. Release проверен сборкой для Simulator, не подписанным archive/App Store install.

Минимальный полезный набор новых проверок:

| Приоритет | Сценарий | Граница проверки |
| --- | --- | --- |
| P1 | Первая игра 0/5, повтор sync и legacy 0/N | Настоящий server response → настоящий iOS decoder |
| P1 | AI success/refusal/invalid explanation и списание квоты | Provider fixture → API → client parser → UI result |
| P1 | Delayed preferences при открытой карточке и игре | App composition callback + Home reducer + session + replay |
| P1 | Import/export ru/fr, hard, country, identity/version | Admin parser → backend request model → сохранённая запись |
| P2 | Смена аккаунта во всех await-точках | Auth, prefs, stats, answer outbox и immutable round owner |
| P2 | Timeout после принятия deploy | UI сохраняет operation key; backend webhook вызывается один раз |
| P2 | Эквивалентные Base64 proof и экспорт Pulse | Auth replay policy; отсутствие синтетических secrets в файле |
| P2 | Offline/500 Start, VoiceOver replay, traits после ответа | Отображаемые состояния и accessibility tree |
| P2 | Token expiry и месячная квота | Auth recovery, эффективный repeat mode, error-specific UI |
| P2 | Release без конфигурации, archive smoke, admin image headers | Проверка готового артефакта |
| P2 | Запуск приложения и одна полная игра на staging | XCUITest с production dependencies; CI gate перед выпуском |
| P2 | Persistence failure, corrupt cache/outbox, восстановление | Изолированные fault-injection tests |

При добавлении сквозного gate использовать изолированный staging. Сейчас `QUIZICE_LIVE_BACKEND_URL` меняет API URL live-тестов, но health/readiness привязаны к отдельному production-origin — сначала сделать override целостным. [LiveBackendContractTests.swift:12](</Users/tabenskii/Desktop/Проектики/Quizice/QuiziceTests/Unit/LiveBackendContractTests.swift:12>).

## Архитектурные выводы

Деление App / Features / Core / Domain уже даёт рабочую основу. Главные проблемные связи — глобальные singleton dependencies, несколько источников auth-state и общая изменяемая session. `NSLock` защищает отдельные свойства session, но не согласованность операции «principal + theme + configuration + lifecycle». Notification/callback обновления каталога сейчас имеют побочные эффекты в активной игре.

Практический следующий шаг — единый composition root с отдельными live/test dependencies, явное состояние авторизации с generation ID и снимок раунда, независимый от дальнейшего обновления каталога. Контракт API следует версионировать совместно: OpenAPI/схема плюс общие реальные JSON fixtures, которые прогоняют Python, Swift и TypeScript validators. Смена DTO должна проверяться во всех трёх репозиториях.

Документацию планов, исторических выпусков и текущих возможностей надо различать. Например, backend-документ о quota UI и фактический iOS error mapping сейчас не совпадают. Для выпуска нужен manifest совместимых client/backend/admin commit и результаты общей acceptance-проверки.

## Порядок устранения

1. **Закрыть F01–F04:** статистика 0/N, AI contract и квота, разрушение session, потеря контентных полей. Сначала добавить воспроизводящие regression-тесты, затем исправить обе стороны контракта.
2. **Изолировать аккаунты и операции:** F05–F09, включая lifecycle sync, canonical replay identity, redaction и стабильный deployment key.
3. **Стабилизировать пользовательские ошибки:** F11–F18; проверить UI через поведение и accessibility, а не наличие исходных строк.
4. **Укрепить выпуск:** F10, F19–F22 и F24, Release/staging gate, locked Docker runtime, проверки фактических артефактов и обновлённые privacy disclosures.
5. **Определить продуктовый объём:** подписка, offline, история, resume и заглушки. Реализовать согласованный объём либо убрать обещания неподдерживаемых возможностей.

Критерий готовности — успешная полная цепочка на совместимых сборках, включая guest, authenticated, offline, expired session, отказ сервиса и восстановление. Зелёных независимых unit-наборов для этого недостаточно.
