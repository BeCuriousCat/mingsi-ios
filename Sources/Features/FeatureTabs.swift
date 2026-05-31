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
        VStack(alignment: .leading, spacing: 12) {
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

// MARK: - Shared Components

struct FeatureContainer<Content: View>: View {
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
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DS.pagePadding)

                VStack(spacing: DS.cardSpacing) {
                    content
                }
                .padding(.horizontal, DS.pagePadding)
            }
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(DS.background)
    }
}

struct ResumeBanner: View {
    let title: String
    let subtitle: String
    let actionTitle: String
    let onDismiss: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(actionTitle, action: onAction)
                .font(.footnote.weight(.semibold))
                .buttonStyle(.borderedProminent)
                .tint(DS.accent)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

// MARK: - Card Components

private struct HistoryCardRow: View {
    let card: ThinkingCard

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(card.type.color)
                .frame(width: 8, height: 8)
                .padding(.top, 7)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.title)
                    .font(.body.weight(.medium))
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .cardSurface()
    }
}

private struct ProjectRow: View {
    let title: String
    let detail: String
    let metric: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundStyle(DS.caution)
                Text(metric)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .cardSurface()
    }
}

private struct MetricCard: View {
    let title: String
    let value: Double

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f", value))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(DS.accent)
            }
            Spacer()
            CircularProgressView(value: value / 5.0, color: DS.accent)
                .frame(width: 44, height: 44)
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
                .font(.body)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct CircularProgressView: View {
    let value: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.06), lineWidth: 3)
            Circle()
                .trim(from: 0, to: value)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
