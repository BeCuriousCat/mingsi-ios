import SwiftUI

struct LifeGuidanceSection: View {
    @ObservedObject var guidance: LifeGuidanceStore
    var reviewID: String? = nil
    @Environment(\.scenePhase) private var scenePhase

    private var cards: [LifeGuidanceCardContext] {
        guard let reviewID else { return guidance.cards }
        return guidance.cards.filter { context in
            context.triggers.contains(.daily) || guidance.exposures.contains {
                $0.id == "review:" + reviewID && $0.item?.contentHash == context.item.contentHash
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(cards) { context in
                LifeGuidanceCardLink(context: context, guidance: guidance)
            }
            NavigationLink {
                SavedLifeGuidanceView(guidance: guidance)
            } label: {
                Label("存下来的建议", systemImage: "bookmark")
                    .frame(minHeight: DS.minimumTapTarget, alignment: .leading)
            }
            .accessibilityIdentifier("life-guidance.saved.open")
            NavigationLink {
                LifeGuidanceCatalogView(guidance: guidance)
            } label: {
                Label("浏览明思精选建议", systemImage: "square.grid.2x2")
                    .frame(minHeight: DS.minimumTapTarget, alignment: .leading)
            }
            .accessibilityIdentifier("life-guidance.catalog.open")
            NavigationLink {
                LifeGuidanceReferenceBookView(guidance: guidance)
            } label: {
                HStack(spacing: 10) {
                    Label("打开完整人生指南", systemImage: "books.vertical")
                    Spacer()
                    Text("\(guidance.referenceBook.counts.entries) 条")
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                }
                .frame(minHeight: DS.minimumTapTarget, alignment: .leading)
            }
            .accessibilityIdentifier("life-guidance.reference.open")
            if let error = guidance.errorMessage {
                Text(error).font(.footnote).foregroundStyle(DS.caution)
                Button("重新读取建议") { Task { await guidance.refresh() } }
                    .frame(minHeight: DS.minimumTapTarget)
            }
        }
        .task { await guidance.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await guidance.refresh() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            Task { await guidance.refresh() }
        }
    }
}

struct LifeGuidanceCardLink: View {
    let context: LifeGuidanceCardContext
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        NavigationLink {
            LifeGuidanceDetailsView(context: context, guidance: guidance)
        } label: {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .firstTextBaseline) {
                    Text(context.triggers == [.dailyReview] ? "回顾里的相关建议" : "今日一条")
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right").font(.caption)
                }
                Text(context.item.title).font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                if let event = context.event {
                    Text("根据这件事：\(event.text)")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                        .lineLimit(3)
                } else {
                    Text(context.item.suggestion).font(.subheadline).foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(context.item.referenceEntry != nil ? "原指南资料 · 查看证据与备注" : context.triggers.count == 2 ? "今日推荐 · 回顾相关 · 查看详情" : "查看详情")
                    .font(.caption).foregroundStyle(DS.accentInk)
            }
            .foregroundStyle(DS.ink)
            .frame(maxWidth: .infinity, minHeight: DS.minimumTapTarget, alignment: .leading)
            .padding(14)
            .background(DS.cardBackground, in: RoundedRectangle(cornerRadius: DS.smallRadius))
            .overlay { RoundedRectangle(cornerRadius: DS.smallRadius).stroke(DS.hairline, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(context.triggers.contains(.daily) ? "today.life-guidance.daily-card" : "today.life-guidance.review-card")
        .accessibilityLabel("打开建议：\(context.item.title)")
        .accessibilityHint(context.item.referenceEntry == nil ? "查看第一个动作、成本和适用边界" : "查看指南原文、证据和备注")
    }
}

struct LifeGuidanceDetailsView: View {
    let context: LifeGuidanceCardContext
    @ObservedObject var guidance: LifeGuidanceStore
    var headingOverride: String? = nil
    @EnvironmentObject private var app: AppStore
    @State private var isSaving = false
    @State private var feedbackMessage: String?
    @State private var observation = ""
    @State private var observationFocused = false
    @State private var conversation: MentorFeatureStore?

