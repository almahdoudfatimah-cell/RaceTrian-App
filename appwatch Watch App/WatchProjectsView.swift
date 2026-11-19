import SwiftUI

/// Projects tab: mirrors the iPhone's Projects list. Projects are created and edited on the iPhone and synced here.
struct WatchProjectsView: View {
    let store: WatchAppStore

    /// Pinned projects first, otherwise keeping the iPhone's order.
    private var sortedProjects: [SyncedWatchProject] {
        store.projects.filter(\.isPinned) + store.projects.filter { !$0.isPinned }
    }

    private var totalMilestones: Int {
        store.projects.reduce(0) { $0 + $1.milestones.count }
    }

    private var completedMilestones: Int {
        store.projects.reduce(0) { $0 + $1.completedCount }
    }

    var body: some View {
        List {
            if store.projects.isEmpty {
                WatchProjectsEmptyState(
                    title: "No projects yet",
                    message: "Projects you add on iPhone appear here."
                )
            } else {
                Section {
                    LabeledContent {
                        Text("\(completedMilestones)/\(totalMilestones)")
                            .foregroundStyle(WatchTheme.ink)
                    } label: {
                        Text("Milestones")
                            .foregroundStyle(WatchTheme.ink)
                    }
                    .watchPaperRow()
                }

                Section {
                    ForEach(sortedProjects) { project in
                        NavigationLink {
                            WatchProjectDetailView(store: store, projectId: project.id)
                        } label: {
                            WatchProjectRow(project: project)
                        }
                        .watchPaperRow()
                    }
                } header: {
                    Text("Projects")
                        .foregroundStyle(WatchTheme.muted)
                }
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        // Projects is both a page and a pushed screen (Today's "See all"), so cover both containers.
        .containerBackground(WatchTheme.paper, for: .tabView)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Projects")
    }
}

/// Project detail: overall progress and milestones that can be ticked off from the wrist.
struct WatchProjectDetailView: View {
    let store: WatchAppStore
    let projectId: UUID

    private var project: SyncedWatchProject? {
        store.projects.first { $0.id == projectId }
    }

    var body: some View {
        List {
            if let project {
                Section {
                    Group {
                        ProgressView(value: project.progress) {
                            Text("\(project.completedCount) of \(project.milestones.count) done")
                                .font(WatchTheme.captionFont)
                                .foregroundStyle(WatchTheme.ink)
                        }
                        .tint(WatchTheme.primary)
                        WatchProjectInfoRow(title: "Status", value: project.status)
                        WatchProjectInfoRow(title: "Category", value: project.category)
                    }
                    .watchPaperRow()
                }

                Section {
                    ForEach(project.milestones) { milestone in
                        Button {
                            store.toggleMilestone(projectId: project.id, milestoneId: milestone.id)
                        } label: {
                            Label {
                                Text(milestone.title)
                                    .strikethrough(milestone.isDone)
                                    .foregroundStyle(milestone.isDone ? WatchTheme.muted : WatchTheme.ink)
                            } icon: {
                                Image(systemName: milestone.isDone ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(WatchTheme.primary)
                            }
                        }
                        .foregroundStyle(milestone.isDone ? WatchTheme.muted : WatchTheme.ink)
                        .watchPaperRow()
                    }
                } header: {
                    Text("Milestones")
                        .foregroundStyle(WatchTheme.muted)
                }
            } else {
                WatchProjectsEmptyState(title: "Project not found", message: nil)
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle(project?.title ?? "Project")
    }
}

/// Status / category line with black text instead of watchOS's default white and gray.
private struct WatchProjectInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(WatchTheme.ink)
        } label: {
            Text(title)
                .foregroundStyle(WatchTheme.ink)
        }
    }
}

/// Empty state in black text; the system `ContentUnavailableView` is white on the cream page.
private struct WatchProjectsEmptyState: View {
    let title: String
    let message: String?

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(WatchTheme.primary)
            Text(title)
                .font(WatchTheme.headlineFont)
                .foregroundStyle(WatchTheme.ink)
            if let message {
                Text(message)
                    .font(WatchTheme.captionFont)
                    .foregroundStyle(WatchTheme.ink)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .listRowBackground(Color.clear)
    }
}

/// A single project row: emoji, title, progress bar, and milestone count.
struct WatchProjectRow: View {
    let project: SyncedWatchProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(project.emoji)
                Text(project.title)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                    .lineLimit(2)
                if project.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(WatchTheme.primary)
                }
            }
            ProgressView(value: project.progress)
                .tint(WatchTheme.primary)
            Text("\(project.completedCount)/\(project.milestones.count) milestones · \(project.status)")
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(WatchTheme.muted)
        }
    }
}

/// Home-tab card with the first few projects, like the iPhone's `ProjectsHomeSection`.
struct WatchHomeProjectsSection: View {
    let store: WatchAppStore

    var body: some View {
        if !store.projects.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Projects")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Spacer()
                    NavigationLink {
                        WatchProjectsView(store: store)
                    } label: {
                        Text("See all")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(WatchTheme.primary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)

                ForEach(store.projects.prefix(2)) { project in
                    NavigationLink {
                        WatchProjectDetailView(store: store, projectId: project.id)
                    } label: {
                        WatchProjectRow(project: project)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .watchGlassCard(cornerRadius: 14)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
