import Charts
import MewFocusDesign
import MewFocusDomain
import SwiftUI

public final class FocusPopoverDisplaySettings: ObservableObject {
    public static let defaultScale = 0.64
    public static let minimumScale = 0.58
    public static let maximumScale = 0.92

    @Published public var scale: Double

    public init(scale: Double = FocusPopoverDisplaySettings.defaultScale) {
        self.scale = min(max(scale, Self.minimumScale), Self.maximumScale)
    }

    public func resetScale() {
        scale = Self.defaultScale
    }
}

public struct FocusPopoverView: View {
    @State private var session = FocusSession()
    @State private var lastTickDate: Date?
    @State private var todayFocusDuration: TimeInterval = 0
    @State private var recentSessions: [SessionRecord] = []
    @State private var focusTrend: [DailyFocusSummary] = []
    @State private var hasRecordedCurrentSession = false
    @State private var isDailyFocusListPresented = false
    @State private var isSessionListPresented = false
    @State private var isSettingsPresented = false
    @State private var selectedSessionDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedDateSessions: [SessionRecord] = []
    @State private var statisticsDay = Calendar.current.startOfDay(for: Date())
    @ObservedObject private var displaySettings: FocusPopoverDisplaySettings

    private let snapshotRepository: FocusSessionSnapshotRepository?
    private let statisticsRepository: (any FocusStatisticsRepository)?
    private let reloadWidgetTimelines: () -> Void

    private let startUseCase = StartFocusSessionUseCase()
    private let pauseUseCase = PauseFocusSessionUseCase()
    private let resetUseCase = ResetFocusSessionUseCase()
    private let endUseCase = EndFocusSessionUseCase()
    private let tickUseCase = TickFocusSessionUseCase()
    private let countdownTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    public init(
        snapshotRepository: FocusSessionSnapshotRepository? = nil,
        statisticsRepository: (any FocusStatisticsRepository)? = nil,
        displaySettings: FocusPopoverDisplaySettings = FocusPopoverDisplaySettings(),
        reloadWidgetTimelines: @escaping () -> Void = {}
    ) {
        self.snapshotRepository = snapshotRepository
        self.statisticsRepository = statisticsRepository
        self._displaySettings = ObservedObject(wrappedValue: displaySettings)
        self.reloadWidgetTimelines = reloadWidgetTimelines
    }

