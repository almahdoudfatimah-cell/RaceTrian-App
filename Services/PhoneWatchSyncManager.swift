import SwiftUI
import WatchConnectivity

extension Notification.Name {
    static let watchSyncSourceDidChange = Notification.Name("watchSyncSourceDidChange")
}

@MainActor
final class PhoneWatchSyncManager: NSObject {
    static let shared = PhoneWatchSyncManager()

    private let session: WCSession? = WCSession.isSupported() ? .default : nil
    private var observer: NSObjectProtocol?

    private override init() {
        super.init()
        observer = NotificationCenter.default.addObserver(
            forName: .watchSyncSourceDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let manager = self else { return }
            Task { @MainActor in
                manager.sendSnapshot()
            }
        }
    }

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    func sendSnapshot() {
        guard let session else { return }
        // Send the whole current week so the watch Plan tab matches the iPhone's week view.
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekTasks = (0..<7)
            .compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
            .flatMap { WeekTaskStore.shared.tasks(for: $0) }

        let payload = PhoneWatchSnapshot(
            tasks: weekTasks.map(PhoneWatchTask.init),
            moodRawValue: MoodStore.shared.todayLog?.mood.rawValue,
            workouts: SportsStore.shared.activities.map(PhoneWatchWorkout.init),
            projects: ProjectStore.shared.projects.map(PhoneWatchProject.init),
            boards: Self.boardKeys.map { PhoneWatchBoard(key: $0, activities: Self.boardActivities(for: $0)) },
            lifeGoals: LifeGoalStore.shared.goals.map(PhoneWatchLifeGoal.init),
            isPremium: PremiumStore.shared.isActive,
            accountEmail: AuthManager.shared.isAuthenticated ? AuthManager.shared.currentEmail : nil
        )
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? session.updateApplicationContext(["snapshot": data])
        if session.isReachable {
            session.sendMessage(["snapshot": data], replyHandler: nil)
        }
    }

    // MARK: - AI Board

    /// The AI Board categories, matching `HomePlanDestination` raw values on the Home screen.
    private static let boardKeys = ["weekly", "monthly", "weekend", "vacation", "travel", "training", "achievement", "raceVision"]

    /// Board activities are stored by `LocalScheduleView` as JSON under `localSchedule.<key>`.
    private static func boardActivities(for key: String) -> [LocalScheduleActivity] {
        guard let data = UserDefaults.standard.data(forKey: "localSchedule.\(key)"),
              let activities = try? JSONDecoder().decode([LocalScheduleActivity].self, from: data) else {
            return []
        }
        return activities
    }

    private static func updateBoard(_ key: String, _ update: (inout [LocalScheduleActivity]) -> Void) {
        guard boardKeys.contains(key) else { return }
        var activities = boardActivities(for: key)
        update(&activities)
        activities.sort { $0.start < $1.start }
        guard let data = try? JSONEncoder().encode(activities) else { return }
        UserDefaults.standard.set(data, forKey: "localSchedule.\(key)")
    }

    private func handle(_ message: [String: Any]) {
        guard let commandData = message["command"] as? Data,
              let command = try? JSONDecoder().decode(WatchPhoneCommand.self, from: commandData) else {
            return
        }

        switch command.kind {
        case .toggleTask:
            guard let id = command.id else { return }
            WeekTaskStore.shared.toggleDone(taskId: id, on: command.date ?? Date())
        case .toggleMilestone:
            guard let projectId = command.projectId, let milestoneId = command.milestoneId else { return }
            ProjectStore.shared.toggleMilestone(projectId: projectId, milestoneId: milestoneId)
        case .addTask:
            guard let title = command.title else { return }
            let scheduledDate = command.date ?? Date()
            let hour = Calendar.current.component(.hour, from: scheduledDate)
            var tasks = WeekTaskStore.shared.tasks(for: scheduledDate)
            tasks.append(
                PlanTask(
                    title: title,
                    time: scheduledDate.formatted(date: .omitted, time: .shortened),
                    hour: hour,
                    durationSlots: 1,
                    category: .focus,
                    date: scheduledDate
                )
            )
            WeekTaskStore.shared[day: scheduledDate] = tasks
        case .setMood:
            guard let moodValue = command.moodRawValue,
                  let mood = MoodLevel(rawValue: moodValue) else { return }
            MoodStore.shared.log(mood: mood)
        case .addWorkout:
            guard let workoutKind = command.workoutKind,
                  let sportType = SportType(watchWorkoutKind: workoutKind) else { return }
            SportsStore.shared.add(
                SportActivity(
                    id: command.id ?? UUID(),
                    type: sportType,
                    date: command.date ?? Date(),
                    duration: max(command.durationMinutes ?? 1, 1)
                )
            )
        case .addBoardActivity:
            guard let key = command.boardKey, let title = command.title else { return }
            let start = command.date ?? Date()
            Self.updateBoard(key) { activities in
                activities.append(
                    LocalScheduleActivity(
                        id: command.id ?? UUID(),
                        activity: title,
                        start: start,
                        finish: command.finishDate ?? start.addingTimeInterval(3600),
                        completedAt: command.completedAt
                    )
                )
            }
        case .setBoardActivityCompleted:
            guard let key = command.boardKey, let id = command.id else { return }
            Self.updateBoard(key) { activities in
                guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
                activities[index].completedAt = command.completedAt
                if let finish = command.finishDate {
                    activities[index].finish = finish
                }
            }
        case .deleteBoardActivity:
            guard let key = command.boardKey, let id = command.id else { return }
            Self.updateBoard(key) { activities in
                activities.removeAll { $0.id == id }
            }
        case .checkInLifeGoal:
            guard let id = command.id else { return }
            LifeGoalStore.shared.checkIn(id: id)
        }
        sendSnapshot()
    }
}

