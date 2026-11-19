import SwiftUI

/// The eight AI Board categories from the iPhone Home screen. Raw values match the iPhone's storage keys.
enum WatchBoard: String, CaseIterable, Identifiable {
    case weekly
    case monthly
    case weekend
    case vacation
    case travel
    case training
    case achievement
    case raceVision

    var id: String { rawValue }

    var title: String {
        switch self {
        case .weekly: "Weekly Plan"
        case .monthly: "Monthly Plan"
        case .weekend: "Weekend Plan"
        case .vacation: "Vacation Plan"
        case .travel: "Travel Plan"
        case .training: "Train & Track"
        case .achievement: "Achievement Timer"
        case .raceVision: "Year Race Vision"
        }
    }

    /// Compact title for the navigation bar, where the + button leaves little room.
    var shortTitle: String {
        switch self {
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        case .weekend: "Weekend"
        case .vacation: "Vacation"
        case .travel: "Travel"
        case .training: "Training"
        case .achievement: "Achieve"
        case .raceVision: "Race Year"
        }
    }

    /// Same subtitles as the iPhone's AI Board buttons.
    var subtitle: LocalizedStringKey {
        switch self {
        case .weekly: "Build the next 7 days"
        case .monthly: "Set this month's focus"
        case .weekend: "Plan rest and activity"
        case .vacation: "Keep holidays organized"
        case .travel: "Prepare trips and workouts"
        case .training: "All sports and tracking"
        case .achievement: "Time your goal sessions"
        case .raceVision: "Map the racing year"
        }
    }

    /// Heading shown at the top of the board page, matching the iPhone's `CategoryScheduleContent`.
    var heading: LocalizedStringKey {
        switch self {
        case .weekly: "Weekly schedule"
        case .monthly: "Monthly calendar"
        case .weekend: "Weekend agenda"
        case .vacation: "Vacation day planner"
        case .travel: "Travel itinerary"
        case .training: "Training sessions"
        case .achievement: "Achievement milestones"
        case .raceVision: "Year race calendar"
        }
    }

    var headingIcon: String {
        self == .achievement ? "flag.fill" : icon
    }

    var headingDescription: LocalizedStringKey {
        switch self {
        case .weekly: "Your activities for the next seven days."
        case .monthly: "This month's focus, day by day."
        case .weekend: "Balance your activities, personal time, and rest."
        case .vacation: "Explore each day of your holiday, with space for activities and downtime."
        case .travel: "Your departures, arrivals, and stops in chronological order."
        case .training: "Review session duration and mark each workout complete."
        case .achievement: "Time each session and tick off milestones."
        case .raceVision: "Organize race dates and preparation milestones by month."
        }
    }

    var icon: String {
        switch self {
        case .weekly: "calendar.badge.clock"
        case .monthly: "calendar"
        case .weekend: "sun.max.fill"
        case .vacation: "beach.umbrella.fill"
        case .travel: "airplane"
        case .training: "figure.run"
        case .achievement: "stopwatch.fill"
        case .raceVision: "flag.checkered"
        }
    }

    /// Same colours as the iPhone's `HomePlanDestination` so each board looks identical on both.
    var color: Color {
        switch self {
        case .weekly: WatchTheme.primary
        case .monthly: .blue
        case .weekend: WatchTheme.accent
        case .vacation: .cyan
        case .travel: .indigo
        case .training: WatchTheme.secondary
        case .achievement: .purple
        case .raceVision: WatchTheme.rose
        }
    }
}

/// AI Board page: every board with its synced activity count.
struct WatchAIBoardView: View {
    let store: WatchAppStore

