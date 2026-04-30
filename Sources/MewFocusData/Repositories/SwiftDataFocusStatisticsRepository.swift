import Foundation
import MewFocusDomain
import SwiftData

@Model
final class FocusSessionRecordModel {
    @Attribute(.unique) var id: UUID
    var title: String
    var duration: TimeInterval
    var completedAt: Date

    init(id: UUID, title: String, duration: TimeInterval, completedAt: Date) {
        self.id = id
        self.title = title
        self.duration = duration
        self.completedAt = completedAt
    }

    convenience init(record: SessionRecord) {
        self.init(
            id: record.id,
            title: record.title,
            duration: record.duration,
            completedAt: record.completedAt
        )
    }

    var record: SessionRecord {
        SessionRecord(
            id: id,
            title: title,
            duration: duration,
            completedAt: completedAt
        )
    }
}

public actor SwiftDataFocusStatisticsRepository: FocusStatisticsRepository {
    private let container: ModelContainer

    public init(isStoredInMemoryOnly: Bool = false) throws {
        let schema = Schema([FocusSessionRecordModel.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        self.container = try ModelContainer(for: schema, configurations: [configuration])
    }

    public func saveSession(_ record: SessionRecord) async throws {
        let context = ModelContext(container)
        context.insert(FocusSessionRecordModel(record: record))
        try context.save()
    }

    public func recentSessions(limit: Int) async throws -> [SessionRecord] {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<FocusSessionRecordModel>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(limit, 0)
        return try context.fetch(descriptor).map(\.record)
    }

    public func sessions(on date: Date) async throws -> [SessionRecord] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        let context = ModelContext(container)
        let predicate = #Predicate<FocusSessionRecordModel> { record in
            record.completedAt >= startOfDay && record.completedAt < endOfDay
        }
        let descriptor = FetchDescriptor<FocusSessionRecordModel>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.record)
    }

    public func todayFocusDuration(now: Date) async throws -> TimeInterval {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? now
        return try focusDuration(from: startOfDay, to: endOfDay)
    }

    public func dailyFocusSummaries(days: Int, now: Date) async throws -> [DailyFocusSummary] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let dayCount = max(days, 1)

        return try (0..<dayCount).reversed().compactMap { offset in
            guard
                let date = calendar.date(byAdding: .day, value: -offset, to: today),
                let nextDate = calendar.date(byAdding: .day, value: 1, to: date)
            else {
                return nil
            }

            return DailyFocusSummary(
                date: date,
                duration: try focusDuration(from: date, to: nextDate)
            )
        }
    }

    private func focusDuration(from startDate: Date, to endDate: Date) throws -> TimeInterval {
        let context = ModelContext(container)
        let predicate = #Predicate<FocusSessionRecordModel> { record in
            record.completedAt >= startDate && record.completedAt < endDate
        }
        let descriptor = FetchDescriptor<FocusSessionRecordModel>(predicate: predicate)
        return try context.fetch(descriptor).reduce(0) { $0 + $1.duration }
    }
}
