import SwiftUI

/// Settings page: notifications, daily target, haptics, iPhone sync, account, and data.
struct WatchSettingsView: View {
    let store: WatchAppStore
    let access: WatchAccessStore
    @State private var showingResetConfirmation = false

    private static let dailyTargets = [15, 30, 45, 60, 90]

    var body: some View {
        // Custom rows instead of a List so every row keeps the same cream colour and text sizes;
        // the system List dims rows near the screen edge to grey.
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    WatchProfileView(store: store, access: access)
                } label: {
                    WatchProfileHeroCard(store: store, access: access)
                }
                .buttonStyle(.plain)

                WatchSettingsSection {
                    NavigationLink {
                        WatchNotificationsView(store: store)
                    } label: {
                        WatchSettingsRow(title: "Notifications", icon: "bell.badge.fill", color: WatchTheme.primary, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        WatchNotificationSettingsView()
                    } label: {
                        WatchSettingsRow(title: "Reminders", icon: "alarm.fill", color: WatchTheme.rose, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }

                WatchSettingsSection(title: "Training") {
                    WatchSettingsRow(title: "Daily target", icon: "target", color: WatchTheme.secondary, stacksTrailing: true) {
                        WatchSettingsStepper(
                            value: "\(store.dailyGoalMinutes) min",
                            decrease: { stepDailyTarget(by: -1) },
                            increase: { stepDailyTarget(by: 1) }
                        )
                    }
                    WatchSettingsRow(title: "Haptics", icon: "waveform", color: WatchTheme.accent) {
                        WatchSettingsSwitch(title: "Haptics", isOn: Bindable(store).hapticsEnabled)
                    }
                }

                WatchSettingsSection(title: "iPhone") {
                    Button {
                        WatchPhoneSyncManager.shared.requestSnapshot()
                    } label: {
                        WatchSettingsRow(title: "Sync now", icon: "arrow.triangle.2.circlepath", color: WatchTheme.secondary)
                    }
                    .buttonStyle(.plain)
                    WatchSettingsRow(title: "Last sync", icon: "clock.fill", color: WatchTheme.primary) {
                        Group {
                            if let lastSyncedAt = store.lastSyncedAt {
                                Text(lastSyncedAt, format: .relative(presentation: .named))
                            } else {
                                Text("Never")
                            }
                        }
                        .font(WatchSettingsFont.value)
                        .foregroundStyle(WatchTheme.muted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                }

                WatchSettingsSection(title: "App") {
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        WatchSettingsRow(title: "Reset Today", icon: "arrow.counterclockwise", color: .red, titleColor: .red)
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        AboutWatchView()
                    } label: {
                        WatchSettingsRow(title: "About", icon: "info.circle.fill", color: WatchTheme.muted, showsChevron: true)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Settings")
        .confirmationDialog("Reset today's tasks, workouts, water, and mood?", isPresented: $showingResetConfirmation) {
            Button("Reset", role: .destructive) { store.resetToday() }
            Button("Cancel", role: .cancel) {}
        }
    }

    /// Moves the daily target to the previous or next preset, wrapping around.
    private func stepDailyTarget(by offset: Int) {
        let targets = Self.dailyTargets
        let index = targets.firstIndex(of: store.dailyGoalMinutes) ?? 1
        store.dailyGoalMinutes = targets[(index + offset + targets.count) % targets.count]
    }
}

/// One text scale for every Settings and Profile row.
private enum WatchSettingsFont {
    static let header = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let title  = Font.system(size: 13, weight: .semibold, design: .rounded)
    static let value  = Font.system(size: 12, weight: .medium, design: .rounded)
}

/// Optional brown header followed by evenly spaced rows.
private struct WatchSettingsSection<Content: View>: View {
    var title: LocalizedStringKey? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title {
                Text(title)
                    .font(WatchSettingsFont.header)
                    .foregroundStyle(WatchTheme.muted)
                    .padding(.horizontal, 6)
            }
            content
        }
    }
}

/// Cream row: coloured icon, black title, and an optional trailing value or control.
private struct WatchSettingsRow<Trailing: View>: View {
    let title: LocalizedStringKey
    let icon: String
    let color: Color
    var titleColor: Color = WatchTheme.ink
    var showsChevron = false
    /// Puts the trailing control on its own line, for controls too wide to share a row with the title.
    var stacksTrailing = false
    @ViewBuilder let trailing: Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 6))
                Text(title)
                    .font(WatchSettingsFont.title)
                    .foregroundStyle(titleColor)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if !stacksTrailing {
                    trailing
                }
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(WatchTheme.primary)
                }
            }
            if stacksTrailing {
                trailing
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, stacksTrailing ? 8 : 0)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(WatchTheme.cardSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

extension WatchSettingsRow where Trailing == EmptyView {
    init(
        title: LocalizedStringKey,
        icon: String,
        color: Color,
        titleColor: Color = WatchTheme.ink,
        showsChevron: Bool = false
    ) {
        self.init(title: title, icon: icon, color: color, titleColor: titleColor, showsChevron: showsChevron) {
            EmptyView()
        }
    }
}

/// Orange on / cream off switch; watchOS ignores `.tint` on the system toggle here.
private struct WatchSettingsSwitch: View {
    let title: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.snappy(duration: 0.2)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? WatchTheme.primary : WatchTheme.paper)
                .overlay(Capsule().strokeBorder(WatchTheme.primary.opacity(isOn ? 0 : 0.5), lineWidth: 1))
                .frame(width: 40, height: 24)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(isOn ? Color.white : WatchTheme.primary)
                        .frame(width: 18, height: 18)
                        .padding(3)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAddTraits(.isToggle)
    }
}

