import SwiftUI
import Observation
import AVFoundation

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    @State private var completedItems: Set<String> = []
    @State private var note = ""
    @State private var savedNotes: [String] = []

    var body: some View {
        ZStack {
            PaperBackground()

            ScrollView {
                VStack(spacing: 18) {
                    featureHeader
                    metrics
                    actionChecklist
                    quickLog
                    recentActivity
                }
                .padding(18)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .appPageTheme()
    }

    private var featureHeader: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: Theme.fontSize(32), weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 72, height: 72)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 22))

            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(cornerRadius: 22, tint: color)
    }

    private var metrics: some View {
        HStack(spacing: 10) {
            ForEach(Array(metricItems.enumerated()), id: \.offset) { _, metric in
                VStack(spacing: 5) {
                    Text(metric.value)
                        .font(.system(size: Theme.fontSize(19), weight: .bold, design: .rounded))
                        .foregroundStyle(color)
                    Text(metric.label)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .glassCard(cornerRadius: 16)
            }
        }
    }

    private var actionChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(actionItems, id: \.self) { item in
                Button {
                    if completedItems.contains(item) {
                        completedItems.remove(item)
                    } else {
                        completedItems.insert(item)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: completedItems.contains(item) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(completedItems.contains(item) ? .green : color)
                        Text(item)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.black)
                            .strikethrough(completedItems.contains(item))
                        Spacer()
                    }
                    .padding(14)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .glassCard()
    }

    private var quickLog: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Log")
                .font(.headline)
                .foregroundStyle(.primary)

            TextField("Add a \(title) note", text: $note, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)

            Button {
                let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedNote.isEmpty else { return }
                savedNotes.insert(trimmedNote, at: 0)
                note = ""
            } label: {
                Label("Save Entry", systemImage: "plus.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)
        }
        .padding(16)
        .glassCard()
    }

    private var recentActivity: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .foregroundStyle(.primary)

            if savedNotes.isEmpty {
                Label("Your new entries will appear here.", systemImage: "clock")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(savedNotes, id: \.self) { entry in
                    Label(entry, systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassCard()
    }

    private var metricItems: [(value: String, label: String)] {
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("water") || lowerTitle.contains("hydration") {
            return [("1.8 L", "Today"), ("2.5 L", "Goal"), ("72%", "Complete")]
        } else if lowerTitle.contains("sleep") || lowerTitle.contains("recovery") || lowerTitle.contains("wellness") {
            return [("82", "Score"), ("7.6 h", "Rest"), ("Good", "Status")]
        } else if lowerTitle.contains("pace") || lowerTitle.contains("cardio") || lowerTitle.contains("training") || lowerTitle.contains("activity") {
            return [("5:24", "Avg Pace"), ("42 min", "Active"), ("4", "Sessions")]
        } else if lowerTitle.contains("meal") || lowerTitle.contains("macro") || lowerTitle.contains("supplement") {
            return [("1,840", "Calories"), ("118 g", "Protein"), ("3", "Meals")]
        } else if lowerTitle.contains("friend") || lowerTitle.contains("community") || lowerTitle.contains("social") || lowerTitle.contains("group") {
            return [("24", "Friends"), ("8", "Updates"), ("3", "Groups")]
        } else if lowerTitle.contains("achievement") || lowerTitle.contains("streak") || lowerTitle.contains("challenge") {
            return [("12", "Completed"), ("7 days", "Streak"), ("3", "Active")]
        } else {
            return [("3", "This Week"), ("78%", "Progress"), ("Today", "Updated")]
        }
    }

    private var actionItems: [String] {
        let lowerTitle = title.lowercased()
        if lowerTitle.contains("water") || lowerTitle.contains("hydration") {
            return ["Drink 250 ml now", "Set the next reminder", "Reach today's hydration goal"]
        } else if lowerTitle.contains("sleep") {
            return ["Log last night's sleep", "Review sleep stages", "Set tonight's bedtime"]
        } else if lowerTitle.contains("recovery") || lowerTitle.contains("wellness") || lowerTitle.contains("energy") {
            return ["Complete today's check-in", "Review readiness signals", "Choose a recovery activity"]
        } else if lowerTitle.contains("pace") || lowerTitle.contains("cardio") || lowerTitle.contains("elevation") || lowerTitle.contains("zone") {
            return ["Review the latest workout", "Compare this week's result", "Set the next performance target"]
        } else if lowerTitle.contains("meal") || lowerTitle.contains("macro") || lowerTitle.contains("supplement") {
            return ["Plan the next meal", "Log today's nutrition", "Review daily targets"]
        } else if lowerTitle.contains("yoga") || lowerTitle.contains("flexibility") || lowerTitle.contains("breathing") {
            return ["Start a guided session", "Complete the daily routine", "Log comfort and mobility"]
        } else if lowerTitle.contains("article") || lowerTitle.contains("video") || lowerTitle.contains("guide") || lowerTitle.contains("card") || lowerTitle.contains("learning") {
            return ["Continue the featured lesson", "Save an item for later", "Complete today's learning goal"]
        } else if lowerTitle.contains("friend") || lowerTitle.contains("community") || lowerTitle.contains("social") || lowerTitle.contains("group") {
            return ["View the latest updates", "Encourage a teammate", "Share today's progress"]
        } else if lowerTitle.contains("route") || lowerTitle.contains("location") || lowerTitle.contains("weather") || lowerTitle.contains("sunrise") {
            return ["Review today's conditions", "Choose a safe training window", "Save the next route"]
        } else {
            return ["Review the \(title) overview", "Add a new entry", "Check weekly progress"]
        }
    }
}

struct AIInsightCard: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label {
                Text("Open AI Planner")
            } icon: {
                Image("iPhone App")
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .accessibilityHidden(true)
            }
        }
    }
}

