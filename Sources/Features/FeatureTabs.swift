import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        FeatureContainer(title: "历史", subtitle: "这里是证据层，不是普通归档。") {
            VStack(spacing: DS.cardSpacing) {
                ForEach(store.thinkingCards) { card in
                    HistoryCardRow(card: card)
                }
            }
        }
    }
}

struct ProjectsView: View {
    var body: some View {
        FeatureContainer(title: "项目", subtitle: "抽象项目上下文和当前阻塞。") {
            VStack(spacing: DS.cardSpacing) {
                ProjectRow(title: "Project A", detail: "目标：减少会议返工", metric: "阻塞：接口归属不清")
                ProjectRow(title: "Project B", detail: "目标：提高判断质量", metric: "阻塞：复盘节奏不稳定")
            }
        }
    }
}

struct GrowthView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        FeatureContainer(title: "成长", subtitle: "展示前后对照、趋势和原则资产。") {
            VStack(spacing: DS.cardSpacing) {
                MetricCard(title: "清晰度", value: store.growthSnapshot.clarity)
                MetricCard(title: "价值判断", value: store.growthSnapshot.valueJudgment)
                MetricCard(title: "执行可靠性", value: store.growthSnapshot.executionReliability)
                MetricCard(title: "校准", value: store.growthSnapshot.calibration)
                MetricCard(title: "反思深度", value: store.growthSnapshot.reflectionDepth)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @State private var apiKeyInput = ""
    @State private var baseURLInput = ""

    var body: some View {
        FeatureContainer(title: "设置", subtitle: "隐私、模型、通知和数据控制。") {
            VStack(spacing: DS.cardSpacing) {
                apiKeyCard
                SettingRow(title: "GLM API Key", value: store.apiKeyConfigured ? "已配置" : "未配置")
                SettingRow(title: "默认模式", value: store.todayDraft.sessionMode.title)
                SettingRow(title: "本地通知", value: store.reminderStatusMessage)
                SettingRow(title: "数据导出", value: "可用")
            }
        }
        .onAppear {
            baseURLInput = store.currentBaseURL
        }
    }

    private var apiKeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GLM API Key")
                .font(.headline)
            Text("API Key 只保存到 iOS Keychain，不写入数据库或代码配置。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            SecureField("输入你的 GLM API Key", text: $apiKeyInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            HStack(spacing: 10) {
                Button("保存") {
                    store.saveGLMAPIKey(apiKeyInput)
                    apiKeyInput = ""
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)

                Button("清除") {
                    store.clearGLMAPIKey()
                    apiKeyInput = ""
                }
                .buttonStyle(.bordered)
            }

            Divider()
                .padding(.vertical, 4)

            Text("API Base URL")
                .font(.headline)
            Text("自定义 GLM API 地址。留空使用默认地址。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            TextField("https://api.z.ai/api/paas/v4/chat/completions", text: $baseURLInput)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.subheadline)

            HStack(spacing: 10) {
                Button("保存地址") {
                    store.saveGLMBaseURL(baseURLInput)
                }
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)

                Button("恢复默认") {
                    baseURLInput = ""
                    store.clearGLMBaseURL()
                }
                .buttonStyle(.bordered)
            }

            Text(store.settingsMessage)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct FeatureContainer<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(subtitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: DS.contentWidth, alignment: .leading)

                VStack(spacing: DS.cardSpacing) {
                    content
                }
                .frame(maxWidth: DS.contentWidth)
            }
            .padding(DS.pagePadding)
        }
        .background(DS.background)
    }
}

private struct HistoryCardRow: View {
    let card: ThinkingCard

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.type.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.surfaceStrong, in: Capsule())
                Spacer()
                Text(card.priority.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(card.title)
                .font(.headline)
            Text(card.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct ProjectRow: View {
    let title: String
    let detail: String
    let metric: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(metric)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct MetricCard: View {
    let title: String
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.headline)
                    .foregroundStyle(DS.accent)
            }
            ProgressView(value: value / 5.0)
                .tint(DS.accent)
        }
        .cardSurface()
    }
}

private struct SettingRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
        .cardSurface()
    }
}