    public var body: some View {
        VStack(spacing: 18) {
            header
            timerDial
            primaryActionButton
            secondaryActions
            presetPicker
            quickStartHint
            statisticsDashboard
        }
        .padding(.top, 28)
        .padding(.horizontal, 34)
        .padding(.bottom, 22)
        .frame(width: 530)
        .background(MewFocusColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            restoreSnapshot()
            statisticsDay = Calendar.current.startOfDay(for: Date())
            Task {
                await loadStatistics()
            }
        }
        .onReceive(countdownTimer) { date in
            tickSession(now: date)
            refreshStatisticsIfDayChanged(now: date)
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

            Button {
                isDailyFocusListPresented = false
                isSessionListPresented = false
                isSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MewFocusColor.textPrimary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isSettingsPresented, arrowEdge: .bottom) {
                FocusSettingsView(displaySettings: displaySettings)
            }
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
                    hasRecordedCurrentSession = false
                    session = FocusSession(
                        preset: preset,
                        duration: preset.duration,
                        remainingTime: preset.duration,
                        state: .idle
                    )
                    saveSnapshot()
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

    private var statisticsDashboard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                todayFocusCard
                recentSessionsCard
            }

            HStack(spacing: 10) {
                Image(systemName: "sparkle")
                    .font(.system(size: 15, weight: .semibold))
                Text("작은 집중이 모여 큰 변화를 만듭니다.")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
            }
            .foregroundStyle(MewFocusColor.textSecondary)
            .padding(.horizontal, 18)
            .frame(height: 42)
            .background(.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.9)))
        }
        .padding(.top, -2)
    }

    private var todayFocusCard: some View {
        Button {
            isSessionListPresented = false
            isDailyFocusListPresented = true
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                Text("오늘의 집중")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(focusHoursText(todayFocusDuration))
                        .font(.system(size: 29, weight: .bold, design: .rounded))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text(focusMinutesText(todayFocusDuration))
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(MewFocusColor.textPrimary)
                }

                Chart(focusTrend) { summary in
                    LineMark(
                        x: .value("날짜", summary.date),
                        y: .value("집중", summary.duration / 3600)
                    )
                    .foregroundStyle(MewFocusColor.coral)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("날짜", summary.date),
                        y: .value("집중", summary.duration / 3600)
                    )
                    .foregroundStyle(MewFocusColor.coral)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...max(maxFocusTrendHours, 0.5))
                .frame(height: 54)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(MewFocusColor.divider.opacity(0.9)))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isDailyFocusListPresented, arrowEdge: .bottom) {
            DailyFocusListView(
                summaries: focusTrend,
                today: statisticsDay,
                maxDuration: focusTrend.map(\.duration).max() ?? 0
            )
        }
    }

    private var recentSessionsCard: some View {
        Button {
            isDailyFocusListPresented = false
            presentSessionsForRecentDate()
        } label: {
            VStack(alignment: .leading, spacing: 13) {
                Text("최근 세션")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)

                if recentSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("아직 기록이 없어요")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MewFocusColor.textPrimary)
                        Text("세션을 종료하면 여기에 쌓입니다.")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(MewFocusColor.textTertiary)
                    }
                    Spacer(minLength: 0)
                } else {
                    VStack(spacing: 10) {
                        ForEach(recentSessions.prefix(3)) { record in
                            recentSessionRow(record)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(.white.opacity(0.92))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(MewFocusColor.divider.opacity(0.9)))
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .popover(isPresented: $isSessionListPresented, arrowEdge: .bottom) {
            SessionListView(
                date: selectedSessionDate,
                sessions: selectedDateSessions
            )
        }
    }

    private func recentSessionRow(_ record: SessionRecord) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MewFocusColor.coral)
                .frame(width: 8, height: 8)

            Text(record.title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MewFocusColor.textPrimary)
                .lineLimit(1)

            Text(compactDurationText(record.duration))
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MewFocusColor.textSecondary)

            Spacer(minLength: 8)

            Text(sessionTimeText(record.completedAt))
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(MewFocusColor.textTertiary)
        }
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

    private var maxFocusTrendHours: Double {
        max(focusTrend.map { $0.duration / 3600 }.max() ?? 0, todayFocusDuration / 3600)
    }

    private func toggleSession() {
        if session.state == .running {
            tickSession(now: Date())
            lastTickDate = nil
            session = pauseUseCase.execute(session)
        } else {
            if session.state == .idle || session.state == .completed {
                hasRecordedCurrentSession = false
            }
            session = startUseCase.execute(session)
            lastTickDate = Date()
        }
        saveSnapshot()
    }

    private func resetSession() {
        hasRecordedCurrentSession = false
        lastTickDate = nil
        session = resetUseCase.execute(session)
        saveSnapshot()
    }

    private func endSession() {
        tickSession(now: Date())
        recordCurrentSessionIfNeeded(completedAt: Date())
        lastTickDate = nil
        session = endUseCase.execute(session)
        saveSnapshot()
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

        if session.state == .completed {
            recordCurrentSessionIfNeeded(completedAt: now)
            saveSnapshot(now: now)
        }
    }

    private func restoreSnapshot() {
        guard let snapshot = snapshotRepository?.loadSnapshot() else {
            saveSnapshot()
            return
        }

        session = resolvedSession(from: snapshot, now: Date())
        lastTickDate = session.state == .running ? Date() : nil
    }

    private func saveSnapshot(now: Date = Date()) {
        snapshotRepository?.saveSnapshot(
            FocusSessionSnapshot(session: session, updatedAt: now)
        )
        reloadWidgetTimelines()
    }

    private func recordCurrentSessionIfNeeded(completedAt: Date) {
        guard let statisticsRepository else { return }
        guard !hasRecordedCurrentSession else { return }

        let completedDuration = min(max(session.duration - session.remainingTime, 0), session.duration)
        guard completedDuration >= 1 else { return }

        hasRecordedCurrentSession = true
        let record = SessionRecord(
            title: "집중",
            duration: completedDuration,
            completedAt: completedAt
        )

        Task {
            try? await statisticsRepository.saveSession(record)
            await loadStatistics()
        }
    }

    @MainActor
    private func loadStatistics() async {
        guard let statisticsRepository else { return }

        do {
            async let todayDuration = statisticsRepository.todayFocusDuration(now: Date())
            async let recent = statisticsRepository.recentSessions(limit: 3)
            async let trend = statisticsRepository.dailyFocusSummaries(days: 7, now: Date())

            todayFocusDuration = try await todayDuration
            recentSessions = try await recent
            focusTrend = try await trend
        } catch {
            todayFocusDuration = 0
            recentSessions = []
            focusTrend = []
        }
    }

    private func refreshStatisticsIfDayChanged(now: Date) {
        let currentDay = Calendar.current.startOfDay(for: now)
        guard currentDay != statisticsDay else { return }

        statisticsDay = currentDay
        Task {
            await loadStatistics()
        }
    }

    private func presentSessionsForRecentDate() {
        let date = recentSessions.first?.completedAt ?? Date()
        selectedSessionDate = Calendar.current.startOfDay(for: date)
        isSessionListPresented = true

        Task {
            await loadSessions(on: date)
        }
    }

    @MainActor
    private func loadSessions(on date: Date) async {
        guard let statisticsRepository else {
            selectedDateSessions = []
            return
        }

        do {
            selectedDateSessions = try await statisticsRepository.sessions(on: date)
        } catch {
            selectedDateSessions = []
        }
    }

    private func resolvedSession(from snapshot: FocusSessionSnapshot, now: Date) -> FocusSession {
        guard snapshot.session.state == .running else { return snapshot.session }

        let elapsedTime = max(now.timeIntervalSince(snapshot.updatedAt), 0)
        let remainingTime = max(snapshot.session.remainingTime - elapsedTime, 0)
        return FocusSession(
            preset: snapshot.session.preset,
            duration: snapshot.session.duration,
            remainingTime: remainingTime,
            state: remainingTime > 0 ? .running : .completed
        )
    }

    private func focusHoursText(_ duration: TimeInterval) -> String {
        "\(Int(duration) / 3600)"
    }

    private func focusMinutesText(_ duration: TimeInterval) -> String {
        let minutes = (Int(duration) % 3600) / 60
        return "시간 \(minutes)분"
    }

    private func compactDurationText(_ duration: TimeInterval) -> String {
        let totalMinutes = max(Int(duration / 60), 1)
        return "\(totalMinutes)분"
    }

    private func sessionTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: date)
    }
}

