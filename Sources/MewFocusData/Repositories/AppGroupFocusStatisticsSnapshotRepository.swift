import Foundation
import MewFocusDomain

public final class AppGroupFocusStatisticsSnapshotRepository {
    private let userDefaults: UserDefaults
    private let key = "focus_statistics_snapshot"

    public init(suiteName: String = AppGroupFocusSessionSnapshotRepository.appGroupIdentifier) {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func loadSnapshot() -> FocusStatisticsSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FocusStatisticsSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: FocusStatisticsSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }
}
