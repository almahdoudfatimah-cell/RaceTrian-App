import SwiftUI

enum OfflineScheduleGenerator {
    static func activities(category: String, focus: String, start: Date, finish: Date) -> [LocalScheduleActivity] {
        let minutes = Int(finish.timeIntervalSince(start) / 60)
        guard minutes >= 15 else { return [] }
        let descriptions = template(category: category)
        let weights = [10, 25, 10, 25, 20, 10]
        var elapsed = 0
        return descriptions.enumerated().map { index, description in
            let rowStart = start.addingTimeInterval(Double(elapsed) * 60)
            elapsed += minutes * weights[index] / 100
            let rowFinish = index == descriptions.count - 1
                ? finish : start.addingTimeInterval(Double(elapsed) * 60)
            let detail = index == 1 && !focus.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? description + "\nYour focus: " + focus.trimmingCharacters(in: .whitespacesAndNewlines)
                : description
            return LocalScheduleActivity(activity: detail, start: rowStart, finish: rowFinish)
        }
    }

    private static func template(category: String) -> [String] {
        let preparation: String
        let first: String
        let second: String
        let recovery: String
        switch category {
        case "weekend":
            preparation = "Review your weekend commitments, choose a manageable personal task, and prepare what you need before starting."
            first = "Complete your chosen personal task. Work through one step at a time and leave optional errands for another day."
            second = "Make time for family, friends, or a hobby. Choose one enjoyable activity and keep this block free from work."
            recovery = "Take an unhurried meal or quiet rest. Add a gentle walk if you feel like moving."
        case "vacation":
            preparation = "Check the day's reservations, opening hours, weather, and transport options. Pack water and essentials."
            first = "Enjoy your main sightseeing or holiday activity. Allow time for travel and queues, and pause whenever you need a rest."
            second = "Explore a nearby attraction or spend time on your preferred leisure activity. Keep the pace comfortable and flexible."
            recovery = "Pause for a meal and downtime. Review your energy before deciding whether to continue exploring."
        case "travel":
            preparation = "Check tickets, documents, luggage, and route details. Confirm actual departure times before leaving."
            first = "Use this block for your planned journey or destination activity. Adjust it to your confirmed transport times."
            second = "Settle in, organize belongings, and explore the local area. Check the route and arrangements for your next stop."
            recovery = "Take a meal and rest after travel. Leave extra time for delays and avoid rushing between commitments."
        case "training":
            preparation = "Check how you feel, prepare your equipment, and warm up gently. Choose an effort appropriate to your current fitness."
            first = "Practice your chosen sport at a comfortable effort with regular breaks. Use any remaining time to rest and record the session."
            second = "Review technique and practice easy skills only if recovered. Otherwise use this block for recovery and equipment preparation."
            recovery = "Cool down gently, hydrate, eat as needed, and record how the session felt. Stop exercise if you feel pain or unwell."
        case "achievement":
            preparation = "Define the outcome for this session, divide it into small steps, and prepare the materials you need."
            first = "Work on your most important milestone. Use focused work intervals with short pauses and note what you complete."
            second = "Continue with the next manageable step. Check your result against the goal and resolve the most important remaining issue."
            recovery = "Step away from the task, rest, and eat or stretch as needed before reviewing your progress."
        case "raceVision":
            preparation = "Review target races, confirmed dates, and your current fitness. Identify one realistic planning priority."
            first = "Research the requirements of your next event and map the preparation milestones. Keep unconfirmed events clearly marked."
            second = "Organize training and recovery commitments around those milestones. Make notes of questions to discuss with your coach."
            recovery = "Take a break, then check whether the plan leaves enough time for recovery, travel, and personal commitments."
        case "monthly":
            preparation = "Review this month's goals and upcoming deadlines. Select one milestone to move forward today."
            first = "Work through the next concrete step of your monthly milestone. Keep notes on progress and any blockers."
            second = "Continue the milestone or handle an important supporting task. Adjust the workload to the time available."
            recovery = "Take a proper break for food, rest, or light movement before checking your progress."
        default:
            preparation = "Review your commitments and choose today's main priority. Gather the materials you need and remove distractions."
            first = "Work on your highest-priority task in focused intervals. Take short pauses as needed and record the steps you finish."
            second = "Continue your priority or complete a supporting task. Keep the workload realistic and leave unfinished items for the next session."
            recovery = "Take time for a meal, rest, or gentle movement. Give yourself a break from focused work."
        }
        return [
            preparation, first,
            "Pause for a break. Drink water, move gently if comfortable, and return when you feel ready.",
            second, recovery,
            "Review what you completed, record anything still outstanding, and prepare the next steps before the schedule finishes."
        ]
    }
}

struct OfflineScheduleForm: View {
    let category: String
    let color: Color
    let replacesExisting: Bool
    let onCreate: ([LocalScheduleActivity]) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var firstDay = Calendar.current.startOfDay(for: Date())
    @State private var lastDay = Calendar.current.startOfDay(for: Date())
    @State private var startTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var finishTime = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var focus = ""
    @State private var confirmingReplacement = false