    private var item: LifeGuidanceItem { context.item }
    private var saved: LifeGuidanceFeedback? { guidance.state(for: item) }

    @ViewBuilder
    var body: some View {
        if let entry = item.referenceEntry {
            LifeGuidanceReferenceEntryView(entry: entry, guidance: guidance, snapshot: item, context: context)
        } else {
            adaptedBody
        }
    }

    private var adaptedBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(item.title).font(.title2.weight(.semibold))
                    .accessibilityIdentifier("today.life-guidance.details.title")
                    .accessibilityAddTraits(.isHeader)
                Text(headingOverride ?? (context.triggers.isEmpty ? "已保存的建议" : context.triggers.count == 2 ? "今日推荐 · 回顾相关" : context.triggers.contains(.dailyReview) ? "回顾相关" : "今日推荐"))
                    .font(.subheadline).foregroundStyle(DS.mutedInk)
                Text(item.suggestion)
                if let event = context.event {
                    block("触发这条建议的事件", event.text)
                    if let explanation = context.explanation { Text(explanation).font(.subheadline) }
                }
                block("先做这一步", item.firstStep)
                block("适用边界", item.boundary)
                    .accessibilityIdentifier("life-guidance.boundary")
                VStack(alignment: .leading, spacing: 8) {
                    Button(saved?.isSaved == true ? "已存下来 · 取消保存" : "先存下来") {
                        let wasSaved = saved?.isSaved == true
                        persist(wasSaved ? "已取消保存。" : "已存下来，可以在首页的存下来的建议里回看。") { $0.isSaved.toggle() }
                    }
                    .accessibilityIdentifier("life-guidance.save")
                    Button("现在试试") {
                        isSaving = true
                        Task {
                            if let feature = await app.prepareMentorFeature() {
                                feature.start(entry: "discuss", initialText: "我想试试这条建议：\(item.title)。第一步是：\(item.firstStep)\n我想改善的是：")
                                conversation = feature
                            } else {
                                feedbackMessage = "暂时没能打开交流，建议仍保留，可以稍后重试。"
                            }
                            isSaving = false
                        }
                    }
                    .accessibilityIdentifier("life-guidance.try")
                    Button(saved?.hasTried == true ? "已记录试过" : "我试过了") {
                        persist("已记录试过。可以在下面留下实际观察。") { $0.hasTried = true }
                    }
                    .accessibilityIdentifier("life-guidance.tried")
                    Button("今天不适合我") {
                        let day = guidance.dayKey
                        persist("今天的入口已收起。这个选择只影响今天。") { $0.dismissedDayKeys.insert(day) }
                    }
                    .accessibilityIdentifier("life-guidance.dismiss")
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(isSaving)
                if let feedbackMessage {
                    Text(feedbackMessage).font(.footnote).foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("today.life-guidance.feedback")
                }
                if let error = guidance.errorMessage { Text(error).font(.footnote).foregroundStyle(DS.caution) }
                if saved?.hasTried == true {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("实际观察").font(.headline)
                        Text("做了什么，发生了什么？没有变化也可以记录。")
                            .font(.subheadline).foregroundStyle(DS.mutedInk)
                        PushToTalkInput(text: $observation, placeholder: "写下这次尝试的结果", accessibilityIdentifier: "life-guidance.observation", focusBinding: $observationFocused, usesTextEditor: true)
                            .frame(minHeight: 120)
                        Button("保存观察") {
                            let text = observation
                            persist("观察已保存；这只是你的记录，不代表建议有效。") { $0.observation = text }
                        }.buttonStyle(.bordered).controlSize(.large).disabled(isSaving)
                        .accessibilityIdentifier("life-guidance.observation.save")
                    }
                }
                block("为什么可能有帮助", item.whyItMayHelp)
                block("成本", item.cost)
                block("观察什么", item.signal)
                VStack(alignment: .leading, spacing: 10) {
                    Text("依据与来源").font(.headline)
                    Text("证据等级 \(item.evidenceLevel) · \(item.sourceHeading)").font(.subheadline)
                    if let url = item.sourceURL { Link("《高性价比人生指南》原条目", destination: url) }
                    Link("内容许可：CC BY 4.0", destination: URL(string: "https://creativecommons.org/licenses/by/4.0/")!)
                    Text(item.adaptationNote).font(.subheadline)
                    Text("同步日期：\(item.retrievedAt)\n内容版本：\(item.version)\n来源提交：\(item.sourceCommit)")
                        .font(.caption).foregroundStyle(DS.mutedInk)
                    ForEach(item.citations, id: \.url) { citation in
                        if let url = URL(string: citation.url) { Link(citation.title, destination: url) }
                    }
                }
                Text("建议提供一个可以尝试的起点，不保证结果，也不会自动创建任务。")
                    .font(.footnote).foregroundStyle(DS.mutedInk)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(DS.pagePadding).frame(maxWidth: .infinity)
        }
        .background(DS.background).foregroundStyle(DS.ink)
        .navigationTitle("建议详情").navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("today.life-guidance.details")
        .task { observation = saved?.observation ?? "" }
        .sheet(isPresented: Binding(get: { conversation != nil }, set: { if !$0 { conversation = nil } })) {
            if let conversation { MentorConversationView(feature: conversation).environmentObject(app) }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline).accessibilityAddTraits(.isHeader)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func persist(_ message: String, change: @escaping (inout LifeGuidanceFeedback) -> Void) {
        isSaving = true
        Task {
            if await guidance.update(item, change: change) { feedbackMessage = message }
            else { feedbackMessage = nil }
            isSaving = false
        }
    }
}

struct SavedLifeGuidanceView: View {
    @ObservedObject var guidance: LifeGuidanceStore
    var body: some View {
        List {
            if guidance.savedItems.isEmpty { Text("还没有保存或试过的建议。").foregroundStyle(DS.mutedInk) }
            ForEach(guidance.savedItems) { saved in
                NavigationLink {
                    LifeGuidanceDetailsView(context: LifeGuidanceCardContext(item: saved.item, triggers: [], event: nil, explanation: nil), guidance: guidance)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(saved.item.title)
                        Text(saved.hasTried ? "已试过 · \(saved.observation.isEmpty ? "尚未记录结果" : "已记录结果")" : "已保存")
                            .font(.caption).foregroundStyle(DS.mutedInk)
                    }
                }
                .accessibilityIdentifier("life-guidance.saved.\(saved.item.id)")
                .swipeActions { Button("删除记录", role: .destructive) { Task { await guidance.deleteRecord(saved) } } }
            }
            if let error = guidance.errorMessage { Text(error).foregroundStyle(DS.caution) }
        }
        .navigationTitle("存下来的建议").navigationBarTitleDisplayMode(.inline)
        .task { await guidance.refresh() }
    }
}