struct AIPlannerSheet: View {
    var body: some View { PlaceholderView(title: "AI Planner", subtitle: "Coming soon", icon: "sparkles") }
}

struct TrainingLogView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Training Log",
            subtitle: "Record workouts, results, and session notes",
            icon: "dumbbell.fill",
            color: Theme.rose,
            focusItems: ["Log today's workout", "Add sets or distance", "Write a recovery note"]
        )
    }
}

struct TrainingCalendarView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Training Calendar",
            subtitle: "Organize upcoming sessions and race preparation",
            icon: "calendar.badge.clock",
            color: .blue,
            focusItems: ["Schedule the next session", "Review this week's load", "Plan a recovery day"]
        )
    }
}

struct IntervalTrainingView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Interval Training",
            subtitle: "Build speed with structured work and recovery",
            icon: "timer",
            color: Theme.primary,
            focusItems: ["Warm up for 10 minutes", "Complete the interval set", "Cool down and stretch"]
        )
    }
}

struct RecoveryTrackerView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Recovery Tracker",
            subtitle: "Balance effort, rest, sleep, and mobility",
            icon: "heart.circle.fill",
            color: Theme.secondary,
            focusItems: ["Check energy level", "Complete mobility work", "Plan tonight's sleep"]
        )
    }
}

struct TrainingGoalsView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Training Goals",
            subtitle: "Turn your season targets into daily actions",
            icon: "target",
            color: .purple,
            focusItems: ["Choose the main goal", "Set a measurable milestone", "Log today's progress"]
        )
    }
}

struct ExerciseLibraryView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Exercise Library",
            subtitle: "Build sessions from strength, mobility, and cardio exercises",
            icon: "books.vertical.fill",
            color: .teal,
            focusItems: ["Squat and lower body", "Push and upper body", "Core and mobility"]
        )
    }
}

struct WorkoutPlansView: View {
    var body: some View {
        TrainingFeatureDashboard(
            title: "Workout Plans",
            subtitle: "Create a balanced plan for your current goal",
            icon: "list.clipboard.fill",
            color: .indigo,
            focusItems: ["Choose training days", "Add key workouts", "Schedule recovery"]
        )
    }
}

struct PerformanceTrackingView: View {
    var body: some View { PerformanceGoalsScreen() }
}

struct WorkoutLoggerView: View {
    var body: some View { WorkoutSessionsScreen() }
}

struct CalorieTrackerView: View {
    var body: some View { PlaceholderView(title: "Calorie Tracker", subtitle: "Coming soon", icon: "sparkles") }
}

struct StepsCounterView: View {
    var body: some View { LiveStepsScreen() }
}

struct HeartRateMonitorView: View {
    var body: some View { PlaceholderView(title: "Heart Rate Monitor", subtitle: "Coming soon", icon: "sparkles") }
}

struct StrengthProgressView: View {
    var body: some View { StrengthLevelsScreen() }
}

struct DistanceTrackerView: View {
    var body: some View { DistanceMapScreen() }
}

