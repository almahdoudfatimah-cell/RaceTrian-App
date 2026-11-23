import SwiftUI
import Observation
import WatchKit

@MainActor
@Observable
final class WatchAppStore {
    var tasks: [WatchTask] {
        didSet { save() }
    }
    var sessions: [WorkoutSession] {
        didSet { save() }
    }
    var waterGlasses: Int {
        didSet { save() }
    }
    var mood: WatchMood? {
        didSet { save() }
    }
    var dailyGoalMinutes: Int {
        didSet { save() }
    }
    /// Projects mirrored from the iPhone. Refreshed on every sync, so they aren't saved locally.
    var projects: [SyncedWatchProject] = []
    /// AI Board activities keyed by board (`WatchBoard.rawValue`), mirrored from the iPhone.
    var boards: [String: [SyncedBoardActivity]] = [:] {
        didSet { save() }
    }
    /// Life goals mirrored from the iPhone, saved so they show before the first sync.
    var lifeGoals: [SyncedLifeGoal] = [] {
        didSet { save() }
    }
    /// Light tap feedback when completing tasks, activities, and goal check-ins.
    var hapticsEnabled = true {
        didSet { save() }
    }
    /// When the last snapshot arrived from the iPhone, shown in Settings.
    var lastSyncedAt: Date? {
        didSet { save() }
    }

