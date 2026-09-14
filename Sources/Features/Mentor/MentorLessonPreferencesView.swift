import SwiftUI

struct MentorLessonPreferencesView: View {
    @StateObject private var preferences: MentorLessonPreferencesStore
    @State private var showsConfirmation = false

    init(feature: MentorFeatureStore) {
        _preferences = StateObject(wrappedValue: feature.makeLessonPreferencesStore())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("听讲偏好").font(.headline).accessibilityAddTraits(.isHeader)
            Text("标记为“已知道”的内容不会再自动推荐。重置后，它们可以重新进入候选；最近读过的内容仍会按去重规则暂时避开。")
                .font(.subheadline).foregroundStyle(DS.mutedInk)
            Button("重置“已知道”反馈") { showsConfirmation = true }
                .buttonStyle(.bordered).controlSize(.large)
                .frame(minHeight: 44)
                .disabled(preferences.isResetting)
                .accessibilityIdentifier("mentor.preferences.reset-known")
            if preferences.isResetting { ProgressView("正在重置…") }
            if let error = preferences.error {
                Text(error).foregroundStyle(DS.caution)
                    .accessibilityIdentifier("mentor.preferences.error")
            }
            if preferences.didReset {
                Text("已重置“已知道”反馈。交流和已读记录都已保留。")
                    .font(.subheadline).foregroundStyle(DS.mutedInk)
                    .accessibilityIdentifier("mentor.preferences.reset-saved")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .alert("重置“已知道”反馈？", isPresented: $showsConfirmation) {
            Button("保留偏好", role: .cancel) {}
            Button("确认重置") {
                Task { @MainActor in await preferences.resetKnownFeedback() }
            }
        } message: {
            Text("所有标记为“已知道”的内容将重新允许自动推荐。交流、理解和已读记录会保留；本次交流的“不相关”反馈不变。")
        }
    }
}