struct LifeGuidanceCatalogView: View {
    @ObservedObject var guidance: LifeGuidanceStore
    @State private var selectedCategory = "全部"

    private var filteredItems: [LifeGuidanceItem] {
        guidance.catalogItems.filter { selectedCategory == "全部" || $0.category == selectedCategory }
    }

    var body: some View {
        List {
            Section {
                Picker("分类", selection: $selectedCategory) {
                    Text("全部").tag("全部")
                    ForEach(guidance.catalogCategories, id: \.self) { category in
                        Text(category).tag(category)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("life-guidance.catalog.category")
            }
            Section {
                ForEach(filteredItems) { item in
                    NavigationLink {
                        LifeGuidanceDetailsView(
                            context: LifeGuidanceCardContext(item: item, triggers: [], event: nil, explanation: nil),
                            guidance: guidance,
                            headingOverride: "建议库 · " + item.category
                        )
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 7) {
                                Text(item.category).font(.caption.weight(.semibold)).foregroundStyle(DS.accentInk)
                                Spacer(minLength: 6)
                                if guidance.state(for: item)?.isSaved == true {
                                    Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(DS.accentInk)
                                }
                            }
                            Text(item.title).fixedSize(horizontal: false, vertical: true)
                            Text(item.firstStep).font(.caption).foregroundStyle(DS.mutedInk).lineLimit(2)
                        }
                    }
                    .accessibilityIdentifier("life-guidance.catalog.\(item.id)")
                }
            } header: {
                Text(String(filteredItems.count) + " 条建议")
            }
        }
        .navigationTitle("建议库")
        .navigationBarTitleDisplayMode(.inline)
        .task { await guidance.refresh() }
    }
}

