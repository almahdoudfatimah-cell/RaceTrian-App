import SwiftUI
import Observation
@preconcurrency import Speech
@preconcurrency import AVFoundation

@MainActor
@Observable
final class ScheduleVoiceRecorder {
    private(set) var transcript = ""
    private(set) var isRecording = false
    private(set) var isRequestingPermission = false
    var errorMessage: String?

    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private var request: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var hasTap = false
    @ObservationIgnored private var sessionID = UUID()

    func start() async {
        guard !isRecording, !isRequestingPermission else { return }
        stop()
        let identifier = UUID()
        sessionID = identifier
        isRequestingPermission = true
        errorMessage = nil
        transcript = ""
        defer { if sessionID == identifier { isRequestingPermission = false } }

        let authorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard sessionID == identifier else { return }
        guard authorized else {
            errorMessage = "Allow Speech Recognition in Settings to use voice entry. You can still type your activity."
            return
        }
        let microphoneAllowed = await AVAudioApplication.requestRecordPermission()
        guard sessionID == identifier else { return }
        guard microphoneAllowed else {
            errorMessage = "Allow Microphone access in Settings to use voice entry. You can still type your activity."
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: .current), recognizer.isAvailable else {
            errorMessage = "Speech recognition is unavailable for your current language. Please try again or type your activity."
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else {
                stop()
                errorMessage = "No microphone is available."
                return
            }
            let audioRequest = SFSpeechAudioBufferRecognitionRequest()
            audioRequest.shouldReportPartialResults = true
            // Prefer device recognition when the current language supports it.
            audioRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request = audioRequest
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { @Sendable buffer, _ in
                audioRequest.append(buffer)
            }
            hasTap = true
            recognitionTask = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
                let text = result?.bestTranscription.formattedString
                let finished = result?.isFinal ?? false
                let failed = error != nil
                Task { @MainActor [weak self] in
                    guard let self, self.sessionID == identifier else { return }
                    if let text { self.transcript = text }
                    if finished || failed {
                        self.stop()
                        if failed && self.transcript.isEmpty {
                            self.errorMessage = "No speech was recognized. Please try again or type your activity."
                        }
                    }
                }
            }
            engine.prepare()
            try engine.start()
            isRecording = true
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(55))
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            stop()
            errorMessage = "Could not start recording. Check the microphone and try again."
        }
    }

    func stop() {
        sessionID = UUID()
        timeoutTask?.cancel()
        timeoutTask = nil
        engine.stop()
        if hasTap {
            engine.inputNode.removeTap(onBus: 0)
            hasTap = false
        }
        request?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        request = nil
        isRecording = false
        isRequestingPermission = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

struct ScheduleVoiceInput: View {
    @Binding var text: String
    var onFinished: (String) -> Void = { _ in }
    @Environment(\.scenePhase) private var scenePhase
    @State private var recorder = ScheduleVoiceRecorder()
    @State private var originalText = ""
    @State private var startTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    originalText = text
                    startTask = Task { await recorder.start() }
                }
            } label: {
                Label(recorder.isRecording ? "Stop recording" : "Add by voice",
                      systemImage: recorder.isRecording ? "stop.circle.fill" : "mic.fill")
            }
            .disabled(recorder.isRequestingPermission)
            if recorder.isRequestingPermission {
                ProgressView("Preparing microphone…")
            }
            if recorder.isRecording {
                Text("Listening… Speak your activity, then tap Stop.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = recorder.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: recorder.transcript) { _, transcript in
            guard !transcript.isEmpty else { return }
            text = originalText.isEmpty ? transcript : originalText + "\n" + transcript
        }
        .onChange(of: recorder.isRecording) { wasRecording, recording in
            if wasRecording && !recording && !recorder.transcript.isEmpty {
                onFinished(recorder.transcript)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                startTask?.cancel()
                recorder.stop()
            }
        }
        .onDisappear {
            startTask?.cancel()
            recorder.stop()
        }
    }
}

// Spoken dates are suggestions only: the editor stays open for review before Save.
enum SpokenScheduleDates {
    static func interval(in text: String) -> DateInterval? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let matches = detector.matches(in: text, range: NSRange(text.startIndex..., in: text))
        if let first = matches.first, let start = first.date {
            if first.duration > 0 { return DateInterval(start: start, duration: first.duration) }
            if matches.count >= 2, let finish = matches[1].date, finish > start {
                return DateInterval(start: start, end: finish)
            }
        }
        return nil
    }
}