/// Small orange − / + around a value, matching the Add Task time control.
private struct WatchSettingsStepper: View {
    let value: String
    let decrease: () -> Void
    let increase: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            stepButton("minus", label: "Decrease", action: decrease)
            Text(value)
                .font(WatchSettingsFont.value)
                .foregroundStyle(WatchTheme.ink)
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize()
            stepButton("plus", label: "Increase", action: increase)
        }
    }

    private func stepButton(_ symbol: String, label: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(WatchTheme.primary, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Reminder switches and times. Changes reschedule notifications immediately.
struct WatchNotificationSettingsView: View {
    @Bindable private var notifications = WatchNotificationManager.shared

    var body: some View {
        List {
            if notifications.isDenied {
                Text("Notifications are off for RaceTrian. Turn them on in the Watch app on iPhone.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
                    .watchPaperRow()
            }

            Section {
                Group {
                    Toggle("Allow reminders", isOn: $notifications.isEnabled)
                        .tint(WatchTheme.primary)
                }
                .watchPaperRow()
            }

            if notifications.isEnabled {
                Section {
                    Group {
                        Toggle("Morning plan", isOn: $notifications.morningReminder)
                        if notifications.morningReminder {
                            hourPicker("Time", selection: $notifications.morningHour)
                        }
                        Toggle("Mood check-in", isOn: $notifications.moodReminder)
                        if notifications.moodReminder {
                            hourPicker("Time", selection: $notifications.moodHour)
                        }
                    }
                    .watchPaperRow()
                } header: {
                    Text("Daily").foregroundStyle(WatchTheme.muted)
                }
                .tint(WatchTheme.primary)

                Section {
                    Group {
                        Toggle("Tasks", isOn: $notifications.taskReminders)
                        Toggle("AI Board", isOn: $notifications.activityReminders)
                        Picker("Remind me", selection: $notifications.leadMinutes) {
                            Text("At start").tag(0)
                            ForEach([5, 10, 15, 30, 60], id: \.self) { minutes in
                                Text("\(minutes) min before").tag(minutes)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    }
                    .watchPaperRow()
                } header: {
                    Text("Plans").foregroundStyle(WatchTheme.muted)
                }
                .tint(WatchTheme.primary)
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Reminders")
        .task {
            await notifications.refreshAuthorization()
        }
        .onChange(of: notifications.isEnabled) { _, isEnabled in
            guard isEnabled, !notifications.isAuthorized else { return }
            Task { await notifications.requestAuthorization() }
        }
    }

    private func hourPicker(_ title: LocalizedStringKey, selection: Binding<Int>) -> some View {
        Picker(title, selection: selection) {
            ForEach(0..<24, id: \.self) { hour in
                Text(DateComponents(calendar: .current, hour: hour).date ?? Date(), format: .dateTime.hour())
                    .tag(hour)
            }
        }
        .pickerStyle(.navigationLink)
    }
}

/// Upcoming task and AI Board reminders, soonest first.
struct WatchNotificationsView: View {
    let store: WatchAppStore
    private let notifications = WatchNotificationManager.shared

    var body: some View {
        let reminders = notifications.upcomingReminders()
        List {
            if !notifications.isEnabled || notifications.isDenied {
                NavigationLink {
                    WatchNotificationSettingsView()
                } label: {
                    Label("Reminders are off", systemImage: "bell.slash.fill")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(WatchTheme.primary)
                }
                .watchPaperRow()
            }

            if reminders.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "bell")
                        .font(.system(size: 18))
                        .foregroundStyle(WatchTheme.primary)
                    Text("Nothing coming up")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Text("Tasks and AI Board activities will show here.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .watchPaperRow()
            } else {
                ForEach(reminders) { reminder in
                    HStack(spacing: 8) {
                        Image(systemName: reminder.icon)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 24, height: 24)
                            .background(WatchTheme.primary.gradient, in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reminder.title)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(WatchTheme.ink)
                                .lineLimit(2)
                            Text(reminder.startDate, format: .dateTime.weekday(.abbreviated).hour().minute())
                                .font(.system(size: 9, weight: .medium, design: .rounded))
                                .foregroundStyle(WatchTheme.muted)
                        }
                    }
                    .watchPaperRow()
                }
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Notifications")
    }
}

/// Name taken from the email (before the @), since the watch only knows the account email.
private extension WatchAccessStore {
    var displayName: String {
        guard let email, let name = email.split(separator: "@").first, !name.isEmpty else {
            return String(localized: "Guest")
        }
        return name.prefix(1).uppercased() + name.dropFirst()
    }

    var initial: String {
        String(displayName.prefix(1)).uppercased()
    }
}

/// Orange-to-yellow gradient card with white text and stats, matching the iPhone's `ProfileHeroCard`.
private struct WatchProfileHeroCard: View {
    let store: WatchAppStore
    let access: WatchAccessStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WatchProfileAvatar(access: access, size: 38)
                VStack(alignment: .leading, spacing: 2) {
                    Text(access.displayName)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(access.email ?? "")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 0)
            }

            WatchPlanBadge(isPremium: access.hasAccess)

            Rectangle()
                .fill(Color.white.opacity(0.3))
                .frame(height: 1)

            HStack(spacing: 0) {
                WatchProfileStat(value: "\(store.tasks.filter(\.isCompleted).count)", label: "Tasks done")
                Rectangle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 1, height: 26)
                WatchProfileStat(value: "🔥 \(store.currentStreak)", label: "Streak")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(WatchTheme.heroGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct WatchProfileStat: View {
    let value: String
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct WatchProfileAvatar: View {
    let access: WatchAccessStore
    let size: CGFloat

    var body: some View {
        Text(access.initial)
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color.white.opacity(0.2), in: Circle())
    }
}

private struct WatchPlanBadge: View {
    let isPremium: Bool

    var body: some View {
        Label(isPremium ? "Premium" : "Free", systemImage: isPremium ? "crown.fill" : "person.fill")
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.25), in: Capsule())
    }
}

/// Profile page: account details, plan, upgrade, and sign out.
struct WatchProfileView: View {
    let store: WatchAppStore
    let access: WatchAccessStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                WatchProfileHeroCard(store: store, access: access)

                WatchSettingsSection(title: "Account") {
                    WatchSettingsRow(title: "Email", icon: "envelope.fill", color: WatchTheme.primary) {
                        Text(access.email ?? "—")
                            .font(WatchSettingsFont.value)
                            .foregroundStyle(WatchTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                    }
                    WatchSettingsRow(title: "Plan", icon: "crown.fill", color: WatchTheme.accent) {
                        Text(access.hasAccess ? "Premium" : "Free")
                            .font(WatchSettingsFont.value)
                            .foregroundStyle(WatchTheme.muted)
                    }
                    if !access.hasAccess {
                        NavigationLink {
                            // Already signed in here, so the paywall hides its account buttons.
                            WatchPaywallView(access: access, showSignIn: {}, showCreateAccount: {})
                                .navigationTitle("Plans")
                        } label: {
                            WatchSettingsRow(title: "Upgrade to Premium", icon: "sparkles", color: WatchTheme.primary, showsChevron: true)
                        }
                        .buttonStyle(.plain)
                    }
                    Button {
                        access.signOut()
                    } label: {
                        WatchSettingsRow(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", color: .red, titleColor: .red)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Profile")
    }
}
