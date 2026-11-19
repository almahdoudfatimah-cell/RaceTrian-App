import SwiftUI

/// Life Goals mirrored from the iPhone's Goals tab. Tap a goal to check in, which syncs back to the iPhone.
struct WatchLifeGoalsView: View {
    let store: WatchAppStore

    var body: some View {
        List {
            if store.lifeGoals.isEmpty {
                VStack(spacing: 4) {
                    Image(systemName: "target")
                        .font(.system(size: 18))
                        .foregroundStyle(WatchTheme.primary)
                    Text("No life goals yet")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WatchTheme.ink)
                    Text("Add goals in the Goals tab on iPhone.")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(WatchTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .watchPaperRow()
            } else {
                ForEach(store.lifeGoals) { goal in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            store.checkInLifeGoal(id: goal.id)
                        }
                    } label: {
                        WatchLifeGoalRow(goal: goal)
                    }
                    .disabled(goal.progress >= 1)
                    .watchPaperRow()
                }
            }
        }
        .font(WatchTheme.bodyFont)
        .foregroundStyle(WatchTheme.ink)
        .containerBackground(WatchTheme.paper, for: .navigation)
        .navigationTitle("Life Goals")
    }
}

private struct WatchLifeGoalRow: View {
    let goal: SyncedLifeGoal

    private var color: Color { Color(goal.color) }
    private var isComplete: Bool { goal.progress >= 1 }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.25), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: goal.progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(goal.emoji)
                    .font(.system(size: 13))
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(goal.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(WatchTheme.ink)
                    .lineLimit(2)
                Text(isComplete
                     ? "Completed"
                     : "\(Int(goal.progress * 100))% · \(goal.streak)d streak")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(WatchTheme.muted)
            }
            Spacer(minLength: 0)
            Image(systemName: isComplete ? "checkmark.seal.fill" : "plus.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(color)
        }
    }
}
