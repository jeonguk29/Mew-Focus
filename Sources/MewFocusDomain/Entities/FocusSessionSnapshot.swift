import Foundation

public struct FocusSessionSnapshot: Codable, Equatable, Sendable {
    public let session: FocusSession
    public let updatedAt: Date

    public init(session: FocusSession, updatedAt: Date) {
        self.session = session
        self.updatedAt = updatedAt
    }
}
