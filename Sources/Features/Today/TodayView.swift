import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.sectionSpacing) {
                header

                switch store.todayDraft.state {
                case .verifyYesterday:
                    verifyYesterdaySection
                case .capture:
                    captureSection
                case .organizing:
                    organizingSection
                case .reviewCards:
                    reviewCardsSection
                case .selectMode:
                    selectModeSection
                case .selectLens:
                    selectLensSection
                case .answerQuestions:
                    answerQuestionsSection
                case .reviewQuests:
                    reviewQuestsSection
                case .extractPrinciple:
                    extractPrincipleSection
                case .sessionComplete:
                    sessionCompleteSection
                }

                actionRow
            }
            .frame(maxWidth: DS.contentWidth)
            .padding(DS.pagePadding)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(store.todayDraft.date, style: .date)
                        .font(.title2.weight(.semibold))
                    Text("今日状态：\(store.currentStateTitle)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("模式")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(store.todayDraft.sessionMode.title)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DS.surfaceStrong, in: Capsule())
                }
            }

            Text("不替你思考，而是训练你把事情想清楚。")
                .font(.callout)
                .foregroundStyle(.secondary)

            if !store.todayLoopMessage.isEmpty {
                Text(store.todayLoopMessage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DS.caution)
                    .padding(.top, 2)
            }
        }
        .cardSurface()
    }

    private var verifyYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "验证昨日", subtitle: "先校准昨天的主线任务，再开始今天的复盘。")
            if let quest = store.mainQuest ?? store.quests.first {
                questSummaryCard(quest)
            } else {
                infoCard(title: "昨日主线任务", body: "暂无昨日任务，先选择校准状态后进入今日输入。")
            }

            HStack(spacing: 10) {
                ForEach(YesterdayCompletion.allCases) { completion in
                    choiceChip(
                        title: completion.title,
                        isSelected: store.todayDraft.yesterdayCompletion == completion,
                        action: { store.selectYesterdayCompletion(completion) }
                    )
                }
            }

            HStack(spacing: 10) {
                ForEach(YesterdayValueRating.allCases) { rating in
                    choiceChip(
                        title: rating.title,
                        isSelected: store.todayDraft.yesterdayValueRating == rating,
                        action: { store.selectYesterdayValueRating(rating) }
                    )
                }
            }
        }
    }

    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "今日输入", subtitle: "先把零散想法放进来，后面再整理。")

            TextEditor(text: Binding(
                get: { store.todayDraft.rawText },
                set: { store.updateTodayCapture($0) }
            ))
                .frame(minHeight: 220)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                        .stroke(DS.border, lineWidth: 1)
                )

            Text("不要输入公司敏感资料、代码、客户信息或内部数据。")
                .font(.footnote)
                .foregroundStyle(.secondary)

            starterPills
        }
    }

    private var organizingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "整理中", subtitle: store.apiKeyConfigured ? "GLM 正在把原始输入拆成可编辑的卡片。" : "未配置 GLM，使用本地模拟数据完成 MVP 闭环。")
            ProgressView()
                .progressViewStyle(.linear)
            infoCard(title: "结构化输出", body: "将生成事实、问题、决策、风险和任务卡片。")
        }
    }

    private var reviewCardsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "思考卡片", subtitle: "请先确认卡片，再进入更深的追问。")
            ForEach(store.thinkingCards) { card in
                ThinkingCardRow(
                    card: card,
                    confirm: { store.confirmCard(card.id) },
                    exclude: { store.excludeCard(card.id) },
                    delete: { store.deleteCard(card.id) }
                )
            }
        }
    }

    private var selectModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "训练模式", subtitle: "Quick / Standard / Deep 决定今天的训练深度。")
            modeCard(mode: .quick, description: "最短路径，只收敛最关键的动作。")
            modeCard(mode: .standard, description: "默认完整流程，平衡速度和深度。")
            modeCard(mode: .deep, description: "追问更深，适合重要事件和周复盘。")
        }
    }

    private var selectLensSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "思考透镜", subtitle: "选择一种方式继续把事情想清楚。")
            ForEach(ThinkingLens.allCases) { lens in
                lensCard(lens)
            }
        }
    }

    private var answerQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "回答问题", subtitle: "至少回答一个，才能进入任务生成。")

            ForEach(Array(store.questions.enumerated()), id: \.element.id) { index, question in
                QuestionCardView(question: question, answer: bindingForQuestion(questionID: question.id, fallbackIndex: index))
            }
        }
    }

    private var reviewQuestsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "明日任务", subtitle: "主线任务必须有明确完成标准。")

            ForEach(store.quests) { quest in
                QuestCardView(quest: quest)
            }
        }
    }

    private var extractPrincipleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "原则候选", subtitle: "把可复用的做法沉淀成长期资产。")

            if let principle = store.principles.first {
                PrincipleCardView(principle: principle)
            } else {
                infoCard(title: "暂无原则候选", body: "可以直接跳过并完成今日闭环。")
            }
        }
    }

    private var sessionCompleteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title: "今日完成", subtitle: "今天形成的结论已经保存为证据链。")
            infoCard(title: "明日主线任务", body: store.quests.first(where: { $0.type == .main })?.title ?? "暂无")
            infoCard(title: "今日沉淀", body: store.principles.first?.title ?? "暂无原则")
            infoCard(title: "成长快照", body: store.growthSnapshot.summary)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                store.submitTodayStep()
            } label: {
                Text(primaryActionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)

            if store.todayDraft.state == .extractPrinciple {
                Button {
                    store.skipPrinciple()
                } label: {
                    Text("跳过")
                        .frame(width: 70)
                }
                .buttonStyle(.bordered)
            }

            Button {
                store.resetTodayLoop()
            } label: {
                Text("重置")
                    .frame(width: 88)
            }
            .buttonStyle(.bordered)
        }
        .padding(.top, 4)
    }

    private var primaryActionTitle: String {
        switch store.todayDraft.state {
        case .verifyYesterday: return "保存验证"
        case .capture: return "整理成卡片"
        case .organizing: return "查看卡片"
        case .reviewCards: return "确认卡片"
        case .selectMode: return "继续透镜"
        case .selectLens: return "回答问题"
        case .answerQuestions: return "生成任务"
        case .reviewQuests: return "保存任务"
        case .extractPrinciple: return "保存原则"
        case .sessionComplete: return "开始新一天"
        }
    }

    private var starterPills: some View {
        FlowPills(items: [
            "今天真正推进了什么？",
            "哪件事让我感觉不清楚？",
            "我是否回避了一个关键判断？",
            "明天最不能忽略什么？"
        ])
    }

    private func bindingForQuestion(questionID: ReflectionQuestion.ID, fallbackIndex index: Int) -> Binding<String> {
        Binding(
            get: {
                store.questions.first(where: { $0.id == questionID })?.answer ?? store.questions[index].answer
            },
            set: { store.updateQuestionAnswer(questionID: questionID, answer: $0) }
        )
    }

    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func infoCard(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private func questSummaryCard(_ quest: Quest) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(quest.title)
                .font(.headline)
            Text(quest.whyItMatters)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }

    private func choiceChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(title)
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? DS.accent.opacity(0.14) : DS.surfaceStrong, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? DS.accent : .primary)
    }

    private func modeCard(mode: SessionMode, description: String) -> some View {
        Button {
            store.selectTodayMode(mode)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.headline)
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.todayDraft.hasSelectedSessionMode && store.todayDraft.sessionMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.success)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
    }

    private func lensCard(_ lens: ThinkingLens) -> some View {
        Button {
            store.selectThinkingLens(lens)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lens.title)
                        .font(.headline)
                    Text(lens.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if store.todayDraft.selectedLens == lens {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.success)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
    }
}

