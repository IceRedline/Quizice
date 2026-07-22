import AVFAudio
import UIKit

final class QuizQuestionFeedbackPlayer {
    enum Outcome {
        case correct
        case incorrect
    }

    private enum Sound {
        case correct
        case incorrect

        var resourceName: String {
            switch self {
            case .correct: "Quizice Correct"
            case .incorrect: "Quizice Incorrect"
            }
        }

        var fileName: String {
            "\(resourceName).m4a"
        }
    }

    private enum PlayerState {
        case notLoaded
        case loaded(AVAudioPlayer)
        case unavailable

        var player: AVAudioPlayer? {
            guard case let .loaded(player) = self else { return nil }
            return player
        }
    }

    private let bundle: Bundle
    private let hapticFeedback: UINotificationFeedbackGenerator
    private var correctAnswerPlayer = PlayerState.notLoaded
    private var incorrectAnswerPlayer = PlayerState.notLoaded

    init(
        bundle: Bundle = .main,
        hapticFeedback: UINotificationFeedbackGenerator = UINotificationFeedbackGenerator()
    ) {
        self.bundle = bundle
        self.hapticFeedback = hapticFeedback
    }

    func prepare() {
        loadPlayersIfNeeded()
        hapticFeedback.prepare()
    }

    func reset() {
        reset(correctAnswerPlayer.player)
        reset(incorrectAnswerPlayer.player)
    }

    func play(_ outcome: Outcome) {
        loadPlayersIfNeeded()
        switch outcome {
        case .correct:
            play(correctAnswerPlayer.player, sound: .correct)
            hapticFeedback.notificationOccurred(.success)
        case .incorrect:
            play(incorrectAnswerPlayer.player, sound: .incorrect)
            hapticFeedback.notificationOccurred(.error)
        }
    }

    func notifyError() {
        hapticFeedback.notificationOccurred(.error)
    }

    private func loadPlayersIfNeeded() {
        correctAnswerPlayer = loadPlayerIfNeeded(correctAnswerPlayer, sound: .correct)
        incorrectAnswerPlayer = loadPlayerIfNeeded(incorrectAnswerPlayer, sound: .incorrect)
    }

    private func loadPlayerIfNeeded(_ state: PlayerState, sound: Sound) -> PlayerState {
        guard case .notLoaded = state else { return state }
        guard let url = bundle.url(forResource: sound.resourceName, withExtension: "m4a") else {
            AppLog.audio.error(
                "\(L10n.Question.audioLoadFailure, privacy: .public): \(sound.fileName, privacy: .public) (resource missing)"
            )
            return .unavailable
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            guard player.prepareToPlay() else {
                AppLog.audio.error(
                    "Answer sound preparation failed: \(sound.fileName, privacy: .public)"
                )
                return .loaded(player)
            }
            return .loaded(player)
        } catch {
            let error = error as NSError
            AppLog.audio.error(
                "Answer sound load failed: \(sound.fileName, privacy: .public), domain=\(error.domain, privacy: .public), code=\(error.code), description=\(error.localizedDescription, privacy: .public)"
            )
            return .unavailable
        }
    }

    private func play(_ player: AVAudioPlayer?, sound: Sound) {
        guard let player else { return }
        guard player.play() else {
            AppLog.audio.error(
                "Answer sound playback did not start: \(sound.fileName, privacy: .public)"
            )
            return
        }
    }

    private func reset(_ player: AVAudioPlayer?) {
        player?.stop()
        player?.currentTime = .zero
    }
}
