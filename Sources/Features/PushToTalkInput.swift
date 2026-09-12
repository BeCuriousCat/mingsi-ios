import SwiftUI

/// A reusable press-and-hold control. The recognized text is returned through
/// the binding only after the user releases; partial text remains visible while
/// recording so the user can cancel before it enters the draft.
struct PushToTalkInput: View {
    @Binding var text: String
    @StateObject private var speech: SpeechTranscriptionService
    @State private var isPressing = false
    @State private var cancelOnRelease = false

    @MainActor
    init(text: Binding<String>, speech: SpeechTranscriptionService? = nil) {
        _text = text
        _speech = StateObject(wrappedValue: speech ?? SpeechTranscriptionService())
    }

    var body: some View {
        HStack(spacing: 12) {
            TextField("说点什么…", text: $text, axis: .vertical)
                .lineLimit(1...5)
            Text(isPressing ? (cancelOnRelease ? "松开取消" : "松开识别") : "按住说话")
                .font(.caption)
                .foregroundStyle(cancelOnRelease ? .red : .secondary)
            Image(systemName: isPressing ? "waveform" : "mic.fill")
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .gesture(pressGesture)
                .accessibilityLabel("按住说话")
                .accessibilityHint("松开后将识别文字放入输入框")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onChange(of: speech.state) { _, newState in
            if case let .recording(partial) = newState { isPressing = true; if cancelOnRelease == false { text = partial } }
            if case let .final(value) = newState, !cancelOnRelease { text = value }
            if case .failed = newState { isPressing = false }
        }
    }

    private var pressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15)
            .onEnded { _ in
                guard !isPressing else { return }
                isPressing = true
                cancelOnRelease = false
                Task { await speech.start() }
            }
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard case .second(true, let drag?) = value else { return }
                cancelOnRelease = drag.translation.width < -70
            }
            .onEnded { _ in
                guard isPressing else { return }
                if cancelOnRelease { speech.cancel() } else { speech.stop() }
                isPressing = false
                cancelOnRelease = false
            }
    }
}
