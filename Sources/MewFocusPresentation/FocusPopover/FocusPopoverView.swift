import Charts
import AppKit
import MewFocusDesign
import MewFocusDomain
import SwiftUI
import UserNotifications

private enum FocusTimerMode {
    case focus
    case shortBreak
}

private extension SessionRecord {
    var accentColor: Color {
        isShortBreak ? MewFocusColor.mint : MewFocusColor.coral
    }

    var isShortBreak: Bool {
        kind == .shortBreak || title == "휴식"
    }
}

private enum FocusPresetStorage {
    static let defaultDurations = FocusPreset.defaults.map(\.duration)

    private static let key = "mew.focus.focusPresetDurations"

    static func load() -> [TimeInterval] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let values = try? JSONDecoder().decode([TimeInterval].self, from: data)
        else {
            return defaultDurations
        }

        return normalizedDurations(values)
    }

    static func save(_ durations: [TimeInterval]) {
        guard let data = try? JSONEncoder().encode(normalizedDurations(durations)) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func normalizedDurations(_ durations: [TimeInterval]) -> [TimeInterval] {
        let filledDurations = Array((durations + defaultDurations).prefix(defaultDurations.count))
        return filledDurations.map { duration in
            if duration <= 10 {
                return defaultDurations.first ?? 5 * 60
            }

            let minutes = min(max(Int((duration / 60).rounded()), 1), 180)
            return TimeInterval(minutes * 60)
        }
    }
}

private struct GoalNotificationSettings: Codable, Equatable {
    var isHalfGoalEnabled: Bool
    var isFullGoalEnabled: Bool

    static let `default` = GoalNotificationSettings(
        isHalfGoalEnabled: false,
        isFullGoalEnabled: false
    )
}

private enum GoalNotificationStorage {
    private static let settingsKey = "mew.focus.goalNotificationSettings"

    static func loadSettings() -> GoalNotificationSettings {
        guard
            let data = UserDefaults.standard.data(forKey: settingsKey),
            let settings = try? JSONDecoder().decode(GoalNotificationSettings.self, from: data)
        else {
            return .default
        }

        return settings
    }

    static func saveSettings(_ settings: GoalNotificationSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        UserDefaults.standard.set(data, forKey: settingsKey)
    }
}

public struct FocusPopoverView: View {
    @State private var session = FocusSession()
    @State private var lastTickDate: Date?
    @State private var timerMode: FocusTimerMode = .focus
    @State private var presetDurations = FocusPresetStorage.defaultDurations
    @State private var todayFocusDuration: TimeInterval = 0
    @State private var recentSessions: [SessionRecord] = []
    @State private var focusTrend: [DailyFocusSummary] = []
    @State private var hasRecordedCurrentSession = false
    @State private var isDailyFocusListPresented = false
    @State private var isSessionListPresented = false
    @State private var isPresetSettingsPresented = false
    @State private var isAppSettingsPresented = false
    @State private var goalNotificationSettings = GoalNotificationSettings.default
    @State private var hasSentHalfGoalNotification = false
    @State private var hasSentFullGoalNotification = false
    @State private var selectedSessionDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedDateSessions: [SessionRecord] = []
    @State private var statisticsDay = Calendar.current.startOfDay(for: Date())

    private let snapshotRepository: FocusSessionSnapshotRepository?
    private let statisticsRepository: (any FocusStatisticsRepository)?
    private let reloadWidgetTimelines: () -> Void
    private let updateWidgetStatistics: (FocusStatisticsSnapshot) -> Void

    private let startUseCase = StartFocusSessionUseCase()
    private let pauseUseCase = PauseFocusSessionUseCase()
    private let resetUseCase = ResetFocusSessionUseCase()
    private let tickUseCase = TickFocusSessionUseCase()
    private let countdownTimer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()
    private let shortBreakDuration: TimeInterval = 10 * 60

    public init(
        snapshotRepository: FocusSessionSnapshotRepository? = nil,
        statisticsRepository: (any FocusStatisticsRepository)? = nil,
        reloadWidgetTimelines: @escaping () -> Void = {},
        updateWidgetStatistics: @escaping (FocusStatisticsSnapshot) -> Void = { _ in }
    ) {
        self.snapshotRepository = snapshotRepository
        self.statisticsRepository = statisticsRepository
        self.reloadWidgetTimelines = reloadWidgetTimelines
        self.updateWidgetStatistics = updateWidgetStatistics
    }