private struct DailyFocusListView: View {
    let summaries: [DailyFocusSummary]
    let today: Date
    let maxDuration: TimeInterval

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
                    .frame(width: 34, height: 34)
                    .background(MewFocusColor.coral.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("일별 집중")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text("최근 7일 집중 시간을 확인합니다.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(summaries) { summary in
                    DailyFocusRow(
                        summary: summary,
                        isToday: Calendar.current.isDate(summary.date, inSameDayAs: today),
                        maxDuration: maxDuration
                    )
                }
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(MewFocusColor.surface)
    }
}

private struct SessionListView: View {
    let date: Date
    let sessions: [SessionRecord]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
                    .frame(width: 34, height: 34)
                    .background(MewFocusColor.coral.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(dayText) 세션")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text(totalDurationText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                }

                Spacer()
            }

            if sessions.isEmpty {
                VStack(alignment: .leading, spacing: 7) {
                    Text("기록된 세션이 없어요")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text("집중을 마치면 이 날짜에 세션이 쌓입니다.")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(MewFocusColor.textTertiary)
                }
                .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.white.opacity(0.86))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.8)))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sessions) { session in
                            SessionListRow(record: session)
                        }
                    }
                }
                .frame(maxHeight: 270)
            }
        }
        .padding(24)
        .frame(width: 420)
        .background(MewFocusColor.surface)
    }

    private var totalDurationText: String {
        "총 \(durationText(sessions.reduce(0) { $0 + $1.duration }))"
    }

    private var dayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: date)
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
}

private struct SessionListRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(MewFocusColor.coral)
                .frame(width: 9, height: 9)

            VStack(alignment: .leading, spacing: 3) {
                Text(record.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)

                Text(timeText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.textTertiary)
            }

            Spacer()

            Text(durationText)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.8)))
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "a h:mm"
        return formatter.string(from: record.completedAt)
    }

    private var durationText: String {
        let totalMinutes = max(Int(record.duration / 60), 1)
        return "\(totalMinutes)분"
    }
}

private struct FocusSettingsView: View {
    @ObservedObject var displaySettings: FocusPopoverDisplaySettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
                    .frame(width: 34, height: 34)
                    .background(MewFocusColor.coral.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("설정")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text("메뉴바 팝오버 크기를 조절합니다.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                }

                Spacer()
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("화면 크기")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)

                    Spacer()

                    Text(scaleText)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(MewFocusColor.textSecondary)
                        .monospacedDigit()
                }

                Slider(
                    value: $displaySettings.scale,
                    in: FocusPopoverDisplaySettings.minimumScale...FocusPopoverDisplaySettings.maximumScale,
                    step: 0.02
                )
                .tint(MewFocusColor.coral)

                HStack {
                    Text("작게")
                    Spacer()
                    Text("크게")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(MewFocusColor.textTertiary)

                Button("기본 크기로") {
                    displaySettings.resetScale()
                }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(MewFocusColor.coral)
                .padding(.top, 2)
            }
            .padding(16)
            .background(.white.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.85)))
        }
        .padding(22)
        .frame(width: 340)
        .background(MewFocusColor.surface)
    }

    private var scaleText: String {
        "\(Int((displaySettings.scale * 100).rounded()))%"
    }
}

private struct DailyFocusRow: View {
    let summary: DailyFocusSummary
    let isToday: Bool
    let maxDuration: TimeInterval

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(dayText)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)

                    if isToday {
                        Text("오늘")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(MewFocusColor.coral)
                            .clipShape(Capsule())
                    }
                }

                Text(weekdayText)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.textTertiary)
            }
            .frame(width: 78, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(MewFocusColor.divider.opacity(0.55))

                    Capsule()
                        .fill(MewFocusColor.coral)
                        .frame(width: proxy.size.width * progress)
                }
            }
            .frame(height: 8)

            Text(durationText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textSecondary)
                .monospacedDigit()
                .frame(width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(isToday ? 0.98 : 0.82))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isToday ? MewFocusColor.coral.opacity(0.45) : MewFocusColor.divider.opacity(0.8))
        )
    }

    private var progress: Double {
        guard maxDuration > 0 else { return 0 }
        return min(max(summary.duration / maxDuration, 0), 1)
    }

    private var dayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "M월 d일"
        return formatter.string(from: summary.date)
    }

    private var weekdayText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: summary.date)
    }

    private var durationText: String {
        let totalMinutes = Int(summary.duration / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(minutes)분"
        }

        return "\(hours)시간 \(minutes)분"
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
