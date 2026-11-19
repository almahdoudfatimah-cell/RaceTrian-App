import SwiftUI
import Observation
import CoreMotion
import MapKit
import CoreLocation

private struct PerformanceGoal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var target: Int
    var progress = 0
    var unit: String
}

private struct LoggedWorkoutSession: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var minutes: Int
    var notes: String
}

private struct StrengthLevel: Identifiable, Codable {
    var id = UUID()
    var title: String
    var requirement: String
    var achieved = false
}

@MainActor
@Observable
private final class TrainingRecords {
    var goals: [PerformanceGoal] = []
    var sessions: [LoggedWorkoutSession] = []
    var levels: [StrengthLevel] = []
    var error: String?

    init() {
        do {
            let defaults = UserDefaults.standard
            if let data = defaults.data(forKey: "performanceGoals.v1") {
                goals = try JSONDecoder().decode([PerformanceGoal].self, from: data)
            }
            if let data = defaults.data(forKey: "workoutSessions.v1") {
                sessions = try JSONDecoder().decode([LoggedWorkoutSession].self, from: data)
            }
            if let data = defaults.data(forKey: "strengthLevels.v1") {
                levels = try JSONDecoder().decode([StrengthLevel].self, from: data)
            }
        } catch {
            self.error = "Some saved training records could not be loaded."
        }
    }

    func saveGoals() { save(goals, key: "performanceGoals.v1") }
    func saveSessions() { save(sessions, key: "workoutSessions.v1") }
    func saveLevels() { save(levels, key: "strengthLevels.v1") }

    private func save<T: Encodable>(_ value: T, key: String) {
        do {
            UserDefaults.standard.set(try JSONEncoder().encode(value), forKey: key)
        } catch {
            self.error = "Your changes could not be saved."
        }
    }
}

struct PerformanceGoalsScreen: View {
    @State private var records = TrainingRecords()
    @State private var title = ""
    @State private var unit = "sessions"
    @State private var target = 10

    var body: some View {
        Form {
            Section("Add a goal") {
                TextField("Goal name", text: $title)
                TextField("Unit, e.g. km or sessions", text: $unit)
                TextField("Target", value: $target, format: .number)
                    .keyboardType(.numberPad)
                Button("Add Goal") {
                    records.goals.append(PerformanceGoal(title: title.trimmingCharacters(in: .whitespacesAndNewlines), target: target, unit: unit.trimmingCharacters(in: .whitespacesAndNewlines)))
                    records.saveGoals()
                    title = ""
                }
                .foregroundStyle(.black)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || target < 1 || target > 100000)
            }
            Section("Your goals") {
                if records.goals.isEmpty {
                    Text("Add your first goal, then update your progress here.")
                }
                ForEach($records.goals) { $goal in
                    PerformanceGoalRow(goal: $goal)
                }
                .onDelete { offsets in
                    records.goals.remove(atOffsets: offsets)
                    records.saveGoals()
                }
            }
            if let error = records.error { Text(error) }
        }
        .onChange(of: records.goals.map(\.progress)) { _, _ in records.saveGoals() }
        .navigationTitle("Performance Tracking")
        .appPageTheme()
    }
}

private struct PerformanceGoalRow: View {
    @Binding var goal: PerformanceGoal

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(goal.title, systemImage: goal.progress >= goal.target ? "checkmark.circle.fill" : "target")
                .font(.headline)
            ProgressView(value: Double(goal.progress), total: Double(goal.target))
            Stepper("\(goal.progress) / \(goal.target) \(goal.unit)", value: $goal.progress, in: 0...goal.target)
            if goal.progress == goal.target {
                Text("Goal achieved").font(.caption)
            }
        }
        .padding(.vertical, 6)
    }
}

struct WorkoutSessionsScreen: View {
    @State private var records = TrainingRecords()
    @State private var adding = false