    public var body: some View {
        VStack(spacing: 18) {
            header
            timerDial
            primaryActionButton
            secondaryActions
            presetPicker
            statisticsDashboard
        }
        .padding(.top, 28)
        .padding(.horizontal, 34)
        .padding(.bottom, 48)
        .frame(width: 530)
        .frame(minHeight: 940, alignment: .top)
        .background(MewFocusColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .onAppear {
            presetDurations = FocusPresetStorage.load()
            goalNotificationSettings = GoalNotificationStorage.loadSettings()
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
        .onChange(of: presetDurations) { _, durations in
            presetDurations = FocusPresetStorage.normalizedDurations(durations)
            FocusPresetStorage.save(durations)
            syncIdleSessionWithEditedPreset()
        }
        .onChange(of: goalNotificationSettings) { _, settings in
            GoalNotificationStorage.saveSettings(settings)
            requestNotificationAuthorizationIfNeeded(settings)
            evaluateSessionGoalNotifications()
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            MewFocusAsset.image(MewFocusAsset.headerCat)
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 2) {
                Text("Mew Focus")
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
                isPresetSettingsPresented = false
                isAppSettingsPresented = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(MewFocusColor.textPrimary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isAppSettingsPresented, arrowEdge: .bottom) {
                FocusSettingsView(
                    notificationSettings: $goalNotificationSettings
                )
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
                    activeAccentColor,
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
        .buttonStyle(
            PrimaryPillButtonStyle(
                leadingColor: activeAccentLightColor,
                trailingColor: activeAccentColor,
                shadowColor: activeAccentColor
            )
        )
        .frame(width: 320)
        .padding(.top, -8)
    }

    private var secondaryActions: some View {
        HStack(spacing: 12) {
            Button(action: resetCurrentSession) {
                Label("세션 초기화", systemImage: "arrow.clockwise")
            }
            .buttonStyle(SecondaryPillButtonStyle())

            Button(action: startShortBreak) {
                Label("짧은 휴식", systemImage: "cup.and.saucer")
            }
            .buttonStyle(SecondaryPillButtonStyle())
        }
        .padding(.top, 4)
    }

    private var presetPicker: some View {
        HStack(spacing: 8) {
            ForEach(focusPresets) { preset in
                Button {
                    hasRecordedCurrentSession = false
                    resetSessionGoalNotificationFlags()
                    timerMode = .focus
                    session = FocusSession(
                        preset: preset,
                        duration: preset.duration,
                        remainingTime: preset.duration,
                        state: .idle
                    )
                    saveSnapshot()
                } label: {
                    Text(preset.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isSelectedPreset(preset) ? .white : MewFocusColor.textPrimary)
                        .frame(width: 58, height: 40)
                        .background(isSelectedPreset(preset) ? MewFocusColor.coral : .white)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(MewFocusColor.divider))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            Button {
                isDailyFocusListPresented = false
                isSessionListPresented = false
                isPresetSettingsPresented = true
            } label: {
                Label("직접 설정", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .frame(width: 88, height: 40)
                    .background(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(MewFocusColor.textTertiary.opacity(0.72), style: StrokeStyle(lineWidth: 1.2, dash: [5, 4]))
                    )
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .popover(isPresented: $isPresetSettingsPresented, arrowEdge: .bottom) {
                FocusPresetSettingsView(durations: $presetDurations)
            }
        }
    }

    private var statisticsDashboard: some View {
        VStack(spacing: 14) {
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
            .frame(height: 50)
            .background(.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.9)))
        }
        .padding(.top, 2)
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
                .fill(record.accentColor)
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
                .fill(activeAccentColor)
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
        case .idle: timerMode == .shortBreak ? "휴식 대기" : "대기 중"
        case .running: timerMode == .shortBreak ? "휴식 중" : "집중 중"
        case .paused: "일시정지"
        case .completed: timerMode == .shortBreak ? "휴식 완료" : "완료"
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
        case .running: activeAccentColor
        case .paused: MewFocusColor.textTertiary
        case .completed: activeAccentColor
        }
    }

    private var activeAccentColor: Color {
        timerMode == .shortBreak ? MewFocusColor.mint : MewFocusColor.coral
    }

    private var activeAccentLightColor: Color {
        timerMode == .shortBreak ? MewFocusColor.mintLight : MewFocusColor.coralLight
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

    private var focusPresets: [FocusPreset] {
        zip(FocusPreset.defaults, presetDurations).map { basePreset, duration in
            FocusPreset(
                id: basePreset.id,
                title: presetTitle(for: duration),
                duration: duration
            )
        }
    }

    private func toggleSession() {
        if session.state == .running {
            tickSession(now: Date())
            lastTickDate = nil
            session = pauseUseCase.execute(session)
        } else {
            if session.state == .idle || session.state == .completed {
                hasRecordedCurrentSession = false
                resetSessionGoalNotificationFlags()
            }
            session = startUseCase.execute(session)
            lastTickDate = Date()
        }
        saveSnapshot()
    }

    private func resetCurrentSession() {
        tickSession(now: Date())
        recordCurrentSessionIfNeeded(completedAt: Date())
        hasRecordedCurrentSession = false
        resetSessionGoalNotificationFlags()
        lastTickDate = nil
        session = resetUseCase.execute(session)
        saveSnapshot()
    }

    private func startShortBreak() {
        timerMode = .shortBreak
        hasRecordedCurrentSession = false
        resetSessionGoalNotificationFlags()
        session = FocusSession(
            preset: nil,
            duration: shortBreakDuration,
            remainingTime: shortBreakDuration,
            state: .running
        )
        lastTickDate = Date()
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
        evaluateSessionGoalNotifications()

        if session.state == .completed {
            recordCurrentSessionIfNeeded(completedAt: now)
            saveSnapshot(now: now)
        }
    }

    private func isSelectedPreset(_ preset: FocusPreset) -> Bool {
        timerMode == .focus && session.preset?.id == preset.id
    }

    private func syncIdleSessionWithEditedPreset() {
        guard
            timerMode == .focus,
            session.state == .idle,
            let presetID = session.preset?.id,
            let editedPreset = focusPresets.first(where: { $0.id == presetID })
        else {
            return
        }

        session = FocusSession(
            preset: editedPreset,
            duration: editedPreset.duration,
            remainingTime: editedPreset.duration,
            state: .idle
        )
        saveSnapshot()
    }

    private func presetTitle(for duration: TimeInterval) -> String {
        "\(max(Int(duration / 60), 1))분"
    }

    private func restoreSnapshot() {
        guard let snapshot = snapshotRepository?.loadSnapshot() else {
            saveSnapshot()
            return
        }

        timerMode = snapshot.mode == .shortBreak ? .shortBreak : .focus
        session = resolvedSession(from: snapshot, now: Date())
        lastTickDate = session.state == .running ? Date() : nil
    }

    private func saveSnapshot(now: Date = Date()) {
        snapshotRepository?.saveSnapshot(
            FocusSessionSnapshot(
                session: session,
                updatedAt: now,
                mode: timerMode == .shortBreak ? .shortBreak : .focus
            )
        )
        reloadWidgetTimelines()
    }

    private func recordCurrentSessionIfNeeded(completedAt: Date) {
        guard let statisticsRepository else { return }
        guard !hasRecordedCurrentSession else { return }

        let completedDuration = min(max(session.duration - session.remainingTime, 0), session.duration)
        guard completedDuration >= 1 else { return }

        hasRecordedCurrentSession = true
        let recordKind: SessionRecordKind = timerMode == .shortBreak ? .shortBreak : .focus
        let record = SessionRecord(
            title: recordKind == .shortBreak ? "휴식" : "집중",
            duration: completedDuration,
            completedAt: completedAt,
            kind: recordKind
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
            updateWidgetStatistics(
                FocusStatisticsSnapshot(
                    todayFocusDuration: todayFocusDuration,
                    recentSessions: recentSessions,
                    updatedAt: Date()
                )
            )
        } catch {
            todayFocusDuration = 0
            recentSessions = []
            focusTrend = []
        }
    }

    private func requestNotificationAuthorizationIfNeeded(_ settings: GoalNotificationSettings) {
        guard settings.isHalfGoalEnabled || settings.isFullGoalEnabled else { return }

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func evaluateSessionGoalNotifications() {
        guard timerMode == .focus, session.duration > 0 else { return }

        if goalNotificationSettings.isFullGoalEnabled,
           session.progress >= 1,
           !hasSentFullGoalNotification {
            hasSentFullGoalNotification = true
            postGoalNotification(
                title: "목표 집중 100% 달성했어요",
                body: "\(sessionDurationText(session.duration)) 집중을 완료했습니다."
            )
        } else if goalNotificationSettings.isHalfGoalEnabled,
                  session.progress >= 0.5,
                  !hasSentHalfGoalNotification {
            hasSentHalfGoalNotification = true
            postGoalNotification(
                title: "목표 집중 50% 달성했어요",
                body: "\(sessionDurationText(session.duration)) 집중의 절반까지 왔습니다."
            )
        }
    }

    private func resetSessionGoalNotificationFlags() {
        hasSentHalfGoalNotification = false
        hasSentFullGoalNotification = false
    }

    private func postGoalNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "mew.focus.goal.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    private func sessionDurationText(_ duration: TimeInterval) -> String {
        if duration < 60 {
            return "\(Int(duration))초"
        }

        let totalMinutes = max(Int(duration / 60), 1)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours == 0 {
            return "\(totalMinutes)분"
        }

        if minutes == 0 {
            return "\(hours)시간"
        }

        return "\(hours)시간 \(minutes)분"
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
                SessionListScrollView(sessions: sessions)
            }
        }
        .padding(24)
        .frame(width: 440)
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

private struct SessionListScrollView: View {
    let sessions: [SessionRecord]

    var body: some View {
        SessionListNSScrollView(sessions: sessions)
            .frame(height: 360)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}

private struct SessionListNSScrollView: NSViewRepresentable {
    let sessions: [SessionRecord]

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.scrollerStyle = .legacy
        scrollView.verticalScroller = CoralSessionScroller()
        scrollView.verticalScrollElasticity = .automatic
        scrollView.horizontalScrollElasticity = .none
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 12)

        let hostingView = NSHostingView(rootView: SessionListContent(sessions: sessions))
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        hostingView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        hostingView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let documentView = NSView()
        documentView.translatesAutoresizingMaskIntoConstraints = false
        documentView.addSubview(hostingView)
        scrollView.documentView = documentView

        NSLayoutConstraint.activate([
            hostingView.topAnchor.constraint(equalTo: documentView.topAnchor),
            hostingView.leadingAnchor.constraint(equalTo: documentView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: documentView.trailingAnchor),
            hostingView.bottomAnchor.constraint(equalTo: documentView.bottomAnchor),
            hostingView.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor, constant: -14)
        ])

        context.coordinator.hostingView = hostingView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.hostingView?.rootView = SessionListContent(sessions: sessions)
        scrollView.verticalScroller?.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hostingView: NSHostingView<SessionListContent>?
    }
}

private struct SessionListContent: View {
    let sessions: [SessionRecord]

    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(sessions) { session in
                SessionListRow(record: session)
            }
        }
        .padding(.trailing, 12)
    }
}

private final class CoralSessionScroller: NSScroller {
    override class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        7
    }

