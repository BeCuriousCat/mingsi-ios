import AVFoundation
import Foundation
import Speech

enum SpeechTranscriptionState: Equatable {
    case idle
    case requestingPermission
    case recording(text: String)
    case final(text: String)
    case failed(String)
}

@MainActor
protocol SpeechTranscribing: AnyObject {
    var state: SpeechTranscriptionState { get }
    func start() async
    func stop()
    func cancel()
}

/// Push-to-talk Mandarin transcription. Audio is held only in the audio engine;
/// this service never persists the source recording.
@MainActor
final class SpeechTranscriptionService: NSObject, ObservableObject, SpeechTranscribing {
    @Published private(set) var state: SpeechTranscriptionState = .idle
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine: AVAudioEngine
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var durationTask: Task<Void, Never>?
    private let maximumDuration: Duration = .seconds(60)

    init(locale: Locale = Locale(identifier: "zh-CN"), audioEngine: AVAudioEngine = AVAudioEngine()) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        self.audioEngine = audioEngine
        super.init()
    }

    func start() async {
        guard case .idle = state else { return }
        state = .requestingPermission
        let speech: SFSpeechRecognizerAuthorizationStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized else {
            state = .failed("speech_permission_denied")
            return
        }
        let microphone = AVAudioSession.sharedInstance().recordPermission
        if microphone == .undetermined {
            let granted: Bool = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
            }
            guard granted else { state = .failed("microphone_permission_denied"); return }
        } else if microphone != .granted {
            state = .failed("microphone_permission_denied")
            return
        }
        guard let recognizer, recognizer.isAvailable else {
            state = .failed("speech_unavailable")
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = audioEngine.inputNode
            input.removeTap(onBus: 0)
            input.installTap(onBus: 0, bufferSize: 1_024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
                self?.request?.append(buffer)
            }
            audioEngine.prepare()
            try audioEngine.start()
            state = .recording(text: "")
            durationTask = Task { [weak self] in
                try? await Task.sleep(for: self?.maximumDuration ?? .seconds(60))
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, case .recording = self.state else { return }
                    self.stop()
                }
            }
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    if let result {
                        self.state = .recording(text: result.bestTranscription.formattedString)
                        if result.isFinal { self.finish(text: result.bestTranscription.formattedString) }
                    } else if let error, !Task.isCancelled { self.state = .failed(error.localizedDescription) }
                }
            }
        } catch { state = .failed(error.localizedDescription); cleanup() }
    }

    func stop() {
        guard case let .recording(text) = state else { return }
        finish(text: text)
    }

    func cancel() { cleanup(); state = .idle }

    private func finish(text: String) { cleanup(); state = .final(text: text) }

    private func cleanup() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        task = nil
        durationTask?.cancel()
        durationTask = nil
        request = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