    private let defaults: UserDefaults
    private var isRestoring = true

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        tasks = []
        sessions = []
        waterGlasses = 0
        mood = nil
        dailyGoalMinutes = 30
        restore()
        isRestoring = false
    }

    var todayTasks: [WatchTask] {
        tasks
            .filter { Calendar.current.isDateInToday($0.scheduledDate) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    var completedTodayCount: Int {
        todayTasks.filter(\.isCompleted).count
    }

    var todayMinutes: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var weekMinutes: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return todayMinutes
        }
        return sessions
            .filter { interval.contains($0.startedAt) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(sessions.map { calendar.startOfDay(for: $0.startedAt) })
        var streak = 0
        var date = calendar.startOfDay(for: Date())
        while activeDays.contains(date) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = previous
        }
        return streak
    }

    func toggleTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isCompleted.toggle()
        playSuccessHaptic()
        // Send the task's own day so tasks on other days in the week toggle correctly.
        WatchPhoneSyncManager.shared.toggleTask(id: id, on: tasks[index].scheduledDate)
    }

    func toggleMilestone(projectId: UUID, milestoneId: UUID) {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }),
              let milestoneIndex = projects[projectIndex].milestones.firstIndex(where: { $0.id == milestoneId })
        else { return }
        projects[projectIndex].milestones[milestoneIndex].isDone.toggle()
        WatchPhoneSyncManager.shared.toggleMilestone(projectId: projectId, milestoneId: milestoneId)
    }

    func addTask(title: String, hour: Int) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let now = Date()
        let selectedTime = Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: now
        ) ?? now
        let scheduledDate = selectedTime > now
            ? selectedTime
            : Calendar.current.date(byAdding: .day, value: 1, to: selectedTime) ?? selectedTime

        tasks.append(WatchTask(id: UUID(), title: trimmed, scheduledDate: scheduledDate, isCompleted: false))
        WatchPhoneSyncManager.shared.addTask(title: trimmed, scheduledDate: scheduledDate)
        WatchNotificationManager.shared.scheduleAfterUserAction()
    }

    func addWorkout(kind: WorkoutKind, durationMinutes: Int) {
        let session = WorkoutSession(
            id: UUID(),
            kind: kind,
            startedAt: Date(),
            durationMinutes: max(durationMinutes, 1)
        )
        sessions.append(session)
        WatchPhoneSyncManager.shared.addWorkout(
            id: session.id,
            kind: kind,
            durationMinutes: session.durationMinutes,
            date: session.startedAt
        )
    }

    func setMood(_ mood: WatchMood) {
        self.mood = mood
        WatchPhoneSyncManager.shared.setMood(mood)
    }

    // MARK: AI Board

    func activities(on board: WatchBoard) -> [SyncedBoardActivity] {
        (boards[board.rawValue] ?? []).sorted { $0.start < $1.start }
    }

    func addBoardActivity(title: String, start: Date, durationMinutes: Int, on board: WatchBoard) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let activity = SyncedBoardActivity(
            id: UUID(),
            activity: trimmed,
            start: start,
            finish: start.addingTimeInterval(TimeInterval(max(durationMinutes, 1) * 60)),
            completedAt: nil
        )
        boards[board.rawValue, default: []].append(activity)
        WatchPhoneSyncManager.shared.addBoardActivity(activity, boardKey: board.rawValue)
    }

    /// Creates a useful starter schedule the first time a board is opened on Apple Watch.
    @discardableResult
    func createStarterScheduleIfNeeded(for board: WatchBoard) -> Bool {
        guard activities(on: board).isEmpty else { return false }

        let templates: [(title: String, day: Int, hour: Int, duration: Int)] = switch board {
        case .weekly:
            [
                ("Set weekly priorities", 0, 1, 20), ("Easy training session", 1, 2, 45),
                ("Midweek progress check", 3, 2, 20), ("Long training session", 5, 3, 60),
                ("Weekly review and recovery", 6, 2, 30)
            ]
        case .monthly:
            [
                ("Set monthly goals", 0, 1, 30), ("Week 1 progress review", 7, 2, 20),
                ("Mid-month check-in", 14, 2, 20), ("Monthly review", 28, 2, 30)
            ]
        case .weekend:
            [
                ("Weekend training", 0, 1, 60), ("Personal time", 0, 4, 60),
                ("Recovery and reset", 1, 2, 30)
            ]
        case .vacation:
            [
                ("Review today's vacation plan", 0, 1, 15), ("Main vacation activity", 0, 3, 90),
                ("Rest and recharge", 0, 6, 45)
            ]
        case .travel:
            [
                ("Check travel documents", 0, 1, 15), ("Departure preparation", 0, 2, 30),
                ("Arrival and check-in", 0, 5, 30)
            ]
        case .training:
            [
                ("Warm-up", 0, 1, 15), ("Training session", 0, 2, 45),
                ("Cool-down and log results", 0, 3, 15)
            ]
        case .achievement:
            [
                ("Define the next milestone", 0, 1, 20), ("Focused achievement session", 1, 2, 45),
                ("Review progress", 2, 2, 20)
            ]
        case .raceVision:
            [
                ("Choose target race", 0, 1, 30), ("Build training roadmap", 7, 2, 45),
                ("Review race readiness", 30, 2, 30)
            ]
        }

        let now = Date()
        let newActivities = templates.map { template in
            let start = Calendar.current.date(
                byAdding: .hour,
                value: template.hour,
                to: Calendar.current.date(byAdding: .day, value: template.day, to: now) ?? now
            ) ?? now.addingTimeInterval(3600)
            return SyncedBoardActivity(
                id: UUID(),
                activity: template.title,
                start: start,
                finish: start.addingTimeInterval(TimeInterval(template.duration * 60)),
                completedAt: nil
            )
        }

        boards[board.rawValue] = newActivities
        for activity in newActivities {
            WatchPhoneSyncManager.shared.addBoardActivity(activity, boardKey: board.rawValue)
        }
        return true
    }

    func toggleBoardActivity(id: UUID, on board: WatchBoard) {
        guard let index = boards[board.rawValue]?.firstIndex(where: { $0.id == id }) else { return }
        let completedAt: Date? = boards[board.rawValue]?[index].completedAt == nil ? Date() : nil
        boards[board.rawValue]?[index].completedAt = completedAt
        if completedAt != nil { playSuccessHaptic() }
        WatchPhoneSyncManager.shared.setBoardActivityCompleted(id: id, boardKey: board.rawValue, completedAt: completedAt)
    }

    /// Ends an Achievement Timer session: marks the activity complete and records the actual finish time.
    func completeTimedActivity(id: UUID, startedAt: Date, on board: WatchBoard) {
        guard let index = boards[board.rawValue]?.firstIndex(where: { $0.id == id }) else { return }
        let now = Date()
        boards[board.rawValue]?[index].start = startedAt
        boards[board.rawValue]?[index].finish = now
        boards[board.rawValue]?[index].completedAt = now
        WatchPhoneSyncManager.shared.setBoardActivityCompleted(id: id, boardKey: board.rawValue, completedAt: now, finishDate: now)
    }

    /// Records an unplanned Achievement Timer session as a completed activity.
    func logTimedSession(title: String, startedAt: Date, on board: WatchBoard) {
        let now = Date()
        let activity = SyncedBoardActivity(id: UUID(), activity: title, start: startedAt, finish: now, completedAt: now)
        boards[board.rawValue, default: []].append(activity)
        WatchPhoneSyncManager.shared.addBoardActivity(activity, boardKey: board.rawValue)
    }

    func deleteBoardActivity(id: UUID, on board: WatchBoard) {
        boards[board.rawValue]?.removeAll { $0.id == id }
        WatchPhoneSyncManager.shared.deleteBoardActivity(id: id, boardKey: board.rawValue)
    }

    // MARK: Life Goals

    /// Mirrors the iPhone's check-in locally so the ring updates right away, then tells the iPhone.
    func checkInLifeGoal(id: UUID) {
        guard let index = lifeGoals.firstIndex(where: { $0.id == id }) else { return }
        lifeGoals[index].progress = min(1, lifeGoals[index].progress + 0.05)
        lifeGoals[index].streak += 1
        playSuccessHaptic()
        WatchPhoneSyncManager.shared.checkInLifeGoal(id: id)
    }

    private func playSuccessHaptic() {
        guard hapticsEnabled else { return }
        WKInterfaceDevice.current().play(.success)
    }

    func apply(snapshot: PhoneSnapshot) {
        tasks = snapshot.tasks.map {
            WatchTask(
                id: $0.id,
                title: $0.title,
                scheduledDate: $0.scheduledDate,
                isCompleted: $0.isCompleted
            )
        }
        sessions = snapshot.workouts.compactMap { workout in
            guard let kind = WorkoutKind(rawValue: workout.kind) else { return nil }
            return WorkoutSession(
                id: workout.id,
                kind: kind,
                startedAt: workout.startedAt,
                durationMinutes: workout.durationMinutes
            )
        }
        mood = snapshot.moodRawValue.flatMap(WatchMood.init(phoneRawValue:))
        projects = snapshot.projects
        if let syncedBoards = snapshot.boards {
            boards = Dictionary(syncedBoards.map { ($0.key, $0.activities) }, uniquingKeysWith: { first, _ in first })
        }
        if let syncedGoals = snapshot.lifeGoals {
            lifeGoals = syncedGoals
        }
        lastSyncedAt = Date()
    }

    func resetToday() {
        tasks.removeAll { Calendar.current.isDateInToday($0.scheduledDate) }
        sessions.removeAll { Calendar.current.isDateInToday($0.startedAt) }
        waterGlasses = 0
        mood = nil
    }

    private func restore() {
        let decoder = JSONDecoder()
        if let data = defaults.data(forKey: "watch.tasks"),
           let value = try? decoder.decode([WatchTask].self, from: data) {
            tasks = value
        }
        if let data = defaults.data(forKey: "watch.sessions"),
           let value = try? decoder.decode([WorkoutSession].self, from: data) {
            sessions = value
        }
        waterGlasses = defaults.integer(forKey: "watch.water")
        dailyGoalMinutes = defaults.object(forKey: "watch.goal") == nil ? 30 : defaults.integer(forKey: "watch.goal")
        if let moodValue = defaults.string(forKey: "watch.mood") {
            mood = WatchMood(rawValue: moodValue)
        }
        if let data = defaults.data(forKey: "watch.boards"),
           let value = try? decoder.decode([String: [SyncedBoardActivity]].self, from: data) {
            boards = value
        }
        hapticsEnabled = defaults.object(forKey: "watch.haptics") as? Bool ?? true
        lastSyncedAt = defaults.object(forKey: "watch.lastSync") as? Date
        if let data = defaults.data(forKey: "watch.lifeGoals"),
           let value = try? decoder.decode([SyncedLifeGoal].self, from: data) {
            lifeGoals = value
        }
    }

    private func save() {
        guard !isRestoring else { return }
        let encoder = JSONEncoder()
        defaults.set(try? encoder.encode(tasks), forKey: "watch.tasks")
        defaults.set(try? encoder.encode(sessions), forKey: "watch.sessions")
        defaults.set(waterGlasses, forKey: "watch.water")
        defaults.set(dailyGoalMinutes, forKey: "watch.goal")
        defaults.set(mood?.rawValue, forKey: "watch.mood")
        defaults.set(try? encoder.encode(boards), forKey: "watch.boards")
        defaults.set(try? encoder.encode(lifeGoals), forKey: "watch.lifeGoals")
        defaults.set(hapticsEnabled, forKey: "watch.haptics")
        defaults.set(lastSyncedAt, forKey: "watch.lastSync")
        // Tasks and activities may have changed, so keep reminders in step.
        WatchNotificationManager.shared.scheduleReschedule()
    }
}

