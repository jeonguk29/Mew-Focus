import Foundation

public struct FocusSession: Codable, Equatable, Sendable {
    public var preset: FocusPreset?
    public var duration: TimeInterval
    public var remainingTime: TimeInterval
    public var state: TimerState

    public init(
        preset: FocusPreset? = .thirtyMinutes,
        duration: TimeInterval = FocusPreset.thirtyMinutes.duration,
        remainingTime: TimeInterval = FocusPreset.thirtyMinutes.duration,
        state: TimerState = .idle
    ) {
        self.preset = preset
        self.duration = duration
        self.remainingTime = remainingTime
        self.state = state
    }

    public var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(1 - (remainingTime / duration), 0), 1)
    }
}
