import Foundation
import Observation
import UserNotifications

/// Watch reminder settings plus local notification scheduling for tasks, AI Board activities,
/// a morning plan nudge, and an evening mood check-in.
@MainActor
@Observable
final class WatchNotificationManager: NSObject {
    static let shared = WatchNotificationManager()

    /// Master switch; individual reminders below only fire when this is on.
    var isEnabled: Bool { didSet { settingsChanged() } }
    var morningReminder: Bool { didSet { settingsChanged() } }
    var morningHour: Int { didSet { settingsChanged() } }
    var moodReminder: Bool { didSet { settingsChanged() } }
    var moodHour: Int { didSet { settingsChanged() } }
    var taskReminders: Bool { didSet { settingsChanged() } }
    var activityReminders: Bool { didSet { settingsChanged() } }
    /// How long before a task or activity starts to remind the user.
    var leadMinutes: Int { didSet { settingsChanged() } }

    /// Whether watchOS currently allows the app to post notifications.
    private(set) var isAuthorized = false
    private(set) var isDenied = false

    private let center = UNUserNotificationCenter.current()
    private let defaults = UserDefaults.standard
    private weak var store: WatchAppStore?
    private var rescheduleTask: Task<Void, Never>?

    /// watchOS allows 64 pending local notifications per app; keep a little headroom.
    private static let maxPending = 60

    private override init() {
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: "watch.notify.enabled") as? Bool ?? true
        morningReminder = defaults.object(forKey: "watch.notify.morning") as? Bool ?? true
        morningHour = defaults.object(forKey: "watch.notify.morningHour") as? Int ?? 8
        moodReminder = defaults.object(forKey: "watch.notify.mood") as? Bool ?? true
        moodHour = defaults.object(forKey: "watch.notify.moodHour") as? Int ?? 20
        taskReminders = defaults.object(forKey: "watch.notify.tasks") as? Bool ?? true
        activityReminders = defaults.object(forKey: "watch.notify.activities") as? Bool ?? true
        leadMinutes = defaults.object(forKey: "watch.notify.lead") as? Int ?? 10
        super.init()
        center.delegate = self
    }

    /// Called once at launch so reminders follow the store's tasks and activities.
    func activate(store: WatchAppStore) {
        self.store = store
        Task {
            await refreshAuthorization()
            if isEnabled && !isAuthorized && !isDenied {
                await requestAuthorization()
            }
            scheduleReschedule()
        }
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        await refreshAuthorization()
        scheduleReschedule()
    }

    func refreshAuthorization() async {
        let status = await center.notificationSettings().authorizationStatus
        isAuthorized = status == .authorized || status == .provisional
        isDenied = status == .denied
    }

    /// Debounced so a burst of store changes (e.g. a full iPhone sync) reschedules once.
    func scheduleReschedule() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.reschedule()
        }
    }

    /// Upcoming reminders, soonest first, for the Notifications page.
    func upcomingReminders(limit: Int = 20) -> [WatchReminder] {
        Array(buildReminders().prefix(limit))
    }

    private func settingsChanged() {
        save()
        scheduleReschedule()
    }

    private func save() {
        defaults.set(isEnabled, forKey: "watch.notify.enabled")
        defaults.set(morningReminder, forKey: "watch.notify.morning")
        defaults.set(morningHour, forKey: "watch.notify.morningHour")
        defaults.set(moodReminder, forKey: "watch.notify.mood")
        defaults.set(moodHour, forKey: "watch.notify.moodHour")
        defaults.set(taskReminders, forKey: "watch.notify.tasks")
        defaults.set(activityReminders, forKey: "watch.notify.activities")
        defaults.set(leadMinutes, forKey: "watch.notify.lead")
    }

    private func reschedule() async {
        center.removeAllPendingNotificationRequests()
        guard isEnabled, isAuthorized else { return }

        if morningReminder {
            addDaily(id: "daily.morning", hour: morningHour,
                     title: String(localized: "Good morning"),
                     body: String(localized: "Check today's plan and get moving."))
        }
        if moodReminder {
            addDaily(id: "daily.mood", hour: moodHour,
                     title: String(localized: "Mood check-in"),
                     body: String(localized: "How are you feeling today? Log your mood."))
        }

        let dailyCount = (morningReminder ? 1 : 0) + (moodReminder ? 1 : 0)
        for reminder in buildReminders().prefix(Self.maxPending - dailyCount) {
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: reminder.id, content: content, trigger: trigger))
        }
    }

    private func addDaily(id: String, hour: Int, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: hour, minute: 0), repeats: true)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    /// Future, not-yet-completed tasks and board activities, each reminded `leadMinutes` before it starts.
    private func buildReminders() -> [WatchReminder] {
        guard let store else { return [] }
        let now = Date()
        let lead = TimeInterval(leadMinutes * 60)
        var reminders: [WatchReminder] = []

        if taskReminders {
            for task in store.tasks where !task.isCompleted {
                let fireDate = task.scheduledDate.addingTimeInterval(-lead)
                guard fireDate > now else { continue }
                reminders.append(WatchReminder(
                    id: "task.\(task.id.uuidString)",
                    title: task.title,
                    body: reminderBody(for: task.scheduledDate),
                    icon: "checklist",
                    startDate: task.scheduledDate,
                    fireDate: fireDate
                ))
            }
        }

        if activityReminders {
            for board in WatchBoard.allCases {
                for activity in store.activities(on: board) where activity.completedAt == nil {
                    let fireDate = activity.start.addingTimeInterval(-lead)
                    guard fireDate > now else { continue }
                    reminders.append(WatchReminder(
                        id: "activity.\(activity.id.uuidString)",
                        title: activity.activity,
                        body: "\(board.title) · \(reminderBody(for: activity.start))",
                        icon: board.icon,
                        startDate: activity.start,
                        fireDate: fireDate
                    ))
                }
            }
        }

        return reminders.sorted { $0.fireDate < $1.fireDate }
    }

    private func reminderBody(for start: Date) -> String {
        let time = start.formatted(date: .omitted, time: .shortened)
        return leadMinutes == 0
            ? String(localized: "Starting now (\(time))")
            : String(localized: "Starts in \(leadMinutes) min at \(time)")
    }
}

extension WatchNotificationManager: UNUserNotificationCenterDelegate {
    /// Show reminders as banners even while the watch app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }
}

struct WatchReminder: Identifiable {
    let id: String
    let title: String
    let body: String
    let icon: String
    let startDate: Date
    let fireDate: Date
}