struct WatchTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var scheduledDate: Date
    var isCompleted: Bool
}

struct WorkoutSession: Identifiable, Codable {
    let id: UUID
    let kind: WorkoutKind
    let startedAt: Date
    let durationMinutes: Int
}

enum WorkoutKind: String, CaseIterable, Codable, Identifiable {
    case run = "Run"
    case walk = "Walk"
    case cycling = "Cycling"
    case strength = "Strength"
    case mobility = "Mobility"
    case recovery = "Recovery"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .run: "figure.run"
        case .walk: "figure.walk"
        case .cycling: "bicycle"
        case .strength: "dumbbell.fill"
        case .mobility: "figure.flexibility"
        case .recovery: "heart.fill"
        }
    }

    var tint: Color {
        switch self {
        case .run, .strength: WatchTheme.primary
        case .walk, .mobility: WatchTheme.secondary
        case .cycling, .recovery: WatchTheme.rose
        }
    }
}

enum WatchMood: String, CaseIterable, Identifiable {
    case low = "Low"
    case okay = "Okay"
    case good = "Good"
    case great = "Great"

    var id: String { rawValue }

    var phoneRawValue: Int {
        switch self {
        case .low: 2
        case .okay: 3
        case .good: 4
        case .great: 5
        }
    }

    init?(phoneRawValue: Int) {
        switch phoneRawValue {
        case 1, 2: self = .low
        case 3: self = .okay
        case 4: self = .good
        case 5: self = .great
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .low: "cloud.rain.fill"
        case .okay: "cloud.fill"
        case .good: "sun.max.fill"
        case .great: "sparkles"
        }
    }
}

