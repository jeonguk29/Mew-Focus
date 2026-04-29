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
}
