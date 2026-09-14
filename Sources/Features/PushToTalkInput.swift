import SwiftUI

/// Recognition is staged separately from the user's draft. Only explicit
/// acceptance appends it to the current draft, including any intervening edits.
struct SpeechInputDraft: Equatable {
    private(set) var isActive = false
    private(set) var isReviewing = false
    var preview = ""
    private(set) var message: String?

    mutating func begin() {
        isActive = true
        isReviewing = false
        preview = ""
        message = "正在准备录音…"
    }

    mutating func receive(_ state: SpeechTranscriptionState) {
        guard isActive else { return }
        switch state {
        case .idle: cancel()
        case .requestingPermission: message = "请允许麦克风和语音识别权限"
        case .recording(let text): preview = text; message = "正在听，最多 60 秒"
        case .final(let text):
            preview = text; isActive = false; isReviewing = true
            message = text.isEmpty ? "没有识别到文字，可以重新录音。" : "请检查识别文字，再添加到输入框。"
        case .interrupted(let text):
            preview = text; isActive = false; isReviewing = true
            message = "录音已中断，请检查已识别的部分。"
        case .failed(let reason):
            isActive = false; isReviewing = true
            switch reason {
            case "speech_permission_denied": message = "请在系统设置中允许语音识别，也可以继续打字。"
            case "microphone_permission_denied": message = "请在系统设置中允许麦克风，也可以继续打字。"
            default: message = "语音识别未完成，可以检查已有文字或重新录音。"
            }
        }
    }

    mutating func cancel() { self = SpeechInputDraft() }

    mutating func accept(into text: inout String) {
        guard isReviewing else { return }
        let value = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        text += (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + value
        cancel()
    }
}

@MainActor
struct PushToTalkInput: View {
    @Binding var text: String
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var speech: SpeechTranscriptionService
    @State private var draft = SpeechInputDraft()
    @State private var isPressing = false
    @State private var cancelOnRelease = false
    @State private var startTask: Task<Void, Never>?

    init(text: Binding<String>, speech: SpeechTranscriptionService? = nil) {
        _text = text
        _speech = StateObject(wrappedValue: speech ?? SpeechTranscriptionService())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("说点什么…", text: $text, axis: .vertical)
                .lineLimit(1...5)
                .accessibilityLabel("交流内容")
            Label(isPressing ? (cancelOnRelease ? "松开取消" : "松开结束，左滑取消") : "按住说话", systemImage: "mic.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(DS.background)
                .contentShape(Rectangle())
                .gesture(pressGesture)
                .accessibilityHidden(true)
            Button(draft.isActive ? "结束录音" : "点击开始录音") {
                if draft.isActive { release() } else { begin() }
            }
            .frame(minHeight: 44)
            .disabled(draft.isReviewing)
            if let message = draft.message {
                Text(message).font(.callout).foregroundStyle(DS.mutedInk)
            }
            if draft.isReviewing {
                TextField("识别文字", text: $draft.preview, axis: .vertical)
                    .lineLimit(2...6)
                    .accessibilityLabel("待确认的识别文字")
                Button("添加到输入框") { draft.accept(into: &text) }
                    .frame(minHeight: 44)
                    .disabled(draft.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("丢弃本次识别") { discard() }.frame(minHeight: 44)
            } else if !draft.preview.isEmpty {
                Text(draft.preview).foregroundStyle(DS.ink)
            }
        }
        .padding(12)
        .onChange(of: speech.state) { _, state in draft.receive(state) }
        .onChange(of: scenePhase) { _, phase in
            // Permission dialogs can make the scene inactive; they must not
            // discard the pending authorization. Backgrounding always cancels.
            if phase == .background { discard() }
        }
        .onDisappear { discard() }
    }

    private func begin() {
        guard !draft.isActive, !draft.isReviewing else { return }
        draft.begin()
        startTask = Task { await speech.start() }
    }

    private func release() {
        startTask?.cancel()
        startTask = nil
        speech.stop()
        draft.receive(speech.state)
    }

    private func discard() {
        startTask?.cancel()
        startTask = nil
        draft.cancel()
        speech.cancel()
        isPressing = false
        cancelOnRelease = false
    }

    private var pressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if !isPressing {
                    guard !draft.isActive, !draft.isReviewing else { return }
                    isPressing = true
                    begin()
                }
                cancelOnRelease = value.translation.width < -70
            }
            .onEnded { _ in
                guard isPressing else { return }
                if cancelOnRelease { discard() } else { release() }
                isPressing = false
                cancelOnRelease = false
            }
    }
}
