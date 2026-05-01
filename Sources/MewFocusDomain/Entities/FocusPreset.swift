import Foundation

public struct FocusPreset: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let duration: TimeInterval

    public init(id: String, title: String, duration: TimeInterval) {
        self.id = id
        self.title = title
        self.duration = duration
    }
}

public extension FocusPreset {
    static let fiveMinutes = FocusPreset(id: "5m", title: "5분", duration: 5 * 60)
    static let tenMinutes = FocusPreset(id: "10m", title: "10분", duration: 10 * 60)
    static let thirtyMinutes = FocusPreset(id: "30m", title: "30분", duration: 30 * 60)
    static let fiftyMinutes = FocusPreset(id: "50m", title: "50분", duration: 50 * 60)
    static let ninetyMinutes = FocusPreset(id: "90m", title: "90분", duration: 90 * 60)

    static let defaults: [FocusPreset] = [
        .fiveMinutes,
        .tenMinutes,
        .thirtyMinutes,
        .fiftyMinutes,
        .ninetyMinutes
    ]
}
