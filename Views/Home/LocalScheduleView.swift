import SwiftUI

struct LocalScheduleActivity: Identifiable, Codable {
    var id = UUID()
    var activity = ""
    var start = Date()
    var finish = Date().addingTimeInterval(3600)
    var completedAt: Date? = nil
}

struct LocalScheduleView: View {
    let title: LocalizedStringResource
    let color: Color
    let category: String
    let opensActivityEditor: Bool
    @State private var didOpenActivityEditor = false

    @Environment(\.dismiss) private var dismiss
    @AppStorage("homeScheduleCategory") private var homeScheduleCategory = ""
    @AppStorage private var savedSchedule: Data
    @State private var scheduleDate = Date()
    @State private var activities: [LocalScheduleActivity] = []
    @State private var editingActivity: LocalScheduleActivity?
    @State private var storageError: String?
    @State private var showingGenerator = false
    @State private var selectedSection: ScheduleSection = .schedule

    private enum ScheduleSection {
        case schedule, charts
    }

    private var initialChartPeriod: ScheduleTrackingPeriod {
        switch category {
        case "monthly": .month
        case "raceVision": .year
        default: .week
        }
    }

    init(title: LocalizedStringResource, storageKey: String, category: String, color: Color, opensActivityEditor: Bool = false) {
        self.title = title
        self.category = category
        self.color = color
        self.opensActivityEditor = opensActivityEditor
        _savedSchedule = AppStorage(wrappedValue: Data(), storageKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Schedule section", selection: $selectedSection) {
                    Text("Schedule").tag(ScheduleSection.schedule)
                    Text("Charts").tag(ScheduleSection.charts)
                }
                .pickerStyle(.segmented)

                if selectedSection == .charts {
                    ScheduleTrackingView(
                        activities: activities,
                        color: color,
                        initialPeriod: initialChartPeriod
                    )
                    Button {
                        showingGenerator = true
                    } label: {
                        Label("Create schedule", systemImage: "calendar.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        selectedSection = .schedule
                    } label: {
                        Label("Go to schedule", systemImage: "calendar")
                            .frame(maxWidth: .infinity, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                } else {
                    scheduleContent
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ScheduleActivityFooter(color: color) {
                let day = category == "weekend"
                    ? ScheduleDateDefaults.range(category: "weekend", date: scheduleDate).lowerBound
                    : scheduleDate
                let selectedStart = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
                let start = ["monthly", "weekend", "raceVision"].contains(category)
                    ? selectedStart : activities.last?.finish ?? selectedStart
                editingActivity = LocalScheduleActivity(
                    start: start,
                    finish: start.addingTimeInterval(3600)
                )
            }
        }
        .background { PaperBackground() }
        .tint(color)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            load()
            if opensActivityEditor && !didOpenActivityEditor {
                didOpenActivityEditor = true
                editingActivity = LocalScheduleActivity()
            }
        }
        .onChange(of: savedSchedule) {
            // Picks up edits made from the Apple Watch while this board is open.
            load()
        }
        .sheet(item: $editingActivity) { item in
            LocalScheduleEditor(activity: item, color: color) { updated in
                var updatedActivities = activities
                if let index = updatedActivities.firstIndex(where: { $0.id == updated.id }) {
                    updatedActivities[index] = updated
                } else {
                    updatedActivities.append(updated)
                }
                save(updatedActivities)
            }
        }
        .sheet(isPresented: $showingGenerator) {
            OfflineScheduleForm(category: category, color: color, replacesExisting: !activities.isEmpty) { generated in
                if save(generated) {
                    homeScheduleCategory = category
                    scheduleDate = generated.first?.start ?? Date()
                    selectedSection = .schedule
                }
            }
        }
        .alert("Schedule could not be saved", isPresented: Binding(
            get: { storageError != nil },
            set: { if !$0 { storageError = nil } }
        )) {
            Button("OK", role: .cancel) { storageError = nil }
        } message: {
            Text(storageError ?? "")
        }
    }

    @ViewBuilder
    private var scheduleContent: some View {
        Button {
            showingGenerator = true
        } label: {
            Label("Create full schedule", systemImage: "calendar.badge.clock")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(color)

        if category == "weekly" {
            if activities.isEmpty {
                ContentUnavailableView(
                    "No activities yet", systemImage: "calendar",
                    description: Text("Create a full schedule or add your own activities.")
                )
            } else {
                scheduleTable
            }
        } else {
            CategoryScheduleContent(
                category: category,
                activities: activities,
                color: color,
                selectedDate: $scheduleDate,
                onEdit: { editingActivity = $0 },
                onToggle: { item in
                    var updated = activities
                    if let index = updated.firstIndex(where: { $0.id == item.id }) {
                        updated[index].completedAt = item.completedAt == nil ? Date() : nil
                        save(updated)
                    }
                },
                onDelete: { item in save(activities.filter { $0.id != item.id }) }
            )
        }


    }

    private var scheduleTable: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 12) {
            GridRow {
                Text("Time")
                Text("Activity")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(.headline)
            .foregroundStyle(.primary)

            Divider().gridCellUnsizedAxes(.horizontal)

            ForEach(activities) { item in
                GridRow(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.start, format: .dateTime.month(.abbreviated).day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.start, style: .time)
                        Text("to")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !Calendar.current.isDate(item.start, inSameDayAs: item.finish) {
                            Text(item.finish, format: .dateTime.month(.abbreviated).day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(item.finish, style: .time)
                    }
                    .monospacedDigit()
                    .accessibilityElement(children: .combine)

                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            var updated = activities
                            if let index = updated.firstIndex(where: { $0.id == item.id }) {
                                updated[index].completedAt = item.completedAt == nil ? Date() : nil
                                save(updated)
                            }
                        } label: {
                            Label(item.completedAt == nil ? "Mark complete" : "Completed",
                                  systemImage: item.completedAt == nil ? "circle" : "checkmark.circle.fill")
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(item.completedAt == nil ? "Mark complete" : "Mark incomplete"): \(item.activity)")
                        Text(item.activity)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Menu {
                            Button("Edit", systemImage: "pencil") { editingActivity = item }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                save(activities.filter { $0.id != item.id })
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Options for \(item.activity)")
                    }
                }
                Divider().gridCellUnsizedAxes(.horizontal)
            }
        }
        .font(.body)
        .padding()
        .glassCard(cornerRadius: 16, tint: color)
    }

    private func load() {
        guard !savedSchedule.isEmpty else {
            scheduleDate = ScheduleDateDefaults.range(category: category).lowerBound
            return
        }
        do {
            activities = try JSONDecoder().decode([LocalScheduleActivity].self, from: savedSchedule)
                .sorted { $0.start < $1.start }
            scheduleDate = activities.first?.start ?? ScheduleDateDefaults.range(category: category).lowerBound
        } catch {
            storageError = "The saved schedule could not be read."
        }
    }

    @discardableResult
    private func save(_ updated: [LocalScheduleActivity]) -> Bool {
        do {
            let sorted = updated.sorted { $0.start < $1.start }
            savedSchedule = try JSONEncoder().encode(sorted)
            activities = sorted
            NotificationCenter.default.post(name: .watchSyncSourceDidChange, object: nil)
            return true
        } catch {
            storageError = "Please try saving your activity again."
            return false
        }
    }
}


private struct ScheduleActivityFooter: View {
    let color: Color
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            Button(action: onAdd) {
                Label("Add activity", systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
    }
}

enum ScheduleDateDefaults {
    static func range(category: String, date: Date = Date(), calendar: Calendar = .current) -> ClosedRange<Date> {
        let today = calendar.startOfDay(for: date)
        var start = today
        var days = 1
        switch category {
        case "monthly", "raceVision":
            let component: Calendar.Component = category == "monthly" ? .month : .year
            if let interval = calendar.dateInterval(of: component, for: today),
               let end = calendar.date(byAdding: .day, value: -1, to: interval.end) {
                return interval.start...end
            }
        case "weekend":
            // Respect the person's calendar, including Friday–Saturday weekends.
            if let interval = calendar.dateIntervalOfWeekend(containing: today)
                ?? calendar.nextWeekend(startingAfter: today),
               let end = calendar.date(byAdding: .day, value: -1, to: interval.end) {
                start = interval.start
                return start...max(start, end)
            }
            days = 2
        case "vacation", "weekly", "training": days = 7
        case "travel": days = 3
        default: break
        }
        return start...(calendar.date(byAdding: .day, value: days - 1, to: start) ?? start)
    }
}

private struct ScheduleDayGroup: Identifiable {
    let date: Date
    let activities: [LocalScheduleActivity]
    var id: Date { date }
}

private struct CategoryScheduleContent: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let category: String
    let activities: [LocalScheduleActivity]
    let color: Color
    @Binding var selectedDate: Date
    let onEdit: (LocalScheduleActivity) -> Void
    let onToggle: (LocalScheduleActivity) -> Void
    let onDelete: (LocalScheduleActivity) -> Void

    private var days: [ScheduleDayGroup] {
        Dictionary(grouping: activities) { Calendar.current.startOfDay(for: $0.start) }
            .map { ScheduleDayGroup(date: $0.key, activities: $0.value.sorted { $0.start < $1.start }) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            switch category {
            case "monthly":
                Label("Monthly calendar", systemImage: "calendar")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                DatePicker("Choose a day", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .dynamicTypeSize(dynamicTypeSize.isAccessibilitySize ? dynamicTypeSize : .small)
                ScheduleDayPanel(
                    date: selectedDate, activities: activitiesOnDay(selectedDate), color: color,
                    onEdit: onEdit, onToggle: onToggle, onDelete: onDelete
                )
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
            case "weekend":
                Label("Weekend agenda", systemImage: "sun.max.fill").font(.title2.bold())
                Text("Balance your activities, personal time, and rest.")
                    .foregroundStyle(.secondary)
                DatePicker("Weekend containing or after", selection: $selectedDate, displayedComponents: .date)
                let range = ScheduleDateDefaults.range(category: "weekend", date: selectedDate)
                let weekendDays = Calendar.current.dateComponents([.day], from: range.lowerBound, to: range.upperBound).day ?? 1
                let dates = (0...weekendDays).compactMap {
                    Calendar.current.date(byAdding: .day, value: $0, to: range.lowerBound)
                }
                ForEach(dates, id: \.self) { day in
                    ScheduleDayPanel(
                        date: day, activities: activitiesOnDay(day), color: color,
                        onEdit: onEdit, onToggle: onToggle, onDelete: onDelete
                    )
                }
            case "vacation":
                Label("Vacation day planner", systemImage: "beach.umbrella.fill").font(.title2.bold())
                Text("Explore each day of your holiday, with space for activities and downtime.")
                    .foregroundStyle(.secondary)
                if days.isEmpty {
                    ContentUnavailableView("Plan your holiday", systemImage: "beach.umbrella",
                                           description: Text("Create a vacation schedule to see each day's activities here."))
                }
                ForEach(days) { day in
                    DisclosureGroup {
                        ScheduleActivityCards(activities: day.activities, color: color,
                                              onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(day.date, format: .dateTime.weekday(.wide).month().day())
                            Text("\(day.activities.count) activities").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .glassCard(cornerRadius: 16, tint: color)
                }
            case "travel":
                Label("Travel itinerary", systemImage: "airplane").font(.title2.bold())
                Text("Your departures, arrivals, and stops in chronological order. Times use your device's time zone.")
                    .foregroundStyle(.secondary)
                if days.isEmpty {
                    ContentUnavailableView("Build your itinerary", systemImage: "airplane",
                                           description: Text("Add journeys, check-ins, and destination activities with their confirmed times."))
                }
                ForEach(days) { day in
                    ScheduleDayPanel(date: day.date, activities: day.activities, color: color,
                                     onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
                }
            case "training":
                Label("Training sessions", systemImage: "figure.run").font(.title2.bold())
                let hours = activities.reduce(0) { $0 + max(0, $1.finish.timeIntervalSince($1.start)) / 3600 }
                Text("\(activities.count) sessions · \(hours.formatted(.number.precision(.fractionLength(1)))) planned hours")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("Review session duration and mark each workout complete.")
                    .foregroundStyle(.secondary)
                ScheduleActivityCards(activities: activities, color: color,
                                      onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
            case "achievement":
                Label("Achievement milestones", systemImage: "flag.fill").font(.title2.bold())
                let completed = activities.filter { $0.completedAt != nil }
                let remaining = activities.filter { $0.completedAt == nil }
                ProgressView(value: Double(completed.count), total: Double(max(1, activities.count)))
                Text("\(completed.count) of \(activities.count) milestones completed")
                    .font(.subheadline)
                Text("Next milestones").font(.headline)
                ScheduleActivityCards(activities: remaining, color: color,
                                      onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
                if !completed.isEmpty {
                    DisclosureGroup("Completed milestones") {
                        ScheduleActivityCards(activities: completed, color: color,
                                              onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
                    }
                }
            case "raceVision":
                YearRaceSchedule(activities: activities, color: color, selectedDate: $selectedDate,
                                 onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
            default:
                ScheduleActivityCards(activities: activities, color: color,
                                      onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
            }
        }
    }

    private func activitiesOnDay(_ date: Date) -> [LocalScheduleActivity] {
        guard let interval = Calendar.current.dateInterval(of: .day, for: date) else { return [] }
        // Include overnight activities on every day they touch.
        return activities.filter { $0.start < interval.end && $0.finish > interval.start }
    }
}

private struct ScheduleDayPanel: View {
    let date: Date
    let activities: [LocalScheduleActivity]
    let color: Color
    let onEdit: (LocalScheduleActivity) -> Void
    let onToggle: (LocalScheduleActivity) -> Void
    let onDelete: (LocalScheduleActivity) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(date, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                .font(.headline)
            ScheduleActivityCards(activities: activities, color: color,
                                  onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
        }
        .padding()
        .glassCard(cornerRadius: 16, tint: color)
    }
}

private struct ScheduleActivityCards: View {
    let activities: [LocalScheduleActivity]
    let color: Color
    let onEdit: (LocalScheduleActivity) -> Void
    let onToggle: (LocalScheduleActivity) -> Void
    let onDelete: (LocalScheduleActivity) -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 12) {
            if activities.isEmpty {
                Text("Nothing scheduled yet. Add an activity or create a schedule.")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 12)
            }
            ForEach(activities) { item in
                VStack(alignment: .leading, spacing: 10) {
                    Text(item.start, format: .dateTime.month(.abbreviated).day().hour().minute())
                        .font(.subheadline.weight(.semibold))
                    Text("Until \(item.finish.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(item.activity)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(Int(max(0, item.finish.timeIntervalSince(item.start)) / 60)) min")
                        .font(.caption.weight(.semibold))
                    HStack {
                        Button {
                            onToggle(item)
                        } label: {
                            Label(item.completedAt == nil ? "Mark complete" : "Completed",
                                  systemImage: item.completedAt == nil ? "circle" : "checkmark.circle.fill")
                        }
                        .accessibilityLabel("\(item.completedAt == nil ? "Mark complete" : "Mark incomplete"): \(item.activity)")
                        Spacer()
                        Menu {
                            Button("Edit", systemImage: "pencil") { onEdit(item) }
                            Button("Delete", systemImage: "trash", role: .destructive) { onDelete(item) }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .accessibilityLabel("Options for \(item.activity)")
                    }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct YearRaceSchedule: View {
    let activities: [LocalScheduleActivity]
    let color: Color
    @Binding var selectedDate: Date
    let onEdit: (LocalScheduleActivity) -> Void
    let onToggle: (LocalScheduleActivity) -> Void
    let onDelete: (LocalScheduleActivity) -> Void

    private var months: [Date] {
        guard let interval = Calendar.current.dateInterval(of: .year, for: selectedDate) else { return [] }
        return (0..<12).compactMap { Calendar.current.date(byAdding: .month, value: $0, to: interval.start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Year race calendar", systemImage: "flag.checkered").font(.title2.bold())
            HStack {
                Button {
                    moveYear(-1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous year")
                Spacer()
                Text(selectedDate, format: .dateTime.year()).font(.title3.bold())
                Spacer()
                Button {
                    moveYear(1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next year")
            }
            Text("Organize race dates and preparation milestones by month.")
                .foregroundStyle(.secondary)
            ForEach(months, id: \.self) { month in
                let items = activities.filter { Calendar.current.isDate($0.start, equalTo: month, toGranularity: .month) }
                DisclosureGroup {
                    ScheduleActivityCards(activities: items, color: color,
                                          onEdit: onEdit, onToggle: onToggle, onDelete: onDelete)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(month, format: .dateTime.month(.wide)).font(.headline)
                        Text("\(items.count) races / milestones").font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .glassCard(cornerRadius: 16, tint: color)
            }
        }
    }

    private func moveYear(_ offset: Int) {
        selectedDate = Calendar.current.date(byAdding: .year, value: offset, to: selectedDate) ?? selectedDate
    }
}

private struct LocalScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var activity: LocalScheduleActivity
    let color: Color
    let onSave: (LocalScheduleActivity) -> Void

    init(activity: LocalScheduleActivity, color: Color, onSave: @escaping (LocalScheduleActivity) -> Void) {
        _activity = State(initialValue: activity)
        self.color = color
        self.onSave = onSave
    }

    private var canSave: Bool {
        !activity.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && activity.finish > activity.start
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Write the full activity", text: $activity.activity, axis: .vertical)
                        .lineLimit(4...12)
                    ScheduleVoiceInput(text: $activity.activity) { transcript in
                        if let interval = SpokenScheduleDates.interval(in: transcript) {
                            activity.start = interval.start
                            activity.finish = interval.end
                        }
                    }
                    Text("Speak the activity and its times, then review the text and dates before saving.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)
                Section("Time") {
                    DatePicker("Start time", selection: $activity.start, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Finish time", selection: $activity.finish, displayedComponents: [.date, .hourAndMinute])
                    if activity.finish <= activity.start {
                        Text("Finish time must be after start time.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .navigationTitle("Schedule activity")
            .navigationBarTitleDisplayMode(.inline)
            .tint(color)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        activity.activity = activity.activity.trimmingCharacters(in: .whitespacesAndNewlines)
                        onSave(activity)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }
}