    var body: some View {
        List {
            if let error = records.error { Text(error) }
            if records.sessions.isEmpty {
                ContentUnavailableView("No sessions yet", systemImage: "dumbbell", description: Text("Tap Add Session to log your workout."))
            }
            ForEach(records.sessions) { session in
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.title).font(.headline)
                    Text(session.date, format: .dateTime.month().day().year().hour().minute())
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(session.minutes) minutes")
                    if !session.notes.isEmpty { Text(session.notes).font(.subheadline) }
                }
                .padding(.vertical, 6)
            }
            .onDelete { offsets in
                records.sessions.remove(atOffsets: offsets)
                records.saveSessions()
            }
        }
        .navigationTitle("Workout Logger")
        .toolbar {
            Button("Add Session", systemImage: "plus") { adding = true }
                .foregroundStyle(.black)
        }
        .sheet(isPresented: $adding) {
            WorkoutSessionEditor { session in
                records.sessions.append(session)
                records.sessions.sort { $0.date > $1.date }
                records.saveSessions()
            }
        }
        .appPageTheme()
    }
}

private struct WorkoutSessionEditor: View {
    let save: (LoggedWorkoutSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var date = Date()
    @State private var minutes = 30
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Session name", text: $title)
                DatePicker("Date", selection: $date, in: ...Date())
                Stepper("Duration: \(minutes) minutes", value: $minutes, in: 1...1440)
                TextField("Exercises, sets, reps, and notes", text: $notes, axis: .vertical)
                    .lineLimit(3...8)
            }
            .navigationTitle("Add Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.black)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save(LoggedWorkoutSession(title: title.trimmingCharacters(in: .whitespacesAndNewlines), date: date, minutes: minutes, notes: notes))
                        dismiss()
                    }
                    .foregroundStyle(.black)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct StrengthLevelsScreen: View {
    @State private var records = TrainingRecords()
    @State private var title = ""
    @State private var requirement = ""

    var body: some View {
        Form {
            Section("Add a strength level") {
                TextField("Level name, e.g. Beginner", text: $title)
                TextField("Target, e.g. squat 40 kg for 5 reps", text: $requirement, axis: .vertical)
                Button("Add Level") {
                    records.levels.append(StrengthLevel(title: title.trimmingCharacters(in: .whitespacesAndNewlines), requirement: requirement.trimmingCharacters(in: .whitespacesAndNewlines)))
                    records.saveLevels()
                    title = ""
                    requirement = ""
                }
                .foregroundStyle(.black)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || requirement.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Section("Your levels") {
                if records.levels.isEmpty { Text("Create levels and mark each one when you reach its target.") }
                ForEach($records.levels) { $level in
                    Toggle(isOn: $level.achieved) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(level.title).font(.headline)
                            Text(level.requirement).font(.subheadline)
                            Text(level.achieved ? "Achieved" : "In progress").font(.caption)
                        }
                    }
                }
                .onDelete { offsets in
                    records.levels.remove(atOffsets: offsets)
                    records.saveLevels()
                }
            }
            if let error = records.error { Text(error) }
        }
        .onChange(of: records.levels.map(\.achieved)) { _, _ in records.saveLevels() }
        .navigationTitle("Strength Progress")
        .appPageTheme()
    }
}

@MainActor
@Observable
private final class DailySteps {
    var count: Int?
    var status = "Enable step counting to read today's steps from this iPhone."
    @ObservationIgnored private let pedometer = CMPedometer()
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var day = Date.distantPast

    func start() {
        stop()
        guard CMPedometer.isStepCountingAvailable() else {
            status = "Step counting is unavailable on this device. Try a physical iPhone."
            return
        }
        guard CMPedometer.authorizationStatus() != .denied,
              CMPedometer.authorizationStatus() != .restricted else {
            status = "Allow Motion & Fitness access in Settings to see your steps."
            return
        }
        day = Calendar.current.startOfDay(for: Date())
        count = nil
        status = "Loading today's steps…"
        let token = generation
        pedometer.queryPedometerData(from: day, to: Date()) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                // A live update may have arrived while the historical query was running.
                if self.count == nil { self.receive(steps, failed: failed) }
            }
        }
        pedometer.startUpdates(from: day) { [weak self] data, error in
            let steps = data?.numberOfSteps.intValue
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.generation == token else { return }
                if !Calendar.current.isDateInToday(self.day) { self.start(); return }
                self.receive(steps, failed: failed)
            }
        }
    }

    private func receive(_ steps: Int?, failed: Bool) {
        if failed {
            status = "Could not read steps. Check Motion & Fitness permission in Settings and try again."
        } else if let steps {
            count = steps
            status = "Today's steps recorded by this iPhone."
        }
    }

    func stop() {
        generation = UUID()
        pedometer.stopUpdates()
    }
}

