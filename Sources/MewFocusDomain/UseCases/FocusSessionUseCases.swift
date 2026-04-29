import Foundation

public struct StartFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession) -> FocusSession {
        var session = session
        if session.remainingTime <= 0 {
            session.remainingTime = session.duration
        }
        session.state = .running
        return session
    }
}

public struct PauseFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession) -> FocusSession {
        var session = session
        session.state = .paused
        return session
    }
}

public struct ResetFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession) -> FocusSession {
        var session = session
        session.remainingTime = session.duration
        session.state = .idle
        return session
    }
}

public struct EndFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession) -> FocusSession {
        var session = session
        session.remainingTime = session.duration
        session.state = .idle
        return session
    }
}

public struct CompleteFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession) -> FocusSession {
        var session = session
        session.remainingTime = 0
        session.state = .completed
        return session
    }
}

public struct TickFocusSessionUseCase: Sendable {
    public init() {}

    public func execute(_ session: FocusSession, elapsedTime: TimeInterval = 1) -> FocusSession {
        guard session.state == .running else { return session }

        var session = session
        let nextRemainingTime = session.remainingTime - elapsedTime

        if nextRemainingTime <= 0 {
            session.remainingTime = 0
            session.state = .completed
        } else {
            session.remainingTime = nextRemainingTime
        }

        return session
    }
}
