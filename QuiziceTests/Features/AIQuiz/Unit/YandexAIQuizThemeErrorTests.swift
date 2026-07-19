import Foundation
import XCTest
@testable import Quizice

@MainActor
final class YandexAIQuizThemeErrorTests: YandexAIQuizThemeServiceTestCase {
    func testURLCancellationIsPropagatedAsCancellationError() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            throw URLError(.cancelled)
        }

        do {
            _ = try await generate()
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            // Expected: cancellation remains distinguishable from user-facing failures.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    func testNetworkFailureIsTyped() async {
        YandexAIURLProtocolStub.requestHandler = { _ in
            throw URLError(.timedOut)
        }

        await assertServiceError(.network(.timedOut)) {
            _ = try await self.generate()
        }
    }

    func testUserFacingErrorsAreClassifiedWithoutServiceText() {
        let refusalAlert = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.refused)
        let emptyResponseAlert = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.missingOutputText)
        let serviceAlert = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(503))
        let unavailableAlert = AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.missingAPIKey)

        XCTAssertEqual(refusalAlert.kind, .refusal)
        XCTAssertEqual(emptyResponseAlert.kind, .invalidQuiz)
        XCTAssertNotEqual(refusalAlert.title, emptyResponseAlert.title)
        XCTAssertNotEqual(refusalAlert.message, emptyResponseAlert.message)
        XCTAssertFalse(refusalAlert.canRetry)
        XCTAssertTrue(emptyResponseAlert.canRetry)
        XCTAssertTrue(refusalAlert.offersEditAction)
        XCTAssertTrue(emptyResponseAlert.offersEditAction)
        XCTAssertTrue(serviceAlert.offersEditAction)
        XCTAssertFalse(unavailableAlert.offersEditAction)
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.network(.notConnectedToInternet)).kind,
            .network
        )
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.network(.secureConnectionFailed)).kind,
            .network
        )
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.network(.unknown)).kind,
            .service
        )
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(429)).kind, .service)
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.httpStatus(503)).kind, .service)
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.generationStatus("incomplete")).kind,
            .service
        )
        XCTAssertEqual(AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.invalidQuizJSON).kind, .invalidQuiz)
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.missingAPIKey).kind,
            .configuration
        )
        XCTAssertEqual(
            AIQuizGenerationAlert(error: YandexAIQuizThemeServiceError.unauthorized).kind,
            .configuration
        )
        XCTAssertTrue(unavailableAlert.message.contains("Quizice AI (Local)"))
        XCTAssertFalse(refusalAlert.message.contains("Yandex"))
    }

    func testProductionPresentationNeverExposesAPIKeyConfigurationErrors() {
        let missingKeyAlert = AIQuizGenerationAlert(
            error: YandexAIQuizThemeServiceError.missingAPIKey,
            exposesConfigurationErrors: false
        )
        let rejectedKeyAlert = AIQuizGenerationAlert(
            error: YandexAIQuizThemeServiceError.unauthorized,
            exposesConfigurationErrors: false
        )

        XCTAssertEqual(missingKeyAlert.kind, .unavailable)
        XCTAssertEqual(rejectedKeyAlert.kind, .unavailable)
        XCTAssertFalse(missingKeyAlert.title.localizedCaseInsensitiveContains("API"))
        XCTAssertFalse(missingKeyAlert.message.localizedCaseInsensitiveContains("API"))
        XCTAssertFalse(rejectedKeyAlert.title.localizedCaseInsensitiveContains("API"))
        XCTAssertFalse(rejectedKeyAlert.message.localizedCaseInsensitiveContains("API"))
    }
}
