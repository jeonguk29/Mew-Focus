import Foundation

public struct SessionRecord: Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let duration: TimeInterval
    public let completedAt: Date

    public init(id: UUID = UUID(), title: String, duration: TimeInterval, completedAt: Date) {
        self.id = id
        self.title = title
        self.duration = duration
        self.completedAt = completedAt
    }
}
