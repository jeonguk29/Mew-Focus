public protocol FocusSessionSnapshotRepository {
    func loadSnapshot() -> FocusSessionSnapshot?
    func saveSnapshot(_ snapshot: FocusSessionSnapshot)
}
