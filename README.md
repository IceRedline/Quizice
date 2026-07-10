# Quizice

### Quiz-game

A quiz app where you can train answering questions on different topics. 

Flexibile and scalable: it can be easily adapted to any topic, be it school tests, interview preparation simulators or just entertaining quizzes.

The quiz includes themes:
- Music
- Tech
- Culture
- Politics

![Quizice Preview](https://github.com/user-attachments/assets/e84484ae-8833-4286-9b77-0fbf0b3b68fa)

> Swift, UIKit, MVP, SwiftData

## Yandex AI Studio (Debug only)

The AI quiz generator calls the saved Yandex AI Studio agent only in Debug builds.

1. In Agent Atelier, set the agent response format to JSON Schema using
   [`docs/yandex-ai-quiz-schema.json`](docs/yandex-ai-quiz-schema.json).
2. [Create an AI Studio API key](https://aistudio.yandex.ru/docs/ru/ai-studio/operations/get-api-key.html)
   and keep it outside the repository.
3. In Xcode, open **Product → Scheme → Manage Schemes…**, duplicate `Quizice`
   as `Quizice Local`, and make sure the duplicate is not shared. Its file will
   live under the git-ignored `xcuserdata` directory.
4. Edit the local scheme, open **Run → Arguments**, and add the enabled
   environment variable `YANDEX_AI_API_KEY` with the API-key secret as its value.

The key is intentionally read from the Xcode launch environment and is never
stored in source control. Release builds do not perform direct AI Studio calls;
use an authenticated backend proxy before enabling this feature in production.
