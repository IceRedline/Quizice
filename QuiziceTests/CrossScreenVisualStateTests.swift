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

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView"))
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
        XCTAssertEqual(backButton.title(for: .normal), L10n.Common.back)
        XCTAssertEqual(backButton.layer.cornerRadius, 22)
        XCTAssertEqual(backButton.layer.borderWidth, 1)
    }

    func testDescriptionScreenKeepsControlsReachableWithEmptyAndLongPresenterText() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "", themeDescription: String(repeating: "Очень длинное описание темы. ", count: 18))
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel") as? UILabel)
        let pickerView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionQuestionCountPicker") as? UIPickerView)
        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let backButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionBackButton") as? UIButton)

        XCTAssertEqual(themeLabel.text, "")
        XCTAssertFalse(descriptionLabel.text?.isEmpty ?? true)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertTrue(scrollView.alwaysBounceVertical)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
        XCTAssertFalse(pickerView.hasAmbiguousLayout)
        XCTAssertTrue(startButton.isEnabled)
        XCTAssertTrue(backButton.isEnabled)
    }

    func testQuestionScreenExposesPolishedLayoutAnchorsAndAnswerControls() {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()

        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionRootView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionThemeLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNumberLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerContainerView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionAnswersStackView"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton"))
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "questionBackButton"))

        let answerButtons = questionAnswerButtons(in: viewController)
        XCTAssertEqual(answerButtons.count, 4)
        XCTAssertTrue(answerButtons.allSatisfy(\.isEnabled))
        XCTAssertTrue(answerButtons.allSatisfy { $0.layer.cornerRadius >= 16 })
        XCTAssertTrue(answerButtons.allSatisfy { $0.backgroundColor == currentAppearance().answerDefaultColor })

        let timerBar = viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView") as? UIProgressView
        assertColor(timerBar?.progressTintColor, equals: currentAppearance().accentColor)
        assertColor(timerBar?.tintColor, equals: currentAppearance().accentColor)
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

    func testResultScreenExposesPolishedCurrentAttemptAnchorsAndPrimaryRestartControl() throws {
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
        XCTAssertNotNil(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton"))

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let restartButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton") as? UIButton)

        XCTAssertEqual(resultLabel.text, "Ваш результат: 4/5")
        XCTAssertEqual(descriptionLabel.text, "Отличный текущий результат — можно начать новую попытку.")
        XCTAssertEqual(cardView.layer.cornerRadius, 30)
        XCTAssertEqual(cardView.layer.borderWidth, 1)
        XCTAssertGreaterThan(cardView.layer.shadowOpacity, 0)
        XCTAssertEqual(resultLabel.numberOfLines, 0)
        XCTAssertEqual(descriptionLabel.numberOfLines, 0)
        XCTAssertEqual(restartButton.title(for: .normal), L10n.Result.restart)
        XCTAssertTrue(restartButton.isEnabled)
        XCTAssertEqual(restartButton.layer.cornerRadius, 24)
        XCTAssertEqual(restartButton.layer.borderWidth, 1)
        XCTAssertGreaterThan(restartButton.layer.shadowOpacity, 0)
        XCTAssertFalse(viewController.view.hasAmbiguousLayout)
    }

    func testResultScreenLoadsWithoutStatisticsHistoryAndKeepsRestartActionSafelyInspectible() throws {
        resetQuestionFactoryState()

        let viewController = QuizResultViewController()
        viewController.loadViewIfNeeded()
        viewController.updateResultLabels(resultText: "0/0", descriptionText: "Нет данных текущей попытки")

        let resultLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultScoreLabel") as? UILabel)
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultDescriptionLabel") as? UILabel)
        let restartButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton") as? UIButton)
        let registeredActions = restartButton.actions(forTarget: viewController, forControlEvent: .touchUpInside) ?? []

        XCTAssertEqual(resultLabel.text, "0/0")
        XCTAssertEqual(descriptionLabel.text, "Нет данных текущей попытки")
        XCTAssertTrue(QuizFactory.shared.themes?.isEmpty ?? true)
        XCTAssertNil(QuizFactory.shared.chosenTheme)
        XCTAssertTrue(registeredActions.contains("backButtonTapped"))
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
        XCTAssertEqual(backButton.title(for: .normal), L10n.Common.back)
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
        XCTAssertNotNil(questionViewController.view.descendant(withAccessibilityIdentifier: "questionBackButton"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultCardView"))
        XCTAssertNotNil(resultViewController.view.descendant(withAccessibilityIdentifier: "resultRestartButton"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsSummaryCardView"))
        XCTAssertNotNil(statisticsViewController.view.descendant(withAccessibilityIdentifier: "statisticsBackButton"))
    }

    private func questionAnswerButtons(in viewController: QuizQuestionViewController) -> [UIButton] {
        (1...4).compactMap { index in
            viewController.view.descendant(withAccessibilityIdentifier: "questionAnswerButton\(index)") as? UIButton
        }
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
            correctAnswer: "Правильный ответ",
            explanation: "Проверяем визуальное состояние ответа."
        )

        return ThemeModel(
            quizTheme: QuizTheme(
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
