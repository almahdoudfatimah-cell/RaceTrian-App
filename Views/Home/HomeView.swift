import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var scheme
    @StateObject private var moodStore = MoodStore.shared
    @State private var taskStore = WeekTaskStore.shared
    private var tasks: [PlanTask] { taskStore.tasks(for: Date()) }
    @State private var showingAIPlanner = false
    @State private var showingNotifications = false
    @State private var showingAddTask = false
    
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var completion: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isDone }.count) / Double(tasks.count)
    }

    var body: some View {
        @Bindable var taskStore = taskStore
        NavigationStack {
            ZStack(alignment: .topLeading) {
                PaperBackground()
                ScrollView {
                    VStack(spacing: isIPad ? 26 : 20) {
                        HomeHeroCard(completion: completion,
                                     doneCount: tasks.filter { $0.isDone }.count,
                                     totalCount: tasks.count)
                        MetricsRow()
                        MoodCheckinBanner()
                        PremiumNudgeBanner()
                        AIInsightCard(action: { showingAIPlanner = true })
                        HomeFeatureGrid()
                        TodayPlanSection(tasks: $taskStore[day: Date()], onAdd: { showingAddTask = true })
                        HomePlanBoard()
                        HomeScheduleSection()
                        PlannerNotesSection()
                        GoalsCarousel()
                        ProjectsHomeSection()
                        Color.clear.frame(height: isIPad ? 40 : 32)
                    }
                    .padding(.horizontal, isIPad ? 24 : 18)
                    .padding(.top, isIPad ? 12 : 8)
                }
            }
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNotifications = true } label: {
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: isIPad ? 28 : 17))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAIPlanner) {
                AIPlannerSheet()
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(tasks: $taskStore[day: Date()], date: Date())
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }.appPageTheme()
    }
}

private struct GreetingTitle: View {
    private var isIPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(greeting())
                .font(.system(size: isIPad ? 36 : 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
            Text("Hey, Alex")
                .font(.system(size: isIPad ? 42 : 18, weight: .bold, design: .rounded))
        }
    }
    private func greeting() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning ☀️"
        case 12..<17: return "Good afternoon 🌤"
        case 17..<22: return "Good evening 🌙"
        default: return "Hello, night owl ✨"
        }
    }
}

/// Shortcut grid so every main feature is reachable from Home.
private struct HomeFeatureGrid: View {
    private enum Target {
        case tab(Int)
        case screen(AnyView)
    }

    private struct Shortcut: Identifiable {
        let id: String
        let icon: String
        let color: Color
        let target: Target
    }

    private let shortcuts: [Shortcut] = [
        Shortcut(id: "Plan", icon: "calendar.badge.clock", color: Theme.primary, target: .tab(1)),
        Shortcut(id: "Training", icon: "figure.run", color: .red, target: .screen(AnyView(TrainingTrackingView()))),
        Shortcut(id: "Nutrition", icon: "fork.knife", color: .green, target: .screen(AnyView(NutritionView()))),
        Shortcut(id: "Mood", icon: "face.smiling", color: .yellow, target: .screen(AnyView(MoodView()))),
        Shortcut(id: "Diary", icon: "book.closed.fill", color: .purple, target: .screen(AnyView(DiaryView()))),
        Shortcut(id: "Notes", icon: "note.text", color: .orange, target: .screen(AnyView(NotesView()))),
        Shortcut(id: "Community", icon: "person.3.fill", color: .blue, target: .screen(AnyView(CommunityPageView()))),
        Shortcut(id: "AI Coach", icon: "sparkles", color: .indigo, target: .screen(AnyView(CoachView()))),
        Shortcut(id: "Races", icon: "flag.checkered", color: .teal, target: .screen(AnyView(RaceCalendarView()))),
        Shortcut(id: "Goals", icon: "target", color: Theme.secondary, target: .tab(2)),
        Shortcut(id: "Projects", icon: "folder.fill", color: .cyan, target: .tab(3)),
        Shortcut(id: "More", icon: "square.grid.2x2.fill", color: .gray, target: .tab(4))
    ]

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Features")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(shortcuts) { shortcut in
                    switch shortcut.target {
                    case .tab(let tab):
                        Button {
                            NotificationCenter.default.post(name: .switchTab, object: tab)
                        } label: {
                            tile(shortcut)
                        }
                        .buttonStyle(.plain)
                    case .screen(let destination):
                        NavigationLink {
                            destination
                        } label: {
                            tile(shortcut)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func tile(_ shortcut: Shortcut) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(shortcut.color.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: shortcut.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(shortcut.color)
            }
            Text(shortcut.id)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

#Preview { HomeView() }
