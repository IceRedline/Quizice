import XCTest
@testable import Quizice

@MainActor
final class CrossScreenVisualStateTests: XCTestCase {
    override func setUp() {
        super.setUp()
        AppLocalizationStore.shared.languagePreference = .russian
        resetQuestionFactoryState()
        UserDefaults.standard.set(AppDesignStyle.clean.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        // Pin the clean color scheme so shadow/surface assertions are deterministic
        // regardless of the host simulator's system light/dark appearance.
        UserDefaults.standard.set(CleanColorSchemePreference.light.rawValue, forKey: AppAppearanceStore.Keys.cleanColorScheme)
        UIView.setAnimationsEnabled(false)
    }

    override func tearDown() {
        UIView.setAnimationsEnabled(true)
        resetQuestionFactoryState()
        UserDefaults.standard.removeObject(forKey: AppLocalizationStore.Keys.language)
        super.tearDown()
    }

    func testDescriptionScreenExposesPolishedLayoutAnchorsAndControls() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(themeLabel.text, "Музыка")
        XCTAssertEqual(descriptionLabel.text, "Проверьте знания о любимых исполнителях и песнях.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(pickerView.layer.cornerRadius, 22)
        XCTAssertEqual(startButton.title(for: .normal), L10n.Common.start)
        XCTAssertEqual(startButton.layer.cornerRadius, 24)
        XCTAssertGreaterThan(startButton.layer.shadowOpacity, 0)
        XCTAssertNotNil(backButton.image(for: .normal))
        XCTAssertEqual(backButton.accessibilityLabel, L10n.Common.back)
        XCTAssertGreaterThanOrEqual(backButton.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(backButton.bounds.height, 44)
        XCTAssertEqual(backButton.layer.cornerRadius, 22)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
        XCTAssertFalse(startButton.isDescendant(of: cardView))
        XCTAssertFalse(backButton.isDescendant(of: cardView))
    }

    func testDescriptionScreenKeepsControlsReachableWithEmptyAndLongPresenterText() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "", themeDescription: String(repeating: "Очень длинное описание темы. ", count: 18))
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)