    var body: some View {
        List {
            ForEach(WatchBoard.allCases) { board in
                let activities = store.activities(on: board)
                NavigationLink {
                    WatchBoardDetailView(store: store, board: board)
                } label: {
                    HStack(spacing: 8) {
                        WatchBoardIcon(board: board)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(board.title)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(WatchTheme.ink)
                                .lineLimit(1)
                            Text(board.subtitle)
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(WatchTheme.muted)
                                .lineLimit(1)
                            Text(activities.isEmpty
                                 ? "No activities"
                                 : "\(activities.filter { $0.completedAt != nil }.count)/\(activities.count) done")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundStyle(WatchTheme.muted)
                        }
                    }
                }
                .watchPaperRow()
            }

            NavigationLink {
                WatchLifeGoalsView(store: store)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "target")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(WatchTheme.secondary.gradient, in: RoundedRectangle(cornerRadius: 7))
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Life Goals")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(WatchTheme.ink)
                        Text(store.lifeGoals.isEmpty
                             ? "No goals"
                             : "\(store.lifeGoals.filter { $0.progress >= 1 }.count)/\(store.lifeGoals.count) done")
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(WatchTheme.muted)
                    }
                }
            }
            .watchPaperRow()
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("AI Board")
    }
}

private struct WatchBoardIcon: View {
    let board: WatchBoard

    var body: some View {
        Image(systemName: board.icon)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 24, height: 24)
            .background(board.color.gradient, in: RoundedRectangle(cornerRadius: 7))
    }
}

/// One board's activities. Tap to complete (or, on Achievement Timer, to time it), swipe to delete, + to add.
struct WatchBoardDetailView: View {
    let store: WatchAppStore
    let board: WatchBoard
    @State private var showingAdd = false

    var body: some View {
        let activities = store.activities(on: board)
        List {
            if board == .achievement {
                NavigationLink {
                    WatchAchievementTimerView(store: store, activity: nil)
                } label: {
                    Label("Quick session", systemImage: "stopwatch")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.primary)
                }
                .watchPaperRow()
            }

            WatchBoardHeader(board: board, activities: activities)
                .watchPaperRow()

            if activities.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: board.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(board.color)
                    Text("No activities yet")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Text("Tap + or plan it with AI on iPhone.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .watchPaperRow()
            } else {
                ForEach(groups(for: activities)) { group in
                    if let title = group.title {
                        Section {
                            rows(group.activities)
                        } header: {
                            WatchBoardGroupHeader(title: title, detail: group.detail, color: board.color)
                        }
                    } else {
                        rows(group.activities)
                    }
                }
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle(board.shortTitle)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .tint(WatchTheme.primary)
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddWatchBoardActivityView(store: store, board: board)
        }
    }

    @ViewBuilder
    private func rows(_ activities: [SyncedBoardActivity]) -> some View {
        ForEach(activities) { activity in
            Group {
                if board == .achievement && activity.completedAt == nil {
                    NavigationLink {
                        WatchAchievementTimerView(store: store, activity: activity)
                    } label: {
                        WatchBoardActivityRow(activity: activity, color: board.color, showsTimer: true)
                    }
                } else {
                    Button {
                        store.toggleBoardActivity(id: activity.id, on: board)
                    } label: {
                        WatchBoardActivityRow(activity: activity, color: board.color, showsTimer: false)
                    }
                }
            }
            .swipeActions {
                Button(role: .destructive) {
                    store.deleteBoardActivity(id: activity.id, on: board)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            .watchPaperRow()
        }
    }

    /// Groups activities the same way the iPhone board lays them out: by day, by month, or by milestone status.
    private func groups(for activities: [SyncedBoardActivity]) -> [WatchBoardGroup] {
        let calendar = Calendar.current
        switch board {
        case .weekly, .training:
            return [WatchBoardGroup(id: "all", title: nil, detail: nil, activities: activities)]
        case .achievement:
            let remaining = activities.filter { $0.completedAt == nil }
            let completed = activities.filter { $0.completedAt != nil }
            var result: [WatchBoardGroup] = []
            if !remaining.isEmpty {
                result.append(WatchBoardGroup(id: "next", title: String(localized: "Next milestones"),
                                              detail: nil, activities: remaining))
            }
            if !completed.isEmpty {
                result.append(WatchBoardGroup(id: "done", title: String(localized: "Completed milestones"),
                                              detail: nil, activities: completed))
            }
            return result
        case .raceVision:
            let byMonth = Dictionary(grouping: activities) {
                calendar.dateInterval(of: .month, for: $0.start)?.start ?? calendar.startOfDay(for: $0.start)
            }
            return byMonth.keys.sorted().map { month in
                let items = byMonth[month] ?? []
                return WatchBoardGroup(
                    id: month.description,
                    title: month.formatted(.dateTime.month(.wide).year()),
                    detail: String(localized: "\(items.count) races / milestones"),
                    activities: items
                )
            }
        case .monthly, .weekend, .vacation, .travel:
            let byDay = Dictionary(grouping: activities) { calendar.startOfDay(for: $0.start) }
            return byDay.keys.sorted().map { day in
                let items = byDay[day] ?? []
                return WatchBoardGroup(
                    id: day.description,
                    title: day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()),
                    detail: board == .vacation ? String(localized: "\(items.count) activities") : nil,
                    activities: items
                )
            }
        }
    }
}

private struct WatchBoardGroup: Identifiable {
    let id: String
    let title: String?
    let detail: String?
    let activities: [SyncedBoardActivity]
}

/// Board heading, description and summary, like the top of the iPhone board page.
private struct WatchBoardHeader: View {
    let board: WatchBoard
    let activities: [SyncedBoardActivity]

