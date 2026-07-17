import AVFAudio
import UIKit

final class QuizQuestionFeedbackPlayer {
    enum Outcome {
        case correct
        case incorrect
    }

    private enum Resource {
        static let correctSoundName = "Quizice Correct"
        static let incorrectSoundName = "Quizice Incorrect"
        static let fileExtension = "m4a"
    }

    private let bundle: Bundle
    private let hapticFeedback: UINotificationFeedbackGenerator
    private var correctAnswerPlayer: AVAudioPlayer?
    private var incorrectAnswerPlayer: AVAudioPlayer?

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
        reset(correctAnswerPlayer)
        reset(incorrectAnswerPlayer)
    }

    func play(_ outcome: Outcome) {
        loadPlayersIfNeeded()
        switch outcome {
        case .correct:
            correctAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.success)
        case .incorrect:
            incorrectAnswerPlayer?.play()
            hapticFeedback.notificationOccurred(.error)
        }
    }

    func notifyError() {
        hapticFeedback.notificationOccurred(.error)
    }

    private func loadPlayersIfNeeded() {
        guard correctAnswerPlayer == nil, incorrectAnswerPlayer == nil else { return }
        guard
            let correctURL = bundle.url(
                forResource: Resource.correctSoundName,
                withExtension: Resource.fileExtension
            ),
            let incorrectURL = bundle.url(
                forResource: Resource.incorrectSoundName,
                withExtension: Resource.fileExtension
            )
        else {
            AppLog.audio.error("\(L10n.Question.audioLoadFailure, privacy: .public)")
            return
        }

        correctAnswerPlayer = try? AVAudioPlayer(contentsOf: correctURL)
        incorrectAnswerPlayer = try? AVAudioPlayer(contentsOf: incorrectURL)
    }

    private func reset(_ player: AVAudioPlayer?) {
        player?.stop()
        player?.currentTime = .zero
    }
}
