import MewFocusData
import MewFocusDesign
import MewFocusDomain
import SwiftUI
import WidgetKit

struct FocusStatisticsEntry: TimelineEntry {
    let date: Date
    let timerSnapshot: FocusSessionSnapshot?
    let snapshot: FocusStatisticsSnapshot
}

struct FocusStatisticsProvider: TimelineProvider {
    private let timerSnapshotRepository = AppGroupFocusSessionSnapshotRepository()
    private let statisticsSnapshotRepository = AppGroupFocusStatisticsSnapshotRepository()
    private let fallbackTimerSnapshot = FocusSessionSnapshot(
        session: FocusSession(
            preset: .thirtyMinutes,
            duration: 30 * 60,
            remainingTime: 22 * 60 + 14,
            state: .running
        ),
        updatedAt: .now,
        mode: .focus
    )
    private let fallbackSnapshot = FocusStatisticsSnapshot(
        todayFocusDuration: 2 * 3600 + 45 * 60,
        recentSessions: [
            SessionRecord(title: "집중", duration: 25 * 60, completedAt: .now.addingTimeInterval(-18 * 60), kind: .focus),
            SessionRecord(title: "휴식", duration: 10 * 60, completedAt: .now.addingTimeInterval(-48 * 60), kind: .shortBreak),
            SessionRecord(title: "집중", duration: 50 * 60, completedAt: .now.addingTimeInterval(-82 * 60), kind: .focus)
        ],
        updatedAt: .now
    )

