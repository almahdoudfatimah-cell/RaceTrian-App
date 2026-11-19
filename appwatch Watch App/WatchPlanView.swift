import SwiftUI

/// Plan tab: the current week's tasks grouped by day, like the iPhone's Plan week view.
struct WatchPlanView: View {
    let store: WatchAppStore
    @State private var showingAddTask = false

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? calendar.startOfDay(for: Date())
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(weekDays, id: \.self) { day in
                    WatchPlanDaySection(store: store, day: day)
                }
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Plan")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                }
                .tint(WatchTheme.primary)
            }
        }
        .sheet(isPresented: $showingAddTask) {
            AddWatchTaskView(store: store)
        }
    }
}

/// One day of the week: a header with the done count, then tappable task rows.
private struct WatchPlanDaySection: View {
    let store: WatchAppStore
    let day: Date

    private var tasks: [WatchTask] {
        store.tasks
            .filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: day) }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    private var doneCount: Int {
        tasks.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(day, format: .dateTime.weekday(.abbreviated).day())
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Calendar.current.isDateInToday(day) ? WatchTheme.primary : WatchTheme.ink)
                Spacer()
                Text("\(doneCount)/\(tasks.count)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
            }
            .padding(.horizontal, 4)

            if tasks.isEmpty {
                Text("No tasks planned")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
                    .padding(.horizontal, 4)
            } else {
                ForEach(tasks) { task in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            store.toggleTask(id: task.id)
                        }
                    } label: {
                        WatchTaskRow(title: task.title, time: task.scheduledDate, isCompleted: task.isCompleted)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
