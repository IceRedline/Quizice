# Quizice — Privacy Policy / Политика конфиденциальности

**Effective date / Дата вступления в силу: 2026-10-23**

[English](#english) · [Русский](#русский)

## English

### Who is responsible

Quizice is operated by **Artem Tabenskii** ("we"). This policy explains how the Quizice iPhone app and its backend process information.

For privacy questions or requests concerning your data, contact [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). General technical support is also available through [GitHub Issues](https://github.com/tabenskii/Quizice/issues). GitHub issues are public: use email for personal information and data-deletion requests.

### Information used to provide the app

**Game Center and your Quizice account.** When you authenticate through Apple's Game Center, the app sends a Game Center player identifier and signed verification information to our backend. The backend creates or finds an internal Quizice user record and issues a session token. This supports authentication, progress synchronization and access to AI quizzes. Quizice does not receive your Apple Account password or email address from this process. Apple processes Game Center information separately under its [Game Center privacy notice](https://www.apple.com/legal/privacy/data/en/game-center/).

**Gameplay and preferences.** With an authenticated backend session, we store quiz completions, scores, completion times, question identifiers, selected answers or timeouts, answer times, progress and favorite themes. We also store whether a completed round used the accessibility mode that disables the timer, so that results from different modes can be handled correctly. These records are associated with your internal Quizice user identifier. AI usage counts are associated with the same identifier to enforce generation limits.

**AI topics.** When you request an AI quiz, your topic, selected language, difficulty and question count are sent through our backend to **Yandex AI** to generate questions. Do not include passwords, contact details or other private information in a topic. Our current generation flow does not save the topic or generated quiz as a permanent backend catalog entry. Operational logs record metadata such as topic length, generation settings, request identifiers and the internal Quizice user identifier, rather than the topic text. Requests to the AI provider ask it not to store the response and disable provider data logging; these settings do not constitute a guarantee about all processing performed by the provider. See the [Yandex Privacy Policy](https://yandex.com/legal/confidential/en/).

**Technical operation.** Requests to online services involve an IP address and technical connection information. Backend logs record the requested endpoint, response status, request identifier and timing. This information helps operate the service and diagnose failures.

**Support.** If you contact us, we receive your email address and the information you choose to include. We use it to respond and investigate your request. Please avoid sending passwords, session tokens or unnecessary personal information.

### Analytics and crash reports

Quizice uses **AppMetrica**, including crash reporting based on KSCrash, to understand app usage and diagnose problems. Information includes app launches and screen views, interactions with themes and settings, quiz progress and results, AI-generation status and timing, network performance, crash and error information, app and operating-system versions, device characteristics and SDK installation/device identifiers. AppMetrica also processes the connection IP address and can derive an approximate country from it.

Our analytics events do not include the text of AI topics, quiz questions or selected answer text. We do not send the backend Quizice user identifier as an AppMetrica profile identifier. AppMetrica nevertheless uses persistent device and installation identifiers, including Apple's identifier for vendor (IDFV) and its own identifiers. These associate usage, diagnostic and device information with a device or installation, including across sessions. This data is linked through the device and is not anonymous.

AppMetrica's GPS/location collection, advertising identifier collection and automatic purchase tracking are disabled in Quizice. Disabling GPS collection does not prevent country-level estimation from the IP address. There is no in-app analytics opt-out in the current version. Analytics may operate when you use the app without signing in to Game Center.

Further information: [AppMetrica data categories](https://yandex.com/support/appmetrica-io/en/data-security/app-privacy-apple), [location handling](https://yandex.com/support/appmetrica-io/en/data-collection/geo) and [Yandex Privacy Policy](https://yandex.com/legal/confidential/en/).

### Information kept on your device

Quizice stores settings, onboarding choices, favorites, cached catalog data, local statistics and pending synchronization records on your device. A backend session token is stored in the iOS Keychain. Device-motion readings used to animate theme cards are processed locally and are not sent by Quizice to the backend or analytics.

Deleting the app normally removes its app-container data, but does not itself delete server records. Keychain items and device backups may persist according to iOS behavior and your backup settings. Signing out of Game Center does not delete the Quizice backend account.

### Services, advertising and security

We use **Yandex Cloud** to host the backend and database, **Yandex AI** for requested quiz generation, **AppMetrica** for analytics and diagnostics, and **Apple Game Center** for authentication. Information is sent to these services for the purposes described above. Our backend database is hosted in Yandex Cloud's Russia region; the providers' own processing locations and practices are described in their policies and service terms.

Quizice has no advertising and does not use app data for tracking across other companies' apps or websites for advertising purposes. The current version has no active in-app purchase flow.

The app uses HTTPS for backend requests. Backend session tokens are stored as hashes on the server and in the Keychain on the device. These measures reduce risk but do not make any network or storage system risk-free.

### Retention and your requests

Account records, gameplay history, preferences and AI usage records have no fixed automatic expiry. In app versions with account deletion, Settings can request removal of the active Quizice account, every backend session, synchronized statistics and completed games, question progress and answer events, favorites in every language, and AI usage counters. The server confirms completion only after that deletion commits. The app reports completion after server confirmation and successful local cleanup. If confirmation is lost, repeating the same deletion request can recover its result.

After deletion, an ordinary Game Center sign-in does not automatically recreate the account. Choosing **Create New Account** explicitly creates a new account with a new internal identifier and no old progress, favorites or AI usage. Removing Quizice data does not delete your Apple, Game Center, Yandex or GitHub account.

We retain two minimal records separately from the deleted account. A **deletion receipt** contains the deletion request identifier, a cryptographic hash of the accepted session token and the completion time. It contains no plaintext token, Game Center identifier or gameplay data. Receipts are retained indefinitely in the current implementation so that a pending request can be safely confirmed even after its session is removed. An **account recreation suppression record** contains a keyed cryptographic digest (HMAC) of the backend identity, the key version and deletion time. It contains no plaintext Game Center identifier or gameplay data and is retained until you explicitly create a new account; otherwise it has no automatic expiry. This prevents background sign-ins from undoing deletion. These records are retained technical data, not a claim of complete anonymization.

Other records have separate handling. The shared Game Center signature replay ledger contains signature fingerprints and consumption times, has no user-account key, and is retained indefinitely by the current backend to prevent reuse of authentication signatures. Backend diagnostic error records are not cascading account records; cleanup uses an age threshold of 90 days and runs during deployment preparation, so records can remain longer between cleanups. Cloud operational logs can contain an internal Quizice user identifier in AI-generation metadata; account deletion does not erase these logs. Their retention is controlled separately by the cloud logging configuration, and no fixed period is promised here.

The production database is configured to retain backups for **7 days**. Deleting an active account does not immediately erase existing backups. If a backup is restored, subsequent account deletions must be reapplied before restored data is served.

Account deletion does not automatically delete AppMetrica analytics, crash reports or records held independently by Apple or Yandex AI. The backend has no AppMetrica deletion integration or mapping from a Quizice account to an AppMetrica profile. AppMetrica data is associated with device and installation identifiers as described above, and analytics can continue when the app is used without a Quizice account. Provider retention and deletion procedures apply separately; we do not promise immediate erasure or a single retention period for these records.

You can request information about, correction of or deletion of your Quizice data by emailing [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Include "Quizice data request" in the subject and describe your request. We may need additional information to locate the correct record and verify that it belongs to you; do not send your Apple password or a session token. We will explain the available action and any information that cannot be removed as part of the request, including whether a separate provider request is needed.

If the deletion service is unavailable or confirmation cannot be obtained, the app shows an error; you can also use the email address above. Sending an email does not itself perform automatic deletion.

### Changes

We may update this policy as Quizice or its data handling changes. The date at the top identifies the current version. Contact the email above if you have a question about a change.

## Русский

### Кто отвечает за обработку

Оператор Quizice — **Artem Tabenskii** («мы»). Эта политика описывает обработку информации приложением Quizice для iPhone и его сервером.

Вопросы о конфиденциальности и запросы, связанные с вашими данными, направляйте на [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Для обычных технических вопросов также доступны [GitHub Issues](https://github.com/tabenskii/Quizice/issues). Обращения в GitHub публичны: личную информацию и запросы на удаление данных отправляйте по электронной почте.

### Данные для работы приложения

**Game Center и аккаунт Quizice.** При авторизации через Apple Game Center приложение передаёт нашему серверу идентификатор игрока Game Center и подписанные данные для проверки подлинности. Сервер создаёт или находит внутреннюю запись пользователя Quizice и выдаёт токен сессии. Это необходимо для авторизации, синхронизации прогресса и доступа к AI-квизам. В ходе этого процесса Quizice не получает пароль или адрес электронной почты вашего Apple Account. Apple отдельно обрабатывает данные Game Center в соответствии со своим [уведомлением о конфиденциальности Game Center](https://www.apple.com/legal/privacy/data/en/game-center/).

**Игра и предпочтения.** При наличии авторизованной серверной сессии мы храним завершённые игры, результаты, время завершения, идентификаторы вопросов, выбранные ответы или пропуски по таймеру, время ответа, прогресс и избранные темы. Также сохраняется признак того, что игра проходила в режиме доступности с отключённым таймером, чтобы корректно учитывать результаты разных режимов. Эти записи связаны с внутренним идентификатором пользователя Quizice. С тем же идентификатором связаны счётчики использования AI для соблюдения лимитов генерации.

**Темы для AI.** Когда вы запрашиваете AI-квиз, текст темы, выбранный язык, сложность и число вопросов передаются через наш сервер в **Yandex AI** для создания вопросов. Не включайте в тему пароли, контактные данные и другую личную информацию. В текущем сценарии генерации тема и полученный квиз не сохраняются как постоянная запись серверного каталога. В технические журналы попадают метаданные: длина темы, настройки генерации, идентификаторы запросов и внутренний идентификатор пользователя Quizice, а не текст темы. Запросы к AI-провайдеру содержат настройки, запрещающие сохранение ответа и отключающие журналирование данных у провайдера; эти настройки не являются гарантией отсутствия любой другой обработки на стороне провайдера. Подробнее — в [политике конфиденциальности Яндекса](https://yandex.com/legal/confidential/).

**Техническая работа.** При обращении к онлайн-сервисам обрабатываются IP-адрес и технические сведения о соединении. Серверные журналы содержат адрес вызываемого метода, статус ответа, идентификатор запроса и длительность. Эти сведения нужны для работы сервиса и диагностики сбоев.

**Поддержка.** При обращении к нам мы получаем ваш адрес электронной почты и сведения, которые вы включили в сообщение. Они используются для ответа и разбора обращения. Не отправляйте пароли, токены сессии и лишние личные данные.

### Аналитика и отчёты о сбоях

Quizice использует **AppMetrica**, включая отчёты о сбоях на основе KSCrash, для анализа использования и диагностики проблем. Обрабатываются запуски приложения и просмотры экранов, действия с темами и настройками, ход и результаты игр, статусы и длительность AI-генерации, сетевые показатели, сведения о сбоях и ошибках, версии приложения и операционной системы, характеристики устройства и идентификаторы установки или устройства, используемые SDK. AppMetrica также обрабатывает IP-адрес соединения и может определять по нему примерную страну.

Наши аналитические события не содержат текстов AI-тем, вопросов или выбранных ответов. Мы не передаём внутренний идентификатор пользователя Quizice в качестве идентификатора профиля AppMetrica. При этом AppMetrica использует постоянные идентификаторы устройства и установки, включая идентификатор поставщика Apple (IDFV) и собственные идентификаторы. Они связывают сведения об использовании, диагностике и устройстве с устройством или установкой, в том числе между сеансами. Эти данные связаны через устройство и не являются анонимными.

В Quizice отключены сбор GPS-геолокации, рекламного идентификатора и автоматический учёт покупок AppMetrica. Отключение GPS не исключает определения страны по IP-адресу. В текущей версии нет настройки отключения аналитики внутри приложения. Аналитика может работать и без входа в Game Center.

Подробнее: [категории данных AppMetrica](https://yandex.com/support/appmetrica-io/en/data-security/app-privacy-apple), [определение местоположения](https://yandex.com/support/appmetrica-io/en/data-collection/geo) и [политика конфиденциальности Яндекса](https://yandex.com/legal/confidential/).

### Данные на устройстве

Quizice хранит на устройстве настройки, результаты первоначальной настройки, избранное, кэш каталога, локальную статистику и записи, ожидающие синхронизации. Токен серверной сессии хранится в iOS Keychain. Показания движения устройства для анимации карточек тем обрабатываются локально и не отправляются приложением на сервер или в аналитику.

Удаление приложения обычно удаляет данные из его контейнера, но само по себе не удаляет серверные записи. Элементы Keychain и резервные копии устройства могут сохраняться в соответствии с поведением iOS и вашими настройками резервного копирования. Выход из Game Center не удаляет серверный аккаунт Quizice.

### Сервисы, реклама и защита

Мы используем **Yandex Cloud** для сервера и базы данных, **Yandex AI** для генерации запрошенных квизов, **AppMetrica** для аналитики и диагностики и **Apple Game Center** для авторизации. Сведения передаются этим сервисам для описанных выше целей. Наша серверная база данных размещена в российском регионе Yandex Cloud; места и порядок собственной обработки данных провайдерами описываются их политиками и условиями сервисов.

В Quizice нет рекламы. Приложение не использует данные для рекламного отслеживания пользователей между приложениями и сайтами других компаний. В текущей версии нет действующего сценария встроенных покупок.

Запросы приложения к серверу передаются по HTTPS. На сервере токены сессий хранятся в виде хешей, на устройстве — в Keychain. Эти меры снижают риски, но не означают полного отсутствия рисков при передаче или хранении данных.

### Хранение и ваши запросы

У аккаунтов, игровой истории, предпочтений и записей об использовании AI нет фиксированного срока автоматического удаления. В версиях приложения с удалением аккаунта из настроек можно запросить удаление действующего аккаунта Quizice, всех серверных сессий, синхронизированной статистики и завершённых игр, прогресса по вопросам и событий ответов, избранного на всех языках и счётчиков AI. Сервер подтверждает завершение только после фиксации удаления. Приложение сообщает об успехе после подтверждения сервера и успешной локальной очистки. Если подтверждение потеряно, повтор того же запроса позволяет получить его результат.

После удаления обычный вход через Game Center не создаёт аккаунт автоматически. Только явный выбор **«Создать новый аккаунт»** создаёт аккаунт с новым внутренним идентификатором, без прежнего прогресса, избранного и расхода AI. Удаление данных Quizice не удаляет ваши аккаунты Apple, Game Center, Яндекса или GitHub.

Отдельно от удалённого аккаунта сохраняются две минимальные записи. **Подтверждение удаления** содержит идентификатор запроса, криптографический хеш принятого токена сессии и время завершения. В нём нет открытого токена, идентификатора Game Center или игровых данных. В текущей реализации подтверждения хранятся бессрочно, чтобы безопасно подтвердить ожидающий запрос даже после удаления сессии. **Запись блокировки автоматического создания аккаунта** содержит криптографический отпечаток серверного идентификатора с секретным ключом (HMAC), версию ключа и время удаления. В ней нет открытого идентификатора Game Center или игровых данных. Она хранится до вашего явного создания нового аккаунта; иначе автоматического срока удаления нет. Это предотвращает восстановление аккаунта фоновыми входами. Это сохраняемые технические данные, а не заявление о полном обезличивании.

У остальных записей отдельный порядок хранения. Общий журнал защиты от повторного использования подписей Game Center содержит отпечатки подписей и время их использования, не имеет ключа связи с аккаунтом и в текущем сервере хранится бессрочно. Диагностические записи ошибок не удаляются каскадно вместе с аккаунтом: очистка использует возрастной порог 90 дней и запускается при подготовке развёртывания, поэтому между очистками записи могут храниться дольше. Облачные технические журналы могут содержать внутренний идентификатор пользователя Quizice в метаданных AI-генерации; удаление аккаунта не стирает эти журналы. Их хранение определяется отдельной настройкой облачного журналирования; фиксированный срок здесь не обещается.

Для рабочей базы данных настроено хранение резервных копий **7 дней**. Удаление действующего аккаунта не стирает уже созданные копии немедленно. При восстановлении из копии последующие удаления аккаунтов должны быть применены повторно до предоставления восстановленных данных пользователям.

Удаление аккаунта не удаляет автоматически аналитику и отчёты о сбоях AppMetrica или записи, самостоятельно обрабатываемые Apple и Yandex AI. У сервера нет интеграции удаления AppMetrica или соответствия между аккаунтом Quizice и профилем AppMetrica. Данные AppMetrica связаны с идентификаторами устройства и установки, как описано выше; аналитика может продолжать работать при использовании приложения без аккаунта Quizice. Сроки хранения и процедуры удаления провайдеров действуют отдельно; мы не обещаем немедленного стирания или единого срока для этих записей.

Запросить сведения о своих данных Quizice, их исправление или удаление можно по адресу [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Укажите в теме письма «Запрос о данных Quizice» и опишите запрос. Для поиска нужной записи и проверки её принадлежности мы можем запросить дополнительные сведения; не отправляйте пароль Apple или токен сессии. В ответе мы сообщим о доступных действиях и данных, которые нельзя удалить в рамках запроса, в том числе о необходимости отдельного обращения к провайдеру.

Если сервис удаления недоступен или подтверждение не получено, приложение показывает ошибку; также можно обратиться по указанной выше электронной почте. Отправка письма сама по себе не запускает автоматическое удаление.

### Изменения

Мы можем обновлять политику при изменении Quizice или порядка обработки данных. Дата в начале документа обозначает актуальную версию. Вопросы об изменениях можно направить на указанный выше адрес электронной почты.
