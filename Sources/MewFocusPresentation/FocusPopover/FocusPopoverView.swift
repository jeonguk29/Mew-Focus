import MewFocusDesign
import MewFocusDomain
import SwiftUI

public struct FocusPopoverView: View {
    @State private var session = FocusSession()

    private let startUseCase = StartFocusSessionUseCase()
    private let pauseUseCase = PauseFocusSessionUseCase()
    private let resetUseCase = ResetFocusSessionUseCase()

    public init() {}

    public var body: some View {
        VStack(spacing: 24) {
            header
            timerDial
            primaryActionButton
            presetPicker
        }
        .padding(28)
        .frame(width: 520)
        .background(.white)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "cat")
                .font(.system(size: 38, weight: .regular))

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Dial")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                Text("집중에 몰입하는 시간")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(MewFocusColor.textSecondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
        }
    }

    private var timerDial: some View {
        ZStack {
            Circle()
                .stroke(MewFocusColor.divider, lineWidth: 3)
                .frame(width: 330, height: 330)

            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(
                    MewFocusColor.coral,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 330, height: 330)

            VStack(spacing: 14) {
                Text("남은 시간")
                    .font(.system(size: 18, weight: .bold))
                Text(statusTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 8)
                    .background(.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(MewFocusColor.divider))
                Text(timeText)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    private var primaryActionButton: some View {
        Button(action: toggleSession) {
            Label(primaryActionTitle, systemImage: primaryActionIcon)
        }
        .buttonStyle(PrimaryPillButtonStyle())
        .frame(width: 300)
    }

    private var presetPicker: some View {
        HStack(spacing: 10) {
            ForEach(FocusPreset.defaults) { preset in
                Button(preset.title) {
                    session = FocusSession(
                        preset: preset,
                        duration: preset.duration,
                        remainingTime: preset.duration,
                        state: .idle
                    )
                }
                .buttonStyle(.plain)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(session.preset == preset ? .white : MewFocusColor.textPrimary)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(session.preset == preset ? MewFocusColor.coral : .white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MewFocusColor.divider))
            }
        }
    }

    private var statusTitle: String {
        switch session.state {
        case .idle: "대기 중"
        case .running: "집중 중"
        case .paused: "일시정지"
        case .completed: "완료"
        }
    }

    private var primaryActionTitle: String {
        session.state == .running ? "일시정지" : "시작"
    }

    private var primaryActionIcon: String {
        session.state == .running ? "pause.fill" : "play.fill"
    }

    private var timeText: String {
        let totalSeconds = Int(session.remainingTime)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func toggleSession() {
        if session.state == .running {
            session = pauseUseCase.execute(session)
        } else {
            session = startUseCase.execute(session)
        }
    }
}

#Preview {
    FocusPopoverView()
}