    init(category: String, color: Color, replacesExisting: Bool, onCreate: @escaping ([LocalScheduleActivity]) -> Void) {
        self.category = category
        self.color = color
        self.replacesExisting = replacesExisting
        self.onCreate = onCreate
        let range = ScheduleDateDefaults.range(category: category)
        _firstDay = State(initialValue: range.lowerBound)
        _lastDay = State(initialValue: range.upperBound)
        let start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: range.lowerBound) ?? range.lowerBound
        _startTime = State(initialValue: start)
        let hours = ["training", "achievement", "raceVision"].contains(category) ? 1 : 8
        _finishTime = State(initialValue: start.addingTimeInterval(Double(hours) * 3600))
    }

    private var dateGuidance: LocalizedStringResource {
        switch category {
        case "monthly": "Starts with the full current month. Choose the days you want to plan."
        case "weekend": "Starts with your current or next local weekend. Adjust the dates if needed."
        case "vacation": "Choose your holiday arrival and departure dates. Each day has its own plan."
        case "travel": "Choose your trip dates. Edit the itinerary to match confirmed departures and arrivals."
        case "training": "Creates one training session per day. Remove sessions to make room for recovery."
        case "achievement": "Creates one milestone per day in your chosen range."
        case "raceVision": "Creates one planning milestone per month. Add confirmed races separately."
        default: "Choose the dates for your schedule."
        }
    }

    private var dayCount: Int {
        (Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: firstDay),
                                        to: Calendar.current.startOfDay(for: lastDay)).day ?? -1) + 1
    }

    private func time(_ value: Date, on day: Date) -> Date {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: value)
        return Calendar.current.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0,
                                     second: 0, of: day) ?? day
    }

    private var valid: Bool {
        dayCount > 0 && dayCount <= 366
            && time(finishTime, on: firstDay).timeIntervalSince(time(startTime, on: firstDay)) >= 900
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    DatePicker("First day", selection: $firstDay, displayedComponents: .date)
                    DatePicker("Last day", selection: $lastDay, in: firstDay..., displayedComponents: .date)
                } header: {
                    Text("Schedule dates")
                } footer: {
                    Text(dateGuidance)
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)

                Section {
                    DatePicker("Start time", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("Finish time", selection: $finishTime, displayedComponents: .hourAndMinute)
                    if !valid {
                        Text("Choose up to 366 days and a finish time at least 15 minutes after the start time on the same day.")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Daily time range")
                } footer: {
                    Text(category == "raceVision"
                         ? "Each monthly planning milestone uses this time range."
                         : ["training", "achievement"].contains(category)
                            ? "Each session or milestone uses this time range."
                            : "Each selected day will be filled between these times, including breaks.")
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)

                Section("Your focus (optional)") {
                    TextField("What would you like to work on?", text: $focus, axis: .vertical)
                        .lineLimit(2...5)
                    ScheduleVoiceInput(text: $focus)
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)

                Section {
                    Button("Create full schedule") {
                        if replacesExisting { confirmingReplacement = true } else { create() }
                    }
                    .disabled(!valid)
                } footer: {
                    Text("Uses a built-in template. You can edit every activity and time afterward.")
                }
                .listRowBackground(scheme == .dark ? Theme.surfaceDark : Theme.surface)
            }
            .scrollContentBackground(.hidden)
            .background { PaperBackground() }
            .navigationTitle("Create full schedule")
            .navigationBarTitleDisplayMode(.inline)
            .tint(color)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .confirmationDialog("Replace the saved schedule in this section?", isPresented: $confirmingReplacement,
                                titleVisibility: .visible) {
                Button("Replace schedule", role: .destructive) { create() }
            } message: {
                Text("Your existing activities in this section will be replaced.")
            }
        }
    }

    private func create() {
        guard valid else { return }
        var rows: [LocalScheduleActivity] = []
        for offset in 0..<dayCount {
            guard let day = Calendar.current.date(byAdding: .day, value: offset, to: firstDay) else { continue }
            let start = time(startTime, on: day)
            let finish = time(finishTime, on: day)
            let detail = focus.trimmingCharacters(in: .whitespacesAndNewlines)
            switch category {
            case "raceVision":
                // One preparation milestone per month, not a daily all-day training plan.
                guard offset == 0 || Calendar.current.component(.day, from: day) == 1 else { continue }
                let month = day.formatted(.dateTime.month(.wide))
                let title = detail.isEmpty ? "Review race goals and preparation for \(month)" : "\(month): \(detail)"
                rows.append(LocalScheduleActivity(activity: title, start: start, finish: finish))
            case "training":
                rows.append(LocalScheduleActivity(
                    activity: detail.isEmpty ? "Training session — include warm-up, practice, and cool-down. Adjust to your recovery needs." : detail,
                    start: start, finish: finish
                ))
            case "achievement":
                rows.append(LocalScheduleActivity(
                    activity: detail.isEmpty ? "Milestone \(offset + 1) — define and complete your next concrete step." : "Milestone \(offset + 1): \(detail)",
                    start: start, finish: finish
                ))
            default:
                rows += OfflineScheduleGenerator.activities(category: category, focus: focus, start: start, finish: finish)
            }
        }
        guard !rows.isEmpty else { return }
        onCreate(rows)
        dismiss()
    }
}