    override func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {
        let trackRect = slotRect.insetBy(dx: 1, dy: 2)
        NSColor(calibratedRed: 0.90, green: 0.90, blue: 0.92, alpha: 0.62).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: 4, yRadius: 4).fill()
    }

    override func drawKnob() {
        let knobRect = rect(for: .knob).insetBy(dx: 1, dy: 2)
        NSColor(calibratedRed: 1.00, green: 0.38, blue: 0.27, alpha: 0.78).setFill()
        NSBezierPath(roundedRect: knobRect, xRadius: 4, yRadius: 4).fill()
    }
}

private struct FocusSettingsView: View {
    @Binding var notificationSettings: GoalNotificationSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(MewFocusColor.coral)
                    .frame(width: 34, height: 34)
                    .background(MewFocusColor.coral.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("설정")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text("목표 집중 알림을 관리합니다.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                FocusNotificationToggleRow(
                    title: "50% 달성 알림",
                    subtitle: "현재 집중 시간의 절반에서 알려줘요.",
                    isOn: $notificationSettings.isHalfGoalEnabled
                )

                FocusNotificationToggleRow(
                    title: "100% 달성 알림",
                    subtitle: "현재 집중 시간이 끝나면 알려줘요.",
                    isOn: $notificationSettings.isFullGoalEnabled
                )
            }

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "power")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(MewFocusColor.coral)
                        .frame(width: 30, height: 30)
                        .background(MewFocusColor.coral.opacity(0.10))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mew Focus 종료")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(MewFocusColor.textPrimary)

                        Text("메뉴바 앱을 완전히 종료합니다.")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(MewFocusColor.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(MewFocusColor.textTertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.85)))
                .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(22)
        .frame(width: 390)
        .background(MewFocusColor.surface)
    }
}

