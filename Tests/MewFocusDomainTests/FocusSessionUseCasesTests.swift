import XCTest
@testable import MewFocusDomain

final class FocusSessionUseCasesTests: XCTestCase {
    func testStartSessionChangesStateToRunning() {
        let session = FocusSession()

        let result = StartFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .running)
    }

    func testPauseSessionKeepsRemainingTime() {
        let session = FocusSession(remainingTime: 120, state: .running)

        let result = PauseFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.remainingTime, 120)
    }

    func testResetSessionRestoresDuration() {
        let session = FocusSession(duration: 1500, remainingTime: 300, state: .paused)

        let result = ResetFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .idle)
        XCTAssertEqual(result.remainingTime, 1500)
    }

    func testTickSessionDecreasesRemainingTimeWhileRunning() {
        let session = FocusSession(duration: 10, remainingTime: 10, state: .running)

        let result = TickFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .running)
        XCTAssertEqual(result.remainingTime, 9)
    }

    func testTickSessionCompletesWhenRemainingTimeReachesZero() {
        let session = FocusSession(duration: 10, remainingTime: 1, state: .running)

        let result = TickFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .completed)
        XCTAssertEqual(result.remainingTime, 0)
    }

    func testTickSessionDoesNothingWhilePaused() {
        let session = FocusSession(duration: 10, remainingTime: 5, state: .paused)

        let result = TickFocusSessionUseCase().execute(session)

        XCTAssertEqual(result.state, .paused)
        XCTAssertEqual(result.remainingTime, 5)
    }
}
