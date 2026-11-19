import SwiftUI
import Observation

private struct ScheduledMeal: Identifiable, Codable {
    var id = UUID()
    var name = ""
    var date = Date()
    var notes = ""
    var completed = false
}

@MainActor
@Observable
private final class MealScheduleStore {
    private(set) var meals: [ScheduledMeal] = []
    var errorMessage: String?
    private let key = "nutrition.mealSchedule.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            meals = try JSONDecoder().decode([ScheduledMeal].self, from: data)
        } catch {
            errorMessage = "Your saved meal schedule could not be loaded."
        }
    }

    func meals(on date: Date, calendar: Calendar) -> [ScheduledMeal] {
        meals.filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted {
                if $0.date == $1.date { return $0.id.uuidString < $1.id.uuidString }
                return $0.date < $1.date
            }
    }

    @discardableResult
    func save(_ meal: ScheduledMeal) -> Bool {
        var updated = meals
        if let index = updated.firstIndex(where: { $0.id == meal.id }) {
            updated[index] = meal
        } else {
            updated.append(meal)
        }
        return persist(updated)
    }

    func delete(_ meal: ScheduledMeal) {
        _ = persist(meals.filter { $0.id != meal.id })
    }

    private func persist(_ updated: [ScheduledMeal]) -> Bool {
        do {
            let data = try JSONEncoder().encode(updated)
            UserDefaults.standard.set(data, forKey: key)
            meals = updated
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Your meal schedule could not be saved. Please try again."
            return false
        }
    }
}

struct MealScheduleView: View {
    @State private var store = MealScheduleStore()
    @State private var selectedDay = Date()
    @State private var draft: ScheduledMeal?
    @Environment(\.calendar) private var calendar

    var body: some View {
        let dailyMeals = store.meals(on: selectedDay, calendar: calendar)

        List {
            Section {
                DatePicker("Day", selection: $selectedDay, displayedComponents: .date)
                Button("Today") { selectedDay = Date() }
                    .foregroundStyle(.black)
            }

            Section("Meal schedule") {
                if dailyMeals.isEmpty {
                    ContentUnavailableView(
                        "No meals planned",
                        systemImage: "fork.knife",
                        description: Text("Add a meal with a time and notes for this day.")
                    )
                }
                ForEach(dailyMeals) { meal in
                    ScheduledMealRow(
                        meal: meal,
                        edit: { draft = meal },
                        toggle: {
                            var updated = meal
                            updated.completed.toggle()
                            store.save(updated)
                        }
                    )
                    .swipeActions {
                        Button("Delete", role: .destructive) { store.delete(meal) }
                        Button("Edit") { draft = meal }.tint(.orange)
                    }
                }
            }
            if let error = store.errorMessage {
                Section { Text(error).font(.caption) }
            }
        }
        .navigationTitle("Nutrition")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Add Meal", systemImage: "plus") {
                    let now = calendar.dateComponents([.hour, .minute], from: Date())
                    let time = calendar.date(bySettingHour: now.hour ?? 12, minute: now.minute ?? 0, second: 0, of: selectedDay) ?? selectedDay
                    draft = ScheduledMeal(date: time)
                }
                .foregroundStyle(.black)
            }
        }
        .sheet(item: $draft) { meal in
            MealScheduleEditor(meal: meal) { updated in
                let saved = store.save(updated)
                if saved { selectedDay = updated.date }
                return saved
            }
        }
        .appPageTheme()
    }
}

private struct ScheduledMealRow: View {
    let meal: ScheduledMeal
    let edit: () -> Void
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: toggle) {
                Image(systemName: meal.completed ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(.black)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(meal.completed ? "Mark meal incomplete" : "Mark meal completed")
            .accessibilityValue(meal.name)

            Button(action: edit) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(meal.name)
                        .font(.headline)
                        .strikethrough(meal.completed)
                    Text(meal.date, format: .dateTime.hour().minute())
                        .font(.subheadline)
                    if !meal.notes.isEmpty {
                        Text(meal.notes)
                            .font(.subheadline)
                            .lineLimit(3)
                    }
                    if meal.completed { Text("Completed").font(.caption) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityHint("Edit this meal and its notes")
        }
    }
}

private struct MealScheduleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var meal: ScheduledMeal
    @State private var saveFailed = false
    private let save: (ScheduledMeal) -> Bool

    init(meal: ScheduledMeal, save: @escaping (ScheduledMeal) -> Bool) {
        _meal = State(initialValue: meal)
        self.save = save
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Meal name, e.g. Breakfast", text: $meal.name)
                    DatePicker("Date and time", selection: $meal.date)
                    Toggle("Completed", isOn: $meal.completed)
                }
                Section("Notes") {
                    TextField("Food, portions, preparation, or other notes", text: $meal.notes, axis: .vertical)
                        .lineLimit(4...10)
                }
                if saveFailed {
                    Text("Could not save this meal. Please try again.")
                }
            }
            .navigationTitle("Meal Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        meal.name = meal.name.trimmingCharacters(in: .whitespacesAndNewlines)
                        meal.notes = meal.notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        if save(meal) { dismiss() }
                        else { saveFailed = true }
                    }
                    .foregroundStyle(.black)
                    .disabled(meal.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .appPageTheme()
        }
    }
}