    private var completedCount: Int {
        activities.filter { $0.completedAt != nil }.count
    }

    private var plannedHours: Double {
        activities.reduce(0) { $0 + max(0, $1.finish.timeIntervalSince($1.start)) / 3600 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(board.heading, systemImage: board.headingIcon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(board.color)
            Text(board.headingDescription)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            if !activities.isEmpty {
                switch board {
                case .training:
                    Text("\(activities.count) sessions · \(plannedHours.formatted(.number.precision(.fractionLength(1)))) planned hours")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                case .achievement:
                    ProgressView(value: Double(completedCount), total: Double(max(1, activities.count)))
                        .tint(board.color)
                    Text("\(completedCount) of \(activities.count) milestones completed")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                default:
                    Text("\(completedCount)/\(activities.count) done")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct WatchBoardGroupHeader: View {
    let title: String
    let detail: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            if let detail {
                Text(detail)
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
            }
        }
        .textCase(nil)
    }
}

private struct WatchBoardActivityRow: View {
    let activity: SyncedBoardActivity
    let color: Color
    let showsTimer: Bool

    private var isCompleted: Bool { activity.completedAt != nil }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isCompleted ? "checkmark.circle.fill" : (showsTimer ? "stopwatch" : "circle"))
                .font(.system(size: 16))
                .foregroundStyle(isCompleted ? color : color.opacity(0.7))
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.activity)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .strikethrough(isCompleted)
                    .foregroundStyle(isCompleted ? WatchTheme.muted : WatchTheme.ink)
                    .lineLimit(2)
                Text("\(activity.start, format: .dateTime.weekday(.abbreviated).hour().minute()) – \(activity.finish, format: .dateTime.hour().minute())")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
                Text("\(Int(max(0, activity.finish.timeIntervalSince(activity.start)) / 60)) min")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundStyle(color)
            }
        }
        .opacity(isCompleted ? 0.7 : 1)
    }
}

/// Start/stop timer for an Achievement Timer activity, or a free "quick session" when `activity` is nil.
struct WatchAchievementTimerView: View {
    let store: WatchAppStore
    let activity: SyncedBoardActivity?
    @Environment(\.dismiss) private var dismiss
    @State private var startedAt: Date?