        XCTAssertEqual(themeLabel.text, "")
        XCTAssertFalse(descriptionLabel.text?.isEmpty ?? true)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertFalse(startButton.isDescendant(of: cardView))
        XCTAssertFalse(startButton.isDescendant(of: scrollView))
        XCTAssertFalse(backButton.isDescendant(of: cardView))
        XCTAssertEqual(
            cardView.bounds.maxY - pickerView.convert(pickerView.bounds, to: cardView).maxY,
            26,
            accuracy: 1
        )
        XCTAssertLessThanOrEqual(scrollView.frame.maxY, startButton.frame.minY)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
        XCTAssertFalse(pickerView.hasAmbiguousLayout)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
    }

    func testDescriptionCardGrowsWithContentInsteadOfUsingAFixedHeight() throws {
        let musicCardHeight = try descriptionCardHeight(
            themeName: "Музыка",
            themeDescription: "В данной викторине вам предстоит угадывать исполнителей и названия песен. Проверьте свои музыкальные знания, вспомните хиты разных эпох и получите удовольствие от путешествия по миру музыки."
        )
        let technologyCardHeight = try descriptionCardHeight(
            themeName: "Технологии",
            themeDescription: "Проверьте знания о гаджетах, языках программирования, компьютерной истории и цифровой культуре."
        )

        XCTAssertGreaterThan(musicCardHeight, technologyCardHeight)
    }

    func testDescriptionStartButtonStaysPinnedWhenCardContentGrows() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "Музыка", themeDescription: "Короткое описание.")
        viewController.view.layoutIfNeeded()

        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)
        let pinnedButtonY = startButton.frame.minY

        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: String(repeating: "Очень длинное описание темы должно прокручиваться независимо от кнопки запуска. ", count: 18)
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertEqual(startButton.frame.minY, pinnedButtonY, accuracy: 0.5)
        XCTAssertFalse(startButton.isDescendant(of: scrollView))
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
    }

    func testDescriptionStartFadesActionButtonsAndRoutesToQuestion() throws {
        let viewController = QuizDescriptionViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()

        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(startButton.alpha, 1)
        XCTAssertEqual(backButton.alpha, 1)

        startButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(startButton.alpha, 0)
        XCTAssertEqual(backButton.alpha, 0)
        XCTAssertEqual(router.showQuestionCallCount, 1)
    }

    func testQuestionScreenExposesPolishedLayoutAnchorsAndAnswerControls() {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionThemeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNumberLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerContainerView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionAnswersStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionScrollView") as? UIScrollView)

        let answerButtons = questionAnswerButtons(in: viewController)
        let cardView = viewController.view.descendant(withAccessibilityIdentifier: "questionCardView")
        let answersStackView = viewController.view.descendant(withAccessibilityIdentifier: "questionAnswersStackView")
        let transitionDestination = viewController as QuizCardSlideTransitionDestination
        let companionViewIDs = transitionDestination.cardSlideTransitionDestinationCompanionViews.compactMap { $0.accessibilityIdentifier }
        XCTAssertEqual(answerButtons.count, 4)
        XCTAssertEqual(companionViewIDs, ["questionThemeLabel", "questionNumberLabel"])
        XCTAssertTrue(answerButtons.allSatisfy(\.isEnabled))
        XCTAssertTrue(answerButtons.allSatisfy { $0.layer.cornerRadius >= 16 })
        XCTAssertTrue(answerButtons.allSatisfy { $0.backgroundColor == currentAppearance().answerDefaultColor })
        if let cardView, let answersStackView {
            XCTAssertEqual(
                cardView.bounds.maxY - answersStackView.convert(answersStackView.bounds, to: cardView).maxY,
                20,
                accuracy: 0.5
            )
        }

        let timerBar = viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView") as? UIProgressView
        assertColor(timerBar?.progressTintColor, equals: currentAppearance().accentColor)
        assertColor(timerBar?.tintColor, equals: currentAppearance().accentColor)
        XCTAssertEqual(timerBar?.accessibilityLabel, L10n.Question.timeRemaining)
        XCTAssertFalse(timerBar?.accessibilityValue?.isEmpty ?? true)
    }

    func testQuestionScreenFadesHeaderAndActionButtonsWhenShowingResult() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }

        let chromeViews = try [
            XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionThemeLabel")),
            XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNumberLabel")),
            XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton")),
            XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton"))
        ]

        XCTAssertTrue(chromeViews.allSatisfy { $0.alpha == 1 })

        viewController.showResults(QuizResultState(correctAnswers: 1, totalQuestions: 1))

        XCTAssertTrue(chromeViews.allSatisfy { $0.alpha == 0 })
        XCTAssertEqual(router.results, [QuizResultState(correctAnswers: 1, totalQuestions: 1)])
    }

    func testQuestionScreenUpdatesExistingCardWhenNextQuestionViewModelIsLoaded() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }

        let nextViewModel = QuizQuestionViewModel(
            themeName: "Визуальный тест",
            questionText: "Какой город называют Северной столицей?",
            questionNumberText: "Вопрос №2",
            answers: [
                QuizAnswerOption(id: "2-0", title: "Санкт-Петербург"),
                QuizAnswerOption(id: "2-1", title: "Москва"),
                QuizAnswerOption(id: "2-2", title: "Казань"),
                QuizAnswerOption(id: "2-3", title: "Новосибирск")
            ]
        )

        viewController.loadQuestionToView(nextViewModel)

        let questionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel") as? UILabel)
        let questionNumberLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNumberLabel") as? UILabel)
        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        let answerButtons = questionAnswerButtons(in: viewController)

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionAnswersStackView"))
        XCTAssertEqual(questionLabel.text, nextViewModel.questionText)
        XCTAssertEqual(questionNumberLabel.text, nextViewModel.questionNumberText)
        XCTAssertEqual(answerButtons.map { $0.title(for: .normal) }, nextViewModel.answers.map(\.title))
        XCTAssertFalse(nextButton.isEnabled)
    }

    func testQuestionNextButtonStaysPinnedWhenCardContentGrows() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Музыка",
                questionText: "Кто исполнитель?",
                questionNumberText: "Вопрос №1",
                answers: [
                    QuizAnswerOption(id: "short-0", title: "A"),
                    QuizAnswerOption(id: "short-1", title: "B"),
                    QuizAnswerOption(id: "short-2", title: "C"),
                    QuizAnswerOption(id: "short-3", title: "D")
                ]
            )
        )
        viewController.view.layoutIfNeeded()

        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionScrollView") as? UIScrollView)
        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        let pinnedButtonY = nextButton.frame.minY
        let shortCardHeight = cardView.frame.height

        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Музыка",
                questionText: String(repeating: "Это длинный текст вопроса, который должен переноситься на несколько строк. ", count: 3),
                questionNumberText: "Вопрос №2",
                answers: [
                    QuizAnswerOption(id: "long-0", title: "Очень длинный вариант ответа A"),
                    QuizAnswerOption(id: "long-1", title: "Очень длинный вариант ответа B"),
                    QuizAnswerOption(id: "long-2", title: "Очень длинный вариант ответа C"),
                    QuizAnswerOption(id: "long-3", title: "Очень длинный вариант ответа D")
                ]
            )
        )
        viewController.view.layoutIfNeeded()

        XCTAssertGreaterThan(cardView.frame.height, shortCardHeight)
        XCTAssertEqual(nextButton.frame.minY, pinnedButtonY, accuracy: 0.5)
        XCTAssertFalse(nextButton.isDescendant(of: scrollView))
        XCTAssertLessThanOrEqual(scrollView.frame.maxY, nextButton.frame.minY)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
    }

    func testQuestionScreenPreservesPresenterDrivenAnswerFeedbackState() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        let answerButtons = questionAnswerButtons(in: viewController)
        let correctButton = try XCTUnwrap(answerButtons.first { $0.title(for: .normal) == "Правильный ответ" })
        let wrongButtons = answerButtons.filter { $0 !== correctButton }

        correctButton.sendActions(for: .touchUpInside)

        XCTAssertTrue(answerButtons.allSatisfy { !$0.isEnabled })
        XCTAssertEqual(correctButton.backgroundColor, currentAppearance().answerDefaultColor)
        XCTAssertEqual(correctButton.layer.borderWidth, 4)
        assertColor(UIColor(cgColor: correctButton.layer.borderColor ?? UIColor.clear.cgColor), equals: currentAppearance().correctAnswerColor)
        XCTAssertTrue(wrongButtons.allSatisfy { $0.backgroundColor == currentAppearance().answerDefaultColor })
        XCTAssertTrue(wrongButtons.allSatisfy { $0.layer.borderWidth == 4 })
        for wrongButton in wrongButtons {
            assertColor(UIColor(cgColor: wrongButton.layer.borderColor ?? UIColor.clear.cgColor), equals: currentAppearance().wrongAnswerColor)
        }

        let timerBar = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView") as? UIProgressView)
        assertColor(timerBar.progressTintColor, equals: currentAppearance().correctAnswerColor)
        assertColor(timerBar.tintColor, equals: currentAppearance().correctAnswerColor)

        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        XCTAssertTrue(nextButton.isEnabled)
    }

    func testQuestionScreenTimeExpiredStateDisablesAnswersAndKeepsNextActionAvailable() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        viewController.showTimeExpired()

        let answerButtons = questionAnswerButtons(in: viewController)
        XCTAssertTrue(answerButtons.allSatisfy { !$0.isEnabled })

        let correctButton = try XCTUnwrap(answerButtons.first { $0.title(for: .normal) == "Правильный ответ" })
        XCTAssertEqual(correctButton.backgroundColor, currentAppearance().answerDefaultColor)
        XCTAssertEqual(correctButton.layer.borderWidth, 4)
        assertColor(UIColor(cgColor: correctButton.layer.borderColor ?? UIColor.clear.cgColor), equals: currentAppearance().correctAnswerColor)
        let wrongButtons = answerButtons.filter { $0 !== correctButton }
        XCTAssertTrue(wrongButtons.allSatisfy { $0.backgroundColor == currentAppearance().answerDefaultColor })
        XCTAssertTrue(wrongButtons.allSatisfy { $0.layer.borderWidth == 4 })
        for wrongButton in wrongButtons {
            assertColor(UIColor(cgColor: wrongButton.layer.borderColor ?? UIColor.clear.cgColor), equals: currentAppearance().wrongAnswerColor)
        }

        let timerBar = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView") as? UIProgressView)
        assertColor(timerBar.progressTintColor, equals: currentAppearance().wrongAnswerColor)
        assertColor(timerBar.tintColor, equals: currentAppearance().wrongAnswerColor)

        let nextButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton)
        XCTAssertTrue(nextButton.isEnabled)
    }

    func testQuestionExitCancellationKeepsQuizAndResumesTimer() throws {
        let (viewController, presenter, router, window) = makeExitConfirmationHarness()
        defer { window.isHidden = true }

        let closeButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton") as? UIButton)
        closeButton.sendActions(for: .touchUpInside)

        let alert = try XCTUnwrap(viewController.presentedViewController as? UIAlertController)
        XCTAssertEqual(alert.title, L10n.Question.exitAlertTitle)
        XCTAssertEqual(alert.message, L10n.Question.exitAlertMessage)
        XCTAssertEqual(alert.actions.map(\.title), [L10n.Common.no, L10n.Common.exit])
        XCTAssertEqual(presenter.pauseTimerCallCount, 1)

        viewController.cancelExitConfirmation()

        XCTAssertEqual(presenter.resumeTimerCallCount, 1)
        XCTAssertEqual(presenter.resetGameProgressCallCount, 0)
        XCTAssertEqual(router.closeQuestionCallCount, 0)
    }

    func testQuestionExitConfirmationResetsProgressAndReturnsHome() throws {
        let (viewController, presenter, router, window) = makeExitConfirmationHarness()
        defer { window.isHidden = true }

        let closeButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton") as? UIButton)
        closeButton.sendActions(for: .touchUpInside)
        XCTAssertNotNil(viewController.presentedViewController as? UIAlertController)

        viewController.confirmExitAndReturnToThemes()

        XCTAssertEqual(presenter.pauseTimerCallCount, 1)
        XCTAssertEqual(presenter.resumeTimerCallCount, 0)
        XCTAssertEqual(presenter.resetGameProgressCallCount, 1)
        XCTAssertEqual(router.closeQuestionCallCount, 1)
    }

    func testRadarQuestionFeedbackKeepsCorrectAnswerBrightAndDimsOtherAnswers() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        let appearance = currentAppearance()
        let answerButtons = questionAnswerButtons(in: viewController)
        let correctButton = try XCTUnwrap(answerButtons.first { $0.title(for: .normal) == "Правильный ответ" })
        let wrongButtons = answerButtons.filter { $0 !== correctButton }

        correctButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(correctButton.alpha, 1)
        XCTAssertEqual(correctButton.backgroundColor, appearance.answerDefaultColor)
        XCTAssertEqual(correctButton.layer.borderWidth, 4)
        assertColor(UIColor(cgColor: correctButton.layer.borderColor ?? UIColor.clear.cgColor), equals: appearance.accentColor)
        XCTAssertTrue(wrongButtons.allSatisfy { $0.alpha < 0.5 })
        XCTAssertTrue(wrongButtons.allSatisfy { $0.backgroundColor == appearance.answerDefaultColor })

        let timerBar = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView") as? UIProgressView)
        assertColor(timerBar.progressTintColor, equals: appearance.accentColor)
        assertColor(timerBar.tintColor, equals: appearance.accentColor)
    }

    func testResultScreenExposesDistinctReplayAndThemeActions() throws {
        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(
            resultText: "Ваш результат: 4/5",
            descriptionText: "Отличный текущий результат — можно начать новую попытку."
        )
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultScrollView") as? UIScrollView)

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let replayButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton") as? UIButton)
        let themesButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton") as? UIButton)

        XCTAssertEqual(resultLabel.text, "Ваш результат: 4/5")
        XCTAssertEqual(descriptionLabel.text, "Отличный текущий результат — можно начать новую попытку.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(resultLabel.numberOfLines, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(replayButton.title(for: .normal), L10n.Result.playAgain)
        XCTAssertEqual(themesButton.title(for: .normal), L10n.Result.toThemes)
        XCTAssertTrue(replayButton.isEnabled)
        XCTAssertTrue(themesButton.isEnabled)
        XCTAssertEqual(replayButton.layer.borderWidth, 1)
        XCTAssertGreaterThan(replayButton.layer.shadowOpacity, 0)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testResultActionsInvokeTheirDistinctRoutes() throws {
        resetQuestionFactoryState()

        let viewController = QuizResultViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(resultText: "0/0", descriptionText: "Нет данных текущей попытки")

        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let replayButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton") as? UIButton)
        let themesButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton") as? UIButton)

        replayButton.sendActions(for: .touchUpInside)
        themesButton.sendActions(for: .touchUpInside)

        XCTAssertEqual(resultLabel.text, "0/0")
        XCTAssertEqual(descriptionLabel.text, "Нет данных текущей попытки")
        XCTAssertTrue(QuizFactory.shared.themes?.isEmpty ?? true)
        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertEqual(router.replayQuizCallCount, 1)
        XCTAssertEqual(router.returnToThemesCallCount, 1)
    }

    func testStatisticsScreenExposesPolishedEmptyStateAndSafeRows() throws {
        let harness = makeStatisticsHarness()
        let viewController = StatisticsViewController(statisticsStore: harness.store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsScreen"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsTitleLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSubtitleLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsRowsStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        let emptyStateLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsEmptyStateLabel") as? UILabel)
        let playedRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzes"))
        let correctRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers"))
        let percentageRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentage"))
        let bestResultRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResult"))
        let playedValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzesValueLabel") as? UILabel)
        let correctValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel") as? UILabel)
        let percentageValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentageValueLabel") as? UILabel)
        let bestResultValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResultValueLabel") as? UILabel)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton") as? UIButton)

        XCTAssertFalse(emptyStateLabel.isHidden)
        XCTAssertEqual(playedValueLabel.text, "0")
        XCTAssertEqual(correctValueLabel.text, "0/0")
        XCTAssertEqual(percentageValueLabel.text, "0%")
        XCTAssertEqual(bestResultValueLabel.text, "0/0")
        XCTAssertEqual(playedRow.accessibilityValue, "0")
        XCTAssertEqual(correctRow.accessibilityValue, "0/0")
        XCTAssertEqual(percentageRow.accessibilityValue, "0%")
        XCTAssertEqual(bestResultRow.accessibilityValue, "0/0")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertNotNil(backButton.image(for: .normal))
        XCTAssertEqual(backButton.accessibilityLabel, L10n.Common.back)
        XCTAssertGreaterThanOrEqual(backButton.bounds.width, 44)
        XCTAssertGreaterThanOrEqual(backButton.bounds.height, 44)
        XCTAssertEqual(backButton.layer.cornerRadius, 22)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testStatisticsScreenRendersRecordedSummaryAndHidesEmptyCopy() throws {
        let harness = makeStatisticsHarness()
        harness.store.recordAttempt(correctAnswers: 3, totalQuestions: 5)
        harness.store.recordAttempt(correctAnswers: 5, totalQuestions: 5)

        let viewController = StatisticsViewController(statisticsStore: harness.store)
        viewController.loadViewIfNeeded()
        viewController.viewWillAppear(false)

        let emptyStateLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsEmptyStateLabel") as? UILabel)
        let playedRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzes"))
        let correctRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers"))
        let percentageRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentage"))
        let bestResultRow = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResult"))
        let playedValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPlayedQuizzesValueLabel") as? UILabel)
        let correctValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel") as? UILabel)
        let percentageValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsPercentageValueLabel") as? UILabel)
        let bestResultValueLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "statisticsBestResultValueLabel") as? UILabel)

        XCTAssertTrue(emptyStateLabel.isHidden)
        XCTAssertEqual(playedValueLabel.text, "2")
        XCTAssertEqual(correctValueLabel.text, "8/10")
        XCTAssertEqual(percentageValueLabel.text, "80%")
        XCTAssertEqual(bestResultValueLabel.text, "5/5")
        XCTAssertEqual(playedRow.accessibilityValue, "2")
        XCTAssertEqual(correctRow.accessibilityValue, "8/10")
        XCTAssertEqual(percentageRow.accessibilityValue, "80%")
        XCTAssertEqual(bestResultRow.accessibilityValue, "5/5")
    }

    func testAllPolishedS03ScreensExposeCoreAnchorsAndControlSurfaces() throws {
        let descriptionViewController = QuizDescriptionViewController()
        descriptionViewController.loadViewIfNeeded()
        descriptionViewController.updateLabels(themeName: "Музыка", themeDescription: "Описание")

        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1
        let questionViewController = QuizQuestionViewController()
        questionViewController.loadViewIfNeeded()

        let resultViewController = QuizResultViewController()
        resultViewController.loadViewIfNeeded()
        resultViewController.updateResultLabels(resultText: "Ваш результат: 1/1", descriptionText: "Готово")

        let statisticsHarness = makeStatisticsHarness()
        let statisticsViewController = StatisticsViewController(statisticsStore: statisticsHarness.store)
        statisticsViewController.loadViewIfNeeded()
        statisticsViewController.viewWillAppear(false)

        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton"))
        XCTAssertNotNil(descriptionViewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionCloseButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultReplayButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultThemesButton"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton"))
    }

    func testCompactNavigationControlsExposeAtLeastFortyFourPointHitAreas() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let controllers: [(UIViewController, String)] = [
            (QuizDescriptionViewController(), "descriptionBackButton"),
            (QuizQuestionViewController(), "questionCloseButton"),
            (StatisticsViewController(statisticsStore: makeStatisticsHarness().store), "statisticsBackButton"),
            (QuizViewController(), "homeSettingsButton")
        ]

        for (viewController, identifier) in controllers {
            viewController.loadViewIfNeeded()
            viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()
            let control = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: identifier), identifier)
            XCTAssertGreaterThanOrEqual(control.bounds.width, 44, identifier)
            XCTAssertGreaterThanOrEqual(control.bounds.height, 44, identifier)
        }
    }

    private func descriptionCardHeight(themeName: String, themeDescription: String) throws -> CGFloat {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.updateLabels(themeName: themeName, themeDescription: themeDescription)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        return cardView.frame.height
    }

    private func questionAnswerButtons(in viewController: QuizQuestionViewController) -> [UIButton] {
        (1...4).compactMap { index in
            viewController.view.descendant(withAccessibilityIdentifier: "questionAnswerButton\(index)") as? UIButton
        }
    }

    private func makeExitConfirmationHarness() -> (
        viewController: QuizQuestionViewController,
        presenter: ExitConfirmationPresenterSpy,
        router: CrossScreenRouterSpy,
        window: UIWindow
    ) {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        let router = CrossScreenRouterSpy()
        viewController.router = router
        viewController.loadViewIfNeeded()
        viewController.presenter?.stopTimer()

        let presenter = ExitConfirmationPresenterSpy()
        presenter.view = viewController
        viewController.presenter = presenter

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        viewController.view.frame = window.bounds
        viewController.view.layoutIfNeeded()
        return (viewController, presenter, router, window)
    }

    private func assertColor(_ actual: UIColor?, equals expected: UIColor, file: StaticString = #filePath, line: UInt = #line) {
        guard let actual else {
            XCTFail("Expected color, got nil", file: file, line: line)
            return
        }

        let traitCollection = UITraitCollection(userInterfaceStyle: .light)
        let actualColor = actual.resolvedColor(with: traitCollection)
        let expectedColor = expected.resolvedColor(with: traitCollection)
        var actualRed: CGFloat = 0
        var actualGreen: CGFloat = 0
        var actualBlue: CGFloat = 0
        var actualAlpha: CGFloat = 0
        var expectedRed: CGFloat = 0
        var expectedGreen: CGFloat = 0
        var expectedBlue: CGFloat = 0
        var expectedAlpha: CGFloat = 0

        XCTAssertTrue(actualColor.getRed(&actualRed, green: &actualGreen, blue: &actualBlue, alpha: &actualAlpha), file: file, line: line)
        XCTAssertTrue(expectedColor.getRed(&expectedRed, green: &expectedGreen, blue: &expectedBlue, alpha: &expectedAlpha), file: file, line: line)
        XCTAssertEqual(actualRed, expectedRed, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualGreen, expectedGreen, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualBlue, expectedBlue, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualAlpha, expectedAlpha, accuracy: 0.001, file: file, line: line)
    }

    private func resetQuestionFactoryState() {
        QuizFactory.shared.themes = []
        QuizFactory.shared.chosenTheme = nil
        QuizFactory.shared.questionsCount = 0
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.cleanColorScheme)
    }

    private func currentAppearance() -> AppAppearance {
        AppAppearanceStore.shared.appearance(compatibleWith: UITraitCollection(userInterfaceStyle: .light))
    }

    private func makeQuestionTheme() -> ThemeModel {
        let question = QuizQuestion(
            question: "Какой ответ должен подсветиться как верный?",
            answers: ["Правильный ответ", "Ошибочный ответ 1", "Ошибочный ответ 2", "Ошибочный ответ 3"],
            correctAnswer: "Правильный ответ"
        )

        return ThemeModel(
            quizTheme: QuizTheme(
                id: "visual_test",
                theme: "Визуальный тест",
                themeDescription: "Тема для проверки вопросного экрана",
                questions: [question]
            )
        )
    }

    private func makeStatisticsHarness() -> (store: StatisticsStore, defaults: UserDefaults, suiteName: String) {
        let suiteName = "CrossScreenVisualStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (StatisticsStore(userDefaults: defaults), defaults, suiteName)
    }
}