struct ProgressChartsView: View {
    var body: some View { PlaceholderView(title: "Progress Charts", subtitle: "Coming soon", icon: "sparkles") }
}

struct WeightTrackingView: View {
    var body: some View { PlaceholderView(title: "Weight Tracking", subtitle: "Coming soon", icon: "sparkles") }
}

struct BodyFatTrackerView: View {
    var body: some View { PlaceholderView(title: "Body Fat Tracker", subtitle: "Coming soon", icon: "sparkles") }
}

struct MeasurementsView: View {
    var body: some View { PlaceholderView(title: "Measurements", subtitle: "Coming soon", icon: "sparkles") }
}

struct WorkoutDurationView: View {
    var body: some View { PlaceholderView(title: "Workout Duration", subtitle: "Coming soon", icon: "sparkles") }
}

struct PersonalRecordsView: View {
    var body: some View { PlaceholderView(title: "Personal Records", subtitle: "Coming soon", icon: "sparkles") }
}

struct ActivityBreakdownView: View {
    var body: some View { PlaceholderView(title: "Activity Breakdown", subtitle: "Coming soon", icon: "sparkles") }
}

struct VO2MaxTrackerView: View {
    var body: some View { PlaceholderView(title: "VO2Max Tracker", subtitle: "Coming soon", icon: "sparkles") }
}

struct NutritionView: View {
    var body: some View { MealScheduleView() }
}

struct SleepTrackerView: View {
    var body: some View { PlaceholderView(title: "Sleep Tracker", subtitle: "Coming soon", icon: "sparkles") }
}

struct BodyMetricsView: View {
    var body: some View { PlaceholderView(title: "Body Metrics", subtitle: "Coming soon", icon: "sparkles") }
}

struct MeditationView: View {
    var body: some View { PlaceholderView(title: "Meditation", subtitle: "Coming soon", icon: "sparkles") }
}

struct MentalHealthView: View {
    var body: some View { PlaceholderView(title: "Mental Health", subtitle: "Coming soon", icon: "sparkles") }
}

struct ShoeTrackerView: View {
    var body: some View { PlaceholderView(title: "Shoe Tracker", subtitle: "Coming soon", icon: "sparkles") }
}

struct BikeMaintenanceView: View {
    var body: some View { PlaceholderView(title: "Bike Maintenance", subtitle: "Coming soon", icon: "sparkles") }
}

struct DeviceSyncView: View {
    var body: some View { PlaceholderView(title: "Device Sync", subtitle: "Coming soon", icon: "sparkles") }
}

struct PremiumMembershipView: View {
    var body: some View { PlaceholderView(title: "Premium Membership", subtitle: "Coming soon", icon: "sparkles") }
}

struct AdvancedAnalyticsView: View {
    var body: some View { PlaceholderView(title: "Advanced Analytics", subtitle: "Coming soon", icon: "sparkles") }
}

struct FriendsView: View {
    var body: some View { PlaceholderView(title: "Friends", subtitle: "Coming soon", icon: "sparkles") }
}

struct LeaderboardsView: View {
    var body: some View { PlaceholderView(title: "Leaderboards", subtitle: "Coming soon", icon: "sparkles") }
}

struct PrivacySettingsView: View {
    var body: some View { PlaceholderView(title: "Privacy Settings", subtitle: "Coming soon", icon: "sparkles") }
}

struct TrainingFeatureDashboard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let focusItems: [String]
    
    @State private var completedItems: Set<Int> = []
    @State private var logText = ""
    @State private var activityLog: [TrainingActivityEntry] = []
    
    var body: some View {
        ZStack {
            PaperBackground()
            
            ScrollView {
                VStack(spacing: 18) {
                    TrainingFeatureHero(
                        title: title,
                        subtitle: subtitle,
                        icon: icon,
                        color: color,
                        completedCount: completedItems.count,
                        totalCount: focusItems.count
                    )
                    
                    TrainingFocusCard(
                        items: focusItems,
                        completedItems: $completedItems,
                        color: color
                    )
                    
                    TrainingQuickLog(
                        text: $logText,
                        entries: $activityLog,
                        color: color
                    )
                }
                .padding()
                .padding(.bottom, 24)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .appPageTheme()
    }
}

private struct TrainingActivityEntry: Identifiable {
    let id = UUID()
    let text: String
    let date = Date()
}

private struct TrainingFeatureHero: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let completedCount: Int
    let totalCount: Int
    
    private var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                    .frame(width: 54, height: 54)
                    .background(color.gradient, in: RoundedRectangle(cornerRadius: 16))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.title2.bold())
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("Session progress")
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Text("\(completedCount) of \(totalCount)")
                        .font(.caption)
                        .foregroundStyle(color)
                }
                
                ProgressView(value: progress)
                    .tint(color)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 22, tint: color)
    }
}

