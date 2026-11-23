import SwiftUI
import UserNotifications

// MARK: - Notification Manager

/// Owns local notification permission, scheduling and the in-app notification list.
@MainActor
@Observable
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var delivered: [UNNotification] = []
    private(set) var pending: [UNNotificationRequest] = []

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    private var isStarted = false

    /// Identifiers are prefixed so rescheduling only replaces notifications this manager created.
    private let taskPrefix = "racetrian.task."
    private let dailyPrefix = "racetrian.daily."

    /// Sets the delegate and keeps task reminders in sync. Call once at launch.
    func start() {
        guard !isStarted else { return }
        isStarted = true
        center.delegate = self

        Task {
            await refresh()
            if isAuthorized { await scheduleAll() }
        }

        // Task edits post `.watchSyncSourceDidChange`; reschedule reminders whenever that happens.
        Task {
            for await _ in NotificationCenter.default.notifications(named: .watchSyncSourceDidChange) {
                if isAuthorized { await scheduleAll() }
            }
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    func requestAuthorizationAndSchedule() {
        Task { await requestAuthorization() }
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            // Permission errors leave the status as-is; the sheet shows how to enable it.
        }
        await refresh()
        if isAuthorized { await scheduleAll() }
    }

    func refresh() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
        delivered = await center.deliveredNotifications()
            .sorted { $0.date > $1.date }
        pending = await center.pendingNotificationRequests()
            .sorted { (nextDate(for: $0) ?? .distantFuture) < (nextDate(for: $1) ?? .distantFuture) }
    }

    /// Replaces all RaceTrian reminders: daily check-ins plus one reminder per upcoming timed task.
    func scheduleAll() async {
        let existing = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(taskPrefix) || $0.hasPrefix(dailyPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: existing)

        for request in dailyRequests() + taskRequests() {
            try? await center.add(request)
        }
        await refresh()
    }

    func sendTestNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "RaceTrian"
        content.body = "Notifications are working. You'll get reminders for your plan."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "racetrian.test.\(UUID().uuidString)",
                                                    content: content, trigger: trigger))
        await refresh()
    }

    func clearDelivered() async {
        center.removeAllDeliveredNotifications()
        await refresh()
    }

    func nextDate(for request: UNNotificationRequest) -> Date? {
        switch request.trigger {
        case let trigger as UNCalendarNotificationTrigger: trigger.nextTriggerDate()
        case let trigger as UNTimeIntervalNotificationTrigger: trigger.nextTriggerDate()
        default: nil
        }
    }

    // MARK: Requests

    private func dailyRequests() -> [UNNotificationRequest] {
        let reminders: [(id: String, hour: Int, title: String, body: String)] = [
            ("morning", 8, "Your plan for today", "Open RaceTrian to review today's training and tasks."),
            ("mood", 13, "Mood check-in", "How are you feeling? Log your mood in a few seconds."),
            ("evening", 20, "Evening review", "Mark what you finished today and plan tomorrow.")
        ]
        return reminders.map { reminder in
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.body
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(
                dateMatching: DateComponents(hour: reminder.hour, minute: 0),
                repeats: true
            )
            return UNNotificationRequest(identifier: dailyPrefix + reminder.id, content: content, trigger: trigger)
        }
    }

    private func taskRequests() -> [UNNotificationRequest] {
        let now = Date()
        let store = WeekTaskStore.shared
        var requests: [UNNotificationRequest] = []

        // iOS keeps at most 64 pending notifications, so only look a week ahead.
        for offset in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            for task in store.tasks(for: day) where !task.isDone && task.time != "Any time" {
                guard let fireDate = calendar.date(bySettingHour: task.hour, minute: 0, second: 0, of: task.date),
                      fireDate > now else { continue }

                let content = UNMutableNotificationContent()
                content.title = task.title
                content.body = "Starting now · \(task.time)"
                content.sound = .default
                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                requests.append(UNNotificationRequest(identifier: taskPrefix + task.id.uuidString,
                                                      content: content, trigger: trigger))
            }
        }
        return Array(requests.prefix(50))
    }

    // MARK: UNUserNotificationCenterDelegate

    /// Show banners even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        Task { @MainActor in await NotificationManager.shared.refresh() }
        return [.banner, .list, .sound]
    }
}

