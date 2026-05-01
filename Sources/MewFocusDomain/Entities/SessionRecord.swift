import Foundation

public enum SessionRecordKind: String, Codable, Sendable {
    case focus
    case shortBreak
}

public struct SessionRecord: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let duration: TimeInterval
    public let completedAt: Date
    public let kind: SessionRecordKind

    public init(
        id: UUID = UUID(),
        title: String,
        duration: TimeInterval,
        completedAt: Date,
        kind: SessionRecordKind = .focus
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.completedAt = completedAt
        self.kind = kind
    }
}

public struct DailyFocusSummary: Codable, Equatable, Identifiable, Sendable {
    public let date: Date
    public let duration: TimeInterval

    public var id: Date { date }

    public init(date: Date, duration: TimeInterval) {
        self.date = date
        self.duration = duration
    }
}

public struct FocusStatisticsSnapshot: Codable, Equatable, Sendable {
    public let todayFocusDuration: TimeInterval
    public let recentSessions: [SessionRecord]
    public let updatedAt: Date

    public init(
        todayFocusDuration: TimeInterval,
        recentSessions: [SessionRecord],
        updatedAt: Date
    ) {
        self.todayFocusDuration = todayFocusDuration
        self.recentSessions = recentSessions
        self.updatedAt = updatedAt
    }
}
