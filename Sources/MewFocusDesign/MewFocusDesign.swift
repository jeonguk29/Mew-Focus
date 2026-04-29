import SwiftUI

public enum MewFocusColor {
    public static let coral = Color(red: 1.0, green: 0.38, blue: 0.27)
    public static let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.13)
    public static let textSecondary = Color(red: 0.48, green: 0.48, blue: 0.50)
    public static let divider = Color(red: 0.90, green: 0.90, blue: 0.92)
}

public struct PrimaryPillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
            .background(MewFocusColor.coral.opacity(configuration.isPressed ? 0.85 : 1))
            .clipShape(Capsule())
    }
}
