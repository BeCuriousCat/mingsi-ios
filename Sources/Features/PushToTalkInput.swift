import Combine
import SwiftUI

/// Recognition is staged separately from the user's draft. Only explicit
/// acceptance appends it to the current draft, including any intervening edits.
struct SpeechInputDraft: Equatable {
    private(set) var isActive = false
    private(set) var isReviewing = false
    private(set) var isPreparing = false
    private(set) var isFinalizing = false
    var preview = ""
    private(set) var message: String?

    mutating func begin() {
        isActive = true
        isReviewing = false
        isPreparing = true
        isFinalizing = false
        preview = ""
        message = "正在准备录音…"
    }

    mutating func receive(_ state: SpeechTranscriptionState) {
        guard isActive else { return }
        switch state {
        case .idle: cancel()
        case .requestingPermission:
            isPreparing = true; isFinalizing = false; message = "请允许麦克风和语音识别权限"
        case .recording(let text):
            preview = text; isPreparing = false; message = "正在听，点右下角停止，最多 60 秒"
        case .finalizing(let text):
            preview = text; isPreparing = false; isFinalizing = true; message = "正在完成识别，点右下角取消"
        case .final(let text):
            preview = text; isActive = false; isPreparing = false; isFinalizing = false; isReviewing = true
            message = text.isEmpty ? "没有识别到文字，可以重新录音。" : "请检查识别文字，再添加到输入框。"
        case .interrupted(let text):
            preview = text; isActive = false; isPreparing = false; isFinalizing = false; isReviewing = true
            message = "录音已中断，请检查已识别的部分。"
        case .failed(let reason):
            isActive = false; isPreparing = false; isFinalizing = false; isReviewing = true
            switch reason {
            case "speech_permission_denied": message = "请在系统设置中允许语音识别，也可以继续打字。"
            case "microphone_permission_denied": message = "请在系统设置中允许麦克风，也可以继续打字。"
            default: message = "语音识别未完成，可以检查已有文字或重新录音。"
            }
        }
    }

    mutating func cancel() { self = SpeechInputDraft() }

    /// Move the control to its cancellable stopping state before the service
    /// publishes its final recognition callback.
    mutating func requestStop() {
        guard isActive, !isFinalizing else { return }
        isPreparing = false
        isFinalizing = true
        message = "正在完成识别，点右下角取消"
    }

    mutating func restart() {
        cancel()
        begin()
    }

    mutating func accept(into text: inout String) {
        guard isReviewing else { return }
        let value = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        text += (text.isEmpty || text.hasSuffix("\n") ? "" : "\n") + value
        cancel()
    }
}

/// Consume service transitions synchronously. SwiftUI onChange can coalesce or
/// deliver an old idle transition after a new recording has already begun.
@MainActor
final class SpeechInputController: ObservableObject {
    // Input fields share the device microphone even though each owns its draft.
    private static weak var microphoneOwner: SpeechInputController?
    @Published var draft = SpeechInputDraft()
    private let speech: SpeechTranscriptionService
    private var subscription: AnyCancellable?
    private var startTask: Task<Void, Never>?

    init(speech: SpeechTranscriptionService) {
        self.speech = speech
        subscription = speech.$state.dropFirst().sink { [weak self] state in
            guard let self else { return }
            self.draft.receive(state)
            if !self.draft.isActive, Self.microphoneOwner === self {
                Self.microphoneOwner = nil
            }
        }
    }

    func toggleRecording() {
        if draft.isActive {
            if draft.isFinalizing { discard() }
            else if case .recording = speech.state {
                draft.requestStop()
                speech.stop()
            } else { discard() }
        } else {
            discard()
            Self.microphoneOwner?.releaseMicrophone()
            Self.microphoneOwner = self
            draft.begin()
            startTask = Task { [weak self] in
                guard let self else { return }
                await self.speech.start()
            }
        }
    }

    func discard() {
        startTask?.cancel()
        startTask = nil
        speech.cancel()
        draft.cancel()
        if Self.microphoneOwner === self { Self.microphoneOwner = nil }
    }

