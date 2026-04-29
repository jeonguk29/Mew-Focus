import SwiftUI

public enum MewFocusColor {
    public static let coral = Color(red: 1.0, green: 0.38, blue: 0.27)
    public static let coralLight = Color(red: 1.0, green: 0.47, blue: 0.35)
    public static let surface = Color(red: 0.99, green: 0.99, blue: 0.98)
    public static let textPrimary = Color(red: 0.12, green: 0.12, blue: 0.13)
    public static let textSecondary = Color(red: 0.48, green: 0.48, blue: 0.50)
    public static let textTertiary = Color(red: 0.64, green: 0.64, blue: 0.66)
    public static let divider = Color(red: 0.90, green: 0.90, blue: 0.92)
    public static let timerTick = Color(red: 0.77, green: 0.77, blue: 0.78)
}

public struct PrimaryPillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .padding(.vertical, 17)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [
                        MewFocusColor.coralLight.opacity(configuration.isPressed ? 0.88 : 1),
                        MewFocusColor.coral.opacity(configuration.isPressed ? 0.88 : 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(Capsule())
            .shadow(color: MewFocusColor.coral.opacity(0.22), radius: 12, x: 0, y: 8)
    }
}

public struct SecondaryPillButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(MewFocusColor.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Color.white.opacity(configuration.isPressed ? 0.72 : 1))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MewFocusColor.divider, lineWidth: 1))
            .shadow(color: .black.opacity(0.045), radius: 8, x: 0, y: 4)
    }
}