struct LiveStepsScreen: View {
    @State private var steps = DailySteps()
    @AppStorage("stepsCounter.enabled") private var enabled = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Form {
            Section("Today") {
                Text(steps.count.map { $0.formatted() } ?? "—")
                    .font(.largeTitle.bold()).monospacedDigit()
                Text(steps.status).font(.subheadline)
                Button(enabled ? "Refresh Steps" : "Enable Step Counting") {
                    enabled = true
                    steps.start()
                }
                .foregroundStyle(.black)
            }
        }
        .navigationTitle("Steps Counter")
        .onAppear { if enabled { steps.start() } }
        .onDisappear { steps.stop() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && enabled { steps.start() }
            else if phase == .background { steps.stop() }
        }
        .appPageTheme()
    }
}

@MainActor
@Observable
private final class DistanceRoute: NSObject, CLLocationManagerDelegate {
    var coordinates: [CLLocationCoordinate2D] = []
    var meters = 0.0
    var isTracking = false
    var status = "Start a route to track your distance while this screen is open."
    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var previous: CLLocation?
    @ObservationIgnored private var wantsTracking = false
    @ObservationIgnored private var startedAt = Date()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        manager.activityType = .fitness
    }

    func start() {
        wantsTracking = true
        switch manager.authorizationStatus {
        case .notDetermined:
            status = "Waiting for location permission…"
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            coordinates = []
            meters = 0
            previous = nil
            startedAt = Date()
            isTracking = true
            status = "Finding your location…"
            manager.startUpdatingLocation()
        default:
            wantsTracking = false
            status = "Allow location access in Settings to record a route."
        }
    }

    func stop() {
        wantsTracking = false
        manager.stopUpdatingLocation()
        if isTracking { status = "Route stopped. Start a new route when you're ready." }
        isTracking = false
        previous = nil
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if wantsTracking { start() }
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            stop()
            status = "Allow location access in Settings to record a route."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isTracking else { return }
        for location in locations {
            // Reject stale fixes and poor accuracy to reduce GPS distance spikes.
            guard location.timestamp >= startedAt, location.horizontalAccuracy >= 0,
                  location.horizontalAccuracy <= 30 else { continue }
            if let previous {
                guard location.timestamp > previous.timestamp else { continue }
                let distance = location.distance(from: previous)
                let seconds = location.timestamp.timeIntervalSince(previous.timestamp)
                guard distance >= 5, distance / seconds < 30 else { continue }
                meters += distance
            }
            previous = location
            coordinates.append(location.coordinate)
            status = "Recording route. Keep this screen open."
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if (error as? CLError)?.code == .locationUnknown {
            status = "Waiting for a stronger GPS signal…"
        } else {
            stop()
            status = "Location is unavailable. Check location access and try again."
        }
    }
}

struct DistanceMapScreen: View {
    @State private var route = DistanceRoute()
    @State private var camera: MapCameraPosition = .automatic
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 16) {
            Map(position: $camera) {
                if route.coordinates.count > 1 {
                    MapPolyline(coordinates: route.coordinates)
                        .stroke(.orange, lineWidth: 5)
                }
                if let first = route.coordinates.first {
                    Marker("Start", coordinate: first).tint(.green)
                }
                if let last = route.coordinates.last {
                    Marker("Current position", coordinate: last)
                }
            }
            .mapControls { MapCompass(); MapScaleView() }
            .frame(minHeight: 220)

            VStack(spacing: 12) {
                Text(Measurement(value: route.meters, unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .road))
                    .font(.title.bold()).monospacedDigit()
                Text(route.status).font(.caption).multilineTextAlignment(.center)
                Button(route.isTracking ? "Stop Route" : "Start New Route") {
                    if route.isTracking { route.stop() }
                    else { route.start(); camera = .automatic }
                }
                .buttonStyle(.bordered)
                .foregroundStyle(.black)
            }
            .padding()
        }
        .navigationTitle("Distance Tracker")
        .onChange(of: route.coordinates.count) { _, _ in camera = .automatic }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background { route.stop() }
        }
        .onDisappear { route.stop() }
        .appPageTheme()
    }
}
