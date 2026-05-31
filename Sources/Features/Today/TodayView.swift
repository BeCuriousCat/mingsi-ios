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
            .padding(.horizontal, DS.pagePadding)
        }
        .background(DS.background)
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(store.todayDraft.date, style: .date)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            HStack(alignment: .firstTextBaseline) {
                Text(store.currentStateTitle)
                    .font(.title.weight(.bold))

                Spacer()

                if store.todayDraft.hasSelectedSessionMode {
                    Text(store.todayDraft.sessionMode.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DS.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DS.accent.opacity(0.08), in: Capsule())
                }
            }

            if !store.todayLoopMessage.isEmpty {
                Text(store.todayLoopMessage)
                    .font(.footnote)
                    .foregroundStyle(DS.caution)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Verify Yesterday

    // Purpose: Close yesterday's loop before starting fresh
    // Design: Warm, reflective - not a form, a moment of honesty
    private var verifyYesterdaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("先回看昨天")
                .font(.headline)

            if let quest = store.mainQuest ?? store.quests.first {
                VStack(alignment: .leading, spacing: 6) {
                    Text("昨日主线任务")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(quest.title)
                        .font(.body.weight(.medium))
                }
                .cardSurface()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("完成了吗？")
                    .font(.subheadline.weight(.medium))
                HStack(spacing: 10) {
                    ForEach(YesterdayCompletion.allCases) { completion in
                        choiceChip(
                            title: completion.title,
                            isSelected: store.todayDraft.yesterdayCompletion == completion,
                            action: { store.selectYesterdayCompletion(completion) }
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("实际价值？")
                    .font(.subheadline.weight(.medium))
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
    }

    // MARK: - Capture

    // Purpose: Raw dump of today's messy thoughts
    // Design: Generous text area, inviting, feels like opening a notebook
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今天发生了什么？")
                .font(.headline)

            TextEditor(text: Binding(
                get: { store.todayDraft.rawText },
                set: { store.updateTodayCapture($0) }
            ))
            .frame(minHeight: 200)
            .scrollContentBackground(.hidden)
            .padding(16)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
            .shadow(color: .black.opacity(0.04), radius: 2, y: 1)

            HStack(spacing: 8) {
                Image(systemName: "hand.raised")
                    .font(.caption2)
                Text("不要输入公司敏感资料、代码、客户信息或内部数据。")
                    .font(.caption)
            }
            .foregroundStyle(.secondary)

            starterPills
        }
    }

    // MARK: - Organizing

    // Purpose: AI is working, give feedback
    // Design: Quiet progress, not a loading spinner spectacle
    private var organizingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.apiKeyConfigured ? "正在整理..." : "本地整理中...")
                .font(.headline)

            ProgressView()
                .tint(DS.accent)

            Text("把零散输入拆成可编辑的卡片")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Review Cards

    // Purpose: User reviews AI-extracted cards, confirms what's real
    // Design: Cards stacked with type color dot, minimal chrome, focus on content
    private var reviewCardsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("思考卡片")
                .font(.headline)

            Text("确认哪些是真正重要的，排除不相关的。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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

    // MARK: - Select Mode

    // Purpose: Choose thinking depth
    // Design: Three clear options, selected state is obvious but calm
    private var selectModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("训练模式")
                .font(.headline)

            modeCard(mode: .quick, icon: "bolt", description: "最短路径，只收敛最关键的动作。")
            modeCard(mode: .standard, icon: "book", description: "默认完整流程，平衡速度和深度。")
            modeCard(mode: .deep, icon: "brain.head.profile", description: "追问更深，适合重要事件和周复盘。")
        }
    }

    // MARK: - Select Lens

    // Purpose: Pick a thinking lens to challenge assumptions
    // Design: Lens name + one-line reason, feels like choosing a perspective
    private var selectLensSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("思考透镜")
                .font(.headline)

            Text("选择一种方式继续把事情想清楚。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(ThinkingLens.allCases) { lens in
                lensCard(lens)
            }
        }
    }

    // MARK: - Answer Questions

    // Purpose: Answer coaching questions to sharpen thinking
    // Design: Each question is a card with answer field, inviting not interrogating
    private var answerQuestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("回答问题")
                .font(.headline)

            Text("至少回答一个，才能进入任务生成。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(store.questions.enumerated()), id: \.element.id) { index, question in
                QuestionCardView(question: question, answer: bindingForQuestion(questionID: question.id, fallbackIndex: index))
            }
        }
    }

    // MARK: - Review Quests

    // Purpose: Review tomorrow's action plan
    // Design: Quest cards feel actionable, main quest is visually prominent
    private var reviewQuestsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("明日任务")
                .font(.headline)

            ForEach(store.quests) { quest in
                QuestCardView(quest: quest)
            }
        }
    }

    // MARK: - Extract Principle

    // Purpose: Distill a reusable rule from today
    // Design: Feels like saving a permanent insight, not just another card
    private var extractPrincipleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("原则候选")
                .font(.headline)

            if let principle = store.principles.first {
                PrincipleCardView(principle: principle)
            } else {
                Text("可以直接跳过并完成今日闭环。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .cardSurface()
            }
        }
    }

    // MARK: - Session Complete

    // Purpose: Summary of what was accomplished
    // Design: Clean summary, feels like closing a notebook
    private var sessionCompleteSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("今日完成")
                .font(.headline)

            if let mainQuest = store.quests.first(where: { $0.type == .main }) {
                completionCard(icon: "flag.checkered", title: "明日主线任务", body: mainQuest.title)
            }

            if let principle = store.principles.first {
                completionCard(icon: "lightbulb", title: "今日沉淀", body: principle.title)
            }

            completionCard(icon: "chart.line.uptrend.xyaxis", title: "成长快照", body: store.growthSnapshot.summary)
        }
    }

    // MARK: - Action Row

    private var actionRow: some View {
        VStack(spacing: 12) {
            Button {
                store.submitTodayStep()
            } label: {
                Text(primaryActionTitle)
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(DS.accent)

            HStack(spacing: 16) {
                if store.todayDraft.state == .extractPrinciple {
                    Button("跳过原则") {
                        store.skipPrinciple()
                    }
                    .font(.subheadline)
                }

                Button("重置今日") {
                    store.resetTodayLoop()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 24)
    }

    private var primaryActionTitle: String {
        switch store.todayDraft.state {
        case .verifyYesterday: return "保存验证"
        case .capture: return "整理成卡片"
        case .organizing: return "查看卡片"
        case .reviewCards: return "确认卡片"
        case .selectMode: return "继续"
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

    // MARK: - Helpers

    private func bindingForQuestion(questionID: ReflectionQuestion.ID, fallbackIndex index: Int) -> Binding<String> {
        Binding(
            get: {
                store.questions.first(where: { $0.id == questionID })?.answer ?? store.questions[index].answer
            },
            set: { store.updateQuestionAnswer(questionID: questionID, answer: $0) }
        )
    }

    private func choiceChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(isSelected ? DS.accent : DS.cardBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func modeCard(mode: SessionMode, icon: String, description: String) -> some View {
        Button(action: { store.selectTodayMode(mode) }) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(DS.accent)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.todayDraft.hasSelectedSessionMode && store.todayDraft.sessionMode == mode {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
    }

    private func lensCard(_ lens: ThinkingLens) -> some View {
        Button(action: { store.selectThinkingLens(lens) }) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lens.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(lens.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if store.todayDraft.selectedLens == lens {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(DS.accent)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .cardSurface()
    }

    private func completionCard(icon: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(DS.accent)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(body)
                    .font(.subheadline.weight(.medium))
            }
        }
        .cardSurface()
    }
}

// MARK: - Card Sub-Views

private struct ThinkingCardRow: View {
    let card: ThinkingCard
    let confirm: () -> Void
    let exclude: () -> Void
    let delete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(card.type.color)
                    .frame(width: 8, height: 8)

                Text(card.type.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if card.isConfirmed {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption)
                        .foregroundStyle(DS.success)
                }
            }

            Text(card.title)
                .font(.body.weight(.medium))
            Text(card.body)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("确认", action: confirm)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                Button(card.isExcludedFromModel ? "已排除" : "排除", action: exclude)
                    .font(.caption)
                    .buttonStyle(.bordered)
                Button("删除", role: .destructive, action: delete)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .cardSurface()
        .opacity(card.isExcludedFromModel ? 0.5 : 1)
    }
}

private struct QuestionCardView: View {
    let question: ReflectionQuestion
    @Binding var answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question.question)
                .font(.body.weight(.medium))
            Text(question.whyItMatters)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField("在这里回答", text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
        }
        .cardSurface()
    }
}

private struct QuestCardView: View {
    let quest: Quest

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(quest.type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(quest.type == .main ? DS.accent : .secondary)
                Spacer()
            }

            Text(quest.title)
                .font(.body.weight(.semibold))

            VStack(alignment: .leading, spacing: 4) {
                Text("完成标准")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(quest.completionCriteria)
                    .font(.subheadline)
            }

            Text("阻力：\(quest.expectedResistance)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .cardSurface()
    }
}

private struct PrincipleCardView: View {
    let principle: PrincipleAsset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(DS.accent)
                Text("原则候选")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(principle.title)
                .font(.body.weight(.semibold))
            Text(principle.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("适用场景：\(principle.triggerContext)")
                .font(.caption)
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
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(DS.surface, in: Capsule())
            }
        }
    }
}