    private func releaseMicrophone() {
        guard draft.isActive else { return }
        if draft.isPreparing {
            discard()
            return
        }
        startTask?.cancel()
        startTask = nil
        // Stop capture before the next field starts. Keep this field's partial
        // result for explicit review; cancelling the service rejects late callbacks.
        draft.receive(.interrupted(text: draft.preview))
        speech.cancel()
    }

    func accept(into text: inout String) {
        draft.accept(into: &text)
        if !draft.isReviewing { discard() }
    }
}

@MainActor
struct PushToTalkInput: View {
    @Binding var text: String
    var placeholder: String = "说点什么…"
    var accessibilityIdentifier: String?
    var focusBinding: Binding<Bool>?
    var usesTextEditor = false
    var autofocus = false
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var textFieldFocused: Bool
    @FocusState private var reviewFieldFocused: Bool
    @StateObject private var controller: SpeechInputController

    private var draft: SpeechInputDraft { controller.draft }

    init(
        text: Binding<String>,
        placeholder: String = "说点什么…",
        accessibilityIdentifier: String? = nil,
        focusBinding: Binding<Bool>? = nil,
        usesTextEditor: Bool = false,
        autofocus: Bool = false,
        speech: SpeechTranscriptionService? = nil
    ) {
        _text = text
        self.placeholder = placeholder
        self.accessibilityIdentifier = accessibilityIdentifier
        self.focusBinding = focusBinding
        self.usesTextEditor = usesTextEditor
        self.autofocus = autofocus
        _controller = StateObject(wrappedValue: SpeechInputController(speech: speech ?? SpeechTranscriptionService.inputService()))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            inputField
            if let message = draft.message {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: statusSymbol)
                        .font(.caption.weight(.semibold))
                    Text(message)
                        .font(.caption)
                }
                .foregroundStyle(statusTint)
                .accessibilityElement(children: .combine)
            }
            if draft.isReviewing {
                TextField("识别文字", text: $controller.draft.preview, axis: .vertical)
                    .lineLimit(2...6)
                    .focused($reviewFieldFocused)
                    .accessibilityLabel("待确认的识别文字")
                    .accessibilityIdentifier(controlIdentifier("review"))
                HStack(spacing: 8) {
                    Button {
                        controller.accept(into: &text)
                    } label: {
                        Label("添加到输入框", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .foregroundStyle(DS.onAccent)
                    .accessibilityIdentifier(controlIdentifier("accept"))
                    .disabled(draft.preview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                Button("丢弃本次识别", role: .cancel) { controller.discard() }
                    .frame(minHeight: 44)
                    .accessibilityIdentifier(controlIdentifier("discard"))
            } else if !draft.preview.isEmpty {
                Text(draft.preview).foregroundStyle(DS.ink)
            }
        }
        .accessibilityElement(children: .contain)
        .padding(12)
        .onChange(of: textFieldFocused) { _, focused in
            focusBinding?.wrappedValue = focused
        }
        .onChange(of: externalFocusValue) { _, focused in
            guard textFieldFocused != focused else { return }
            textFieldFocused = focused
        }
        .onAppear { textFieldFocused = externalFocusValue }
        .task(id: autofocus) {
            guard autofocus else { return }
            // Focus after the native editor has mounted.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            textFieldFocused = true
            focusBinding?.wrappedValue = true
        }
        .onChange(of: scenePhase) { _, phase in
            // Permission dialogs can make the scene inactive; they must not
            // discard the pending authorization. Backgrounding always cancels.
            if phase == .background { controller.discard() }
        }
        .onDisappear {
            controller.discard()
        }
    }

    @ViewBuilder
    private var inputField: some View {
        ZStack(alignment: .topLeading) {
            if usesTextEditor {
                TextEditor(text: $text)
                    .frame(minHeight: usesTextEditor ? 64 : 44, maxHeight: usesTextEditor ? 220 : 140)
                    .scrollContentBackground(.hidden)
                    .focused($textFieldFocused)
                    .accessibilityLabel(placeholder)
                    .modifier(InputIdentifierModifier(identifier: accessibilityIdentifier))
                    .padding(.trailing, controlTrailingPadding)
            } else {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .frame(minHeight: 52)
                    .focused($textFieldFocused)
                    .accessibilityLabel(placeholder)
                    .modifier(InputIdentifierModifier(identifier: accessibilityIdentifier))
                    .padding(.trailing, controlTrailingPadding)
            }
            if usesTextEditor && text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(DS.mutedInk)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 8)
                    .padding(.trailing, controlTrailingPadding)
                    .allowsHitTesting(false)
            }

        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                if textFieldFocused || reviewFieldFocused {
                    Button { dismissKeyboard() } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(DS.mutedInk)
                            .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(VoiceInputButtonStyle())
                    .accessibilityLabel("收起键盘")
                    .accessibilityHint("保留输入和待确认的识别文字")
                    .accessibilityIdentifier(accessibilityIdentifier.map { "\($0).keyboard-dismiss" } ?? "speech-input.keyboard-dismiss")
                }
                Button {
                    dismissKeyboard()
                    controller.toggleRecording()
                } label: {
                    Image(systemName: voiceButtonSymbol)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(voiceButtonTint)
                        .frame(width: DS.minimumTapTarget, height: DS.minimumTapTarget)
                        .background(
                            voiceButtonTint.opacity(0.12),
                            in: Circle()
                        )
                        .overlay {
                            if draft.isActive {
                                Circle().stroke(voiceButtonTint.opacity(0.32), lineWidth: 1)
                            }
                        }
                        .contentShape(Circle())
                }
                .buttonStyle(VoiceInputButtonStyle())
                .accessibilityLabel(voiceButtonLabel)
                .accessibilityHint(voiceButtonHint)
                .accessibilityIdentifier(voiceToggleIdentifier)
            }
            .padding(.trailing, 8)
            .padding(.bottom, usesTextEditor ? 6 : 4)
        }
        .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        }
    }

    private var externalFocusValue: Bool {
        focusBinding?.wrappedValue ?? false
    }

    private var controlTrailingPadding: CGFloat {
        textFieldFocused || reviewFieldFocused ? 108 : 56
    }

    private func dismissKeyboard() {
        textFieldFocused = false
        reviewFieldFocused = false
        focusBinding?.wrappedValue = false
    }

    private var voiceToggleIdentifier: String { controlIdentifier("toggle") }

    private func controlIdentifier(_ action: String) -> String {
        accessibilityIdentifier.map { "\($0).voice-\(action)" } ?? "speech-input.\(action)"
    }

    private var voiceButtonLabel: String {
        if draft.isFinalizing { return "取消语音识别" }
        if draft.isPreparing { return "取消语音输入准备" }
        if draft.isActive { return "停止语音输入" }
        return draft.isReviewing ? "重新录音" : "开始语音输入"
    }

    private var voiceButtonSymbol: String {
        if draft.isFinalizing { return "xmark" }
        if draft.isPreparing { return "xmark" }
        if draft.isActive { return "stop.fill" }
        return draft.isReviewing ? "arrow.clockwise" : "mic.fill"
    }

    private var voiceButtonHint: String {
        if draft.isFinalizing { return "取消等待中的识别" }
        if draft.isPreparing { return "取消权限请求或录音准备" }
        if draft.isActive { return "点按结束录音并查看识别文字" }
        return draft.isReviewing ? "放弃当前识别并重新录音" : "点按开始语音输入"
    }

    private var voiceButtonTint: Color {
        draft.isActive ? DS.caution : DS.accent
    }

    private var statusSymbol: String {
        if draft.isFinalizing { return "ellipsis.circle" }
        if draft.isActive { return draft.isPreparing ? "mic" : "waveform" }
        if draft.isReviewing { return "checkmark.circle" }
        return "info.circle"
    }

    private var statusTint: Color {
        draft.isReviewing ? DS.accent : (draft.isActive ? DS.caution : DS.mutedInk)
    }
}

private struct VoiceInputButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.62 : 1)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct InputIdentifierModifier: ViewModifier {
    let identifier: String?

    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}
