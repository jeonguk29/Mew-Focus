public protocol FocusSessionRepository: Sendable {
    func currentSession() async throws -> FocusSession
    func saveCurrentSession(_ session: FocusSession) async throws
}
