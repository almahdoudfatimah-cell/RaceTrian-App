import SwiftUI

public struct PlanView: View {
    @State private var selectedDate = Date()
    @ObservedObject private var store = WeekTaskStore.shared
    @State private var showAddTask = false
    @State private var mode: Mode = .week

    public enum Mode: String, CaseIterable, Identifiable {
        case week = "Week", day = "Day"
        public var id: String { rawValue }
    }

    public init() {}

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Picker("Plan view", selection: $mode) {
                        Text("Week").tag(Mode.week)
                        Text("Day").tag(Mode.day)
                    }
                    .pickerStyle(.segmented)
                    dateNavigation
                }
                .padding(.horizontal)
                .padding(.top, 8)

                planContent
            }
            .background { PaperBackground() }
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.primary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") { selectedDate = Date() }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    showAddTask = true
                } label: {
                    Label("Add task", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showAddTask) {
                AddTaskSheet(tasks: taskBinding, date: selectedDate)
                    .presentationDetents([.large])
            }

        }
        .appPageTheme()
    }


    private var taskBinding: Binding<[PlanTask]> {
        Binding(
            get: { store.tasks(for: selectedDate) },
            set: { updatedTasks in
                store.saveTasks(updatedTasks, for: selectedDate)
            }
        )
    }

    private var planContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if mode == .week {
                    PlannerWeekOverview(days: weekDays, store: store) { day in
                        selectedDate = day
                        mode = .day
                    }
                } else {
                    PlannerDayHeading(date: selectedDate, tasks: store.tasks(for: selectedDate))
                    TimelineView(tasks: taskBinding, selectedDate: $selectedDate)
                }
                HabitsTrackerSticker(days: weekDays)
                PlannerNotesSection()
            }
            .padding()
        }
    }

    private var dateNavigation: some View {
        HStack {
                        Button { move(-1) } label: {
                            Image(systemName: "chevron.left").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(mode == .week ? "Previous week" : "Previous day")
                        DatePicker("Plan date", selection: $selectedDate, displayedComponents: .date)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("Plan date")
                        Button { move(1) } label: {
                            Image(systemName: "chevron.right").frame(width: 44, height: 44)
                        }
                        .accessibilityLabel(mode == .week ? "Next week" : "Next day")
                    }
    }

    private func move(_ direction: Int) {
        selectedDate = Calendar.current.date(
            byAdding: .day, value: direction * (mode == .week ? 7 : 1), to: selectedDate
        ) ?? selectedDate
    }
}

private struct PlannerWeekOverview: View {
    let days: [Date]
    let store: WeekTaskStore
    let onOpenDay: (Date) -> Void

    var body: some View {
        let tasks = days.flatMap { store.tasks(for: $0) }
        let completed = tasks.filter(\.isDone).count
        VStack(alignment: .leading, spacing: 14) {
            Text("Week overview").font(.title2.bold())
            if let first = days.first, let last = days.last {
                Text("\(first.formatted(date: .abbreviated, time: .omitted)) – \(last.formatted(date: .abbreviated, time: .omitted))")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(completed), total: Double(max(1, tasks.count)))
            Text("\(completed) of \(tasks.count) tasks completed").font(.subheadline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 155), spacing: 12)], spacing: 12) {
                ForEach(days, id: \.self) { day in
                    PlannerDayCard(date: day, tasks: store.tasks(for: day)) { onOpenDay(day) }
                }
            }
        }
    }
}

private struct PlannerDayCard: View {
    let date: Date
    let tasks: [PlanTask]
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 10) {
                Text(date, format: .dateTime.weekday(.wide))
                    .font(.headline)
                Text(date, format: .dateTime.month(.abbreviated).day())
                    .font(.subheadline).foregroundStyle(.secondary)
                if tasks.isEmpty {
                    Text("No tasks planned").font(.subheadline).foregroundStyle(.secondary)
                }
                ForEach(tasks.prefix(3)) { task in
                    Label(task.title, systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.subheadline)
                        .lineLimit(2)
                }
                if tasks.count > 3 {
                    Text("+\(tasks.count - 3) more").font(.caption)
                }
                Text("\(tasks.filter(\.isDone).count)/\(tasks.count) complete")
                    .font(.caption.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .padding()
            .background(Theme.primary.opacity(Calendar.current.isDateInToday(date) ? 0.15 : 0.06),
                        in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Theme.primary.opacity(Calendar.current.isDateInToday(date) ? 0.6 : 0.15))
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open this day's tasks")
    }
}

private struct PlannerDayHeading: View {
    let date: Date
    let tasks: [PlanTask]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(date, format: .dateTime.weekday(.wide).month(.wide).day())
                .font(.title2.bold())
            Text("\(tasks.filter(\.isDone).count) of \(tasks.count) tasks completed")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct PlannerNotesSection: View {
    @ObservedObject private var store = NotesStore.shared
    @State private var addingNote = false
    @State private var editingNote: Note?

    private var recentNotes: [Note] {
        Array(store.notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }.prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Your notes", systemImage: "note.text").font(.headline)
                Spacer()
                Button { addingNote = true } label: {
                    Image(systemName: "plus").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Add note")
            }
            Text("Shared between Home and Plan.")
                .font(.caption).foregroundStyle(.secondary)
            if recentNotes.isEmpty {
                Text("Keep your ideas, reminders, and planning notes here.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            ForEach(recentNotes) { note in
                Button { editingNote = note } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(note.title.isEmpty ? "Untitled note" : note.title).font(.headline)
                        Text(note.body).font(.subheadline).lineLimit(3).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(note.color.cardBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            NavigationLink { NotesView() } label: {
                Label("All notes", systemImage: "note.text")
            }
        }
        .padding()
        .glassCard(cornerRadius: 16, tint: Theme.primary)
        .sheet(isPresented: $addingNote) { NoteEditorView(note: nil, store: store) }
        .sheet(item: $editingNote) { note in NoteEditorView(note: note, store: store) }
    }
}

#Preview { PlanView() }