private struct FocusNotificationToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)

                Text(subtitle)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
            }

            Spacer()

            FocusNotificationSwitch(isOn: $isOn)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.85)))
    }
}

private struct FocusNotificationSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(isOn ? MewFocusColor.coral : MewFocusColor.divider)
                    .frame(width: 48, height: 28)

                Circle()
                    .fill(.white)
                    .frame(width: 22, height: 22)
                    .padding(.horizontal, 3)
                    .shadow(color: .black.opacity(0.16), radius: 4, x: 0, y: 2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOn ? "알림 켜짐" : "알림 꺼짐")
        .animation(.spring(response: 0.22, dampingFraction: 0.82), value: isOn)
    }
}

private struct FocusPresetSettingsView: View {
    @Binding var durations: [TimeInterval]

    @State private var minuteTexts: [String] = []

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
                    Text("프리셋 설정")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(MewFocusColor.textPrimary)
                    Text("최대 5개까지 1분 단위로 조정합니다.")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(MewFocusColor.textSecondary)
                }

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(0..<FocusPresetStorage.defaultDurations.count, id: \.self) { index in
                    FocusPresetSettingRow(
                        index: index,
                        duration: duration(at: index),
                        minuteText: minuteTextBinding(at: index)
                    )
                }
            }

            Button {
                applyPresetEdits()
            } label: {
                Label("수정하기", systemImage: "checkmark")
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .background(MewFocusColor.coral)
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .padding(22)
        .frame(width: 390)
        .background(MewFocusColor.surface)
        .onAppear {
            syncMinuteTexts(force: true)
        }
        .onChange(of: durations) { _, _ in
            syncMinuteTexts(force: false)
        }
    }

    private func duration(at index: Int) -> TimeInterval {
        guard durations.indices.contains(index) else {
            return FocusPresetStorage.defaultDurations[index]
        }

        return durations[index]
    }

    private func minuteTextBinding(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard minuteTexts.indices.contains(index) else { return "" }
                return minuteTexts[index]
            },
            set: { value in
                var nextTexts = normalizedMinuteTexts(minuteTexts)
                guard nextTexts.indices.contains(index) else { return }

                nextTexts[index] = String(value.filter(\.isNumber).prefix(3))
                minuteTexts = nextTexts
            }
        )
    }

    private func syncMinuteTexts(force: Bool) {
        if !force, !minuteTexts.isEmpty {
            return
        }

        minuteTexts = durationsForEditing.map { duration in
            "\(max(Int(duration / 60), 1))"
        }
    }

    private func applyPresetEdits() {
        let currentDurations = durationsForEditing
        let nextDurations = normalizedMinuteTexts(minuteTexts).enumerated().map { index, text in
            guard !text.isEmpty, let minutes = Int(text) else {
                return currentDurations[index]
            }

            return TimeInterval(min(max(minutes, 1), 180) * 60)
        }
        durations = FocusPresetStorage.normalizedDurations(nextDurations)
        minuteTexts = durations.map { "\(max(Int($0 / 60), 1))" }
    }

    private var durationsForEditing: [TimeInterval] {
        FocusPresetStorage.normalizedDurations(durations)
    }

    private func normalizedMinuteTexts(_ texts: [String]) -> [String] {
        Array((texts + Array(repeating: "", count: FocusPresetStorage.defaultDurations.count)).prefix(FocusPresetStorage.defaultDurations.count))
    }
}