// MARK: - Notifications Sheet

struct NotificationsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var manager = NotificationManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                PaperBackground()
                ScrollView {
                    VStack(spacing: 12) {
                        statusCard

                        if manager.isAuthorized {
                            sectionTitle("Recent")
                            if manager.delivered.isEmpty {
                                emptyRow("No notifications yet.")
                            } else {
                                ForEach(manager.delivered, id: \.request.identifier) { notification in
                                    row(icon: "bell.badge.fill", tint: Theme.primary,
                                        title: notification.request.content.title,
                                        message: notification.request.content.body,
                                        date: notification.date)
                                }
                            }

                            sectionTitle("Upcoming")
                            if manager.pending.isEmpty {
                                emptyRow("No reminders scheduled. Add tasks with a time to get reminders.")
                            } else {
                                ForEach(manager.pending, id: \.identifier) { request in
                                    row(icon: "clock.fill", tint: Theme.secondary,
                                        title: request.content.title,
                                        message: request.content.body,
                                        date: manager.nextDate(for: request))
                                }
                            }
                        }
                        Color.clear.frame(height: 24)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if manager.isAuthorized && !manager.delivered.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") { Task { await manager.clearDelivered() } }
                            .font(.system(size: Theme.fontSize(15), weight: .semibold, design: .rounded))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: Theme.fontSize(15), weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.primary)
                }
            }
            .task { await manager.refresh() }
            .refreshable { await manager.scheduleAll() }
        }.appPageTheme()
    }

    @ViewBuilder
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch manager.authorizationStatus {
            case .denied:
                Label("Notifications are off", systemImage: "bell.slash.fill")
                    .font(.system(size: Theme.fontSize(15), weight: .bold, design: .rounded))
                Text("Turn on notifications for RaceTrian in Settings to get plan reminders.")
                    .font(.system(size: Theme.fontSize(13), design: .rounded))
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                        openURL(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            case .notDetermined:
                Label("Stay on track", systemImage: "bell.fill")
                    .font(.system(size: Theme.fontSize(15), weight: .bold, design: .rounded))
                Text("Get reminders for your tasks, a morning plan, a mood check-in and an evening review.")
                    .font(.system(size: Theme.fontSize(13), design: .rounded))
                    .foregroundStyle(.secondary)
                Button("Turn On Notifications") {
                    Task { await manager.requestAuthorization() }
                }
                .buttonStyle(.borderedProminent)
            default:
                Label("Notifications are on", systemImage: "bell.badge.fill")
                    .font(.system(size: Theme.fontSize(15), weight: .bold, design: .rounded))
                Text("Daily reminders at 8:00, 13:00 and 20:00, plus reminders when timed tasks start.")
                    .font(.system(size: Theme.fontSize(13), design: .rounded))
                    .foregroundStyle(.secondary)
                Button("Send Test Notification") {
                    Task { await manager.sendTestNotification() }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: Theme.fontSize(13), weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }

    private func emptyRow(_ message: String) -> some View {
        Text(message)
            .font(.system(size: Theme.fontSize(13), design: .rounded))
            .foregroundStyle(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(cornerRadius: 18)
    }

    private func row(icon: String, tint: Color, title: String, message: String, date: Date?) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(tint.opacity(0.18)).frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: Theme.fontSize(16), weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: Theme.fontSize(14), weight: .bold, design: .rounded))
                Text(message)
                    .font(.system(size: Theme.fontSize(12), design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if let date {
                    Text(date, format: .dateTime.weekday(.abbreviated).hour().minute())
                        .font(.system(size: Theme.fontSize(10), weight: .medium, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(cornerRadius: 18)
    }
}

#Preview { NotificationsSheet() }
