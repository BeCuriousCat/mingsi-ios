import SwiftUI

/// One catalog, reachable from both lens selection and the main coach composer.
/// Pending methods can be inspected but cannot enter an ordinary model request.
struct CoachMethodLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    var onSelect: ((String) -> Void)? = nil
    var onSelectLens: ((LensCatalogItem) -> Void)? = nil

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("选一个角度就够，也可以不用。书籍方法先经过来源审核和对照评测；试用结果仍需你的实际体验确认。")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                }
                Section("现有透镜") {
                    ForEach(BuiltinLensCatalog.items) { lens in
                        NavigationLink {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 18) {
                                    Text(lens.title).font(.title2.weight(.semibold))
                                    Text(lens.methodLine)
                                    Text(lens.purpose).foregroundStyle(DS.mutedInk)
                                    Text(lens.applicability)
                                    Text("现有内置方法；不代表书籍提炼已通过效果评测。")
                                        .font(.footnote).foregroundStyle(DS.mutedInk)
                                    if onSelect != nil || onSelectLens != nil {
                                        Button("使用这个透镜") {
                                            if let onSelectLens { onSelectLens(lens) }
                                            else { onSelect?("lens." + lens.id) }
                                            dismiss()
                                        }.buttonStyle(DSCompactButtonStyle(prominent: true))
                                            .accessibilityIdentifier("methods.use." + lens.id)
                                    }
                                }.padding(DS.pagePadding).frame(maxWidth: 640, alignment: .leading)
                            }.accessibilityIdentifier("methods.lens.detail").background(DS.background).navigationTitle("透镜详情").navigationBarTitleDisplayMode(.inline)
                        } label: {
                            Label { Text(lens.title).font(.callout) } icon: { Image(systemName: lens.symbolName) }
                        }.accessibilityIdentifier("methods.lens." + lens.id)
                    }
                }
                Section("书籍与指南方法") {
                    if let catalog = CoachMethodCatalog.bundled {
                        ForEach(catalog.methods) { method in
                            NavigationLink {
                                CoachMethodDetailView(method: method, onSelect: onSelect.map { select in
                                    { select(method.id); dismiss() }
                                })
                            } label: {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack(alignment: .firstTextBaseline) {
                                        Text(method.snapshot.title).font(.callout)
                                        Spacer(minLength: 8)
                                        Text(method.isAvailable(promptVersion: CoachMethodCatalog.currentPromptVersion) ? "限定试用" : "待验证")
                                            .font(.caption).foregroundStyle(DS.mutedInk)
                                    }
                                    Text(method.summary).font(.subheadline).foregroundStyle(DS.mutedInk)
                                }.padding(.vertical, 4)
                            }.accessibilityIdentifier("methods.book." + method.id)
                        }
                    } else {
                        Text("方法库暂不可用，请稍后重新打开。")
                    }
                }
            }
            .accessibilityIdentifier("methods.library.list")
            .scrollContentBackground(.hidden).background(DS.background)
            .navigationTitle("透镜与方法库").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

private struct CoachMethodDetailView: View {
    let method: CoachMethod
    let onSelect: (() -> Void)?
    private var available: Bool { method.isAvailable(promptVersion: CoachMethodCatalog.currentPromptVersion) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(method.snapshot.title).font(.title2.weight(.semibold))
                Text(method.summary)
                detail("适合什么时候", method.applicable)
                detail("边界", method.boundaries)
                detail("蓝本与已读范围", method.snapshot.sourceTitle + "\n" + method.snapshot.sourceScope)
                if let url = URL(string: method.snapshot.sourceURL) { Link("查看原始来源", destination: url) }
                detail("质量状态", available ? "已通过本次合成场景对照，可在导师交流限定试用；尚未证明真实用户的能力提升。" : method.holdReason)
                if let evaluation = method.evaluation {
                    detail("本次评测", "\(Set(evaluation.passedCases).count)/\(Set(evaluation.requiredCases).count)个场景完成并通过 · \(evaluation.reviewer)\n\(evaluation.improvedPairs.isEmpty ? "尚无明确对照增益" : "已发现有限场景增益") · \(evaluation.decision == "scopedTrial" ? "限定试用" : "继续待验证")")
                }
                detail("来源审核", method.editorialReviewer)
                if available, let onSelect {
                    Button("本轮使用这个方法", action: onSelect)
                        .buttonStyle(DSCompactButtonStyle(prominent: true))
                        .accessibilityIdentifier("methods.use." + method.id)
                } else if available {
                    Text("可在导师交流输入框旁选择使用。今日整理暂保留原有透镜流程。")
                        .font(.footnote).foregroundStyle(DS.mutedInk)
                } else {
                    Label("完成验证前不会用于教练回答", systemImage: "clock")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("methods.pending." + method.id)
                }
            }.padding(DS.pagePadding).frame(maxWidth: 640, alignment: .leading).frame(maxWidth: .infinity)
        }.accessibilityIdentifier("methods.detail.scroll").background(DS.background).navigationTitle("方法详情").navigationBarTitleDisplayMode(.inline)
    }
    private func detail(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.subheadline.weight(.semibold)).accessibilityAddTraits(.isHeader)
            Text(text).font(.callout).textSelection(.enabled)
        }
    }
}
