import Foundation

public struct FocusSessionSnapshot: Codable, Equatable, Sendable {
    public let session: FocusSession
    public let updatedAt: Date
    public let mode: SessionRecordKind

    public init(
        session: FocusSession,
        updatedAt: Date,
        mode: SessionRecordKind = .focus
    ) {
        self.session = session
        self.updatedAt = updatedAt
        self.mode = mode
    }

    private enum CodingKeys: String, CodingKey {
        case session
        case updatedAt
        case mode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        session = try container.decode(FocusSession.self, forKey: .session)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        mode = try container.decodeIfPresent(SessionRecordKind.self, forKey: .mode) ?? .focus
    }
}
