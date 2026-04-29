import MewFocusDomain

public actor InMemoryFocusSessionRepository: FocusSessionRepository {
    private var session: FocusSession

    public init(session: FocusSession = FocusSession()) {
        self.session = session
    }

    public func currentSession() async throws -> FocusSession {
        session
    }

    public func saveCurrentSession(_ session: FocusSession) async throws {
        self.session = session
    }
}