struct LifeGuidanceReferenceBookView: View {
    @ObservedObject var guidance: LifeGuidanceStore
    @State private var searchText = ""
    @State private var selectedSection = 0
    @State private var selectedEvidence = "全部"
    @State private var selectedBenefit = "全部"
    @State private var lowCostOnly = false

    private var entries: [LifeGuidanceReferenceEntry] {
        guidance.referenceBook.search(
            searchText,
            evidenceLevel: selectedEvidence,
            sectionNumber: selectedSection == 0 ? nil : selectedSection,
            benefitLevel: selectedBenefit,
            lowCostOnly: lowCostOnly
        )
    }

    var body: some View {
        List {
            Section {
                Text(guidance.referenceBook.summary)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                Text("完整参考库 · \(guidance.referenceBook.counts.sections) 节 · \(guidance.referenceBook.counts.entries) 条")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accentInk)
                Text("全部条目都可通过每日推荐或回顾相关卡片打开，也可以按章节查阅。")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                NavigationLink {
                    LifeGuidanceReferenceSectionsView(guidance: guidance)
                } label: {
                    Label("按章节浏览", systemImage: "list.number")
                }
                NavigationLink {
                    LifeGuidanceReferenceLibraryView(guidance: guidance)
                } label: {
                    Label("长文与术语表", systemImage: "text.book.closed")
                }
                NavigationLink {
                    SavedLifeGuidanceReferenceView(guidance: guidance)
                } label: {
                    HStack {
                        Label("我收藏的完整条目", systemImage: "bookmark")
                        Spacer()
                        Text("\(guidance.bookmarkedReferenceEntries.count) 条")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                .accessibilityIdentifier("life-guidance.reference.bookmarked.open")
            } header: {
                Text("《高性价比人生指南》")
            }

            Section {
                PushToTalkInput(text: $searchText, placeholder: "搜索标题、说人话、来源或备注", accessibilityIdentifier: "life-guidance.reference.search")
                    .textFieldStyle(.roundedBorder)
                Picker("章节", selection: $selectedSection) {
                    Text("全部章节").tag(0)
                    ForEach(guidance.referenceBook.sections) { section in
                        Text("第\(section.number)节 · \(section.title)").tag(section.number)
                    }
                }
                .accessibilityIdentifier("life-guidance.reference.section")
                Picker("证据等级", selection: $selectedEvidence) {
                    Text("全部").tag("全部")
                    Text("A").tag("A")
                    Text("B").tag("B")
                    Text("C").tag("C")
                }
                .accessibilityIdentifier("life-guidance.reference.evidence")
                Picker("收益", selection: $selectedBenefit) {
                    Text("全部收益").tag("全部")
                    Text("大").tag("大")
                    Text("中").tag("中")
                    Text("小").tag("小")
                }
                .accessibilityIdentifier("life-guidance.reference.benefit")
                Toggle("只看低成本", isOn: $lowCostOnly)
                    .accessibilityIdentifier("life-guidance.reference.low-cost")
            }

            Section {
                ForEach(entries) { entry in
                    NavigationLink {
                        LifeGuidanceReferenceEntryView(entry: entry, guidance: guidance)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 8) {
                                Text("\(entry.evidenceLevel)级")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DS.accentInk)
                                Text("第\(sectionNumber(for: entry))节")
                                    .font(.caption)
                                    .foregroundStyle(DS.mutedInk)
                                Spacer(minLength: 4)
                                if guidance.isBookmarked(entry) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.caption)
                                        .foregroundStyle(DS.accentInk)
                                }
                            }
                            Text(entry.title)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.humanSummary)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(3)
                        }
                    }
                    .accessibilityIdentifier("life-guidance.reference.\(entry.id)")
                }
            } header: {
                Text("找到 \(entries.count) 条")
            }
        }
        .navigationTitle("完整人生指南")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("life-guidance.reference")
    }

    private func sectionNumber(for entry: LifeGuidanceReferenceEntry) -> Int {
        guidance.referenceBook.sections.first { $0.entries.contains(entry) }?.number ?? 0
    }
}

