import SwiftUI

struct TimelineView: View {
    @Binding var tasks: [PlanTask]
    @Binding var selectedDate: Date

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 14) {
            if tasks.isEmpty {
                ContentUnavailableView("Your day is open", systemImage: "calendar",
                                       description: Text("Add a task to start planning this day."))
            }
            ForEach($tasks) { $task in
                PlannerTimelineRow(task: $task) {
                    tasks.removeAll { $0.id == task.id }
                }
            }
        }
    }
}

private struct PlannerTimelineRow: View {
    @Binding var task: PlanTask
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 6) {
                Circle().fill(task.category.tint).frame(width: 10, height: 10)
                Rectangle().fill(task.category.tint.opacity(0.25)).frame(width: 2)
            }
            .frame(width: 12)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(task.time).font(.subheadline.weight(.semibold))
                    Spacer()
                    Text("\(task.durationSlots * 30) min").font(.caption).foregroundStyle(.secondary)
                }
                Text(task.title)
                    .font(.body.weight(.medium))
                    .strikethrough(task.isDone)
                    .fixedSize(horizontal: false, vertical: true)
                Label(task.category.rawValue, systemImage: task.category.icon)
                    .font(.caption).foregroundStyle(task.category.tint)
                HStack {
                    Button {
                        task.isDone.toggle()
                    } label: {
                        Label(task.isDone ? "Completed" : "Mark complete",
                              systemImage: task.isDone ? "checkmark.circle.fill" : "circle")
                    }
                    .accessibilityLabel("\(task.isDone ? "Mark incomplete" : "Mark complete"): \(task.title)")
                    Spacer()
                    Menu {
                        Button("Delete task", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Options for \(task.title)")
                }
                .font(.subheadline)
                .buttonStyle(.borderless)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(task.category.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