private struct TrainingFocusCard: View {
    let items: [String]
    @Binding var completedItems: Set<Int>
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Today's focus", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(color)
            
            ForEach(items.indices, id: \.self) { index in
                Button {
                    if completedItems.contains(index) {
                        completedItems.remove(index)
                    } else {
                        completedItems.insert(index)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: completedItems.contains(index) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(completedItems.contains(index) ? color : .secondary)
                        
                        Text(items[index])
                            .foregroundStyle(.black)
                            .strikethrough(completedItems.contains(index))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: color)
    }
}

private struct TrainingQuickLog: View {
    @Binding var text: String
    @Binding var entries: [TrainingActivityEntry]
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick log", systemImage: "square.and.pencil")
                .font(.headline)
                .foregroundStyle(color)
            
            HStack {
                TextField("Add a workout note or result", text: $text)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(addEntry)
                
                Button(action: addEntry) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(color)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("Add training log")
            }
            
            ForEach(entries) { entry in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.text)
                        Text(entry.date, format: .dateTime.hour().minute())
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
        .padding(18)
        .glassCard(cornerRadius: 20, tint: color)
    }
    
    private func addEntry() {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        entries.insert(TrainingActivityEntry(text: trimmedText), at: 0)
        text = ""
    }
}


private struct WorkoutVoiceNote: Identifiable {
    let url: URL
    let createdAt: Date
    var id: URL { url }
}

@MainActor
@Observable
private final class WorkoutVoiceNotes {
    private(set) var notes: [WorkoutVoiceNote] = []
    private(set) var isRecording = false
    private(set) var isPreparing = false
    private(set) var playingURL: URL?
    private(set) var recordingSeconds = 0
    var errorMessage: String?

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var requestID = UUID()

    private var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WorkoutVoiceNotes", isDirectory: true)
    }

    func load() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            notes = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.creationDateKey]
            )
            .filter { $0.pathExtension == "m4a" && $0 != recorder?.url }
            .map { url in
                WorkoutVoiceNote(url: url, createdAt: (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast)
            }
            .sorted { $0.createdAt > $1.createdAt }
        } catch {
            errorMessage = "Could not load your saved voice notes."
        }
    }

    func start() async {
        guard !isPreparing, !isRecording else { return }
        stopPlayback()
        errorMessage = nil
        let identifier = UUID()
        requestID = identifier
        isPreparing = true
        defer { if requestID == identifier { isPreparing = false } }
        let allowed = await AVAudioApplication.requestRecordPermission()
        guard requestID == identifier, !Task.isCancelled else { return }
        guard allowed else {
            errorMessage = "Allow microphone access in Settings to record a voice note."
            return
        }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            let audio = try AVAudioRecorder(
                url: directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a"),
                settings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC,
                    AVSampleRateKey: 44100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ]
            )
            recorder = audio
            guard audio.record() else {
                audio.deleteRecording()
                recorder = nil
                deactivateSession()
                errorMessage = "Could not start recording. Please try again."
                return
            }
            recordingSeconds = 0
            isRecording = true
        } catch {
            recorder = nil
            deactivateSession()
            errorMessage = "Could not access the microphone or save the recording."
        }
    }

    func saveRecording() {
        guard let recorder else { return }
        recorder.stop()
        self.recorder = nil
        isRecording = false
        deactivateSession()
        load()
    }

    func play(_ note: WorkoutVoiceNote) {
        guard !isRecording, !isPreparing else { return }
        if playingURL == note.url {
            stopPlayback()
            return
        }
        stopPlayback()
        errorMessage = nil
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
            let audio = try AVAudioPlayer(contentsOf: note.url)
            guard audio.play() else {
                deactivateSession()
                errorMessage = "Could not play this voice note."
                return
            }
            player = audio
            playingURL = note.url
        } catch {
            deactivateSession()
            errorMessage = "Could not play this voice note."
        }
    }

    func delete(_ note: WorkoutVoiceNote) {
        if playingURL == note.url { stopPlayback() }
        do {
            try FileManager.default.removeItem(at: note.url)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = "Could not delete this voice note."
        }
    }

    func refresh() {
        if let recorder {
            recordingSeconds = Int(recorder.currentTime)
            // An interruption can stop recording without a button tap.
            if !recorder.isRecording { saveRecording() }
        }
        if let player, !player.isPlaying { stopPlayback() }
    }

    func stop() {
        requestID = UUID()
        isPreparing = false
        saveRecording()
        stopPlayback()
    }

    private func stopPlayback() {
        guard player != nil else { return }
        player?.stop()
        player = nil
        playingURL = nil
        deactivateSession()
    }

    private func deactivateSession() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