struct LifeGuidanceReferenceSectionsView: View {
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        List {
            ForEach(guidance.referenceBook.sections) { section in
                NavigationLink {
                    LifeGuidanceReferenceSectionView(section: section, guidance: guidance)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("第\(section.number)节")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DS.accentInk)
                        Text(section.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(section.entries.count) 条建议")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                .accessibilityIdentifier("life-guidance.reference.section.\(section.number)")
            }
        }
        .navigationTitle("按章节浏览")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LifeGuidanceReferenceSectionView: View {
    let section: LifeGuidanceReferenceSection
    @ObservedObject var guidance: LifeGuidanceStore
    @State private var searchText = ""

    private var entries: [LifeGuidanceReferenceEntry] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return section.entries }
        return guidance.referenceBook.search(searchText, sectionNumber: section.number)
    }

    var body: some View {
        List {
            Section {
                TextField("在本节搜索", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("life-guidance.reference.section.search")
            }
            if !section.intro.isEmpty {
                Section("本节导读") {
                    ForEach(Array(section.intro.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph).font(.subheadline)
                    }
                }
            }
            Section("\(entries.count) 条建议") {
                ForEach(entries) { entry in
                    NavigationLink {
                        LifeGuidanceReferenceEntryView(entry: entry, guidance: guidance)
                    } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(entry.number). \(entry.title)")
                                .fixedSize(horizontal: false, vertical: true)
                            Text(entry.humanSummary)
                                .font(.caption)
                                .foregroundStyle(DS.mutedInk)
                                .lineLimit(3)
                        }
                    }
                }
            }
        }
        .navigationTitle("第\(section.number)节")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LifeGuidanceReferenceEntryView: View {
    let entry: LifeGuidanceReferenceEntry
    @ObservedObject var guidance: LifeGuidanceStore
    var snapshot: LifeGuidanceItem? = nil
    var context: LifeGuidanceCardContext? = nil
    @EnvironmentObject private var app: AppStore
    @State private var actionMessage: String?
    @State private var isSaving = false
    @State private var showsCapture = false
    @State private var observation = ""
    @State private var observationFocused = false
    @State private var conversation: MentorFeatureStore?

    private var item: LifeGuidanceItem? { snapshot ?? guidance.referenceBook.item(for: entry) }
    private var saved: LifeGuidanceFeedback? { item.flatMap { guidance.state(for: $0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(entry.title)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityIdentifier("today.life-guidance.details.title")
                if let item {
                    Text(item.category)
                        .font(.subheadline)
                        .foregroundStyle(DS.accentInk)
                }
                if let context, !context.triggers.isEmpty {
                    Text(context.triggers.contains(.dailyReview) ? "回顾相关 · 原指南资料" : "今日一条 · 原指南资料")
                        .font(.subheadline).foregroundStyle(DS.mutedInk)
                }
                if let event = context?.event {
                    referenceBlock("触发这条资料的事件", event.text)
                    if let explanation = context?.explanation { Text(explanation).font(.subheadline) }
                }
                referenceBlock("说人话", entry.humanSummary)
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        showsCapture = true
                    } label: {
                        Label("带入今日闪念", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .foregroundStyle(DS.onAccent)
                    .accessibilityIdentifier("life-guidance.reference.use-in-today")
                    Button {
                        persist(saved?.isSaved == true ? "已取消收藏。" : "已收藏，可以在收藏列表回看。") { $0.isSaved.toggle() }
                    } label: {
                        Label(saved?.isSaved == true ? "已收藏 · 取消收藏" : "收藏这条完整条目",
                              systemImage: saved?.isSaved == true ? "bookmark.fill" : "bookmark")
                    }
                    .accessibilityIdentifier("life-guidance.reference.bookmark")
                    Button("结合我的情况聊聊") {
                        guard let item else { return }
                        isSaving = true
                        Task {
                            if let feature = await app.prepareMentorFeature() {
                                feature.start(entry: "discuss", initialText: item.captureMaterial)
                                conversation = feature
                            } else { actionMessage = "暂时没能打开交流，请重试。" }
                            isSaving = false
                        }
                    }
                    .accessibilityIdentifier("life-guidance.reference.discuss")
                    Button(saved?.hasTried == true ? "已记录试过" : "我试过了") {
                        persist("已记录试过，可以留下实际观察。") { $0.hasTried = true }
                    }
                    .accessibilityIdentifier("life-guidance.tried")
                    if context?.triggers.isEmpty == false {
                        Button("今天不适合我") {
                            let day = guidance.dayKey
                            persist("今天的入口已收起。") { $0.dismissedDayKeys.insert(day) }
                        }
                        .accessibilityIdentifier("life-guidance.dismiss")
                    }
                    ShareLink(item: shareText) { Label("分享条目摘要", systemImage: "square.and.arrow.up") }
                }
                .buttonStyle(.bordered).controlSize(.large)
                .disabled(isSaving)
                if let actionMessage {
                    Text(actionMessage).font(.footnote).foregroundStyle(DS.mutedInk)
                        .accessibilityIdentifier("today.life-guidance.feedback")
                }
                if let error = guidance.errorMessage { Text(error).font(.footnote).foregroundStyle(DS.caution) }
                if saved?.hasTried == true {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("实际观察").font(.headline)
                        PushToTalkInput(text: $observation, placeholder: "做了什么，发生了什么？没有变化也可以记录。", accessibilityIdentifier: "life-guidance.observation", focusBinding: $observationFocused, usesTextEditor: true)
                            .frame(minHeight: 120)
                        Button("保存观察") {
                            let text = observation
                            persist("观察已保存。") { $0.observation = text }
                        }
                        .buttonStyle(.bordered).controlSize(.large).disabled(isSaving)
                        .accessibilityIdentifier("life-guidance.observation.save")
                    }
                }
                referenceBlock("成本", entry.cost)
                referenceBlock("收益", entry.gain)
                referenceBlock("证据等级", entry.evidenceLevel)
                referenceBlock("收益等级", entry.benefitLevel)
                referenceBlock("观察视角", entry.lens)
                referenceBlock("备注", entry.note)
                referenceBlock("成本标签", "钱：\(entry.moneyCost) · 时间：\(entry.timeCost) · 毅力：\(entry.willCost)")
                DisclosureGroup("查看原始条目") {
                    Text(entry.rawMarkdown)
                        .font(.subheadline)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 6)
                }
                .accessibilityIdentifier("life-guidance.reference.raw")
                VStack(alignment: .leading, spacing: 8) {
                    Text("来源").font(.headline)
                    Text(entry.source)
                    if let url = sourceURL {
                        Link("打开 GitHub 原条目", destination: url)
                    }
                }
                .font(.subheadline)
                Text("原项目：\(item?.sourceRepo ?? "") · 提交 \(item?.sourceCommit.prefix(12) ?? "") · 同步 \(item?.retrievedAt ?? "")")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
                Text("内容许可：\(item?.license ?? "")。\(item?.adaptationNote ?? "")")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            .frame(maxWidth: 680, alignment: .leading)
            .padding(DS.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .background(DS.background)
        .foregroundStyle(DS.ink)
        .navigationTitle("指南条目")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("life-guidance.reference.entry")
        .task { await guidance.refresh(); observation = saved?.observation ?? "" }
        .sheet(isPresented: $showsCapture) {
            QuickCaptureSheet(initialText: item?.captureMaterial ?? "").environmentObject(app)
        }
        .sheet(isPresented: Binding(get: { conversation != nil }, set: { if !$0 { conversation = nil } })) {
            if let conversation { MentorConversationView(feature: conversation).environmentObject(app) }
        }
    }

    private var sourceURL: URL? {
        item?.sourceURL
    }

    private var shareText: String {
        "《高性价比人生指南》\n\(entry.title)\n\n说人话：\(entry.humanSummary)\n\n备注：\(entry.note)\n来源：\(entry.source)\n\(sourceURL?.absoluteString ?? "")\n\(item?.license ?? "")"
    }

    private func persist(_ message: String, change: @escaping (inout LifeGuidanceFeedback) -> Void) {
        guard let item else { return }
        isSaving = true
        Task {
            actionMessage = await guidance.update(item, change: change) ? message : nil
            isSaving = false
        }
    }

    private func referenceBlock(_ title: String, _ text: String) -> some View {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return AnyView(EmptyView()) }
        return AnyView(VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(text).fixedSize(horizontal: false, vertical: true)
        })
    }
}