private struct ThinkingCardRow: View {
    let card: ThinkingCard
    let confirm: () -> Void
    let exclude: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(card.type.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.surfaceStrong, in: Capsule())
                Spacer()
                if card.isConfirmed {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(DS.success)
                }
            }

            Text(card.title)
                .font(.headline)
            Text(card.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button("确认", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                Button(card.isExcludedFromModel ? "已排除" : "排除", action: exclude)
                    .buttonStyle(.bordered)
                Button("删除", role: .destructive, action: delete)
                    .buttonStyle(.bordered)
            }
            .font(.footnote.weight(.semibold))
        }
        .cardSurface()
        .opacity(card.isExcludedFromModel ? 0.62 : 1)
    }
}

private struct QuestionCardView: View {
    let question: ReflectionQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question.question)
                .font(.headline)
            Text(question.whyItMatters)
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextField("在这里回答", text: $answer, axis: .vertical)
                .textFieldStyle(.roundedBorder)
        }
        .cardSurface()
    }
}

private struct QuestCardView: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(quest.type.title)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DS.surfaceStrong, in: Capsule())
                Spacer()
                Text(quest.status.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(quest.title)
                .font(.headline)
            Text("完成标准")
                .font(.caption.weight(.semibold))
                .foregroundStyle(quest.type == .main ? DS.accent : .secondary)
            Text(quest.completionCriteria)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("阻力：\(quest.expectedResistance)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct PrincipleCardView: View {
    let principle: PrincipleAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(principle.title)
                .font(.headline)
            Text(principle.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("触发场景：\(principle.triggerContext)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct FlowPills: View {
    let items: [String]

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.surfaceStrong, in: Capsule())
            }
        }
    }
}
