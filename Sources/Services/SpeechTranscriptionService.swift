import AVFoundation
import Foundation
import Speech

enum SpeechTranscriptionState: Equatable {
    case idle
    case requestingPermission
    case recording(text: String)
    case interrupted(text: String)
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
    private var generation = UUID()
    private var tapInstalled = false
    private var ownsAudioSession = false
    private let authorizeSpeech: () async -> SFSpeechRecognizerAuthorizationStatus
    private let authorizeMicrophone: () async -> Bool
    private let maximumDuration: Duration = .seconds(60)

    init(locale: Locale = Locale(identifier: "zh-CN"), audioEngine: AVAudioEngine = AVAudioEngine(),
         authorizeSpeech: @escaping () async -> SFSpeechRecognizerAuthorizationStatus = {
             await withCheckedContinuation { continuation in
                 SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
             }
         },
         authorizeMicrophone: @escaping () async -> Bool = {
             await AVAudioApplication.requestRecordPermission()
         }) {
        self.recognizer = SFSpeechRecognizer(locale: locale)
        self.audioEngine = audioEngine
        self.authorizeSpeech = authorizeSpeech
        self.authorizeMicrophone = authorizeMicrophone
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    func start() async {
        switch state {
        case .requestingPermission, .recording: return
        default: break
        }
        cleanup()
        let attempt = UUID()
        generation = attempt
        state = .requestingPermission
        let speech = await authorizeSpeech()
        guard generation == attempt else { return }
        guard !Task.isCancelled else { cancel(); return }
        guard speech == .authorized else {
            state = .failed("speech_permission_denied")
            return
        }
        let microphone = await authorizeMicrophone()
        guard generation == attempt else { return }
        guard !Task.isCancelled else { cancel(); return }
        guard microphone else {
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
            try session.setActive(true)
            ownsAudioSession = true
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            self.request = request
            let input = audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1_024, format: input.outputFormat(forBus: 0)) { buffer, _ in
                request.append(buffer)
            }
            tapInstalled = true
            audioEngine.prepare()
            try audioEngine.start()
            state = .recording(text: "")
            durationTask = Task { [weak self] in
                try? await Task.sleep(for: self?.maximumDuration ?? .seconds(60))
                guard !Task.isCancelled else { return }
                await MainActor.run { [weak self] in
                    guard let self, self.generation == attempt, case .recording = self.state else { return }
                    self.stop()
                }
            }
            task = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor [weak self] in
                    guard let self, self.generation == attempt, case .recording = self.state else { return }
                    if let result {
                        self.state = .recording(text: result.bestTranscription.formattedString)
                        if result.isFinal { self.finish(text: result.bestTranscription.formattedString) }
                    } else if let error, !Task.isCancelled { self.cleanup(); self.state = .failed(error.localizedDescription) }
                }
            }
        } catch { state = .failed(error.localizedDescription); cleanup() }
    }

    func stop() {
        if case .requestingPermission = state { cancel(); return }
        guard case let .recording(text) = state else { return }
        finish(text: text)
    }

    func cancel() { cleanup(); state = .idle }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard case let .recording(text) = state,
              let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw), type == .began else { return }
        cleanup()
        state = .interrupted(text: text)
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard case let .recording(text) = state,
              let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw), reason == .oldDeviceUnavailable else { return }
        cleanup()
        state = .interrupted(text: text)
    }

    private func finish(text: String) { cleanup(); state = .final(text: text) }

    private func cleanup() {
        generation = UUID()
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        task?.cancel()
        task = nil
        durationTask?.cancel()
        durationTask = nil
        request = nil
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }
}
