import AVFoundation
import Foundation
import Speech

enum SpeechTranscriptionState: Equatable {
    case idle
    case requestingPermission
    case recording(text: String)
    case finalizing(text: String)
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

/// Tap-to-toggle Mandarin transcription. Audio is held only in the audio engine;
/// this service never persists the source recording.
@MainActor
final class SpeechTranscriptionService: NSObject, ObservableObject, SpeechTranscribing {
    @Published private(set) var state: SpeechTranscriptionState = .idle
    private let backend: SpeechRecognitionBackend
    private var durationTask: Task<Void, Never>?
    private var finalizationTask: Task<Void, Never>?
    private var generation = UUID()
    private let finalizationTimeout: Duration
    private let authorizeSpeech: () async -> SFSpeechRecognizerAuthorizationStatus
    private let authorizeMicrophone: () async -> Bool
    private let maximumDuration: Duration = .seconds(60)

    init(locale: Locale = Locale(identifier: "zh-CN"), audioEngine: AVAudioEngine = AVAudioEngine(),
         backend: SpeechRecognitionBackend? = nil, finalizationTimeout: Duration = .seconds(3),
         authorizeSpeech: @escaping () async -> SFSpeechRecognizerAuthorizationStatus = {
             await withCheckedContinuation { continuation in
                 SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
             }
         },
         authorizeMicrophone: @escaping () async -> Bool = {
             await AVAudioApplication.requestRecordPermission()
         }) {
        self.backend = backend ?? AppleSpeechRecognitionBackend(locale: locale, audioEngine: audioEngine)
        self.finalizationTimeout = finalizationTimeout
        self.authorizeSpeech = authorizeSpeech
        self.authorizeMicrophone = authorizeMicrophone
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: AVAudioSession.routeChangeNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// UI tests exercise the production service/controller without requiring
    /// microphone hardware or network recognition. Never enabled in Release.
    static func inputService() -> SpeechTranscriptionService {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--speech-ui-fixture") {
            return SpeechTranscriptionService(
                backend: UISpeechRecognitionBackend(), finalizationTimeout: .seconds(30),
                authorizeSpeech: { .authorized }, authorizeMicrophone: { true }
            )
        }
#endif
        return SpeechTranscriptionService()
    }

    func start() async {
        guard !Task.isCancelled else { return }
        switch state {
        case .requestingPermission, .recording, .finalizing: return
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
        guard backend.isAvailable else {
            state = .failed("speech_unavailable")
            return
        }
        do {
            state = .recording(text: "")
            try backend.start { [weak self] event in
                guard let self, self.generation == attempt else { return }
                self.receive(event)
            }
            durationTask = Task { [weak self] in
                try? await Task.sleep(for: self?.maximumDuration ?? .seconds(60))
                guard !Task.isCancelled, let self, self.generation == attempt else { return }
                self.stop()
            }
        } catch { cleanup(); state = .failed(error.localizedDescription) }
    }

    private var currentText: String? {
        switch state {
        case .recording(let text), .finalizing(let text): return text
        default: return nil
        }
    }

    private func receive(_ event: SpeechRecognitionEvent) {
        guard let previous = currentText else { return }
        switch event {
        case .transcript(let text, let isFinal):
            if isFinal { finish(text: text) }
            else if case .finalizing = state { state = .finalizing(text: text) }
            else { state = .recording(text: text) }
        case .failure:
            cleanup()
            state = .interrupted(text: previous)
        }
    }

    func stop() {
        if case .requestingPermission = state { cancel(); return }
        guard case let .recording(text) = state else { return }
        state = .finalizing(text: text)
        durationTask?.cancel()
        durationTask = nil
        let attempt = generation
        backend.endAudio()
        guard generation == attempt else { return }
        let timeout = finalizationTimeout
        finalizationTask = Task { [weak self] in
            try? await Task.sleep(for: timeout)
            guard !Task.isCancelled, let self, self.generation == attempt,
                  case .finalizing(let partial) = self.state else { return }
            self.cleanup()
            self.state = .interrupted(text: partial)
        }
    }

    func cancel() { cleanup(); state = .idle }

    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let text = currentText,
              let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: raw), type == .began else { return }
        cleanup()
        state = .interrupted(text: text)
    }

    @objc private func handleRouteChange(_ notification: Notification) {
        guard let text = currentText,
              let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: raw), reason == .oldDeviceUnavailable else { return }
        cleanup()
        state = .interrupted(text: text)
    }

    private func finish(text: String) { cleanup(); state = .final(text: text) }

    private func cleanup() {
        generation = UUID()
        durationTask?.cancel()
        durationTask = nil
        finalizationTask?.cancel()
        finalizationTask = nil
        backend.cancel()
    }
}

/// Events are delivered on the main actor, keeping AVFoundation callbacks out
/// of the presentation state. endAudio stops capture but allows a final result.
enum SpeechRecognitionEvent {
    case transcript(String, isFinal: Bool)
    case failure
}

@MainActor
protocol SpeechRecognitionBackend: AnyObject {
    var isAvailable: Bool { get }
    func start(_ receive: @escaping @MainActor (SpeechRecognitionEvent) -> Void) throws
    func endAudio()
    func cancel()
}

#if DEBUG
/// Attempt 1 waits for cancellation, 2 completes, 3 is interrupted, and later
/// attempts complete. Tests drive every transition through the same UI button.
@MainActor
private final class UISpeechRecognitionBackend: SpeechRecognitionBackend {
    let isAvailable = true
    private var attempt = 0
    private var receive: (@MainActor (SpeechRecognitionEvent) -> Void)?

    func start(_ receive: @escaping @MainActor (SpeechRecognitionEvent) -> Void) throws {
        attempt += 1
        self.receive = receive
        receive(.transcript("语音测试第 \(attempt) 次。", isFinal: false))
    }

    func endAudio() {
        guard attempt != 1 else { return }
        if attempt == 3 { receive?(.failure) }
        else { receive?(.transcript("语音测试第 \(attempt) 次。", isFinal: true)) }
    }

    func cancel() { receive = nil }
}
#endif

@MainActor
private final class AppleSpeechRecognitionBackend: SpeechRecognitionBackend {
    private let recognizer: SFSpeechRecognizer?
    private let audioEngine: AVAudioEngine
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var ownsAudioSession = false

    init(locale: Locale, audioEngine: AVAudioEngine) {
        recognizer = SFSpeechRecognizer(locale: locale)
        self.audioEngine = audioEngine
    }

    var isAvailable: Bool { recognizer?.isAvailable == true }

    func start(_ receive: @escaping @MainActor (SpeechRecognitionEvent) -> Void) throws {
        guard let recognizer else { throw PersistenceError.validationFailed("speech_unavailable") }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true)
        ownsAudioSession = true
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        self.request = request
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw PersistenceError.validationFailed("microphone_unavailable")
        }
        input.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in request.append(buffer) }
        tapInstalled = true
        audioEngine.prepare()
        try audioEngine.start()
        task = recognizer.recognitionTask(with: request) { result, error in
            let text = result?.bestTranscription.formattedString
            let isFinal = result?.isFinal == true
            let failed = error != nil
            Task { @MainActor in
                if let text { receive(.transcript(text, isFinal: isFinal)) }
                if failed && !isFinal { receive(.failure) }
            }
        }
    }

    func endAudio() {
        if audioEngine.isRunning { audioEngine.stop() }
        if tapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            tapInstalled = false
        }
        request?.endAudio()
        if ownsAudioSession {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            ownsAudioSession = false
        }
    }

    func cancel() {
        endAudio()
        task?.cancel()
        task = nil
        request = nil
    }
}