struct ContentView: View {
    let store: WatchAppStore
    let access: WatchAccessStore

    var body: some View {
        NavigationStack {
            // The iPhone's five tab sections plus the Home screen's AI Board.
            TabView {
                WatchTodayView(store: store, access: access)
                WatchPlanView(store: store)
                WatchAIBoardView(store: store)
                WatchGoalsView(store: store)
                WatchProjectsView(store: store)
                WatchSettingsView(store: store, access: access)
            }
            .tabViewStyle(.verticalPage)
            .tint(WatchTheme.primary)
        }
    }
}

struct WatchTodayView: View {
    let store: WatchAppStore
    let access: WatchAccessStore
    @State private var showingAddTask = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Shown until the first iPhone sync so a new watch can link up from the first page.
                if store.lastSyncedAt == nil {
                    WatchConnectPhoneCard()
                }

                WatchHomeHeroCard(
                    doneCount: store.completedTodayCount,
                    totalCount: store.todayTasks.count
                )

                WatchMetricsRow(
                    minutes: store.todayMinutes,
                    streak: store.currentStreak,
                    mood: store.mood
                )

                WatchMoodCheckinCard(store: store)

                WatchQuickActionsGrid(store: store, access: access, onAddTask: { showingAddTask = true })

                WatchHomeAIBoardSection(store: store)

                WatchTodayPlanSection(store: store, onAdd: { showingAddTask = true })

                WatchHomeProjectsSection(store: store)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .background(WatchTheme.paper)
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .toolbarColorScheme(.light, for: .navigationBar)
        .tint(WatchTheme.ink)
        .navigationTitle("Today")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    WatchNotificationsView(store: store)
                } label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(WatchTheme.ink)
                        .frame(width: 28, height: 28)
                        .background(WatchTheme.accent, in: Circle())
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(WatchTheme.primary)
                        .frame(width: 28, height: 28)
                        .background(WatchTheme.cardSurface, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddWatchTaskView(store: store)
        }
    }
}

