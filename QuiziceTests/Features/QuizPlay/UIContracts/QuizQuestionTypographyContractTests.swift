import XCTest
@testable import Quizice

@MainActor
final class QuizQuestionTypographyContractTests: CrossScreenVisualTestCase {
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
}
