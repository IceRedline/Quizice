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

The current backend does not have a fixed automatic deletion period for Quizice account records, gameplay history, preferences or AI usage records. These records may remain until removed by the operator. Diagnostic logs, backups and records held by service providers have separate retention settings; this policy does not promise a single retention period for all of them. Deleting an active record does not necessarily immediately remove copies in backups or provider systems.

You can request information about, correction of or deletion of your Quizice data by emailing [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Include "Quizice data request" in the subject and describe your request. We may need additional information to locate the correct record and verify that it belongs to you; do not send your Apple password or a session token. We will explain the available action and any information that cannot be removed as part of the request.

In app versions that include an account-deletion control, you can send a deletion request from Settings. The app reports completion only after the server confirms deletion and local cleanup succeeds. If the service is unavailable or confirmation cannot be obtained, the app shows an error; you can also request deletion by emailing [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Sending an email does not itself perform automatic deletion. Removing Quizice data does not delete your Apple, Game Center, Yandex or GitHub account.

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

В текущей серверной реализации не установлен фиксированный срок автоматического удаления аккаунтов Quizice, игровой истории, предпочтений и записей об использовании AI. Они могут сохраняться до удаления оператором. У диагностических журналов, резервных копий и данных провайдеров отдельные настройки хранения; эта политика не обещает единого срока для всех таких данных. Удаление действующей записи не обязательно означает немедленное удаление её копий из резервных копий или систем провайдеров.

Запросить сведения о своих данных Quizice, их исправление или удаление можно по адресу [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Укажите в теме письма «Запрос о данных Quizice» и опишите запрос. Для поиска нужной записи и проверки её принадлежности мы можем запросить дополнительные сведения; не отправляйте пароль Apple или токен сессии. В ответе мы сообщим о доступных действиях и данных, которые нельзя удалить в рамках запроса.

В версиях приложения с кнопкой удаления аккаунта запрос можно отправить из настроек. Приложение сообщает о завершении только после подтверждения удаления сервером и успешной локальной очистки. Если сервис недоступен или подтверждение не получено, приложение показывает ошибку; запросить удаление также можно по адресу [tabenskii_dev@icloud.com](mailto:tabenskii_dev@icloud.com). Отправка письма сама по себе не запускает автоматическое удаление. Удаление данных Quizice не удаляет ваши аккаунты Apple, Game Center, Яндекса или GitHub.

### Изменения

Мы можем обновлять политику при изменении Quizice или порядка обработки данных. Дата в начале документа обозначает актуальную версию. Вопросы об изменениях можно направить на указанный выше адрес электронной почты.