private final class CrossScreenRouterSpy: QuizRouting {
    private(set) var results: [QuizResultState] = []
    private(set) var showQuestionCallCount = 0
    private(set) var closeQuestionCallCount = 0
    private(set) var replayQuizCallCount = 0
    private(set) var returnToThemesCallCount = 0

    func showDescription() {}
    func showQuestion() { showQuestionCallCount += 1 }
    func showResult(_ result: QuizResultState) { results.append(result) }
    func showStatistics() {}
    func showAIThemeCreation() {}
    func showSettings() {}
    func closeDescription() {}
    func closeStatistics() {}
    func closeQuestion() { closeQuestionCallCount += 1 }
    func replayQuiz() { replayQuizCallCount += 1 }
    func returnToThemes() { returnToThemesCallCount += 1 }
}

private final class ExitConfirmationPresenterSpy: QuizQuestionPresenterProtocol {
    var view: QuizQuestionViewControllerProtocol?
    var correctAnswers = 0
    var questionsTotalCount: Int? = 1
    var currentProgress: Float = 0.6
    private(set) var pauseTimerCallCount = 0
    private(set) var resumeTimerCallCount = 0
    private(set) var resetGameProgressCallCount = 0

    func viewDidLoad() {}
    func startTimer() {}
    func pauseTimer() { pauseTimerCallCount += 1 }
    func resumeTimer() { resumeTimerCallCount += 1 }
    func stopTimer() {}
    func loadQuestion() {}
    func checkQuestionNumberAndProceed() {}
    func answerFeedback(for optionID: String) -> QuizAnswerFeedback { .normal }
    func checkAnswer(optionID: String) {}
    func updateQuizState(isCorrect: Bool) {}
    func resetGameProgress() { resetGameProgressCallCount += 1 }
}

private extension UIView {
    func descendant(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier {
            return self
        }

        for subview in subviews {
            if let match = subview.descendant(withAccessibilityIdentifier: identifier) {
                return match
            }
        }

        return nil
    }
}
