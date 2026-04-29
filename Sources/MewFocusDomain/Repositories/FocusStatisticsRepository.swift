import Foundation

public protocol FocusStatisticsRepository: Sendable {
    func recentSessions(limit: Int) async throws -> [SessionRecord]
    func todayFocusDuration(now: Date) async throws -> TimeInterval
}
