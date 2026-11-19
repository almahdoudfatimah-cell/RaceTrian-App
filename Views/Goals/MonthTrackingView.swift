import SwiftUI

enum GoalTrackingCalendar {
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = Calendar.current.firstWeekday
        return calendar
    }

    // Store calendar dates, not timestamps, so travel does not shift a check-in.
    static func dayKey(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

struct YearTrackingView: View {
    @State private var displayedYear = GoalTrackingCalendar.calendar.component(.year, from: Date())
    @AppStorage("goals.trackedDays") private var trackedDays = ""

    private var completedDays: Set<String> {
        Set(trackedDays.split(separator: ",").map(String.init))
    }

    private var months: [Date] {
        (1...12).compactMap {
            GoalTrackingCalendar.calendar.date(from: DateComponents(year: displayedYear, month: $0, day: 1))
        }
    }

    private var yearCount: Int {
        completedDays.filter { $0.hasPrefix(String(format: "%04d-", displayedYear)) }.count
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 14) {
                HStack {
                    Button {
                        displayedYear -= 1
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Previous year")

                    Spacer()
                    Text(String(displayedYear))
                        .font(.title2.bold())
                    Spacer()

                    Button {
                        displayedYear += 1
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Next year")
                }
                .tint(Theme.primary)

                Label("\(yearCount) days tracked", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(Theme.primary)
                Text("Tap a day to track your progress or remove a check-in. Goal check-ins also mark today.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Current Year") {
                    displayedYear = GoalTrackingCalendar.calendar.component(.year, from: Date())
                }
            }
            .padding(16)
            .glassCard(cornerRadius: 22)

            LazyVStack(spacing: 16) {
                ForEach(months, id: \.self) { month in
                    YearMonthCard(month: month, completedDays: completedDays, onToggle: toggle)
                }
            }
        }
    }

    private func toggle(_ date: Date) {
        guard date <= GoalTrackingCalendar.calendar.startOfDay(for: Date()) else { return }
        let key = GoalTrackingCalendar.dayKey(date)
        var days = completedDays
        if days.contains(key) {
            days.remove(key)
        } else {
            days.insert(key)
        }
        trackedDays = days.sorted().joined(separator: ",")
    }
}

private struct YearMonthCard: View {
    let month: Date
    let completedDays: Set<String>
    let onToggle: (Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 3), count: 7)
    private var calendar: Calendar { GoalTrackingCalendar.calendar }

    private var days: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        return range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
    }

    private var leadingSpaces: Int {
        (calendar.component(.weekday, from: month) - calendar.firstWeekday + 7) % 7
    }

    private var weekdayNames: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(month, format: .dateTime.month(.wide))
                    .font(.headline)
                Spacer()
                Text("\(days.filter { completedDays.contains(GoalTrackingCalendar.dayKey($0)) }.count) tracked")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 5) {
                ForEach(0..<7, id: \.self) { index in
                    Text(weekdayNames[index])
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<leadingSpaces, id: \.self) { _ in
                    Color.clear.frame(height: 44)
                }
                ForEach(days, id: \.self) { date in
                    dayButton(date)
                }
            }
        }
        .padding(14)
        .glassCard(cornerRadius: 22)
    }

    private func dayButton(_ date: Date) -> some View {
        let isTracked = completedDays.contains(GoalTrackingCalendar.dayKey(date))
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > calendar.startOfDay(for: Date())
        return Button {
            onToggle(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(.caption.weight(isToday ? .bold : .medium))
                Image(systemName: isTracked ? "checkmark" : "circle")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(isTracked ? 1 : 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .foregroundStyle(isTracked ? Color.white : Color.primary)
            .background(isTracked ? Theme.primary : Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isToday ? Theme.primary : .clear, lineWidth: 2)
            }
            .opacity(isFuture ? 0.35 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue(isTracked ? "Tracked" : "Not tracked")
        .accessibilityHint(isFuture ? "Future date" : "Double tap to change check-in")
    }
}
