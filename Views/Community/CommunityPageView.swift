#if !os(watchOS)
import SwiftUI

private enum CommunitySection: String, CaseIterable, Identifiable {
    case notes = "Shared Notes"
    case people = "Friends"
    case groups = "Groups"
    case challenges = "Challenges"

    var id: Self { self }
}

private struct CommunityPerson: Identifiable {
    let id: Int
    let name: String
    let detail: String
    let initials: String
    var isFollowing: Bool
}

private struct CommunityNote: Identifiable {
    let id: Int
    let author: String
    let time: String
    let title: String
    let body: String
    let tags: [String]
    var likes: Int
    var isLiked: Bool
}

private struct TrainingGroup: Identifiable {
    let id: Int
    let name: String
    let detail: String
    let members: String
    let icon: String
    let color: Color
    var isJoined: Bool
}

private struct GroupChallenge: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let progress: Double
    let participants: String
    let icon: String
    let color: Color
    var isJoined: Bool
}

struct CommunityPageView: View {
    @State private var selectedSection: CommunitySection = .notes
    @State private var isComposerPresented = false
    @State private var notes = CommunitySampleData.notes
    @State private var people = CommunitySampleData.people
    @State private var groups = CommunitySampleData.groups
    @State private var challenges = CommunitySampleData.challenges

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CommunityHero()
                    CommunitySectionPicker(selection: $selectedSection)

                    switch selectedSection {
                    case .notes:
                        SharedNotesSection(notes: $notes)
                    case .people:
                        FriendsFollowingSection(people: $people)
                    case .groups:
                        TrainingGroupsSection(groups: $groups)
                    case .challenges:
                        ChallengesSection(challenges: $challenges)
                    }
                }
                .padding()
            }
            .background(Theme.pageBackground)
            .navigationTitle("Community")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isComposerPresented = true
                    } label: {
                        Label("Share a note", systemImage: "square.and.pencil")
                    }
                }
            }
            .sheet(isPresented: $isComposerPresented) {
                ShareNoteView { title, body in
                    notes.insert(
                        CommunityNote(
                            id: (notes.map(\.id).max() ?? 0) + 1,
                            author: "You",
                            time: "Now",
                            title: title,
                            body: body,
                            tags: ["Shared"],
                            likes: 0,
                            isLiked: false
                        ),
                        at: 0
                    )
                    selectedSection = .notes
                }
            }
        }
        .appPageTheme()
    }
}