/// Cream card with an orange Connect iPhone button that asks the paired iPhone for its data.
struct WatchConnectPhoneCard: View {
    private var sync: WatchPhoneSyncManager { .shared }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Connect to your iPhone")
                .font(WatchTheme.headlineFont)
                .foregroundStyle(WatchTheme.ink)
            Text("Open RaceTrian on your iPhone, then tap Connect.")
                .font(WatchTheme.captionFont)
                .foregroundStyle(WatchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                sync.connect()
            } label: {
                Label(sync.isPhoneReachable ? "Syncing…" : "Connect", systemImage: "iphone")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 34)
                    .background(WatchTheme.heroGradient, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .watchGlassCard(cornerRadius: 14)
    }
}

/// Gradient hero with a progress ring, scaled down from the iOS `HomeHeroCard`.
struct WatchHomeHeroCard: View {
    let doneCount: Int
    let totalCount: Int

    private var completion: Double {
        guard totalCount > 0 else { return 0 }
        return Double(doneCount) / Double(totalCount)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Label("AI Plan ready", systemImage: "sparkles")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(WatchTheme.cardSurface.opacity(0.72)))
                    .foregroundStyle(WatchTheme.ink)

                Text("Your day,\noptimized.")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)

                Text("\(doneCount) of \(totalCount) tasks")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.ink.opacity(0.75))
            }
            Spacer(minLength: 0)
            progressRing
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                WatchTheme.heroGradient
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 110, height: 110)
                    .blur(radius: 12)
                    .offset(x: 70, y: -40)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(WatchTheme.ink.opacity(0.18), lineWidth: 5)
            Circle()
                .trim(from: 0, to: completion)
                .stroke(WatchTheme.ink, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: completion)
            Text("\(Int(completion * 100))%")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
        }
        .frame(width: 46, height: 46)
    }
}

/// Three compact metric cards, matching the iOS `MetricsRow` tints.
struct WatchMetricsRow: View {
    let minutes: Int
    let streak: Int
    let mood: WatchMood?

    var body: some View {
        HStack(spacing: 6) {
            WatchMetricCard(icon: "figure.run", value: "\(minutes)m", label: "Train", tint: WatchTheme.primary)
            WatchMetricCard(icon: "flame.fill", value: "\(streak)d", label: "Streak", tint: WatchTheme.secondary)
            WatchMetricCard(icon: "face.smiling.fill", value: mood?.rawValue ?? "—", label: "Mood", tint: WatchTheme.accent)
        }
    }
}

private struct WatchMetricCard: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(Circle().fill(tint.opacity(0.15)))
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchGlassCard(cornerRadius: 12)
    }
}

/// Quick mood check-in, mirroring the iOS `MoodCheckinBanner`.
struct WatchMoodCheckinCard: View {
    let store: WatchAppStore

