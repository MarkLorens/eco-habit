import AVFoundation
import Combine
import Foundation
import Speech

/// Live speech-to-text for the search field. Wraps `SFSpeechRecognizer` and an audio tap
/// so a view only has to call `toggle()` and watch `transcript`.
///
/// Needs both `NSMicrophoneUsageDescription` and `NSSpeechRecognitionUsageDescription`;
/// they are two separate grants and the user can refuse either one independently.
@MainActor
final class DictationService: ObservableObject {

    @Published private(set) var isRecording = false
    /// Partial results land here as the user speaks, so the caller sees live text.
    @Published private(set) var transcript = ""
    /// Set when the user needs telling — a refused permission or an unavailable
    /// recogniser. Cleared on the next successful start.
    @Published var errorMessage: String?

    private let recognizer = SFSpeechRecognizer(locale: Locale.current)
    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// False when the device has no recogniser for this locale at all. Callers should
    /// hide the button rather than offer something that can never work.
    var isSupported: Bool { recognizer != nil }

    func toggle() {
        if isRecording {
            stop()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            errorMessage = "Dictation isn’t available right now."
            return
        }
        guard await requestAuthorisation() else { return }

        do {
            errorMessage = nil
            transcript = ""
            try beginSession(with: recognizer)
            isRecording = true
        } catch {
            errorMessage = "Couldn’t start the microphone."
            teardown()
        }
    }

    func stop() {
        guard isRecording else { return }
        isRecording = false
        teardown()
    }

    // MARK: - Permissions

    private func requestAuthorisation() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            errorMessage = "Speech recognition is off. Turn it on in Settings to dictate."
            return false
        }

        let microphone = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard microphone else {
            errorMessage = "Microphone access is off. Turn it on in Settings to dictate."
            return false
        }
        return true
    }

    // MARK: - Session

    private func beginSession(with recognizer: SFSpeechRecognizer) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request

        // Runs on an audio thread — appending the buffer is all it may safely do here.
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        try engine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            // Recognition callbacks arrive on an arbitrary queue.
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.stop() }
                }
                if error != nil { self.stop() }
            }
        }
    }

    private func teardown() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        request?.endAudio()
        request = nil
        task?.cancel()
        task = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
