import MewFocusDesign
import MewFocusDomain
import SwiftUI

public struct FocusPopoverView: View {
    @State private var session = FocusSession()
    @State private var lastTickDate: Date?

    private let startUseCase = StartFocusSessionUseCase()
    private let pauseUseCase = PauseFocusSessionUseCase()
    private let resetUseCase = ResetFocusSessionUseCase()
    private let endUseCase = EndFocusSessionUseCase()
    private let tickUseCase = TickFocusSessionUseCase()
    private let countdownTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    public init() {}

    public var body: some View {
        VStack(spacing: 18) {
            header
            timerDial
            primaryActionButton
            secondaryActions
            presetPicker
            quickStartHint
        }
        .padding(.top, 28)
        .padding(.horizontal, 34)
        .padding(.bottom, 22)
        .frame(width: 530)
        .background(MewFocusColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onReceive(countdownTimer) { date in
            tickSession(now: date)
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            MewFocusAsset.image(MewFocusAsset.headerCat)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text("Focus Dial")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                Text("집중에 몰입하는 시간")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
            }

            Spacer()

            Button(action: {}) {
                Image(systemName: "gearshape")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MewFocusColor.textPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    private var timerDial: some View {
        ZStack {
            TimerTickMarks()
                .stroke(MewFocusColor.timerTick.opacity(0.62), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 324, height: 324)

            Circle()
                .stroke(MewFocusColor.divider.opacity(0.85), lineWidth: 2)
                .frame(width: 360, height: 360)

            Circle()
                .trim(from: 0, to: session.progress)
                .stroke(
                    MewFocusColor.coral,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 344, height: 344)
                .animation(.linear(duration: 1.0 / 30.0), value: session.progress)

            progressKnob

            VStack(spacing: 16) {
                Text("남은 시간")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .padding(.top, 8)
                statusPill
                Text(timeText)
                    .font(.system(size: 86, weight: .bold, design: .rounded))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .monospacedDigit()
            }
            .offset(y: -16)

            MewFocusAsset.image(MewFocusAsset.timerCat)
                .resizable()
                .scaledToFit()
                .frame(width: 178, height: 116)
                .offset(y: 143)
        }
        .frame(width: 372, height: 372)
        .padding(.top, -4)
    }

    private var primaryActionButton: some View {
        Button(action: toggleSession) {
            HStack(spacing: 18) {
                Image(systemName: primaryActionIcon)
                    .font(.system(size: 26, weight: .bold))
                Text(primaryActionTitle)
                    .font(.system(size: 25, weight: .bold))
            }
        }
        .buttonStyle(PrimaryPillButtonStyle())
        .frame(width: 320)
        .padding(.top, -8)
    }

    private var secondaryActions: some View {
        HStack(spacing: 10) {
            Button(action: resetSession) {
                Label("초기화", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryPillButtonStyle())

            Button(action: {}) {
                Label("짧은 휴식", systemImage: "cup.and.saucer")
            }
            .buttonStyle(SecondaryPillButtonStyle())

            Button(action: endSession) {
                Label("세션 종료", systemImage: "stop.fill")
            }
            .buttonStyle(SecondaryPillButtonStyle())
        }
        .padding(.top, 4)
    }

    private var presetPicker: some View {
        HStack(spacing: 8) {
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
                .frame(width: 58, height: 40)
                .background(session.preset == preset ? MewFocusColor.coral : .white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MewFocusColor.divider))
            }

            Button(action: {}) {
                Label("직접 설정", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(MewFocusColor.textPrimary)
            .frame(width: 88, height: 40)
            .background(.white)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(MewFocusColor.textTertiary.opacity(0.72), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
            )
        }
    }

    private var quickStartHint: some View {
        HStack(spacing: 6) {
            Image(systemName: "command")
                .font(.system(size: 11, weight: .bold))
            Text("D")
                .font(.system(size: 12, weight: .bold))
            Text("빠른 시작")
                .font(.system(size: 12, weight: .bold))
        }
        .foregroundStyle(MewFocusColor.textTertiary)
        .padding(.horizontal, 24)
        .padding(.vertical, 7)
        .background(.white.opacity(0.76))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MewFocusColor.divider.opacity(0.65)))
        .padding(.top, -8)
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor)
                .frame(width: 9, height: 9)
            Text(statusTitle)
        }
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(MewFocusColor.textPrimary)
        .padding(.horizontal, 18)
        .padding(.vertical, 9)
        .background(.white)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(MewFocusColor.divider.opacity(0.85)))
        .shadow(color: .black.opacity(0.035), radius: 8, x: 0, y: 3)
    }

    private var progressKnob: some View {
        ZStack(alignment: .top) {
            Color.clear

            Circle()
                .fill(MewFocusColor.coral)
                .frame(width: 27, height: 27)
                .padding(6)
                .background(.white)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.14), radius: 5, x: 0, y: 2)
                .offset(y: -9)
        }
        .frame(width: 344, height: 344)
            .rotationEffect(.degrees(progressAngle))
            .animation(.linear(duration: 1.0 / 30.0), value: session.progress)
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

    private var statusDotColor: Color {
        switch session.state {
        case .idle: MewFocusColor.textTertiary
        case .running: MewFocusColor.coral
        case .paused: MewFocusColor.textTertiary
        case .completed: MewFocusColor.coral
        }
    }

    private var progressAngle: Double {
        session.progress * 360
    }

    private var timeText: String {
        let totalSeconds = Int(ceil(session.remainingTime))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func toggleSession() {
        if session.state == .running {
            tickSession(now: Date())
            lastTickDate = nil
            session = pauseUseCase.execute(session)
        } else {
            session = startUseCase.execute(session)
            lastTickDate = Date()
        }
    }

    private func resetSession() {
        lastTickDate = nil
        session = resetUseCase.execute(session)
    }

    private func endSession() {
        lastTickDate = nil
        session = endUseCase.execute(session)
    }

    private func tickSession(now: Date) {
        guard session.state == .running else { return }

        guard let lastTickDate else {
            self.lastTickDate = now
            return
        }

        let elapsedTime = now.timeIntervalSince(lastTickDate)
        session = tickUseCase.execute(session, elapsedTime: elapsedTime)
        self.lastTickDate = session.state == .running ? now : nil
    }
}

private struct TimerTickMarks: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for index in 0..<44 {
            let angle = (Double(index) / 44.0) * 2 * .pi - (.pi / 2)
            let innerRadius = radius - 13
            let outerRadius = radius - 4
            let start = CGPoint(
                x: center.x + CGFloat(cos(angle)) * innerRadius,
                y: center.y + CGFloat(sin(angle)) * innerRadius
            )
            let end = CGPoint(
                x: center.x + CGFloat(cos(angle)) * outerRadius,
                y: center.y + CGFloat(sin(angle)) * outerRadius
            )
            path.move(to: start)
            path.addLine(to: end)
        }

        return path
    }
}

#Preview {
    FocusPopoverView()
}
