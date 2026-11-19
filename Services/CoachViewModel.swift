import SwiftUI
import Combine

@MainActor
final class CoachViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isThinking = false
    @Published var errorBanner: String? = nil
    @Published var showWelcome = true
    @Published private(set) var failedMessage: String?

    func send(text: String) async {
        guard !isThinking, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        showWelcome = false
        errorBanner = nil
        failedMessage = nil
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        isThinking = true
        defer { isThinking = false }

        let apiMessages = messages.map { message in
            ["role": message.role == .user ? "user" : "assistant", "content": message.content]
        }
        do {
            let reply = try await CoachService.shared.sendMessages(apiMessages)
            messages.append(ChatMessage(role: .assistant, content: reply))
        } catch {
            // Keep failed requests out of model history; retry restores the same user turn.
            messages.removeAll { $0.id == userMessage.id }
            failedMessage = text
            errorBanner = error.localizedDescription
        }
    }

    func retry() async {
        guard let failedMessage else { return }
        await send(text: failedMessage)
    }

    func clear() {
        guard !isThinking else { return }
        messages = []
        showWelcome = true
        errorBanner = nil
        failedMessage = nil
    }
}