    func placeholder(in context: Context) -> FocusStatisticsEntry {
        FocusStatisticsEntry(
            date: .now,
            timerSnapshot: fallbackTimerSnapshot,
            snapshot: fallbackSnapshot
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (FocusStatisticsEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FocusStatisticsEntry>) -> Void) {
        completion(
            Timeline(
                entries: [entry()],
                policy: .after(.now.addingTimeInterval(15 * 60))
            )
        )
    }

    private func entry() -> FocusStatisticsEntry {
        FocusStatisticsEntry(
            date: .now,
            timerSnapshot: timerSnapshotRepository.loadSnapshot() ?? fallbackTimerSnapshot,
            snapshot: statisticsSnapshotRepository.loadSnapshot() ?? fallbackSnapshot
        )
    }
}

struct MewFocusWidgetEntryView: View {
    let entry: FocusStatisticsEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottomTrailing) {
                switch family {
                case .systemSmall:
                    smallWidget(size: proxy.size)
                case .systemLarge:
                    largeWidget(size: proxy.size)
                default:
                    mediumWidget(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .unredacted()
        .containerBackground(for: .widget) {
            widgetContainerBackground
        }
        .widgetURL(URL(string: "mewfocus://timer"))
    }

    private func smallWidget(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                catIcon(size: 42)

                VStack(alignment: .leading, spacing: 0) {
                    Text("Mew Focus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.70)

                    Text("집중 시간")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 2)

            Text("남은 시간")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MewFocusColor.textSecondary)

            countdownText(fontSize: 30)

            statusPill(compact: true)

            Spacer(minLength: 2)

            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
                Text(durationText(entry.snapshot.todayFocusDuration))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(14)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func mediumWidget(size: CGSize) -> some View {
        let cardHeight = max(82, size.height - 74)

        return VStack(alignment: .leading, spacing: 9) {
            header(iconSize: 44, titleSize: 21, subtitleSize: 11)

            HStack(alignment: .top, spacing: 10) {
                mediumCountdownCard()
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)

                mediumTodayFocusCard
                    .frame(maxWidth: .infinity)
                    .frame(height: cardHeight)
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 20)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func largeWidget(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            header(iconSize: 58, titleSize: 25, subtitleSize: 14)

            HStack(alignment: .bottom, spacing: 10) {
                countdownBlock(fontSize: 52, showSessionTitle: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                MewFocusAsset.image(MewFocusAsset.timerCat)
                    .resizable()
                    .scaledToFit()
                    .frame(width: min(112, size.width * 0.26), height: 74)
                    .opacity(0.9)
                    .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(filledCardBackground(cornerRadius: 20, tint: activeTintColor))

            HStack(alignment: .top, spacing: 10) {
                statTile(
                    title: "오늘의 집중",
                    systemImage: "chart.bar.fill",
                    value: durationText(entry.snapshot.todayFocusDuration),
                    accent: MewFocusColor.coral,
                    isLarge: true
                )

                recentTile(limit: 4, isLarge: true)
            }
            .frame(height: 96)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(.top, 18)
        .padding(.horizontal, 18)
        .padding(.bottom, 48)
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func countdownBlock(fontSize: CGFloat, showSessionTitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("남은 시간")
                .font(.system(size: fontSize > 50 ? 14 : 12, weight: .bold))
                .foregroundStyle(MewFocusColor.textSecondary)
                .lineLimit(1)

            countdownText(fontSize: fontSize)

            HStack(spacing: 8) {
                statusPill(compact: fontSize < 45)

                if showSessionTitle, let timerSnapshot = entry.timerSnapshot {
                    Text(sessionDescription(for: timerSnapshot.session))
                        .font(.system(size: fontSize > 50 ? 12 : 11, weight: .bold))
                        .foregroundStyle(MewFocusColor.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
        }
    }

    private func mediumCountdownCard() -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("남은 시간")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MewFocusColor.textSecondary)
                .lineLimit(1)

            countdownText(fontSize: 30)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                statusPill(compact: true)
                    .fixedSize(horizontal: true, vertical: false)

                if let timerSnapshot = entry.timerSnapshot {
                    Text(sessionDescription(for: timerSnapshot.session))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(MewFocusColor.textTertiary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                }
            }
        }
        .layoutPriority(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(filledCardBackground(cornerRadius: 18, tint: activeTintColor))
    }

    private func statTile(
        title: String,
        systemImage: String,
        value: String,
        accent: Color,
        isLarge: Bool = false,
        compact: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: isLarge ? 6 : 5) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: isLarge ? 15 : 12, weight: .bold))
                    .foregroundStyle(accent)

                Text(title)
                    .font(.system(size: isLarge ? 13 : 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(compact ? 1 : 2)
                    .minimumScaleFactor(0.7)
            }
            .lineLimit(1)

            Text(compact ? compactDurationText(entry.snapshot.todayFocusDuration) : value)
                .font(.system(size: isLarge ? 23 : (compact ? 16 : 18), weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.58)

            if isLarge {
                Text("차곡차곡 쌓인 기록")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MewFocusColor.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, minHeight: isLarge ? 88 : (compact ? 84 : 68), alignment: .topLeading)
        .padding(isLarge ? 11 : (compact ? 9 : 10))
        .background(outlinedCardBackground(cornerRadius: isLarge ? 18 : 14))
    }

    private var mediumTodayFocusCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 7) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)

                Text("오늘의 집중")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(durationText(entry.snapshot.todayFocusDuration))
                .font(.system(size: 25, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .monospacedDigit()
                .lineLimit(2)
                .minimumScaleFactor(0.58)

            Text("차곡차곡 쌓인 기록")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(MewFocusColor.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(outlinedCardBackground(cornerRadius: 18))
        .overlay(alignment: .topTrailing) {
            MewFocusAsset.image(MewFocusAsset.timerCat)
                .resizable()
                .scaledToFit()
                .frame(width: 84, height: 58)
                .offset(x: -56, y: -42)
                .opacity(0.94)
                .allowsHitTesting(false)
        }
    }

    private func recentTile(limit: Int, isLarge: Bool = false, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: isLarge ? 6 : 5) {
            HStack(spacing: 7) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: isLarge ? 15 : 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)

                Text("최근 세션")
                    .font(.system(size: isLarge ? 13 : 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            if entry.snapshot.recentSessions.isEmpty {
                emptyRecentText
            } else {
                ForEach(Array(entry.snapshot.recentSessions.prefix(limit))) { session in
                    sessionRow(session, isLarge: isLarge, compact: compact)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: isLarge ? 88 : (compact ? 56 : 68), alignment: .topLeading)
        .padding(isLarge ? 11 : (compact ? 9 : 10))
        .background(outlinedCardBackground(cornerRadius: isLarge ? 18 : 14))
    }

    private var widgetContainerBackground: some View {
        LinearGradient(
            colors: [
                MewFocusColor.surface,
                Color(red: 1.0, green: 0.985, blue: 0.965),
                Color(red: 1.0, green: 0.955, blue: 0.935)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func filledCardBackground(cornerRadius: CGFloat, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        tint.opacity(0.105),
                        Color.white.opacity(0.92),
                        tint.opacity(0.055)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }

    private func outlinedCardBackground(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.white.opacity(0.82))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(MewFocusColor.divider.opacity(0.92), lineWidth: 1)
            )
    }

    private func header(iconSize: CGFloat, titleSize: CGFloat, subtitleSize: CGFloat) -> some View {
        HStack(spacing: 10) {
            catIcon(size: iconSize)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mew Focus")
                    .font(.system(size: titleSize, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("집중에 몰입하는 시간")
                    .font(.system(size: subtitleSize, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 0)
        }
    }

    private func catIcon(size: CGFloat) -> some View {
        MewFocusAsset.image(MewFocusAsset.headerCat)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }

    @ViewBuilder
    private func countdownText(fontSize: CGFloat) -> some View {
        if let timerInterval = timerInterval {
            Text(timerInterval: timerInterval, pauseTime: nil, countsDown: true, showsHours: false)
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        } else {
            Text(timeText(for: resolvedSession.remainingTime))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
    }

    private func statusPill(compact: Bool = false) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(statusColor)
                .frame(width: compact ? 7 : 8, height: compact ? 7 : 8)

            Text(statusTitle)
                .font(.system(size: compact ? 12 : 13, weight: .bold))
                .foregroundStyle(MewFocusColor.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 9 : 11)
        .padding(.vertical, compact ? 5 : 7)
        .background(Color.white.opacity(0.92))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(statusColor.opacity(0.24)))
    }

    private func compactMetricRow(title: String, systemImage: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)

                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
        }
        .frame(maxWidth: .infinity, minHeight: 49, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(outlinedCardBackground(cornerRadius: 14))
    }

    private func compactRecentRow(_ session: SessionRecord) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)

                Text("최근 세션")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(sessionAccentColor(session))
                    .frame(width: 7, height: 7)

                Text(session.title)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .lineLimit(1)

                Text(compactDurationText(session.duration))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 49, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(outlinedCardBackground(cornerRadius: 14))
    }

    private func sessionRow(_ session: SessionRecord, isLarge: Bool, compact: Bool = false) -> some View {
        HStack(spacing: isLarge ? 7 : 5) {
            Circle()
                .fill(sessionAccentColor(session))
                .frame(width: isLarge ? 8 : 7, height: isLarge ? 8 : 7)

            Text(session.title)
                .font(.system(size: isLarge ? 12 : (compact ? 9 : 10), weight: .bold))
                .foregroundStyle(MewFocusColor.textPrimary)
                .lineLimit(1)

            Text(compactDurationText(session.duration))
                .font(.system(size: isLarge ? 12 : (compact ? 9 : 10), weight: .bold))
                .foregroundStyle(MewFocusColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 2)

        }
    }

    private var emptyRecentText: some View {
        Text("아직 기록이 없어요")
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(MewFocusColor.textTertiary)
    }

    private func sessionAccentColor(_ session: SessionRecord) -> Color {
        session.kind == .shortBreak || session.title == "휴식" ? MewFocusColor.mint : MewFocusColor.coral
    }

    private var resolvedSession: FocusSession {
        guard let timerSnapshot = entry.timerSnapshot else { return FocusSession() }
        guard timerSnapshot.session.state == .running else { return timerSnapshot.session }

        let elapsedTime = max(entry.date.timeIntervalSince(timerSnapshot.updatedAt), 0)
        let remainingTime = max(timerSnapshot.session.remainingTime - elapsedTime, 0)

        return FocusSession(
            preset: timerSnapshot.session.preset,
            duration: timerSnapshot.session.duration,
            remainingTime: remainingTime,
            state: remainingTime > 0 ? .running : .completed
        )
    }

    private var timerInterval: ClosedRange<Date>? {
        guard
            let timerSnapshot = entry.timerSnapshot,
            timerSnapshot.session.state == .running
        else {
            return nil
        }

        let startDate = timerSnapshot.updatedAt
        let endDate = startDate.addingTimeInterval(timerSnapshot.session.remainingTime)
        guard endDate > entry.date else { return nil }

        return startDate...endDate
    }

    private var statusTitle: String {
        switch resolvedSession.state {
        case .idle: isShortBreakMode ? "휴식 대기" : "대기 중"
        case .running: isShortBreakMode ? "휴식 중" : "집중 중"
        case .paused: "일시정지"
        case .completed: isShortBreakMode ? "휴식 완료" : "완료"
        }
    }

    private var statusColor: Color {
        switch resolvedSession.state {
        case .idle, .paused:
            MewFocusColor.textTertiary
        case .running, .completed:
            activeTintColor
        }
    }

    private func sessionDescription(for session: FocusSession) -> String {
        let title = session.preset?.title ?? durationText(session.duration)
        return isShortBreakMode ? "\(title) 휴식" : "\(title) 세션"
    }

    private var isShortBreakMode: Bool {
        entry.timerSnapshot?.mode == .shortBreak
    }

    private var activeTintColor: Color {
        isShortBreakMode ? MewFocusColor.mint : MewFocusColor.coral
    }

    private func timeText(for remainingTime: TimeInterval) -> String {
        let totalSeconds = max(Int(ceil(remainingTime)), 0)
        return String(format: "%02d:%02d", totalSeconds / 60, totalSeconds % 60)
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let totalMinutes = Int(duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)분"
        }

        return "\(hours)시간 \(minutes)분"
    }

    private func compactDurationText(_ duration: TimeInterval) -> String {
        "\(max(Int(duration / 60), 1))분"
    }

    private func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

struct MewFocusWidget: Widget {
    static let kind = "MewFocusDashboardWidget"
    let kind = Self.kind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FocusStatisticsProvider()) { entry in
            MewFocusWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Mew Focus")
        .description("오늘의 집중 시간과 최근 세션을 확인합니다.")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
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
    FocusStatisticsEntry(
        date: .now,
        timerSnapshot: FocusSessionSnapshot(
            session: FocusSession(
                preset: .thirtyMinutes,
                duration: 30 * 60,
                remainingTime: 22 * 60 + 14,
                state: .running
            ),
            updatedAt: .now,
            mode: .focus
        ),
        snapshot: FocusStatisticsSnapshot(
            todayFocusDuration: 2 * 3600 + 45 * 60,
            recentSessions: [
                SessionRecord(title: "집중", duration: 25 * 60, completedAt: .now.addingTimeInterval(-18 * 60), kind: .focus),
                SessionRecord(title: "휴식", duration: 10 * 60, completedAt: .now.addingTimeInterval(-48 * 60), kind: .shortBreak),
                SessionRecord(title: "집중", duration: 50 * 60, completedAt: .now.addingTimeInterval(-82 * 60), kind: .focus)
            ],
            updatedAt: .now
        )
    )
}

#Preview(as: .systemMedium) {
    MewFocusWidget()
} timeline: {
    FocusStatisticsEntry(
        date: .now,
        timerSnapshot: FocusSessionSnapshot(
            session: FocusSession(
                preset: .thirtyMinutes,
                duration: 30 * 60,
                remainingTime: 22 * 60 + 14,
                state: .running
            ),
            updatedAt: .now,
            mode: .focus
        ),
        snapshot: FocusStatisticsSnapshot(
            todayFocusDuration: 2 * 3600 + 45 * 60,
            recentSessions: [
                SessionRecord(title: "집중", duration: 25 * 60, completedAt: .now.addingTimeInterval(-18 * 60), kind: .focus),
                SessionRecord(title: "휴식", duration: 10 * 60, completedAt: .now.addingTimeInterval(-48 * 60), kind: .shortBreak),
                SessionRecord(title: "집중", duration: 50 * 60, completedAt: .now.addingTimeInterval(-82 * 60), kind: .focus)
            ],
            updatedAt: .now
        )
    )
}
