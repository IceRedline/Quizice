import Foundation
@testable import Quizice

extension SwiftUISnapshotTests {
    var denseOnboardingThemes: [OnboardingTheme] {
        let titles = [
            "Математика",
            "Автомобили",
            "Биология",
            "Космос",
            "Физика",
            "Химия",
            "Литература",
            "География",
            "Кино",
            "Видеоигры",
            "История и культура",
            "Политика и бизнес",
            "Музыка",
            "Технологии"
        ]
        let symbols = [
            "function",
            "car.fill",
            "asterisk",
            "moon.stars.fill",
            "atom",
            "flask.fill",
            "book.fill",
            "globe",
            "film.fill",
            "gamecontroller.fill",
            "theatermask.and.paintbrush.fill",
            "briefcase.fill",
            "music.note.list",
            "cpu.fill"
        ]
        let colors = [
            "#FF2D55",
            "#FF453A",
            "#30D158",
            "#BF5AF2",
            "#5E5CE6",
            "#64D2FF",
            "#C7A97B",
            "#00C7BE",
            "#FF375F",
            "#34C759",
            "#FF9F0A",
            "#5E5CE6",
            "#AF52DE",
            "#0A84FF"
        ]

        return titles.indices.map { index in
            OnboardingTheme(
                id: "compact-\(index)",
                title: titles[index],
                sfSymbolName: symbols[index],
                colorHex: colors[index]
            )
        }
    }
}
