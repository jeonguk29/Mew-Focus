import Foundation

public protocol FocusStatisticsRepository: Sendable {
    func saveSession(_ record: SessionRecord) async throws
    func recentSessions(limit: Int) async throws -> [SessionRecord]
    func sessions(on date: Date) async throws -> [SessionRecord]
    func todayFocusDuration(now: Date) async throws -> TimeInterval
    func dailyFocusSummaries(days: Int, now: Date) async throws -> [DailyFocusSummary]
}