    /// Planned length from the activity's start/finish, used for the progress bar.
    private var plannedSeconds: TimeInterval? {
        guard let activity else { return nil }
        let seconds = activity.finish.timeIntervalSince(activity.start)
        return seconds > 0 ? seconds : nil
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = startedAt.map { max(context.date.timeIntervalSince($0), 0) } ?? 0
            let seconds = Int(elapsed)
            VStack(spacing: 8) {
                Text(activity?.activity ?? "Quick session")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text("\(seconds / 3600):\((seconds / 60) % 60, format: .number.precision(.integerLength(2))):\(seconds % 60, format: .number.precision(.integerLength(2)))")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(WatchTheme.primary)

                if let plannedSeconds {
                    ProgressView(value: min(elapsed / plannedSeconds, 1))
                        .tint(WatchTheme.primary)
                    Text("Goal: \(Int(plannedSeconds / 60)) min")
                        .font(WatchTheme.captionFont)
                        .foregroundStyle(WatchTheme.muted)
                }

                if startedAt == nil {
                    Button("Start") {
                        startedAt = Date()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(WatchTheme.primary)
                } else {
                    Button("Stop & Save") {
                        stop()
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                }
            }
            .padding(.horizontal)
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Timer")
        .navigationBarBackButtonHidden(startedAt != nil)
    }

    private func stop() {
        guard let startedAt else { return }
        if let activity {
            store.completeTimedActivity(id: activity.id, startedAt: startedAt, on: .achievement)
        } else {
            store.logTimedSession(title: String(localized: "Focus session"), startedAt: startedAt, on: .achievement)
        }
        dismiss()
    }
}

/// New board activity, styled like `AddWatchTaskView`: cream cards and a gradient Add button.
private struct AddWatchBoardActivityView: View {
    let store: WatchAppStore
    let board: WatchBoard
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var dayOffset = 0
    @State private var hour = min(Calendar.current.component(.hour, from: Date()) + 1, 23)
    @State private var durationMinutes = 60

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var start: Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: Date())) ?? Date()
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text(board.shortTitle)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                        .padding(.horizontal, 4)

                    WatchBoardFormCard(label: "Activity") {
                        TextField("e.g. Long run", text: $title)
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(WatchTheme.ink)
                            .tint(WatchTheme.primary)
                    }

                    WatchBoardFormCard(label: "Day") {
                        Picker("Day", selection: $dayOffset) {
                            ForEach(0..<31, id: \.self) { offset in
                                Text(dayLabel(offset)).tag(offset)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    WatchBoardFormCard(label: "Start") {
                        Picker("Start", selection: $hour) {
                            ForEach(0..<24, id: \.self) { value in
                                Text(DateComponents(calendar: .current, hour: value).date ?? Date(), format: .dateTime.hour())
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    WatchBoardFormCard(label: "Duration") {
                        Picker("Duration", selection: $durationMinutes) {
                            ForEach([15, 30, 45, 60, 90, 120], id: \.self) { minutes in
                                Text("\(minutes) min").tag(minutes)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }

                    Button {
                        store.addBoardActivity(title: title, start: start, durationMinutes: durationMinutes, on: board)
                        dismiss()
                    } label: {
                        Text("Add")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
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
            .tint(WatchTheme.muted)
        }
    }

    private func dayLabel(_ offset: Int) -> String {
        switch offset {
        case 0: String(localized: "Today")
        case 1: String(localized: "Tomorrow")
        default:
            (Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date())
                .formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
        }
    }
}

/// Labelled cream card used by the add-activity form.
private struct WatchBoardFormCard<Content: View>: View {
    let label: LocalizedStringKey
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
            content
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .watchGlassCard(cornerRadius: 14)
    }
}

/// Home-page AI Board: every board (Weekly, Monthly, Weekend, Vacation, Travel, …) as a tile,
/// like the iPhone Home screen's `HomePlanBoard`.
struct WatchHomeAIBoardSection: View {
    let store: WatchAppStore

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("AI Board")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                Spacer()
                NavigationLink {
                    WatchAIBoardView(store: store)
                } label: {
                    Text("See all")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(WatchBoard.allCases) { board in
                    NavigationLink {
                        WatchBoardDetailView(store: store, board: board)
                    } label: {
                        WatchHomeBoardTile(board: board, activities: store.activities(on: board))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct WatchHomeBoardTile: View {
    let board: WatchBoard
    let activities: [SyncedBoardActivity]

    private var detail: String {
        guard !activities.isEmpty else { return "No activities" }
        return "\(activities.filter { $0.completedAt != nil }.count)/\(activities.count) done"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            WatchBoardIcon(board: board)
            Text(board.shortTitle)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(WatchTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(detail)
                .font(.system(size: 9, weight: .medium, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
                .lineLimit(1)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        // Tinted with the board's colour like the iPhone's `HomePlanButton`.
        .background(board.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(board.color.opacity(0.22))
        }
    }
}
