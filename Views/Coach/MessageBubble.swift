import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 40) }

            if message.role == .assistant {
                assistantAvatar
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                bubble
                timeLabel
            }

            if message.role == .assistant { Spacer(minLength: 40) }
        }
    }

    private var bubble: some View {
        ChatMessageContent(content: message.content, rendersTables: message.role == .assistant)
            .font(.system(size: Theme.fontSize(15), design: .rounded))
            .foregroundStyle(message.role == .user ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                if message.role == .user {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Theme.heroGradient)
                } else {
                    // Coach message: tinted card with left accent strip
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Theme.primary.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(Theme.primary.opacity(0.18), lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Theme.heroGradient)
                            .frame(width: 4)
                            .padding(.vertical, 10)
                            .padding(.leading, -1)
                    }
                }
            }
            .shadow(color: message.role == .user ? Theme.primary.opacity(0.25) : Theme.primary.opacity(0.08),
                    radius: 8, x: 0, y: 4)
    }

    private var timeLabel: some View {
        Text(message.timestamp, style: .time)
            .font(.system(size: Theme.fontSize(10), design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(Theme.heroGradient)
                .frame(width: 30, height: 30)
                .shadow(color: Theme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
            Text("✦")
                .font(.system(size: Theme.fontSize(13), weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

// Message text is immutable once delivered, so source line IDs remain stable.
private struct ChatContentLine: Identifiable {
    let id: Int
    let text: String
    let cells: [String]?

    var isSeparator: Bool {
        guard let cells else { return false }
        return cells.allSatisfy { cell in
            cell.contains("-") && cell.allSatisfy { "-: ".contains($0) }
        }
    }
}

private struct ChatMessageContent: View {
    let lines: [ChatContentLine]

    init(content: String, rendersTables: Bool) {
        lines = content.components(separatedBy: .newlines).enumerated().map { index, line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let cells = trimmed.split(separator: "|", omittingEmptySubsequences: false)
                .dropFirst().dropLast()
                .map { $0.trimmingCharacters(in: .whitespaces) }
            return ChatContentLine(
                id: index,
                text: line,
                cells: rendersTables && trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && cells.count == 2
                    ? cells : nil
            )
        }.filter { !$0.isSeparator }
    }

    var body: some View {
        Grid(alignment: .topLeading, horizontalSpacing: 12, verticalSpacing: 8) {
            ForEach(lines) { line in
                if let cells = line.cells {
                    GridRow(alignment: .top) {
                        Text(cells[0])
                            .monospacedDigit()
                        Text(cells[1])
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .fontWeight(cells[0].lowercased() == "time" ? .bold : .regular)
                    .padding(.vertical, 6)
                    .background(Theme.primary.opacity(0.05))
                } else if !line.text.isEmpty {
                    Text(line.text)
                        .gridCellColumns(2)
                }
            }
        }
        .font(.subheadline)
        .fixedSize(horizontal: false, vertical: true)
        .textSelection(.enabled)
    }
}

struct ThinkingBubble: View {
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(Theme.heroGradient).frame(width: 30, height: 30)
                    .shadow(color: Theme.primary.opacity(0.3), radius: 6, x: 0, y: 3)
                Text("✦")
                    .font(.system(size: Theme.fontSize(13), weight: .bold))
                    .foregroundStyle(.white)
            }
            HStack(spacing: 5) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(Theme.primary.opacity(0.6))
                        .frame(width: 7, height: 7)
                        .offset(y: phase == i ? -4 : 0)
                        .animation(
                            .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                            value: phase
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
            Spacer(minLength: 40)
        }
        .onAppear {
            withAnimation { phase = 1 }
        }
    }
}

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.rose)
            Text(message)
                .font(.system(size: Theme.fontSize(13), design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundStyle(.secondary)
                    .font(.system(size: Theme.fontSize(12), weight: .bold))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Theme.rose.opacity(0.12))
                .overlay(RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.rose.opacity(0.3), lineWidth: 1))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 4)
    }
}