private struct WorkoutVoiceNotesView: View {
    @State private var audio = WorkoutVoiceNotes()
    @State private var startTask: Task<Void, Never>?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Voice Notes", systemImage: "waveform")
                .font(.headline)

            Text("Record a workout reminder or how your session felt. Notes stay on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                if audio.isRecording {
                    audio.saveRecording()
                } else {
                    startTask = Task { await audio.start() }
                }
            } label: {
                Label(audio.isRecording ? "Stop & Save Note" : "Record Voice Note",
                      systemImage: audio.isRecording ? "stop.circle.fill" : "mic.fill")
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .disabled(audio.isPreparing)

            if audio.isPreparing {
                ProgressView("Preparing microphone…")
            }
            if audio.isRecording {
                Text("Recording · \(audio.recordingSeconds) seconds")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let error = audio.errorMessage {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }

            ForEach(audio.notes) { note in
                HStack(spacing: 12) {
                    Button {
                        audio.play(note)
                    } label: {
                        Image(systemName: audio.playingURL == note.url ? "stop.circle.fill" : "play.circle.fill")
                            .font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel(audio.playingURL == note.url ? "Stop voice note" : "Play voice note")
                    .disabled(audio.isRecording || audio.isPreparing)

                    Text(note.createdAt, format: .dateTime.month().day().hour().minute())
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(role: .destructive) {
                        audio.delete(note)
                    } label: {
                        Image(systemName: "trash")
                            .frame(minWidth: 44, minHeight: 44)
                    }
                    .accessibilityLabel("Delete voice note")
                }
                .foregroundStyle(.black)
            }
        }
        .task {
            audio.load()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) }
                catch { break }
                audio.refresh()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background {
                startTask?.cancel()
                audio.stop()
            }
        }
        .onDisappear {
            startTask?.cancel()
            audio.stop()
        }
    }
}

struct ThemedWorkoutTimerView: View {
    @State private var isRunning = false
    @State private var startedAt = Date()
    @State private var savedDuration: TimeInterval = 0
    
    var body: some View {
        ZStack {
            PaperBackground()
            
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "stopwatch.fill")
                        .font(.system(size: Theme.fontSize(42), weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 88, height: 88)
                        .background(Theme.primary.gradient, in: Circle())
                        .shadow(color: Theme.primary.opacity(0.3), radius: 12, y: 6)
                    
                    SwiftUI.TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(duration(at: context.date), format: .time(pattern: .hourMinuteSecond))
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity)
                            .contentTransition(.numericText())
                    }
                    
                    Text(isRunning ? "Workout in progress" : "Ready for your next workout")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 14) {
                        Button(action: toggleTimer) {
                            Label(isRunning ? "Pause" : "Start", systemImage: isRunning ? "pause.fill" : "play.fill")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(isRunning ? Theme.rose : Theme.secondary)
                        
                        Button {
                            isRunning = false
                            savedDuration = 0
                            startedAt = Date()
                        } label: {
                            Label("Reset", systemImage: "arrow.counterclockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.bordered)
                    }

                    WorkoutVoiceNotesView()
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 28, tint: Theme.primary)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
                .padding(16)
            }
        }
        .navigationTitle("Workout Timer")
        .navigationBarTitleDisplayMode(.inline)
        .appPageTheme()
    }
    
    private func duration(at date: Date) -> Duration {
        .seconds(savedDuration + (isRunning ? date.timeIntervalSince(startedAt) : 0))
    }
    
    private func toggleTimer() {
        if isRunning {
            savedDuration += Date().timeIntervalSince(startedAt)
        } else {
            startedAt = Date()
        }
        isRunning.toggle()
    }
}
