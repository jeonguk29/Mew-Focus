import Foundation

public struct FocusSession: Equatable, Sendable {
    public var preset: FocusPreset?
    public var duration: TimeInterval
    public var remainingTime: TimeInterval
    public var state: TimerState

    public init(
        preset: FocusPreset? = .twentyFiveMinutes,
        duration: TimeInterval = FocusPreset.twentyFiveMinutes.duration,
        remainingTime: TimeInterval = FocusPreset.twentyFiveMinutes.duration,
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
