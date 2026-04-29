public enum TimerState: Codable, Equatable, Sendable {
    case idle
    case running
    case paused
    case completed
}
