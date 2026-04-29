import MewFocusDesign
import MewFocusDomain
import MewFocusData
import SwiftUI
import WidgetKit

struct FocusTimerEntry: TimelineEntry {
    let date: Date
    let snapshot: FocusSessionSnapshot
}

struct FocusTimerProvider: TimelineProvider {
    private let snapshotRepository = AppGroupFocusSessionSnapshotRepository()

    func placeholder(in context: Context) -> FocusTimerEntry {
        FocusTimerEntry(
            date: .now,
            snapshot: FocusSessionSnapshot(
                session: FocusSession(
                    preset: .twentyFiveMinutes,
                    duration: 25 * 60,
                    remainingTime: 19 * 60 + 38,
                    state: .running
                ),
                updatedAt: .now
            )
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusTimerEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusTimerEntry>) -> Void) {
        let now = Date()
        let snapshot = snapshotRepository.loadSnapshot() ?? placeholder(in: context).snapshot
        let entry = FocusTimerEntry(date: now, snapshot: snapshot)
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(60))))
    }
}

struct MewFocusWidgetEntryView: View {
    let entry: FocusTimerEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        TimelineView(.periodic(from: entry.date, by: 1.0)) { context in
            let session = session(at: context.date)

            GeometryReader { proxy in
                widgetContent(session: session, size: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .containerBackground(MewFocusColor.surface, for: .widget)
            .widgetURL(URL(string: "mewfocus://timer"))
        }
    }

    @ViewBuilder
    private func widgetContent(session: FocusSession, size: CGSize) -> some View {
        switch family {
        case .systemLarge:
            largeWidget(session: session)
        default:
            mediumWidget(session: session)
        }
    }

    private func mediumWidget(session: FocusSession) -> some View {
        HStack(spacing: 16) {
            catStage(catSize: CGSize(width: 122, height: 88), isLarge: false)
                .frame(width: 134, height: 132)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    statusDotColor(for: session.state)
                        .frame(width: 8, height: 8)
                        .clipShape(Circle())

                    Text(statusTitle(for: session.state))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(MewFocusColor.divider.opacity(0.82)))

                timerText(for: session, fontSize: 46)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)

                progressBar(progress: session.progress)
                    .frame(height: 10)

                Text("Focus Dial")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
    }

    private func largeWidget(session: FocusSession) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                MewFocusAsset.image(MewFocusAsset.headerCat)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Focus Dial")
                        .font(.system(size: 27, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                        .lineLimit(1)

                    Text("집중에 몰입하는 시간")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
            }

            catStage(catSize: CGSize(width: 194, height: 132), isLarge: true)
                .frame(maxWidth: .infinity)
                .frame(height: 166)

            VStack(spacing: 10) {
                statusPill(session: session)
                timerText(for: session, fontSize: 66)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                progressBar(progress: session.progress)
                    .frame(height: 12)
            }
        }
        .padding(.top, 22)
        .padding(.horizontal, 22)
        .padding(.bottom, 20)
    }

    private func catStage(catSize: CGSize, isLarge: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: isLarge ? 28 : 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.94, green: 0.97, blue: 1.0),
                            MewFocusColor.surface,
                            Color(red: 1.0, green: 0.91, blue: 0.87)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: isLarge ? 28 : 24, style: .continuous)
                        .stroke(.white.opacity(0.82), lineWidth: 1.4)
                )

            VStack(spacing: isLarge ? 8 : 4) {
                HStack(spacing: 6) {
                    Capsule()
                        .fill(MewFocusColor.coral.opacity(0.9))
                        .frame(width: isLarge ? 54 : 34, height: isLarge ? 8 : 6)
                    Capsule()
                        .fill(Color(red: 0.42, green: 0.64, blue: 0.96).opacity(0.62))
                        .frame(width: isLarge ? 28 : 18, height: isLarge ? 8 : 6)
                    Capsule()
                        .fill(MewFocusColor.divider)
                        .frame(width: isLarge ? 18 : 12, height: isLarge ? 8 : 6)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                Spacer(minLength: 0)
            }
            .padding(isLarge ? 18 : 13)

            MewFocusAsset.image(MewFocusAsset.timerCat)
                .resizable()
                .scaledToFit()
                .frame(width: catSize.width, height: catSize.height)
                .offset(y: isLarge ? 18 : 12)

            Capsule()
                .fill(.white.opacity(0.82))
                .frame(width: catSize.width * 0.82, height: isLarge ? 12 : 9)
                .blur(radius: 8)
                .offset(y: catSize.height / 2 + (isLarge ? 20 : 14))
        }
    }

    private func statusPill(session: FocusSession) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusDotColor(for: session.state))
                .frame(width: 9, height: 9)
            Text(statusTitle(for: session.state))
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

    private func progressBar(progress: Double) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width * progress, 8)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(MewFocusColor.divider.opacity(0.82))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [MewFocusColor.coralLight, MewFocusColor.coral],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width)
            }
        }
    }

    private func session(at date: Date) -> FocusSession {
        let snapshot = entry.snapshot
        guard snapshot.session.state == .running else { return snapshot.session }

        let elapsedTime = max(date.timeIntervalSince(snapshot.updatedAt), 0)
        let remainingTime = max(snapshot.session.remainingTime - elapsedTime, 0)
        return FocusSession(
            preset: snapshot.session.preset,
            duration: snapshot.session.duration,
            remainingTime: remainingTime,
            state: remainingTime > 0 ? .running : .completed
        )
    }

    private func statusTitle(for state: TimerState) -> String {
        switch state {
        case .idle: "대기 중"
        case .running: "집중 중"
        case .paused: "일시정지"
        case .completed: "완료"
        }
    }

    private func statusDotColor(for state: TimerState) -> Color {
        switch state {
        case .idle: MewFocusColor.textTertiary
        case .running: MewFocusColor.coral
        case .paused: MewFocusColor.textTertiary
        case .completed: MewFocusColor.coral
        }
    }

    private func timeText(for remainingTime: TimeInterval) -> String {
        let totalSeconds = Int(ceil(remainingTime))
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    @ViewBuilder
    private func timerText(for session: FocusSession, fontSize: CGFloat) -> some View {
        if let interval = timerInterval(for: session) {
            Text(
                timerInterval: interval,
                pauseTime: nil,
                countsDown: true,
                showsHours: false
            )
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(MewFocusColor.textPrimary)
            .monospacedDigit()
        } else {
            Text(timeText(for: session.remainingTime))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .monospacedDigit()
        }
    }

    private func timerInterval(for session: FocusSession) -> ClosedRange<Date>? {
        guard session.state == .running else { return nil }

        let startDate = entry.snapshot.updatedAt
        let endDate = startDate.addingTimeInterval(entry.snapshot.session.remainingTime)

        guard endDate > startDate else { return nil }
        return startDate...endDate
    }
}

struct MewFocusWidget: Widget {
    static let kind = "MewFocusCatWidget"
    let kind = Self.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusTimerProvider()) { entry in
            MewFocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mew Focus Cat")
        .description("고양이와 함께 남은 집중 시간을 확인합니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct MewFocusWidgetBundle: WidgetBundle {
    var body: some Widget {
        MewFocusWidget()
    }
}

#Preview(as: .systemLarge) {
    MewFocusWidget()
} timeline: {
    FocusTimerEntry(
        date: .now,
        snapshot: FocusSessionSnapshot(
            session: FocusSession(
                preset: .twentyFiveMinutes,
                duration: 25 * 60,
                remainingTime: 19 * 60 + 38,
                state: .running
            ),
            updatedAt: .now
        )
    )
}