private struct FocusPresetSettingRow: View {
    let index: Int
    let duration: TimeInterval
    @Binding var minuteText: String

    @FocusState private var isInputFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("프리셋 \(index + 1)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(MewFocusColor.textTertiary)
                Text(durationText)
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .monospacedDigit()
            }

            Spacer()

            HStack(spacing: 7) {
                TextField("분", text: $minuteText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(MewFocusColor.textPrimary)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .focused($isInputFocused)
                    .frame(width: 54, height: 34)
                    .padding(.horizontal, 10)
                    .background(.white)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isInputFocused ? MewFocusColor.coral : MewFocusColor.divider, lineWidth: 1.2)
                    )
                    .onChange(of: minuteText) { _, value in
                        minuteText = sanitizedMinuteText(value)
                    }

                Text("분")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MewFocusColor.textSecondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(MewFocusColor.divider.opacity(0.85)))
    }

    private var durationText: String {
        "\(max(Int(duration / 60), 1))분"
    }

    private func sanitizedMinuteText(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(3))
    }
}

private struct SessionListRow: View {
    let record: SessionRecord

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(record.accentColor)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(MewFocusColor.textPrimary)

                Text(timeText)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(MewFocusColor.textTertiary)
            }

            Spacer()

            Text(durationText)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(MewFocusColor.textSecondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background(.white.opacity(0.86))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(MewFocusColor.divider.opacity(0.8)))
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
