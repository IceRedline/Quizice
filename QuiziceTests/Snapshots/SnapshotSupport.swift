import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import Quizice

@MainActor
enum SnapshotSupport {
    static let componentSize = CGSize(width: 390, height: 220)

    static func setUp(
        designStyle: AppDesignStyle = .clean,
        cleanColorScheme: CleanColorSchemePreference = .light,
        language: AppLanguagePreference = .russian
    ) {
        UIView.setAnimationsEnabled(false)
        AppLocalizationStore.shared.languagePreference = language
        UserDefaults.standard.set(designStyle.rawValue, forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.set(cleanColorScheme.rawValue, forKey: AppAppearanceStore.Keys.cleanColorScheme)
    }

    static func tearDown() {
        UIView.setAnimationsEnabled(true)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.designStyle)
        UserDefaults.standard.removeObject(forKey: AppAppearanceStore.Keys.cleanColorScheme)
        UserDefaults.standard.removeObject(forKey: AppLocalizationStore.Keys.language)
        resetSharedQuizFactoryForTests()
    }

    static func assertScreen(
        _ viewController: UIViewController,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        prepare(viewController)
        assertSnapshot(
            of: viewController,
            as: .image(on: .iPhoneX),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    static func assertComponent(
        _ view: UIView,
        named name: String,
        size: CGSize = CGSize(width: 390, height: 220),
        backgroundAppearance: AppAppearance? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        let viewController = ComponentHostViewController(
            contentView: view,
            canvasSize: size,
            backgroundAppearance: backgroundAppearance
        )
        prepare(viewController, size: size)
        assertSnapshot(
            of: viewController,
            as: .image(size: size),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    static func appearance(
        designStyle: AppDesignStyle,
        cleanColorScheme: CleanColorSchemePreference = .light
    ) -> AppAppearance {
        AppAppearance(
            designStyle: designStyle,
            cleanColorSchemePreference: cleanColorScheme,
            traitCollection: UITraitCollection(userInterfaceStyle: cleanColorScheme == .dark ? .dark : .light)
        )
    }

    static func makeActionButton(title: String, style: AppSurfaceStyle, appearance: AppAppearance) -> UIButton {
        let button = UIButton(type: .system)
        button.applyActionAppearance(style, appearance: appearance)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = appearance.typography.button()
        button.heightAnchor.constraint(equalToConstant: 52).isActive = true
        button.widthAnchor.constraint(equalToConstant: 280).isActive = true
        return button
    }

    static func makeCollectionCell(
        item: Int,
        themes: [QuizTheme],
        designStyle: AppDesignStyle = .clean,
        cleanColorScheme: CleanColorSchemePreference = .light
    ) -> UICollectionViewCell {
        setUp(designStyle: designStyle, cleanColorScheme: cleanColorScheme)
        let repository = SnapshotThemeRepository(themes: themes)
        let service = ThemesCollectionService(themeRepository: repository)
        let collectionView = makeCollectionView()
        collectionView.dataSource = service
        collectionView.delegate = service
        collectionView.layoutIfNeeded()
        let cell = service.collectionView(collectionView, cellForItemAt: IndexPath(item: item, section: 0))
        cell.frame = CGRect(origin: .zero, size: service.collectionView(
            collectionView,
            layout: collectionView.collectionViewLayout,
            sizeForItemAt: IndexPath(item: item, section: 0)
        ))
        cell.contentView.frame = cell.bounds
        cell.setNeedsLayout()
        cell.layoutIfNeeded()
        cell.contentView.layoutIfNeeded()
        return cell
    }

    static func makeTheme(
        id: String,
        name: String,
        description: String = "Synthetic snapshot theme",
        questions: [QuizQuestion] = [
            QuizQuestion(
                question: "Question?",
                answers: ["A", "B", "C", "D"],
                correctAnswer: "A"
            )
        ]
    ) -> QuizTheme {
        QuizTheme(id: id, theme: name, themeDescription: description, questions: questions)
    }

    private static func prepare(_ viewController: UIViewController, size: CGSize? = nil) {
        viewController.loadViewIfNeeded()
        if let size {
            viewController.view.frame = CGRect(origin: .zero, size: size)
        }
        viewController.view.setNeedsLayout()
        viewController.view.layoutIfNeeded()
    }

    private static func makeCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        let collectionView = UICollectionView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), collectionViewLayout: layout)
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: ThemesCollectionService.Content.themeCellReuseIdentifier)
        return collectionView
    }
}

@MainActor
final class ComponentHostViewController: UIViewController {
    private let contentView: UIView
    private let canvasSize: CGSize
    private let backgroundAppearance: AppAppearance?

    init(contentView: UIView, canvasSize: CGSize, backgroundAppearance: AppAppearance? = nil) {
        self.contentView = contentView
        self.canvasSize = canvasSize
        self.backgroundAppearance = backgroundAppearance
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func loadView() {
        let rootView = UIView(frame: CGRect(origin: .zero, size: canvasSize))
        let appearance = backgroundAppearance ?? AppAppearanceStore.shared.appearance(compatibleWith: rootView.traitCollection)
        appearance.applyBackground(to: rootView)
        rootView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        var constraints = [
            contentView.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: rootView.centerYAnchor)
        ]
        if contentView.bounds.width > 0 {
            constraints.append(contentView.widthAnchor.constraint(equalToConstant: contentView.bounds.width))
        }
        if contentView.bounds.height > 0 {
            constraints.append(contentView.heightAnchor.constraint(equalToConstant: contentView.bounds.height))
        }
        NSLayoutConstraint.activate(constraints)
        view = rootView
    }
}

final class SnapshotThemeRepository: ThemeRepository {
    var themes: [QuizTheme]?

    init(themes: [QuizTheme]) {
        self.themes = themes
    }

    func loadData(forceReload: Bool) {}

    func fetchQuizThemes() -> [QuizTheme] {
        themes ?? []
    }
}

func resetSharedQuizFactoryForTests() {
    QuizFactory.shared.themes = nil
    QuizFactory.shared.chosenTheme = nil
    QuizFactory.shared.questionsCount = 5
    QuizFactory.shared.startup1st = false
}

extension UIView {
    func snapshotDescendant(withAccessibilityIdentifier identifier: String) -> UIView? {
        if accessibilityIdentifier == identifier {
            return self
        }
        for subview in subviews {
            if let match = subview.snapshotDescendant(withAccessibilityIdentifier: identifier) {
                return match
            }
        }
        return nil
    }
}