extension PhoneWatchSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        Task { @MainActor in
            self.sendSnapshot()
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if message["requestSnapshot"] as? Bool == true {
                self.sendSnapshot()
            } else {
                self.handle(message)
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor in
            self.handle(message)
            replyHandler(["accepted": true])
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any] = [:]
    ) {
        Task { @MainActor in
            self.handle(userInfo)
        }
    }
}

private struct PhoneWatchSnapshot: Codable {
    let tasks: [PhoneWatchTask]
    let moodRawValue: Int?
    let workouts: [PhoneWatchWorkout]
    let projects: [PhoneWatchProject]
    let boards: [PhoneWatchBoard]
    let lifeGoals: [PhoneWatchLifeGoal]
    let isPremium: Bool
    let accountEmail: String?
}

private struct PhoneWatchLifeGoal: Codable {
    let id: UUID
    let title: String
    let emoji: String
    let progress: Double
    let streak: Int
    let color: Color.Resolved

    init(_ goal: LifeGoal) {
        id = goal.id
        title = goal.title
        emoji = goal.emoji
        progress = goal.progress
        streak = goal.streak
        color = goal.color.resolve(in: EnvironmentValues())
    }
}

private struct PhoneWatchBoard: Codable {
    let key: String
    let activities: [LocalScheduleActivity]
}

private struct PhoneWatchProject: Codable {
    let id: UUID
    let title: String
    let emoji: String
    let category: String
    let status: String
    let isPinned: Bool
    let milestones: [PhoneWatchMilestone]

    init(_ project: AIProject) {
        id = project.id
        title = project.title
        emoji = project.emoji
        category = project.category.rawValue
        status = project.status.rawValue
        isPinned = project.isPinned
        milestones = project.milestones.map(PhoneWatchMilestone.init)
    }
}

// Plain value type built from nonisolated contexts (PhoneWatchProject.init), so opt out of the target's MainActor default.
nonisolated private struct PhoneWatchMilestone: Codable {
    let id: UUID
    let title: String
    let isDone: Bool

    init(_ milestone: Milestone) {
        id = milestone.id
        title = milestone.title
        isDone = milestone.isDone
    }
}

private struct PhoneWatchTask: Codable {
    let id: UUID
    let title: String
    let scheduledDate: Date
    let isCompleted: Bool

    init(_ task: PlanTask) {
        id = task.id
        title = task.title
        scheduledDate = Calendar.current.date(
            bySettingHour: task.hour,
            minute: 0,
            second: 0,
            of: task.date
        ) ?? task.date
        isCompleted = task.isDone
    }
}

private struct PhoneWatchWorkout: Codable {
    let id: UUID
    let kind: String
    let startedAt: Date
    let durationMinutes: Int

    init(_ activity: SportActivity) {
        id = activity.id
        kind = activity.type.watchWorkoutKind
        startedAt = activity.date
        durationMinutes = activity.duration
    }
}

private enum WatchCommandKind: String, Codable {
    case toggleTask
    case toggleMilestone
    case addTask
    case setMood
    case addWorkout
    case addBoardActivity
    case setBoardActivityCompleted
    case deleteBoardActivity
    case checkInLifeGoal
}

private struct WatchPhoneCommand: Codable {
    let kind: WatchCommandKind
    let id: UUID?
    let title: String?
    let moodRawValue: Int?
    let workoutKind: String?
    let durationMinutes: Int?
    let date: Date?
    let projectId: UUID?
    let milestoneId: UUID?
    let boardKey: String?
    let finishDate: Date?
    let completedAt: Date?
}

private extension SportType {
    init?(watchWorkoutKind: String) {
        switch watchWorkoutKind {
        case "Run": self = .running
        case "Walk": self = .hiking
        case "Cycling": self = .cycling
        case "Strength": self = .gym
        case "Mobility": self = .yoga
        case "Recovery": self = .other
        default: return nil
        }
    }

    var watchWorkoutKind: String {
        switch self {
        case .running, .triathlon: "Run"
        case .cycling: "Cycling"
        case .gym, .basketball, .soccer, .tennis: "Strength"
        case .yoga: "Mobility"
        case .swimming: "Recovery"
        case .hiking, .other: "Walk"
        }
    }
}
