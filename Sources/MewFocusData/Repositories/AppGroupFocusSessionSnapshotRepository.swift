import Foundation
import MewFocusDomain

public final class AppGroupFocusSessionSnapshotRepository: FocusSessionSnapshotRepository {
    public static let appGroupIdentifier = "group.com.mashup.MewFocus"

    private let userDefaults: UserDefaults
    private let key = "focus_session_snapshot"

    public init(suiteName: String = AppGroupFocusSessionSnapshotRepository.appGroupIdentifier) {
        self.userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    public func loadSnapshot() -> FocusSessionSnapshot? {
        guard let data = userDefaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(FocusSessionSnapshot.self, from: data)
    }

    public func saveSnapshot(_ snapshot: FocusSessionSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        userDefaults.set(data, forKey: key)
    }
}
