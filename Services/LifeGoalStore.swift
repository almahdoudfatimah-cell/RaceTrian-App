import SwiftUI
import Observation

/// Persists the user's life goals so the Goals tab, Home carousel, and Apple Watch share one list.
@Observable
final class LifeGoalStore {
    static let shared = LifeGoalStore()

    private static let key = "lifeGoals.v1"
    private static let expandedSamplesKey = "lifeGoals.expandedSamples.v1"

    var goals: [LifeGoal] {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([LifeGoal].self, from: data) {
            goals = saved
        } else {
            // First launch: start with the sample goals the Goals tab has always shown.
            goals = SampleData.goals
        }

        if !UserDefaults.standard.bool(forKey: Self.expandedSamplesKey) {
            let existingTitles = Set(goals.map(\.title))
            goals.append(contentsOf: SampleData.goals.filter { !existingTitles.contains($0.title) })
            UserDefaults.standard.set(true, forKey: Self.expandedSamplesKey)
        }
    }

    func add(_ goal: LifeGoal) {
        goals.append(goal)
    }

    func delete(id: UUID) {
        goals.removeAll { $0.id == id }
    }

    /// A check-in nudges progress by 5%, extends the streak, and marks today as tracked.
    func checkIn(id: UUID) {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return }
        goals[index].progress = min(1, goals[index].progress + 0.05)
        goals[index].streak += 1

        // Shared with `LifeGoalsSection`'s `@AppStorage("goals.trackedDays")`.
        let defaults = UserDefaults.standard
        var days = Set((defaults.string(forKey: "goals.trackedDays") ?? "").split(separator: ",").map(String.init))
        days.insert(GoalTrackingCalendar.dayKey(Date()))
        defaults.set(days.sorted().joined(separator: ","), forKey: "goals.trackedDays")
    }

    private func save() {
        if let data = try? JSONEncoder().encode(goals) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        NotificationCenter.default.post(name: .watchSyncSourceDidChange, object: nil)
    }
}
