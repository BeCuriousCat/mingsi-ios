import SwiftUI

/// Presented by the conversation surface after selecting or beginning a draft.
/// This page never owns a second copy of the user's text.
struct MentorUnderstandingEditor: View {
    @ObservedObject var store: MentorFeatureStore
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isEditing: Bool
    @State private var isClosing = false
    @State private var closeFailed = false
    @State private var requestedConfirmation = false
    @State private var showsDiscardConfirmation = false

    private var locked: Bool {
        isClosing || store.state.isTransitioningSession || store.state.isConfirmingUnderstanding
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("用自己的话，留下这一点")
                        .font(.title2.weight(.semibold))
                        .accessibilityAddTraits(.isHeader)
                    Text("可以只写一句。返回会保留草稿；确认后，才会成为“我的理解”。")
                        .foregroundStyle(DS.mutedInk)

                    if store.state.understanding?.state == .confirmed {
                        Text(store.state.understanding?.text ?? "")
                            .textSelection(.enabled)
                        Label("已保存为我的理解", systemImage: "checkmark.circle")
                            .foregroundStyle(DS.accentInk)
                            .accessibilityIdentifier("mentor.understanding.confirmed")
                    } else {
                        editor
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(DS.pagePadding)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(DS.background)
            .foregroundStyle(DS.ink)
            .navigationTitle("我的理解")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(DS.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { close() }
                        .frame(minWidth: 44, minHeight: 44)
                        .disabled(locked)
                        .accessibilityIdentifier("mentor.understanding.back")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("收起键盘") { isEditing = false }
                        .frame(minHeight: 44)
                }
            }
            .tint(DS.accent)
        }
        // All exits go through the save barrier; swiping cannot bypass it.
        .interactiveDismissDisabled()
        .confirmationDialog("放弃这份理解尚未保存的修改？", isPresented: $showsDiscardConfirmation,
                            titleVisibility: .visible) {
            Button("放弃修改并返回", role: .destructive) {
                isEditing = false
                isClosing = true
                Task { @MainActor in
                    let discarded = await store.discardUnderstandingEdits()
                    isClosing = false
                    if discarded { dismiss() }
                    else { closeFailed = true }
                }
            }
            Button("继续编辑", role: .cancel) {}
        } message: {
            Text("将保留已经保存的草稿和已确认版本，只放弃这份理解尚未保存的文字。")
        }
        .onChange(of: store.state.isConfirmingUnderstanding) { _, confirming in
            guard requestedConfirmation, !confirming else { return }
            requestedConfirmation = false
            if store.state.understanding?.state == .confirmed { dismiss() }
        }
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("理解正文").font(.headline)
            TextEditor(text: Binding(
                get: { store.state.understandingInputText },
                set: { store.updateUnderstandingText($0) }
            ))
            .font(.body)
            .frame(minHeight: 200)
            .padding(8)
            .scrollContentBackground(.hidden)
            .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: DS.cornerRadius).stroke(DS.hairline))
            .focused($isEditing)
            .disabled(locked)
            .accessibilityLabel("理解正文")
            .accessibilityHint("输入会自动保存为草稿，确认后保存为我的理解。")
            .accessibilityIdentifier("mentor.understanding.input")

            if store.state.understandingError != nil || closeFailed {
                Label("暂时没有保存成功，文字仍留在这里。可以重试，或放弃未保存修改。", systemImage: "exclamationmark.circle")
                    .foregroundStyle(DS.caution)
                    .accessibilityIdentifier("mentor.understanding.error")
                Button("重试保存") {
                    closeFailed = false
                    store.retryUnderstandingSave()
                    isClosing = true
                    Task { @MainActor in
                        closeFailed = !(await store.flushPendingEdits())
                        isClosing = false
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(minHeight: 44)
                .disabled(locked || store.state.pendingUnderstandingOperations > 0)
                .accessibilityIdentifier("mentor.understanding.retry")
                Button(role: .destructive) {
                    showsDiscardConfirmation = true
                } label: {
                    Text("放弃未保存修改并返回").frame(minHeight: 44)
                }
                .disabled(locked)
                .accessibilityIdentifier("mentor.understanding.discard")
            } else {
                Text(saveStatus)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier("mentor.understanding.save-status")
            }

            Button {
                isEditing = false
                requestedConfirmation = true
                store.confirmUnderstanding()
                if !store.state.isConfirmingUnderstanding { requestedConfirmation = false }
            } label: {
                Text(store.state.isConfirmingUnderstanding ? "正在保存…" : "保存为我的理解")
                    .foregroundStyle(DS.background)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(locked || store.state.understandingError != nil ||
                      store.state.understandingInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("mentor.understanding.confirm")
        }
    }

    private var saveStatus: String {
        if isClosing { return "正在保存草稿…" }
        if store.state.pendingUnderstandingOperations > 0 { return "正在保存草稿…" }
        if store.state.hasUnsavedUnderstanding { return "等待保存草稿…" }
        return "草稿已保存，尚未确认"
    }

    private func close() {
        isEditing = false
        isClosing = true
        closeFailed = false
        Task { @MainActor in
            let saved = await store.flushPendingEdits()
            isClosing = false
            if saved { dismiss() }
            else { closeFailed = true }
        }
    }
}

/// Local, explicit user-note entry; it does not claim to generate an AI summary.
struct MentorUnderstandingSection: View {
    @ObservedObject var store: MentorFeatureStore
    @State private var showsEditor = false
    @State private var groupToDelete: UUID?
    @State private var showsDeleteConfirmation = false

    private var canOpenEditor: Bool {
        store.state.session != nil && !store.state.isViewingHistory && !store.state.isTransitioningSession &&
        store.state.pendingUnderstandingOperations == 0 && !store.state.hasUnsavedUnderstanding &&
        store.state.understandingError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("我的理解").font(.headline).accessibilityAddTraits(.isHeader)
            if store.state.isDeletingUnderstanding {
                ProgressView("正在删除这组理解…")
            }
            if let error = store.state.understandingDeletionError {
                Text(error).foregroundStyle(DS.caution)
                    .accessibilityIdentifier("mentor.understanding.delete-error")
            }
            ForEach(store.state.understandings, id: \.id) { note in
                VStack(alignment: .leading, spacing: 8) {
                    Text(note.text.isEmpty ? "还没写完的草稿" : note.text)
                        .textSelection(.enabled)
                    Text(note.state == .confirmed ? "已确认 · 第 \(note.revision) 版" : "未确认草稿")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                    if note.state == .draft {
                        Button {
                            store.selectUnderstandingDraft(id: note.id)
                            if store.state.understanding?.id == note.id { showsEditor = true }
                        } label: {
                            Text("继续编辑").frame(minHeight: 44)
                        }
                        .disabled(!canOpenEditor)
                    } else if !store.state.understandings.contains(where: {
                        $0.groupID == note.groupID && $0.revision > note.revision
                    }) {
                        Button {
                            store.beginUnderstanding(previousRevisionID: note.id)
                            showsEditor = true
                        } label: {
                            Text("修改为新版本").frame(minHeight: 44)
                        }
                        .disabled(!canOpenEditor)
                    }
                    if store.state.isViewingHistory && !store.state.understandings.contains(where: {
                        $0.groupID == note.groupID && $0.revision > note.revision
                    }) {
                        Button(role: .destructive) {
                            groupToDelete = note.groupID
                            showsDeleteConfirmation = true
                        } label: {
                            Text("删除这组理解").frame(minHeight: 44)
                        }
                        .disabled(store.state.isTransitioningSession)
                        .accessibilityIdentifier("mentor.understanding.delete-group")
                    }
                }
            }
            Button {
                store.beginUnderstanding()
                showsEditor = true
            } label: {
                Text("自己写一句理解").frame(minHeight: 44)
            }
            .accessibilityIdentifier("mentor.understanding.begin")
            .disabled(!canOpenEditor)
        }
        .sheet(isPresented: $showsEditor) { MentorUnderstandingEditor(store: store) }
        .alert("删除这组理解？", isPresented: $showsDeleteConfirmation) {
            Button("保留理解", role: .cancel) { groupToDelete = nil }
            Button("删除全部版本", role: .destructive) {
                guard let groupID = groupToDelete else { return }
                groupToDelete = nil
                Task { @MainActor in _ = await store.deleteViewedUnderstanding(groupID: groupID) }
            }
        } message: {
            Text("将删除这组理解的全部版本和草稿，并清理引用它的派生回应。交流原话和其他理解会保留。此操作无法撤销。")
        }
    }
}
