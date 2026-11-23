import SwiftUI
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchPhoneSyncManager: NSObject {
    static let shared = WatchPhoneSyncManager()

    /// Whether the paired iPhone can be reached right now, shown by the Connect iPhone buttons.
    private(set) var isPhoneReachable = false

    @ObservationIgnored private let session: WCSession? = WCSession.isSupported() ? .default : nil
    @ObservationIgnored private weak var store: WatchAppStore?
    @ObservationIgnored private weak var access: WatchAccessStore?

    private override init() {
        super.init()
    }

    func activate(store: WatchAppStore, access: WatchAccessStore) {
        self.store = store
        self.access = access
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    /// Starts the iPhone session if it isn't running yet, loads the last data the iPhone sent,
    /// and asks for a fresh snapshot when the iPhone is reachable.
    func connect() {
        guard let session else { return }
        guard session.activationState == .activated else {
            session.delegate = self
            session.activate()
            return
        }
        isPhoneReachable = session.isReachable
        apply(session.receivedApplicationContext)
        requestSnapshot()
    }

    func requestSnapshot() {
        guard let session else { return }
        if session.isReachable {
            session.sendMessage(["requestSnapshot": true], replyHandler: nil)
        }
    }

    func toggleTask(id: UUID, on date: Date) {
        send(WatchCommand(kind: .toggleTask, id: id, date: date))
    }

    func toggleMilestone(projectId: UUID, milestoneId: UUID) {
        send(WatchCommand(kind: .toggleMilestone, projectId: projectId, milestoneId: milestoneId))
    }

    func addTask(title: String, scheduledDate: Date) {
        send(WatchCommand(kind: .addTask, title: title, date: scheduledDate))
    }

    func setMood(_ mood: WatchMood) {
        send(WatchCommand(kind: .setMood, moodRawValue: mood.phoneRawValue))
    }

    func addWorkout(id: UUID, kind: WorkoutKind, durationMinutes: Int, date: Date) {
        send(
            WatchCommand(
                kind: .addWorkout,
                id: id,
                workoutKind: kind.rawValue,
                durationMinutes: durationMinutes,
                date: date
            )
        )
    }

    func addBoardActivity(_ activity: SyncedBoardActivity, boardKey: String) {
        send(
            WatchCommand(
                kind: .addBoardActivity,
                id: activity.id,
                title: activity.activity,
                date: activity.start,
                boardKey: boardKey,
                finishDate: activity.finish,
                completedAt: activity.completedAt
            )
        )
    }

    func setBoardActivityCompleted(id: UUID, boardKey: String, completedAt: Date?, finishDate: Date? = nil) {
        send(
            WatchCommand(
                kind: .setBoardActivityCompleted,
                id: id,
                boardKey: boardKey,
                finishDate: finishDate,
                completedAt: completedAt
            )
        )
    }

    func deleteBoardActivity(id: UUID, boardKey: String) {
        send(WatchCommand(kind: .deleteBoardActivity, id: id, boardKey: boardKey))
    }

    func checkInLifeGoal(id: UUID) {
        send(WatchCommand(kind: .checkInLifeGoal, id: id))
    }

    private func send(_ command: WatchCommand) {
        guard let session,
              let data = try? JSONEncoder().encode(command) else { return }
        let message: [String: Any] = ["command": data]
        if session.isReachable {
            session.sendMessage(message, replyHandler: nil)
        } else {
            session.transferUserInfo(message)
        }
    }

    private func apply(_ message: [String: Any]) {
        guard let data = message["snapshot"] as? Data,
              let snapshot = try? JSONDecoder().decode(PhoneSnapshot.self, from: data) else {
            return
        }
        store?.apply(snapshot: snapshot)
        if let isPremium = snapshot.isPremium {
            access?.applyPhoneAccount(isPremium: isPremium, email: snapshot.accountEmail)
        }
    }
}

extension WatchPhoneSyncManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated, error == nil else { return }
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = isReachable
            self.requestSnapshot()
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let isReachable = session.isReachable
        Task { @MainActor in
            self.isPhoneReachable = isReachable
            if isReachable {
                self.requestSnapshot()
            }
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String: Any]
    ) {
        Task { @MainActor in
            self.apply(applicationContext)
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            self.apply(message)
        }
    }
}

struct PhoneSnapshot: Codable {
    let tasks: [SyncedWatchTask]
    let moodRawValue: Int?
    let workouts: [SyncedWatchWorkout]
    let projects: [SyncedWatchProject]
    /// Optional so snapshots from an older iPhone build still decode.
    let boards: [SyncedWatchBoard]?
    /// Optional so snapshots from an older iPhone build still decode.
    let lifeGoals: [SyncedLifeGoal]?
    /// The iPhone's subscription and signed-in account, so the watch unlocks without a second purchase.
    let isPremium: Bool?
    let accountEmail: String?
}

/// A life goal mirrored from the iPhone's `LifeGoalStore`.
struct SyncedLifeGoal: Codable, Identifiable {
    let id: UUID
    let title: String
    let emoji: String
    var progress: Double
    var streak: Int
    let color: Color.Resolved
}

/// One AI Board category and its activities, mirrored from the iPhone's `localSchedule.<key>` storage.
struct SyncedWatchBoard: Codable {
    let key: String
    let activities: [SyncedBoardActivity]
}

/// Matches the iPhone's `LocalScheduleActivity` JSON shape.
struct SyncedBoardActivity: Codable, Identifiable {
    var id: UUID
    var activity: String
    var start: Date
    var finish: Date
    var completedAt: Date?
}

/// A project as mirrored from the iPhone's `AIProject`.
struct SyncedWatchProject: Codable, Identifiable {
    let id: UUID
    let title: String
    let emoji: String
    let category: String
    let status: String
    let isPinned: Bool
    var milestones: [SyncedWatchMilestone]

    var completedCount: Int { milestones.filter(\.isDone).count }

    var progress: Double {
        guard !milestones.isEmpty else { return 0 }
        return Double(completedCount) / Double(milestones.count)
    }
}

struct SyncedWatchMilestone: Codable, Identifiable {
    let id: UUID
    let title: String
    var isDone: Bool
}

struct SyncedWatchTask: Codable {
    let id: UUID
    let title: String
    let scheduledDate: Date
    let isCompleted: Bool
}

struct SyncedWatchWorkout: Codable {
    let id: UUID
    let kind: String
    let startedAt: Date
    let durationMinutes: Int
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

private struct WatchCommand: Codable {
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

    init(
        kind: WatchCommandKind,
        id: UUID? = nil,
        title: String? = nil,
        moodRawValue: Int? = nil,
        workoutKind: String? = nil,
        durationMinutes: Int? = nil,
        date: Date? = nil,
        projectId: UUID? = nil,
        milestoneId: UUID? = nil,
        boardKey: String? = nil,
        finishDate: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.kind = kind
        self.id = id
        self.title = title
        self.moodRawValue = moodRawValue
        self.workoutKind = workoutKind
        self.durationMinutes = durationMinutes
        self.date = date
        self.projectId = projectId
        self.milestoneId = milestoneId
        self.boardKey = boardKey
        self.finishDate = finishDate
        self.completedAt = completedAt
    }
}
