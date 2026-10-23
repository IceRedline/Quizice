protocol HomeRouting: AnyObject {
    func showQuestion()
    func showSettings()
    func showOnboarding()
    func showSubscription()
}

extension HomeRouting {
    func showOnboarding() {}
    func showSubscription() {}
}

protocol QuizPlayRouting: AnyObject {
    func showResult(_ result: QuizResultState)
    func closeQuestion()
}

protocol QuizResultRouting: AnyObject {
    func replayQuiz()
    func returnToThemes()
}

protocol QuizRouting:
    HomeRouting,
    QuizPlayRouting,
    QuizResultRouting
{}

protocol QuizHomeReturnHandling: AnyObject {
    func quizFlowWillReturnToThemes()
}