    var body: some View {
        if let mood = store.mood {
            HStack(spacing: 8) {
                Image(systemName: mood.symbol)
                    .font(.system(size: 18))
                    .foregroundStyle(WatchTheme.primary)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Mood logged")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Text("Feeling \(mood.rawValue.lowercased())")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                }
                Spacer(minLength: 0)
                NavigationLink {
                    MoodCheckInView(store: store)
                } label: {
                    Text("Edit")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(WatchTheme.primary.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(10)
            .watchGlassCard(cornerRadius: 14)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("How are you feeling?")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                HStack(spacing: 4) {
                    ForEach(WatchMood.allCases) { mood in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                store.setMood(mood)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                Image(systemName: mood.symbol)
                                    .font(.system(size: 14))
                                    .foregroundStyle(WatchTheme.primary)
                                Text(mood.rawValue)
                                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                                    .foregroundStyle(WatchTheme.muted)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(WatchTheme.primary.opacity(0.22), in: .rect(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .watchGlassCard(cornerRadius: 14)
        }
    }
}

/// Two-column action buttons styled like the iOS `HomePlanButton` grid.
struct WatchQuickActionsGrid: View {
    let store: WatchAppStore
    let access: WatchAccessStore
    var onAddTask: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            NavigationLink {
                WorkoutLibraryView(store: store)
            } label: {
                WatchActionButtonLabel(title: "Workout", icon: "figure.run", color: WatchTheme.primary)
            }
            .buttonStyle(.plain)

            Button(action: onAddTask) {
                WatchActionButtonLabel(title: "Add Task", icon: "plus", color: WatchTheme.primary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    store.waterGlasses += 1
                }
            } label: {
                WatchActionButtonLabel(
                    title: "Water",
                    detail: "\(store.waterGlasses)",
                    icon: "drop.fill",
                    color: Color(red: 0.20, green: 0.60, blue: 0.95)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchGoalsView(store: store)
            } label: {
                WatchActionButtonLabel(title: "Goals", icon: "chart.bar.fill", color: WatchTheme.accent)
            }
            .buttonStyle(.plain)

            // Profile and Settings are also the last page, but that's a long scroll on the wrist.
            NavigationLink {
                WatchProfileView(store: store, access: access)
            } label: {
                WatchActionButtonLabel(title: "Profile", icon: "person.crop.circle.fill", color: WatchTheme.secondary)
            }
            .buttonStyle(.plain)

            NavigationLink {
                WatchSettingsView(store: store, access: access)
            } label: {
                WatchActionButtonLabel(title: "Settings", icon: "gearshape.fill", color: WatchTheme.primary)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct WatchActionButtonLabel: View {
    let title: String
    var detail: String? = nil
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 7))
                Spacer(minLength: 0)
                if let detail {
                    Text(detail)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                }
            }
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(color.opacity(0.22), in: .rect(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.45))
        }
    }
}

/// "Today's Plan" header with the orange Add button and task cards, like `TodayPlanSection`.
struct WatchTodayPlanSection: View {
    let store: WatchAppStore
    var onAdd: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Today's Plan")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                Spacer()
                Button(action: onAdd) {
                    Label("Add", systemImage: "plus")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.primary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(WatchTheme.primary.opacity(0.22), in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            if store.todayTasks.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 18))
                        .foregroundStyle(WatchTheme.primary)
                    Text("No plans yet")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Text("Tap + to add your first task.")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .watchGlassCard(cornerRadius: 14)
            } else {
                ForEach(store.todayTasks) { task in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            store.toggleTask(id: task.id)
                        }
                    } label: {
                        WatchTaskRow(
                            title: task.title,
                            time: task.scheduledDate,
                            isCompleted: task.isCompleted
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct WatchTaskRow: View {
    let title: String
    let time: Date
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .strokeBorder(WatchTheme.primary.opacity(0.5), lineWidth: 2)
                    .frame(width: 20, height: 20)
                if isCompleted {
                    Circle().fill(WatchTheme.primary).frame(width: 20, height: 20)
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? WatchTheme.muted : WatchTheme.ink)
                    .lineLimit(1)
                Label {
                    Text(time, format: .dateTime.hour().minute())
                } icon: {
                    Image(systemName: "clock")
                }
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .watchGlassCard(cornerRadius: 14)
        .opacity(isCompleted ? 0.65 : 1.0)
    }
}

extension View {
    /// Light card row for List-based pages so they match the cream Today and Plan pages.
    func watchPaperRow() -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(WatchTheme.cardSurface)
        )
    }

    /// Light surface card with a faint highlight border, a compact take on the iOS `glassCard`.
    func watchGlassCard(cornerRadius: CGFloat) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(WatchTheme.cardSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.6), lineWidth: 0.5)
            )
    }
}

/// New Task sheet styled to match the iOS `AddTaskSheet`: dark header with date, cream cards, gradient button.
struct AddWatchTaskView: View {
    let store: WatchAppStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hour = Calendar.current.component(.hour, from: Date())

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("New Task")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchTheme.ink)
                        Text(Date(), format: .dateTime.weekday(.wide).month().day())
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(WatchTheme.muted)
                    }
                    .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Task name")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(WatchTheme.muted)
                        TextField(
                            "Task name",
                            text: $title,
                            prompt: Text("e.g. Morning run").foregroundStyle(WatchTheme.muted)
                        )
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                        .tint(WatchTheme.primary)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .watchGlassCard(cornerRadius: 14)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Time")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(WatchTheme.muted)
                        // Orange − / + around the hour, instead of the system picker's tan button.
                        HStack {
                            Button {
                                hour = (hour + 23) % 24
                            } label: {
                                Image(systemName: "minus")
                            }
                            .buttonStyle(WatchRoundIconButtonStyle())
                            .accessibilityLabel("Earlier")

                            Spacer(minLength: 0)
                            Text(DateComponents(calendar: .current, hour: hour).date ?? Date(), format: .dateTime.hour())
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(WatchTheme.ink)
                                .monospacedDigit()
                            Spacer(minLength: 0)

                            Button {
                                hour = (hour + 1) % 24
                            } label: {
                                Image(systemName: "plus")
                            }
                            .buttonStyle(WatchRoundIconButtonStyle())
                            .accessibilityLabel("Later")
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .watchGlassCard(cornerRadius: 14)

                    Button {
                        store.addTask(title: title, hour: hour)
                        dismiss()
                    } label: {
                        Text("Add Task")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchTheme.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(WatchTheme.primary)
                    .disabled(!canSave)
                }
                .padding(.horizontal, 4)
            }
            .containerBackground(WatchTheme.paper, for: .navigation)
            .tint(WatchTheme.primary)
        }
    }
}