struct SavedLifeGuidanceReferenceView: View {
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        List {
            if guidance.bookmarkedReferenceEntries.isEmpty {
                Text("还没有收藏完整条目。打开一条指南后，点收藏即可在这里回看。")
                    .foregroundStyle(DS.mutedInk)
            }
            ForEach(guidance.bookmarkedReferenceRecords) { record in
                NavigationLink {
                    LifeGuidanceDetailsView(context: LifeGuidanceCardContext(item: record.item, triggers: [], event: nil, explanation: nil), guidance: guidance)
                } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(record.item.title)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("证据\(record.item.evidenceLevel) · 来源 \(record.item.sourceCommit.prefix(8))")
                            .font(.caption)
                            .foregroundStyle(DS.mutedInk)
                    }
                }
                .accessibilityIdentifier("life-guidance.reference.bookmarked.\(record.item.id)")
                .swipeActions {
                    Button("取消收藏") { Task { await guidance.update(record.item) { $0.isSaved = false } } }
                }
            }
        }
        .navigationTitle("我收藏的完整条目")
        .navigationBarTitleDisplayMode(.inline)
        .task { await guidance.refresh() }
    }
}

struct LifeGuidanceReferenceLibraryView: View {
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        List {
            Section("项目说明") {
                ForEach(guidance.referenceBook.readmeSections) { section in
                    NavigationLink {
                        LifeGuidanceReferenceReadmeView(section: section, guidance: guidance)
                    } label: {
                        Text(section.title).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            Section("长文") {
                ForEach(guidance.referenceBook.longReads) { document in
                    NavigationLink {
                        LifeGuidanceReferenceDocumentView(document: document, guidance: guidance)
                    } label: {
                        Text(document.title).fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityIdentifier("life-guidance.reference.document.\(document.id)")
                }
            }
            Section("术语表") {
                ForEach(guidance.referenceBook.glossary) { term in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(term.term).font(.headline)
                        Text(term.meaning).font(.subheadline).foregroundStyle(DS.mutedInk)
                    }
                }
            }
        }
        .navigationTitle("长文与术语表")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LifeGuidanceReferenceReadmeView: View {
    let section: LifeGuidanceReferenceReadmeSection
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LifeGuidanceReferenceTextView(markdown: section.markdown, sourcePath: "README.md", guidance: guidance)
                Text("原项目：\(guidance.referenceBook.sourceRepo) · \(guidance.referenceBook.license)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(DS.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .background(DS.background)
        .foregroundStyle(DS.ink)
        .navigationTitle(section.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LifeGuidanceReferenceDocumentView: View {
    let document: LifeGuidanceReferenceDocument
    @ObservedObject var guidance: LifeGuidanceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                LifeGuidanceReferenceTextView(markdown: document.markdown, sourcePath: document.sourcePath, guidance: guidance)
                Text("原项目：\(guidance.referenceBook.sourceRepo) · \(guidance.referenceBook.license)")
                    .font(.caption)
                    .foregroundStyle(DS.mutedInk)
            }
            .frame(maxWidth: 720, alignment: .leading)
            .padding(DS.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .background(DS.background)
        .foregroundStyle(DS.ink)
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Native reading blocks keep long articles, tables, and relative links usable on a phone.
struct LifeGuidanceReferenceTextView: View {
    let markdown: String
    let sourcePath: String
    @ObservedObject var guidance: LifeGuidanceStore
    @State private var internalLink: ReferenceLink?

    private struct ReferenceLink: Identifiable {
        var id: String { path }
        let path: String
    }

    private var baseURL: URL? {
        URL(string: "https://github.com/\(guidance.referenceBook.sourceRepo)/blob/\(guidance.referenceBook.sourceCommit)/\(sourcePath)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .heading(let level, let text):
                    richText(text).font(level <= 2 ? .title2.weight(.semibold) : .headline)
                        .accessibilityAddTraits(.isHeader)
                case .paragraph(let text): richText(text).font(.body)
                case .code(let text): Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                case .table(let headers, let rows):
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                                    VStack(alignment: .leading, spacing: 3) {
                                        if index < headers.count { richText(headers[index]).font(.caption.weight(.semibold)).foregroundStyle(DS.mutedInk) }
                                        richText(cell)
                                    }
                                }
                            }
                            Divider()
                        }
                    }
                }
            }
        }
        .environment(\.openURL, OpenURLAction { url in
            let prefix = "https://github.com/\(guidance.referenceBook.sourceRepo)/blob/\(guidance.referenceBook.sourceCommit)/"
            if url.absoluteString.hasPrefix(prefix) {
                let path = String(url.absoluteString.dropFirst(prefix.count)).components(separatedBy: "#")[0].removingPercentEncoding ?? ""
                if path == "README.md" || guidance.referenceBook.sections.contains(where: { $0.sourcePath == path }) || guidance.referenceBook.longReads.contains(where: { $0.sourcePath == path }) {
                    internalLink = ReferenceLink(path: path)
                    return .handled
                }
            }
            return .systemAction(url)
        })
        .sheet(item: $internalLink) { link in
            NavigationStack {
                Group {
                    if let section = guidance.referenceBook.sections.first(where: { $0.sourcePath == link.path }) {
                        LifeGuidanceReferenceSectionView(section: section, guidance: guidance)
                    } else if let document = guidance.referenceBook.longReads.first(where: { $0.sourcePath == link.path }) {
                        LifeGuidanceReferenceDocumentView(document: document, guidance: guidance)
                    } else {
                        LifeGuidanceReferenceLibraryView(guidance: guidance)
                    }
                }
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { internalLink = nil }.frame(minWidth: 44, minHeight: 44) } }
            }
        }
    }

