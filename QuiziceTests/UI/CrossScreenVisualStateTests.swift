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

    func testDescriptionCardKeepsStableSizeAcrossThemeDescriptions() throws {
        let musicCardHeight = try descriptionCardHeight(
            themeName: "Музыка",
            themeDescription: "В данной викторине вам предстоит угадывать исполнителей и названия песен. Проверьте свои музыкальные знания, вспомните хиты разных эпох и получите удовольствие от путешествия по миру музыки."
        )
        let technologyCardHeight = try descriptionCardHeight(
            themeName: "Технологии",
            themeDescription: "Проверьте знания о гаджетах, языках программирования, компьютерной истории и цифровой культуре."
        )

        XCTAssertEqual(musicCardHeight, technologyCardHeight, accuracy: 0.5)
        XCTAssertEqual(musicCardHeight, 510, accuracy: 0.5)
    }

    func testDescriptionTextIsCenteredBetweenThemeNameAndQuestionCountLabel() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: "Проверьте знания о любимых исполнителях и песнях."
        )
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let themeLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionThemeNameLabel"))
        let descriptionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionTextLabel"))
        let questionCountLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionPickerCaptionLabel"))
        let themeFrame = themeLabel.convert(themeLabel.bounds, to: cardView)
        let descriptionFrame = descriptionLabel.convert(descriptionLabel.bounds, to: cardView)
        let questionCountFrame = questionCountLabel.convert(questionCountLabel.bounds, to: cardView)
        let availableGapMidY = (themeFrame.maxY + questionCountFrame.minY) / 2

        XCTAssertEqual(descriptionFrame.midY, availableGapMidY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(descriptionFrame.minY - themeFrame.maxY, 32)
        XCTAssertGreaterThanOrEqual(questionCountFrame.minY - descriptionFrame.maxY, 32)
    }

    func testDescriptionStartButtonStaysPinnedWhenCardContentGrows() throws {
        let viewController = QuizDescriptionViewController()
        viewController.loadViewIfNeeded()
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

        viewController.updateLabels(themeName: "Музыка", themeDescription: "Короткое описание.")
        viewController.view.layoutIfNeeded()

        let startButton = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionStartButton") as? UIButton)
        let scrollView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionScrollView") as? UIScrollView)
        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "descriptionContentCardView"))
        let pinnedButtonY = startButton.frame.minY
        let stableCardHeight = cardView.frame.height

        viewController.updateLabels(
            themeName: "Музыка",
            themeDescription: String(repeating: "Очень длинное описание темы должно прокручиваться независимо от кнопки запуска. ", count: 18)
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        XCTAssertEqual(startButton.frame.minY, pinnedButtonY, accuracy: 0.5)
        XCTAssertGreaterThan(cardView.frame.height, stableCardHeight)
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

    func testQuestionTextIsCenteredBetweenProgressBarAndFirstAnswer() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        viewController.view.layoutIfNeeded()

        let cardView = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionCardView"))
        let progressBar = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTimerProgressView"))
        let questionLabel = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel"))
        let firstAnswer = try XCTUnwrap(viewController.view.descendant(withAccessibilityIdentifier: "questionAnswerButton1"))
        let progressFrame = progressBar.convert(progressBar.bounds, to: cardView)
        let questionFrame = questionLabel.convert(questionLabel.bounds, to: cardView)
        let firstAnswerFrame = firstAnswer.convert(firstAnswer.bounds, to: cardView)
        let availableGapMidY = (progressFrame.maxY + firstAnswerFrame.minY) / 2

        XCTAssertEqual(questionFrame.midY, availableGapMidY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(questionFrame.minY - progressFrame.maxY, 24)
        XCTAssertGreaterThanOrEqual(firstAnswerFrame.minY - questionFrame.maxY, 24)
    }

    func testRadarThemeTitleCanShrinkToFitLegacySEWidth() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "История и культура",
                questionText: "Короткий вопрос?",
                questionNumberText: "Вопрос №1",
                answers: [
                    QuizAnswerOption(id: "theme-0", title: "A"),
                    QuizAnswerOption(id: "theme-1", title: "B"),
                    QuizAnswerOption(id: "theme-2", title: "C"),
                    QuizAnswerOption(id: "theme-3", title: "D")
                ]
            )
        )
        viewController.view.layoutIfNeeded()

        let themeLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionThemeLabel") as? UILabel
        )
        let unscaledWidth = (themeLabel.text! as NSString).size(withAttributes: [.font: themeLabel.font!]).width
        let minimumFont = themeLabel.font.withSize(themeLabel.font.pointSize * themeLabel.minimumScaleFactor)
        let minimumWidth = (themeLabel.text! as NSString).size(withAttributes: [.font: minimumFont]).width

        XCTAssertEqual(themeLabel.numberOfLines, 1)
        XCTAssertTrue(themeLabel.adjustsFontSizeToFitWidth)
        XCTAssertEqual(themeLabel.minimumScaleFactor, 0.70, accuracy: 0.001)
        XCTAssertGreaterThan(unscaledWidth, themeLabel.bounds.width)
        XCTAssertLessThanOrEqual(minimumWidth, themeLabel.bounds.width + 0.5)
    }

    func testLongAnswersShrinkWithoutClippingAcrossSelectableStylesAndPhoneSizes() throws {
        let styles: [AppDesignStyle] = [.classic, .radar, .clean]
        let phoneSizes = [
            CGSize(width: 402, height: 874),
            CGSize(width: 375, height: 667),
            CGSize(width: 320, height: 568)
        ]
        let longAnswers = philosopherQuoteAnswers

        for style in styles {
            UserDefaults.standard.set(style.rawValue, forKey: AppAppearanceStore.Keys.designStyle)

            for phoneSize in phoneSizes {
                QuizFactory.shared.chosenTheme = makeQuestionTheme()
                QuizFactory.shared.questionsCount = 1

                let viewController = QuizQuestionViewController()
                viewController.loadViewIfNeeded()
                viewController.view.frame = CGRect(origin: .zero, size: phoneSize)
                viewController.loadQuestionToView(
                    QuizQuestionViewModel(
                        themeName: "Цитаты философов",
                        questionText: "Какое из высказываний принадлежит Иммануилу Канту?",
                        questionNumberText: "Вопрос №2",
                        answers: longAnswers.enumerated().map { index, title in
                            QuizAnswerOption(id: "long-answer-\(index)", title: title)
                        }
                    )
                )
                viewController.view.setNeedsLayout()
                viewController.view.layoutIfNeeded()
                viewController.view.layoutIfNeeded()

                try assertAnswerLabelsFit(in: viewController, expectedTitles: longAnswers)

                let baseFont = currentAppearance().typography.font(size: 18, weight: .semibold)
                let firstAnswerLabel = try XCTUnwrap(questionAnswerButtons(in: viewController).first?.titleLabel)
                XCTAssertLessThan(firstAnswerLabel.font.pointSize, baseFont.pointSize)
                XCTAssertGreaterThanOrEqual(firstAnswerLabel.font.pointSize, baseFont.pointSize * 0.72 - 0.1)

                let shortAnswers = ["A", "B", "C", "D"]
                viewController.loadQuestionToView(
                    QuizQuestionViewModel(
                        themeName: "Короткая тема",
                        questionText: "Короткий вопрос?",
                        questionNumberText: "Вопрос №3",
                        answers: shortAnswers.enumerated().map { index, title in
                            QuizAnswerOption(id: "short-answer-\(index)", title: title)
                        }
                    )
                )
                viewController.view.setNeedsLayout()
                viewController.view.layoutIfNeeded()
                viewController.view.layoutIfNeeded()

                let shortAnswerButtons = questionAnswerButtons(in: viewController)
                XCTAssertEqual(shortAnswerButtons.count, shortAnswers.count)
                XCTAssertTrue(shortAnswerButtons.allSatisfy {
                    abs(($0.titleLabel?.font.pointSize ?? 0) - baseFont.pointSize) <= 0.1
                })
                viewController.presenter?.stopTimer()
            }
        }
    }

    func testInitialLongAnswersFitBeforeSelectionAndStayStableAfterFeedback() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        let fixture = japanUnificationQuestionFixture
        QuizFactory.shared.chosenTheme = makeQuestionTheme(
            id: "initial_long_answers",
            themeName: "История Японии",
            questionText: fixture.question,
            answers: fixture.answers
        )
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 402, height: 874))
        window.rootViewController = viewController
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let answerButtons = questionAnswerButtons(in: viewController)
        let displayedAnswers = answerButtons.compactMap { $0.title(for: .normal) }
        XCTAssertEqual(Set(displayedAnswers), Set(fixture.answers))
        XCTAssertTrue(answerButtons.allSatisfy(\.isEnabled))
        let nextButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton
        )
        XCTAssertFalse(nextButton.isEnabled)
        try assertAnswerLabelsFit(in: viewController, expectedTitles: displayedAnswers)

        let baseFont = currentAppearance().typography.font(
            size: 18,
            weight: .semibold,
            compatibleWith: viewController.view.traitCollection
        )
        let initialResolvedFontSizes = answerButtons.compactMap { $0.titleLabel?.font.pointSize }
        XCTAssertTrue(initialResolvedFontSizes.contains { $0 < baseFont.pointSize - 0.1 })
        XCTAssertTrue(initialResolvedFontSizes.allSatisfy { $0 >= baseFont.pointSize * 0.72 - 0.1 })

        let initialFontSizes = answerButtons.map { $0.titleLabel?.font.pointSize }
        let initialHeights = answerButtons.map(\.bounds.height)
        let selectedButton = try XCTUnwrap(answerButtons.first)
        selectedButton.sendActions(for: .touchUpInside)
        viewController.view.layoutIfNeeded()

        try assertAnswerLabelsFit(in: viewController, expectedTitles: displayedAnswers)
        XCTAssertEqual(answerButtons.map { $0.titleLabel?.font.pointSize }, initialFontSizes)
        XCTAssertEqual(answerButtons.map(\.bounds.height), initialHeights)
    }

    func testLongQuestionsShrinkWithinReadableFloorAcrossSelectableStylesAndPhoneSizes() throws {
        let styles: [AppDesignStyle] = [.classic, .radar, .clean]
        let phoneSizes = [
            CGSize(width: 402, height: 874),
            CGSize(width: 375, height: 667),
            CGSize(width: 320, height: 568)
        ]
        let fixture = japanUnificationQuestionFixture

        for style in styles {
            UserDefaults.standard.set(style.rawValue, forKey: AppAppearanceStore.Keys.designStyle)

            for phoneSize in phoneSizes {
                QuizFactory.shared.chosenTheme = makeQuestionTheme()
                QuizFactory.shared.questionsCount = 1

                let viewController = QuizQuestionViewController()
                viewController.loadViewIfNeeded()
                defer { viewController.presenter?.stopTimer() }
                viewController.view.frame = CGRect(origin: .zero, size: phoneSize)
                viewController.loadQuestionToView(
                    QuizQuestionViewModel(
                        themeName: "История Японии",
                        questionText: fixture.question,
                        questionNumberText: "Вопрос №1",
                        answers: fixture.answers.enumerated().map { index, title in
                            QuizAnswerOption(id: "japan-\(index)", title: title)
                        }
                    )
                )
                viewController.view.setNeedsLayout()
                viewController.view.layoutIfNeeded()

                let questionLabel = try XCTUnwrap(
                    viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel") as? UILabel
                )
                let cardView = try XCTUnwrap(
                    viewController.view.descendant(withAccessibilityIdentifier: "questionCardView")
                )
                let baseFont = currentAppearance().typography.font(
                    size: 26,
                    weight: .bold,
                    compatibleWith: viewController.view.traitCollection
                )
                let fittedHeight = textHeight(
                    fixture.question,
                    font: questionLabel.font,
                    width: questionLabel.bounds.width
                )
                let baseHeight = textHeight(
                    fixture.question,
                    font: baseFont,
                    width: questionLabel.bounds.width
                )
                let questionFrame = questionLabel.convert(questionLabel.bounds, to: cardView)

                XCTAssertEqual(questionLabel.text, fixture.question)
                XCTAssertEqual(questionLabel.numberOfLines, 0)
                XCTAssertEqual(questionLabel.lineBreakMode, .byWordWrapping)
                XCTAssertLessThan(questionLabel.font.pointSize, baseFont.pointSize - 0.1)
                XCTAssertGreaterThanOrEqual(questionLabel.font.pointSize, baseFont.pointSize * 0.72 - 0.1)
                XCTAssertLessThan(fittedHeight, baseHeight)
                XCTAssertLessThanOrEqual(fittedHeight, questionLabel.bounds.height + 1)
                XCTAssertTrue(cardView.bounds.insetBy(dx: -0.5, dy: -0.5).contains(questionFrame))
            }
        }
    }

    func testExtremeQuestionStopsAtReadableFloorAndUsesScrollableFallback() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        let fixture = japanUnificationQuestionFixture
        let extremeQuestion = String(repeating: fixture.question + " ", count: 5)
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "История Японии",
                questionText: extremeQuestion,
                questionNumberText: "Вопрос №1",
                answers: fixture.answers.enumerated().map { index, title in
                    QuizAnswerOption(id: "extreme-question-\(index)", title: title)
                }
            )
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()

        let questionLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel") as? UILabel
        )
        let scrollView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionScrollView") as? UIScrollView
        )
        let nextButton = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionNextButton") as? UIButton
        )
        let baseFont = currentAppearance().typography.font(
            size: 26,
            weight: .bold,
            compatibleWith: viewController.view.traitCollection
        )
        let requiredHeight = textHeight(
            extremeQuestion,
            font: questionLabel.font,
            width: questionLabel.bounds.width
        )

        XCTAssertEqual(questionLabel.font.pointSize, baseFont.pointSize * 0.72, accuracy: 0.1)
        XCTAssertLessThanOrEqual(requiredHeight, questionLabel.bounds.height + 0.5)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
        XCTAssertFalse(nextButton.isDescendant(of: scrollView))
        XCTAssertLessThanOrEqual(scrollView.frame.maxY, nextButton.frame.minY)
    }

    func testQuestionFontRestoresForShortQuestionAndRefitsAfterWidthChange() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        let fixture = japanUnificationQuestionFixture
        let longQuestionViewModel = QuizQuestionViewModel(
            themeName: "История Японии",
            questionText: fixture.question,
            questionNumberText: "Вопрос №1",
            answers: fixture.answers.enumerated().map { index, title in
                QuizAnswerOption(id: "resize-question-\(index)", title: title)
            }
        )

        viewController.view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        viewController.loadQuestionToView(longQuestionViewModel)
        viewController.view.layoutIfNeeded()
        let questionLabel = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionTextLabel") as? UILabel
        )
        let compactPointSize = questionLabel.font.pointSize

        viewController.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        let widePointSize = questionLabel.font.pointSize
        XCTAssertGreaterThanOrEqual(widePointSize, compactPointSize)

        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Короткая тема",
                questionText: "Короткий вопрос?",
                questionNumberText: "Вопрос №2",
                answers: ["A", "B", "C", "D"].enumerated().map { index, title in
                    QuizAnswerOption(id: "short-question-\(index)", title: title)
                }
            )
        )
        viewController.view.layoutIfNeeded()

        let baseFont = currentAppearance().typography.font(
            size: 26,
            weight: .bold,
            compatibleWith: viewController.view.traitCollection
        )
        XCTAssertEqual(questionLabel.font.pointSize, baseFont.pointSize, accuracy: 0.1)
    }

    func testLongAnswersRespectAccessibilityContentSizeWhileFitting() throws {
        UserDefaults.standard.set(AppDesignStyle.classic.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.traitOverrides.preferredContentSizeCategory = .accessibilityExtraExtraExtraLarge
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Цитаты философов",
                questionText: "Какое из высказываний принадлежит Иммануилу Канту?",
                questionNumberText: "Вопрос №2",
                answers: philosopherQuoteAnswers.enumerated().map { index, title in
                    QuizAnswerOption(id: "accessibility-answer-\(index)", title: title)
                }
            )
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        viewController.view.layoutIfNeeded()

        try assertAnswerLabelsFit(in: viewController, expectedTitles: philosopherQuoteAnswers)

        let typography = currentAppearance().typography
        let defaultFont = typography.font(
            size: 18,
            weight: .semibold,
            compatibleWith: UITraitCollection(preferredContentSizeCategory: .large)
        )
        let accessibilityFont = typography.font(
            size: 18,
            weight: .semibold,
            compatibleWith: viewController.traitCollection
        )
        let firstAnswerLabel = try XCTUnwrap(questionAnswerButtons(in: viewController).first?.titleLabel)

        XCTAssertGreaterThan(accessibilityFont.pointSize, defaultFont.pointSize)
        XCTAssertLessThan(firstAnswerLabel.font.pointSize, accessibilityFont.pointSize)
        XCTAssertGreaterThanOrEqual(
            firstAnswerLabel.font.pointSize,
            accessibilityFont.pointSize * 0.72 - 0.1
        )
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

    func testQuestionNextButtonStaysPinnedWhenExtremeAnswerGrowsCard() throws {
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
        let extremeAnswer = String(
            repeating: "Это экстремально длинный вариант ответа, который должен полностью оставаться внутри кнопки. ",
            count: 8
        )

        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Музыка",
                questionText: "Какой вариант верный?",
                questionNumberText: "Вопрос №2",
                answers: [
                    QuizAnswerOption(id: "long-0", title: extremeAnswer),
                    QuizAnswerOption(id: "long-1", title: "B"),
                    QuizAnswerOption(id: "long-2", title: "C"),
                    QuizAnswerOption(id: "long-3", title: "D")
                ]
            )
        )
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
        viewController.view.layoutIfNeeded()

        let longAnswerButton = try XCTUnwrap(questionAnswerButtons(in: viewController).first)
        let longAnswerLabel = try XCTUnwrap(longAnswerButton.titleLabel)
        let baseFont = currentAppearance().typography.font(size: 18, weight: .semibold)

        XCTAssertGreaterThan(cardView.frame.height, shortCardHeight)
        XCTAssertGreaterThan(longAnswerButton.bounds.height, 52)
        XCTAssertEqual(longAnswerLabel.font.pointSize, baseFont.pointSize * 0.72, accuracy: 0.1)
        try assertAnswerLabelsFit(in: viewController, expectedTitles: [extremeAnswer, "B", "C", "D"])
        XCTAssertEqual(nextButton.frame.minY, pinnedButtonY, accuracy: 0.5)
        XCTAssertFalse(nextButton.isDescendant(of: scrollView))
        XCTAssertLessThanOrEqual(scrollView.frame.maxY, nextButton.frame.minY)
        XCTAssertGreaterThan(scrollView.contentSize.height, scrollView.bounds.height)
    }

    func testQuestionAdvanceResetsScrolledLongAnswerCardToTop() throws {
        QuizFactory.shared.chosenTheme = makeQuestionTheme()
        QuizFactory.shared.questionsCount = 1

        let viewController = QuizQuestionViewController()
        viewController.loadViewIfNeeded()
        defer { viewController.presenter?.stopTimer() }
        viewController.view.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        let extremeAnswer = String(
            repeating: "Это экстремально длинный вариант ответа, который делает карточку прокручиваемой. ",
            count: 8
        )
        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Цитаты философов",
                questionText: "Какой вариант верный?",
                questionNumberText: "Вопрос №2",
                answers: [
                    QuizAnswerOption(id: "scroll-answer-0", title: extremeAnswer),
                    QuizAnswerOption(id: "scroll-answer-1", title: "B"),
                    QuizAnswerOption(id: "scroll-answer-2", title: "C"),
                    QuizAnswerOption(id: "scroll-answer-3", title: "D")
                ]
            )
        )
        viewController.view.layoutIfNeeded()

        let scrollView = try XCTUnwrap(
            viewController.view.descendant(withAccessibilityIdentifier: "questionScrollView") as? UIScrollView
        )
        let maximumOffsetY = scrollView.contentSize.height - scrollView.bounds.height + scrollView.adjustedContentInset.bottom
        XCTAssertGreaterThan(maximumOffsetY, -scrollView.adjustedContentInset.top)
        scrollView.setContentOffset(CGPoint(x: 0, y: maximumOffsetY), animated: false)
        XCTAssertGreaterThan(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top)

        viewController.loadQuestionToView(
            QuizQuestionViewModel(
                themeName: "Следующая тема",
                questionText: "Следующий короткий вопрос?",
                questionNumberText: "Вопрос №3",
                answers: [
                    QuizAnswerOption(id: "next-0", title: "A"),
                    QuizAnswerOption(id: "next-1", title: "B"),
                    QuizAnswerOption(id: "next-2", title: "C"),
                    QuizAnswerOption(id: "next-3", title: "D")
                ]
            )
        )
        viewController.view.layoutIfNeeded()

        XCTAssertEqual(scrollView.contentOffset.y, -scrollView.adjustedContentInset.top, accuracy: 0.5)
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

    func testStatisticsCorrectAnswersValueStaysFullyVisibleForLargeHistory() throws {
        UserDefaults.standard.set(AppDesignStyle.radar.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        let harness = makeStatisticsHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suiteName) }

        for _ in 0..<10 {
            harness.store.recordAttempt(correctAnswers: 5, totalQuestions: 5)
        }
        for _ in 0..<24 {
            harness.store.recordAttempt(correctAnswers: 1, totalQuestions: 5)
        }
        for _ in 0..<19 {
            harness.store.recordAttempt(correctAnswers: 0, totalQuestions: 5)
        }

        for width in [CGFloat(402), CGFloat(320)] {
            let viewController = StatisticsViewController(statisticsStore: harness.store)
            viewController.loadViewIfNeeded()
            viewController.view.frame = CGRect(x: 0, y: 0, width: width, height: 874)
            viewController.viewWillAppear(false)
            viewController.view.setNeedsLayout()
            viewController.view.layoutIfNeeded()

            let correctRow = try XCTUnwrap(
                viewController.view.descendant(withAccessibilityIdentifier: "statisticsCorrectAnswers")
            )
            let correctValueLabel = try XCTUnwrap(
                viewController.view.descendant(
                    withAccessibilityIdentifier: "statisticsCorrectAnswersValueLabel"
                ) as? UILabel
            )
            let titleLabel = try XCTUnwrap(
                correctRow.subviews.compactMap { $0 as? UILabel }.first { $0 !== correctValueLabel }
            )
            let requiredValueWidth = ceil(
                ("74/265" as NSString).size(withAttributes: [.font: correctValueLabel.font!]).width
            )
            let valueFrame = correctValueLabel.convert(correctValueLabel.bounds, to: correctRow)

            XCTAssertEqual(correctValueLabel.text, "74/265")
            XCTAssertEqual(correctRow.accessibilityValue, "74/265")
            XCTAssertTrue(correctValueLabel.adjustsFontSizeToFitWidth)
            XCTAssertEqual(correctValueLabel.minimumScaleFactor, 0.75, accuracy: 0.001)
            XCTAssertGreaterThanOrEqual(correctValueLabel.bounds.width + 0.5, requiredValueWidth)
            XCTAssertGreaterThan(
                correctValueLabel.contentCompressionResistancePriority(for: .horizontal).rawValue,
                titleLabel.contentCompressionResistancePriority(for: .horizontal).rawValue
            )
            XCTAssertTrue(correctRow.bounds.insetBy(dx: -0.5, dy: -0.5).contains(valueFrame))
        }
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

    private var philosopherQuoteAnswers: [String] {
        [
            "«Поступай так, чтобы максима твоей воли могла бы быть всеобщим законом»",
            "«Бытие определяет сознание»",
            "«Человек — это то, что должно быть преодолено»",
            "«Жизнь — это страдание»"
        ]
    }

    private var japanUnificationQuestionFixture: (question: String, answers: [String]) {
        (
            question: "Какое событие положило конец периоду феодальной раздробленности и способствовало объединению Японии в конце XVI века?",
            answers: [
                "Деятельность Оды Нобунаги, Тоётоми Хидэёси и Токугавы Иэясу",
                "Приход к власти Токугавы Иэясу",
                "Восстание крестьян",
                "Битва при Сэкигахаре"
            ]
        )
    }

    private func assertAnswerLabelsFit(
        in viewController: QuizQuestionViewController,
        expectedTitles: [String],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let buttons = questionAnswerButtons(in: viewController)
        XCTAssertEqual(buttons.count, expectedTitles.count, file: file, line: line)

        for (button, expectedTitle) in zip(buttons, expectedTitles) {
            let titleLabel = try XCTUnwrap(button.titleLabel, file: file, line: line)
            let requiredBounds = (expectedTitle as NSString).boundingRect(
                with: CGSize(width: titleLabel.bounds.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: titleLabel.font!],
                context: nil
            )
            let titleFrame = titleLabel.convert(titleLabel.bounds, to: button)

            XCTAssertEqual(button.title(for: .normal), expectedTitle, file: file, line: line)
            XCTAssertEqual(titleLabel.numberOfLines, 0, file: file, line: line)
            XCTAssertEqual(titleLabel.lineBreakMode, .byWordWrapping, file: file, line: line)
            XCTAssertGreaterThan(titleLabel.bounds.width, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(
                ceil(requiredBounds.height),
                titleLabel.bounds.height + 0.5,
                "Answer \(expectedTitle) at \(titleLabel.font.pointSize)pt requires \(ceil(requiredBounds.height))pt but has \(titleLabel.bounds.height)pt in button \(button.bounds)",
                file: file,
                line: line
            )
            XCTAssertTrue(
                button.bounds.insetBy(dx: -0.5, dy: -0.5).contains(titleFrame),
                "Answer title frame \(titleFrame) escapes button bounds \(button.bounds)",
                file: file,
                line: line
            )
        }
    }

    private func textHeight(_ text: String, font: UIFont, width: CGFloat) -> CGFloat {
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height
        )
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

    private func makeQuestionTheme(
        id: String,
        themeName: String,
        questionText: String,
        answers: [String]
    ) -> ThemeModel {
        ThemeModel(
            quizTheme: QuizTheme(
                id: id,
                theme: themeName,
                themeDescription: "Тема для проверки адаптивной типографики",
                questions: [
                    QuizQuestion(
                        question: questionText,
                        answers: answers,
                        correctAnswer: answers[0]
                    )
                ]
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