/// Solid orange circle with a white symbol, used for the Add Task time stepper.
private struct WatchRoundIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 34, height: 34)
            .background(WatchTheme.primary.opacity(configuration.isPressed ? 0.8 : 1), in: Circle())
    }
}

#Preview("New Task") {
    AddWatchTaskView(store: WatchAppStore())
}

struct MoodCheckInView: View {
    let store: WatchAppStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List(WatchMood.allCases) { mood in
            Button {
                store.setMood(mood)
                dismiss()
            } label: {
                Label(mood.rawValue, systemImage: mood.symbol)
                    .foregroundStyle(store.mood == mood ? WatchTheme.primary : WatchTheme.ink)
            }
            .watchPaperRow()
        }
        .font(WatchTheme.bodyFont)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Mood")
    }
}

struct WorkoutLibraryView: View {
    let store: WatchAppStore

    var body: some View {
        List {
            Section {
                ForEach(WorkoutKind.allCases) { kind in
                    NavigationLink {
                        WorkoutSetupView(store: store, kind: kind)
                    } label: {
                        Label {
                            Text(kind.rawValue)
                        } icon: {
                            Image(systemName: kind.icon)
                                .foregroundStyle(kind.tint)
                        }
                    }
                    .watchPaperRow()
                }
            } header: {
                Text("Choose a workout")
                    .foregroundStyle(WatchTheme.muted)
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Workout")
    }
}

struct WorkoutSetupView: View {
    let store: WatchAppStore
    let kind: WorkoutKind
    @State private var targetMinutes = 30
    @State private var isActive = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: kind.icon)
                .font(.system(size: 40))
                .foregroundStyle(kind.tint)

            Text(kind.rawValue)
                .font(WatchTheme.titleFont)
                .foregroundStyle(WatchTheme.ink)

            Picker("Goal", selection: $targetMinutes) {
                ForEach([10, 20, 30, 45, 60], id: \.self) { minutes in
                    Text("\(minutes) min").tag(minutes)
                }
            }
            .pickerStyle(.navigationLink)
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundStyle(WatchTheme.ink)
            .tint(WatchTheme.muted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .watchGlassCard(cornerRadius: 14)

            Button("Start") {
                isActive = true
            }
            .buttonStyle(.glassProminent)
            .tint(kind.tint)
        }
        .navigationDestination(isPresented: $isActive) {
            ActiveWorkoutView(store: store, kind: kind, targetMinutes: targetMinutes)
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Set Goal")
    }
}

struct ActiveWorkoutView: View {
    let store: WatchAppStore
    let kind: WorkoutKind
    let targetMinutes: Int
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt = Date()
    @State private var showingFinishConfirmation = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = max(context.date.timeIntervalSince(startedAt), 0)
            let elapsedSeconds = Int(elapsed)
            VStack(spacing: 12) {
                Image(systemName: kind.icon)
                    .font(.title2)
                    .foregroundStyle(kind.tint)

                Text("\(elapsedSeconds / 60):\(elapsedSeconds % 60, format: .number.precision(.integerLength(2)))")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.ink)

                ProgressView(value: min(elapsed / Double(targetMinutes * 60), 1))
                    .tint(kind.tint)

                Text("Goal: \(targetMinutes) min")
                    .font(WatchTheme.captionFont)
                    .foregroundStyle(WatchTheme.muted)

