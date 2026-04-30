import MewFocusData
import MewFocusDomain
import XCTest

final class SwiftDataFocusStatisticsRepositoryTests: XCTestCase {
    func testTodayFocusDurationUsesCurrentDayBoundary() async throws {
        let repository = try SwiftDataFocusStatisticsRepository(isStoredInMemoryOnly: true)
        let calendar = Calendar.current
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 12)))
        let startOfToday = calendar.startOfDay(for: today)
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .second, value: -1, to: startOfToday))
        let tomorrow = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: startOfToday))

        try await repository.saveSession(record(duration: 30 * 60, completedAt: yesterday))
        try await repository.saveSession(record(duration: 25 * 60, completedAt: startOfToday))
        try await repository.saveSession(record(duration: 10 * 60, completedAt: today))
        try await repository.saveSession(record(duration: 50 * 60, completedAt: tomorrow))

        let duration = try await repository.todayFocusDuration(now: today)

        XCTAssertEqual(duration, 35 * 60)
    }

    func testTodayFocusDurationResetsAfterMidnight() async throws {
        let repository = try SwiftDataFocusStatisticsRepository(isStoredInMemoryOnly: true)
        let calendar = Calendar.current
        let beforeMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 23, minute: 50)))
        let afterMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 0, minute: 10)))

        try await repository.saveSession(record(duration: 25 * 60, completedAt: beforeMidnight))

        let duration = try await repository.todayFocusDuration(now: afterMidnight)

        XCTAssertEqual(duration, 0)
    }

    func testDailyFocusSummariesReturnsChronologicalWindowWithEmptyDays() async throws {
        let repository = try SwiftDataFocusStatisticsRepository(isStoredInMemoryOnly: true)
        let calendar = Calendar.current
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 18)))
        let today = calendar.startOfDay(for: now)
        let twoDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -2, to: today))
        let sixDaysAgo = try XCTUnwrap(calendar.date(byAdding: .day, value: -6, to: today))

        try await repository.saveSession(record(duration: 15 * 60, completedAt: sixDaysAgo))
        try await repository.saveSession(record(duration: 20 * 60, completedAt: twoDaysAgo))
        try await repository.saveSession(record(duration: 10 * 60, completedAt: twoDaysAgo.addingTimeInterval(3600)))
        try await repository.saveSession(record(duration: 25 * 60, completedAt: today))

        let summaries = try await repository.dailyFocusSummaries(days: 7, now: now)

        XCTAssertEqual(summaries.count, 7)
        XCTAssertEqual(summaries.map { calendar.startOfDay(for: $0.date) }, (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        })
        XCTAssertEqual(summaries[0].duration, 15 * 60)
        XCTAssertEqual(summaries[4].duration, 30 * 60)
        XCTAssertEqual(summaries[6].duration, 25 * 60)
        XCTAssertEqual(summaries[1].duration, 0)
    }

    func testRecentSessionsReturnsNewestRecordsUpToLimit() async throws {
        let repository = try SwiftDataFocusStatisticsRepository(isStoredInMemoryOnly: true)
        let calendar = Calendar.current
        let baseDate = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 10)))
        let old = baseDate
        let middle = baseDate.addingTimeInterval(60)
        let newest = baseDate.addingTimeInterval(120)

        try await repository.saveSession(record(title: "old", duration: 10 * 60, completedAt: old))
        try await repository.saveSession(record(title: "middle", duration: 20 * 60, completedAt: middle))
        try await repository.saveSession(record(title: "newest", duration: 30 * 60, completedAt: newest))

        let sessions = try await repository.recentSessions(limit: 2)

        XCTAssertEqual(sessions.map(\.title), ["newest", "middle"])
    }

    func testSessionsOnDateReturnsSelectedDayNewestFirst() async throws {
        let repository = try SwiftDataFocusStatisticsRepository(isStoredInMemoryOnly: true)
        let calendar = Calendar.current
        let selectedDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 9)))
        let sameDayMorning = selectedDay
        let sameDayAfternoon = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 4, day: 30, hour: 15)))
        let otherDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 5, day: 1, hour: 9)))

        try await repository.saveSession(record(title: "morning", duration: 10 * 60, completedAt: sameDayMorning))
        try await repository.saveSession(record(title: "afternoon", duration: 25 * 60, completedAt: sameDayAfternoon))
        try await repository.saveSession(record(title: "tomorrow", duration: 50 * 60, completedAt: otherDay))

        let sessions = try await repository.sessions(on: selectedDay)

        XCTAssertEqual(sessions.map(\.title), ["afternoon", "morning"])
    }

    private func record(
        title: String = "집중",
        duration: TimeInterval,
        completedAt: Date
    ) -> SessionRecord {
        SessionRecord(
            id: UUID(),
            title: title,
            duration: duration,
            completedAt: completedAt
        )
    }
}
