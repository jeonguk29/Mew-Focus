import Foundation
import MewFocusDomain

public actor InMemoryFocusStatisticsRepository: FocusStatisticsRepository {
    private var records: [SessionRecord]

    public init(records: [SessionRecord] = []) {
        self.records = records
    }

    public func recentSessions(limit: Int) async throws -> [SessionRecord] {
        Array(records.sorted { $0.completedAt > $1.completedAt }.prefix(limit))
    }

    public func todayFocusDuration(now: Date) async throws -> TimeInterval {
        let calendar = Calendar.current
        return records
            .filter { calendar.isDate($0.completedAt, inSameDayAs: now) }
            .reduce(0) { $0 + $1.duration }
    }
}