                Button("Finish") {
                    showingFinishConfirmation = true
                }
                .buttonStyle(.glassProminent)
                .tint(.red)
            }
            .padding(.horizontal)
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationBarBackButtonHidden()
        .confirmationDialog("Finish workout?", isPresented: $showingFinishConfirmation) {
            Button("Save Workout") {
                let elapsedMinutes = max(Int(Date().timeIntervalSince(startedAt) / 60), 1)
                store.addWorkout(kind: kind, durationMinutes: elapsedMinutes)
                dismiss()
            }
            Button("Keep Going", role: .cancel) {}
        }
    }
}

/// Goals tab: mirrors the iPhone's Goals "Week" view (weekly training, streak, mood, recent workouts).
struct WatchGoalsView: View {
    let store: WatchAppStore

    var body: some View {
        List {
            ProgressHero(minutes: store.weekMinutes, goal: store.dailyGoalMinutes * 7)

            NavigationLink {
                WatchLifeGoalsView(store: store)
            } label: {
                Label("Life Goals", systemImage: "target")
                    .foregroundStyle(WatchTheme.ink)
            }
            .watchPaperRow()

            Section {
                Group {
                    LabeledContent("Training", value: "\(store.weekMinutes) min")
                    LabeledContent("Daily goal", value: "\(store.dailyGoalMinutes) min")
                    LabeledContent("Streak", value: "\(store.currentStreak) days")
                    LabeledContent("Workouts", value: store.sessionsThisWeekCount.formatted())
                    LabeledContent("Mood", value: store.mood?.rawValue ?? "—")
                    LabeledContent("Water", value: "\(store.waterGlasses) glasses")
                }
                .watchPaperRow()
            } header: {
                Text("This week")
                    .foregroundStyle(WatchTheme.muted)
            }

            Section {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "figure.run",
                        description: Text("Start one from the Workout page.")
                    )
                    .watchPaperRow()
                } else {
                    ForEach(store.sessions.sorted { $0.startedAt > $1.startedAt }.prefix(5)) { session in
                        WorkoutHistoryRow(session: session)
                            .watchPaperRow()
                    }
                }
            } header: {
                Text("Recent")
                    .foregroundStyle(WatchTheme.muted)
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        // Goals is both a page and a pushed screen (Today's quick actions), so cover both containers.
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Goals")
    }
}

private extension WatchAppStore {
    var sessionsThisWeekCount: Int {
        guard let interval = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) else {
            return sessions.count
        }
        return sessions.filter { interval.contains($0.startedAt) }.count
    }
}

struct ProgressHero: View {
    let minutes: Int
    let goal: Int

    var body: some View {
        Gauge(value: Double(minutes), in: 0...Double(max(goal, 1))) {
            Text("Weekly training")
        } currentValueLabel: {
            Text("\(minutes)m")
                .font(WatchTheme.headlineFont)
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WatchTheme.primary)
        .frame(maxWidth: .infinity)
        .listRowBackground(WatchTheme.primary.opacity(0.12))
    }
}

struct WorkoutHistoryRow: View {
    let session: WorkoutSession

    var body: some View {
        HStack {
            Image(systemName: session.kind.icon)
                .foregroundStyle(session.kind.tint)
            VStack(alignment: .leading) {
                Text(session.kind.rawValue)
                Text(session.startedAt, format: .dateTime.weekday(.abbreviated).hour().minute())
                    .font(WatchTheme.captionFont)
                    .foregroundStyle(WatchTheme.muted)
            }
            Spacer()
            Text("\(session.durationMinutes)m")
                .font(WatchTheme.bodyFont)
        }
    }
}

struct AboutWatchView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Image(systemName: "flag.checkered")
                    .font(.largeTitle)
                    .foregroundStyle(WatchTheme.primary)
                Text("RaceTrian")
                    .font(WatchTheme.titleFont)
                    .foregroundStyle(WatchTheme.ink)
                Text("Plan your day, record training, and keep an eye on progress from your wrist.")
                    .font(WatchTheme.captionFont)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WatchTheme.muted)
            }
            .padding()
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("About")
    }
}

#Preview {
    ContentView(store: WatchAppStore(), access: WatchAccessStore())
}
