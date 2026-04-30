import Foundation
import MewFocusDomain

public actor InMemoryFocusStatisticsRepository: FocusStatisticsRepository {
    private var records: [SessionRecord]

    public init(records: [SessionRecord] = []) {
        self.records = records
    }

    public func saveSession(_ record: SessionRecord) async throws {
        records.append(record)
    }

    public func recentSessions(limit: Int) async throws -> [SessionRecord] {
        Array(records.sorted { $0.completedAt > $1.completedAt }.prefix(limit))
    }

    public func sessions(on date: Date) async throws -> [SessionRecord] {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
            .sorted { $0.completedAt > $1.completedAt }
    }

    public func todayFocusDuration(now: Date) async throws -> TimeInterval {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.completedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.duration }
    }

    public func dailyFocusSummaries(days: Int, now: Date) async throws -> [DailyFocusSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dayCount = max(days, 1)

        return (0..<dayCount).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let duration = records
                .filter { calendar.isDate($0.completedAt, inSameDayAs: date) }
                .reduce(0) { $0 + $1.duration }
            return DailyFocusSummary(date: date, duration: duration)
        }
    }
}