    private func richText(_ text: String) -> some View {
        let attributed = (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace), baseURL: baseURL)) ?? AttributedString(text)
        return Text(attributed).textSelection(.enabled)
    }

    private enum Block {
        case heading(Int, String), paragraph(String), code(String), table([String], [[String]])
    }

    private var blocks: [Block] {
        let lines = markdown.components(separatedBy: .newlines)
        var result: [Block] = []
        var paragraph: [String] = []
        var index = 0
        func flush() { if !paragraph.isEmpty { result.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] } }
        func cells(_ line: String) -> [String] { line.trimmingCharacters(in: CharacterSet(charactersIn: "| ")).components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) } }
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("```") {
                flush(); index += 1
                var code: [String] = []
                while index < lines.count && !lines[index].hasPrefix("```") { code.append(lines[index]); index += 1 }
                result.append(.code(code.joined(separator: "\n")))
            } else if line.hasPrefix("|"), index + 1 < lines.count,
                      lines[index + 1].hasPrefix("|"), lines[index + 1].contains("---") {
                flush(); let headers = cells(line); index += 2
                var rows: [[String]] = []
                while index < lines.count && lines[index].hasPrefix("|") { rows.append(cells(lines[index])); index += 1 }
                result.append(.table(headers, rows)); continue
            } else if line.hasPrefix("#") {
                flush(); let level = line.prefix(while: { $0 == "#" }).count
                result.append(.heading(level, String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty { flush() }
            else { paragraph.append(line) }
            index += 1
        }
        flush(); return result
    }
}

struct LifeGuidanceReviewSection: View {
    @ObservedObject var guidance: LifeGuidanceStore
    let reviewID: String
    var body: some View {
        if let exposure = guidance.exposures.first(where: { $0.id == "review:" + reviewID }),
           let item = exposure.item,
           guidance.state(for: item)?.dismissedDayKeys.contains(guidance.dayKey) != true {
            LifeGuidanceCardLink(context: LifeGuidanceCardContext(item: item, triggers: [.dailyReview], event: exposure.event, explanation: exposure.explanation), guidance: guidance)
        }
    }
}