private struct CommunityHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Train better, together", systemImage: "person.3.fill")
                .font(.title2.bold())
            Text("Share useful notes, follow athletes, and stay accountable with training groups and challenges.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                CommunityMetric(value: "248", label: "Following")
                CommunityMetric(value: "18", label: "Groups")
                CommunityMetric(value: "6", label: "Challenges")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Theme.heroGradient.opacity(0.18), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct CommunityMetric: View {
    let value: String
    let label: LocalizedStringResource

    var body: some View {
        VStack(spacing: 3) {
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct CommunitySectionPicker: View {
    @Binding var selection: CommunitySection

    var body: some View {
        Picker("Community section", selection: $selection) {
            ForEach(CommunitySection.allCases) { section in
                Text(section.rawValue).tag(section)
            }
        }
        .pickerStyle(.segmented)
    }
}

private struct SharedNotesSection: View {
    @Binding var notes: [CommunityNote]

    var body: some View {
        LazyVStack(spacing: 14) {
            CommunitySectionHeader(title: "Shared Notes", subtitle: "Ideas and lessons shared by the community")
            ForEach($notes) { $note in
                SharedNoteCard(note: $note)
            }
        }
    }
}

private struct SharedNoteCard: View {
    @Binding var note: CommunityNote

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(Theme.primary.opacity(0.18))
                    .frame(width: 40, height: 40)
                    .overlay(Text(String(note.author.prefix(1))).font(.headline))
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.author).font(.subheadline.bold())
                    Text(note.time).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(note.title).font(.headline)
            Text(note.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack {
                ForEach(note.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.primary.opacity(0.12), in: Capsule())
                }
                Spacer()
                Button {
                    note.isLiked.toggle()
                    note.likes += note.isLiked ? 1 : -1
                } label: {
                    Label(note.likes.formatted(), systemImage: note.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(note.isLiked ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct FriendsFollowingSection: View {
    @Binding var people: [CommunityPerson]

    var body: some View {
        LazyVStack(spacing: 12) {
            CommunitySectionHeader(title: "Friends & Following", subtitle: "Discover athletes with similar goals")
            ForEach($people) { $person in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Theme.primary.opacity(0.16))
                        .frame(width: 48, height: 48)
                        .overlay(Text(person.initials).font(.subheadline.bold()))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(person.name).font(.headline)
                        Text(person.detail).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(person.isFollowing ? "Following" : "Follow") {
                        person.isFollowing.toggle()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(person.isFollowing ? .secondary : Theme.primary)
                }
                .padding()
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}

private struct TrainingGroupsSection: View {
    @Binding var groups: [TrainingGroup]

    var body: some View {
        LazyVStack(spacing: 12) {
            CommunitySectionHeader(title: "Training Groups", subtitle: "Find a team for your next training block")
            ForEach($groups) { $group in
                CommunityJoinCard(
                    title: group.name,
                    subtitle: group.detail,
                    metadata: "\(group.members) members",
                    icon: group.icon,
                    color: group.color,
                    isJoined: $group.isJoined
                )
            }
        }
    }
}

private struct ChallengesSection: View {
    @Binding var challenges: [GroupChallenge]

    var body: some View {
        LazyVStack(spacing: 12) {
            CommunitySectionHeader(title: "Group Challenges", subtitle: "Join a goal and make progress together")
            ForEach($challenges) { $challenge in
                VStack(alignment: .leading, spacing: 12) {
                    CommunityJoinCard(
                        title: challenge.title,
                        subtitle: challenge.subtitle,
                        metadata: "\(challenge.participants) participants",
                        icon: challenge.icon,
                        color: challenge.color,
                        isJoined: $challenge.isJoined
                    )
                    ProgressView(value: challenge.progress)
                        .tint(challenge.color)
                    Text(challenge.progress, format: .percent.precision(.fractionLength(0)))
                        .font(.caption.bold())
                        .foregroundStyle(challenge.color)
                }
                .padding()
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }
}

private struct CommunityJoinCard: View {
    let title: String
    let subtitle: String
    let metadata: String
    let icon: String
    let color: Color
    @Binding var isJoined: Bool

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.16))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: icon).foregroundStyle(color).font(.title3))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
                Text(metadata).font(.caption2).foregroundStyle(color)
            }
            Spacer()
            Button(isJoined ? "Joined" : "Join") {
                isJoined.toggle()
            }
            .buttonStyle(.bordered)
            .tint(color)
        }
    }
}

private struct CommunitySectionHeader: View {
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.title3.bold())
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShareNoteView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    let onShare: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Note title", text: $title)
                TextField("What would you like to share?", text: $bodyText, axis: .vertical)
                    .lineLimit(5...10)
            }
            .navigationTitle("Share Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        onShare(title.trimmingCharacters(in: .whitespacesAndNewlines), bodyText.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private enum CommunitySampleData {
    static let notes = [
        CommunityNote(id: 1, author: "Lina A.", time: "35 min ago", title: "Easy-run pacing reminder", body: "Keep the first ten minutes genuinely easy. It makes the final third smoother and helps the group stay together.", tags: ["Running", "Recovery"], likes: 24, isLiked: false),
        CommunityNote(id: 2, author: "Omar K.", time: "2 hr ago", title: "Strength session notes", body: "Three quality sets beat five rushed sets. Track form, rest fully, then add load only when every rep looks consistent.", tags: ["Strength"], likes: 17, isLiked: true)
    ]

    static let people = [
        CommunityPerson(id: 1, name: "Sara Mohammed", detail: "10K runner · Riyadh", initials: "SM", isFollowing: true),
        CommunityPerson(id: 2, name: "Faisal Ahmed", detail: "Cycling · Endurance", initials: "FA", isFollowing: false),
        CommunityPerson(id: 3, name: "Noura Ali", detail: "Strength · Mobility", initials: "NA", isFollowing: false)
    ]

    static let groups = [
        TrainingGroup(id: 1, name: "Riyadh Morning Runners", detail: "Easy runs and weekend long runs", members: "2.3K", icon: "figure.run", color: .orange, isJoined: true),
        TrainingGroup(id: 2, name: "Women Who Lift", detail: "Progressive strength training", members: "1.8K", icon: "dumbbell.fill", color: .purple, isJoined: false),
        TrainingGroup(id: 3, name: "Weekend Cycling Club", detail: "Road rides for every pace", members: "940", icon: "bicycle", color: .blue, isJoined: false)
    ]

    static let challenges = [
        GroupChallenge(id: 1, title: "30-Day Consistency", subtitle: "Move for at least 20 minutes daily", progress: 0.63, participants: "4,280", icon: "calendar.badge.checkmark", color: .green, isJoined: true),
        GroupChallenge(id: 2, title: "Run 50K This Month", subtitle: "Build distance at your own pace", progress: 0.38, participants: "1,920", icon: "figure.run", color: .orange, isJoined: false),
        GroupChallenge(id: 3, title: "Mobility Week", subtitle: "Seven days of guided mobility", progress: 0.14, participants: "860", icon: "figure.cooldown", color: .mint, isJoined: false)
    ]
}

#Preview {
    CommunityPageView()
}
#endif
