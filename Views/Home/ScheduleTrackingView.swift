import SwiftUI
import Charts

enum ScheduleTrackingPeriod: String, CaseIterable, Identifiable {
    case week = "Week"
    case month = "Month"
    case year = "Year"

    var id: String { rawValue }
    var component: Calendar.Component {
        switch self {
        case .week: .weekOfYear
        case .month: .month
        case .year: .year
        }
    }
}

struct ScheduleTrackingBucket: Identifiable {
    let start: Date
    let finish: Date
    var plannedHours = 0.0
    var completedHours = 0.0
    var id: Date { start }
}

enum ScheduleTrackingSummary {
    static func buckets(
        activities: [LocalScheduleActivity],
        period: ScheduleTrackingPeriod,
        date: Date,
        calendar: Calendar = .current
    ) -> [ScheduleTrackingBucket] {
        guard let interval = calendar.dateInterval(of: period.component, for: date) else { return [] }
        let step: Calendar.Component = period == .year ? .month : .day
        var cursor = interval.start
        var buckets: [ScheduleTrackingBucket] = []
        while cursor < interval.end {
            guard let next = calendar.date(byAdding: step, value: 1, to: cursor), next > cursor else { break }
            let end = min(next, interval.end)
            var bucket = ScheduleTrackingBucket(start: cursor, finish: end)
            // Clip overnight and multi-day activities to each calendar bucket.
            for activity in activities where activity.start < end && activity.finish > cursor {
                let hours = max(0, min(activity.finish, end).timeIntervalSince(max(activity.start, cursor))) / 3600
                bucket.plannedHours += hours
                if activity.completedAt != nil { bucket.completedHours += hours }
            }
            buckets.append(bucket)
            cursor = end
        }
        return buckets
    }
}

struct ScheduleTrackingView: View {
    let activities: [LocalScheduleActivity]
    let color: Color

    @State private var period: ScheduleTrackingPeriod = .week
    @State private var selectedDate = Date()
    @State private var didSelectInitialDate = false

    init(activities: [LocalScheduleActivity], color: Color, initialPeriod: ScheduleTrackingPeriod = .week) {
        self.activities = activities
        self.color = color
        _period = State(initialValue: initialPeriod)
    }

    private var buckets: [ScheduleTrackingBucket] {
        ScheduleTrackingSummary.buckets(activities: activities, period: period, date: selectedDate)
    }

    var body: some View {
        let data = buckets
        let planned = data.reduce(0) { $0 + $1.plannedHours }
        let completed = data.reduce(0) { $0 + $1.completedHours }
        VStack(alignment: .leading, spacing: 14) {
            Label("Schedule tracking", systemImage: "chart.bar.fill")
                .font(.headline)
            Picker("Tracking period", selection: $period) {
                ForEach(ScheduleTrackingPeriod.allCases) { period in
                    Text(period.rawValue).tag(period)
                }
            }
            .pickerStyle(.segmented)

            HStack {
                Button {
                    movePeriod(by: -1)
                } label: {
                    Image(systemName: "chevron.left").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Previous period")
                DatePicker("Period containing", selection: $selectedDate, displayedComponents: .date)
                    .labelsHidden()
                    .accessibilityLabel("Date in tracking period")
                Button {
                    movePeriod(by: 1)
                } label: {
                    Image(systemName: "chevron.right").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Next period")
            }
            if let first = data.first, let last = data.last {
                Text("\(first.start.formatted(date: .abbreviated, time: .omitted)) – \(last.finish.addingTimeInterval(-1).formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if planned == 0 {
                Text("No scheduled activities in this period.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Chart(data) { bucket in
                BarMark(
                    x: .value("Date", bucket.start, unit: period == .year ? .month : .day),
                    y: .value("Hours", bucket.plannedHours)
                )
                .foregroundStyle(by: .value("Status", "Planned"))
                .position(by: .value("Status", "Planned"))
                .accessibilityLabel(bucket.start.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("Planned: \(bucket.plannedHours.formatted(.number.precision(.fractionLength(1)))) hours")
                BarMark(
                    x: .value("Date", bucket.start, unit: period == .year ? .month : .day),
                    y: .value("Hours", bucket.completedHours)
                )
                .foregroundStyle(by: .value("Status", "Completed"))
                .position(by: .value("Status", "Completed"))
                .accessibilityLabel(bucket.start.formatted(date: .abbreviated, time: .omitted))
                .accessibilityValue("Completed: \(bucket.completedHours.formatted(.number.precision(.fractionLength(1)))) hours")
            }
            .chartForegroundStyleScale(["Planned": color.opacity(0.45), "Completed": color])
            .chartYAxisLabel("Hours")
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: period == .week ? 7 : 6)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: period == .year ? .dateTime.month(.abbreviated) : .dateTime.day())
                }
            }
            .chartYScale(domain: 0...max(1, data.map(\.plannedHours).max() ?? 0))
            .frame(height: 210)

            Text("\(completed.formatted(.number.precision(.fractionLength(1)))) of \(planned.formatted(.number.precision(.fractionLength(1)))) planned hours completed")
                .font(.subheadline.weight(.semibold))
            ProgressView(value: planned > 0 ? min(completed / planned, 1) : 0)
                .tint(color)
                .accessibilityLabel("Schedule completion")
            Text("Mark activities complete in the schedule. Completed hours use their scheduled duration, not a running timer.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassCard(cornerRadius: 16, tint: color)
        .onAppear {
            guard !didSelectInitialDate else { return }
            didSelectInitialDate = true
            selectedDate = activities.first?.start ?? Date()
        }
    }

    private func movePeriod(by value: Int) {
        if let next = Calendar.current.date(byAdding: period.component, value: value, to: selectedDate) {
            selectedDate = next
        }
    }
}
