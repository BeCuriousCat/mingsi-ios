import Foundation

enum LifeGuidanceTrigger: String, Codable, Hashable {
    case daily
    case dailyReview
}

enum LifeGuidanceReviewStatus: String, Codable, Hashable {
    case draft
    case approved
    case retired
}

struct LifeGuidanceCitation: Codable, Hashable {
    var title: String
    var url: String
}

struct LifeGuidanceItem: Identifiable, Codable, Hashable {
    var id: String
    var version: String
    var editorialOrder: Int
    var title: String
    var suggestion: String
    var whyItMayHelp: String
    var firstStep: String
    var cost: String
    var signal: String
    var boundary: String
    var category: String
    var evidenceLevel: String
    var sourceRepo: String
    var sourceCommit: String
    var sourcePath: String
    var sourceHeading: String
    var license: String
    var retrievedAt: String
    var adaptationNote: String
    var keywords: [String]
    var citations: [LifeGuidanceCitation]
    var reviewStatus: LifeGuidanceReviewStatus
    /// Exact upstream material; its presence never implies editorial approval.
    var referenceEntry: LifeGuidanceReferenceEntry? = nil

    var isApproved: Bool { reviewStatus == .approved }
}

enum BuiltinLifeGuidanceCatalog {
    static let sourceRepo = "eternity4719/HowToLiveBetter"
    static let sourceCommit = "e73cb638b27f12a422546e5c09cadcac6fce03fe"
    static let retrievedAt = "2026-10-08"
    static let version = "howtolivebetter.e73cb638.v2"
    private static let expandedVersion = "howtolivebetter.e73cb638.v3"

    static let items: [LifeGuidanceItem] = [
        LifeGuidanceItem(
            id: "life.attention.nonessential-notifications",
            version: version,
            editorialOrder: 1,
            title: "关掉非必要通知，把手机放到视线之外",
            suggestion: "做需要连续思考的事情时，先挡住最常打断你的非必要通知。",
            whyItMayHelp: "即使不点开，收到通知和看到手机也可能消耗注意力。",
            firstStep: "现在选一个最常打断你的应用，关闭非必要通知。",
            cost: "几分钟设置时间；不需要购买东西。",
            signal: "记录这段时间是否更容易完成预定的小结果，以及中断来自哪里。",
            boundary: "值班、照护或正在处理紧急事项时，不要关闭必要提醒。",
            category: "注意力",
            evidenceLevel: "B",
            sourceRepo: sourceRepo,
            sourceCommit: sourceCommit,
            sourcePath: "book/03-不要浪费精力.md",
            sourceHeading: "1. 关掉非必要通知，工作时把手机放到视线之外",
            license: "CC BY 4.0",
            retrievedAt: retrievedAt,
            adaptationNote: "明思将原条目改成可从详情页开始的单一步骤。",
            keywords: ["通知", "消息", "打断", "手机", "注意力"],
            citations: [
                LifeGuidanceCitation(title: "The attentional cost of receiving a cell phone notification", url: "https://doi.org/10.1037/xhp0000100"),
                LifeGuidanceCitation(title: "Brain Drain", url: "https://doi.org/10.1086/691462")
            ],
            reviewStatus: .approved
        ),
        LifeGuidanceItem(
            id: "life.attention.single-task",
            version: version,
            editorialOrder: 2,
            title: "给重要事情留一段不被打断的时间",
            suggestion: "选一个最重要的小结果，先安排一段 25 分钟的连续时间。",
            whyItMayHelp: "连续时间能帮助你分辨困难来自时间不够，还是任务本身没有说清。",
            firstStep: "在今天的日程里留出 25 分钟，并提前挡住可延后的打断。",
            cost: "25 分钟；可能需要和他人说清楚回复时间。",
            signal: "结束后写下完成的小结果和实际发生的中断。",
            boundary: "不要为了完成这条建议而忽略紧急工作、照护责任或必要联系。",
            category: "注意力",
            evidenceLevel: "B",
            sourceRepo: sourceRepo,
            sourceCommit: sourceCommit,
            sourcePath: "book/03-不要浪费精力.md",
            sourceHeading: "6. 做需要连续思考的工作时，把哪怕几秒钟的打断也挡在外面",
            license: "CC BY 4.0",
            retrievedAt: retrievedAt,
            adaptationNote: "明思将动作缩小为一次时间实验。25 分钟是方便尝试的长度，不是研究证明的最佳时长；不承诺提高效率。",
            keywords: ["打断", "专注", "连续", "任务", "工作", "时间"],
            citations: [
                LifeGuidanceCitation(title: "Momentary interruptions can derail the train of thought", url: "https://doi.org/10.1037/a0030986"),
                LifeGuidanceCitation(title: "The cost of interrupted work", url: "https://doi.org/10.1145/1357054.1357072")
            ],
            reviewStatus: .approved
        ),
        LifeGuidanceItem(
            id: "life.sleep.fixed-wake-time",
            version: version,
            editorialOrder: 3,
            title: "固定一个能做到的起床时间",
            suggestion: "先为一周选一个现实的起床锚点，尽量让工作日和休息日不要差太多。",
            whyItMayHelp: "规律作息让你更容易观察睡眠和白天精力的真实变化。",
            firstStep: "写下明天能做到的起床时间；起床后在条件允许时接触自然光。",
            cost: "几分钟准备；休息日可能少睡一会儿。",
            signal: "记录起床时间和当天白天的清醒程度，不把一次表现当成结论。",
            boundary: "生病、轮班、照护或睡眠问题明显时，不要把它当作医疗建议。",
            category: "睡眠",
            evidenceLevel: "B",
            sourceRepo: sourceRepo,
            sourceCommit: sourceCommit,
            sourcePath: "book/03-不要浪费精力.md",
            sourceHeading: "2. 固定起床时间，周末也一样",
            license: "CC BY 4.0",
            retrievedAt: retrievedAt,
            adaptationNote: "明思改写为一周内可观察的起点，不承诺改善睡眠。",
            keywords: ["睡眠", "起床", "作息", "生物钟", "精力"],
            citations: [
                LifeGuidanceCitation(title: "Irregular sleep/wake patterns and academic performance", url: "https://doi.org/10.1038/s41598-017-03171-4")
            ],
            reviewStatus: .approved
        ),
        LifeGuidanceItem(
            id: "life.learning.recall",
            version: version,
            editorialOrder: 4,
            title: "用一次回忆代替重复重读",
            suggestion: "学习后先合上材料，用自己的话写下记得的要点，再回去核对。",
            whyItMayHelp: "主动回忆能让你看见自己真正记住了什么，而不只是读起来熟悉。",
            firstStep: "今天学完一个小主题后，用三句话写下你记得的内容。",
            cost: "几分钟回忆和核对时间。",
            signal: "记录哪些内容能想起、哪些需要回看，下一次据此调整。",
            boundary: "这不是对所有学科和所有人的保证，复杂技能仍需要练习和反馈。",
            category: "学习",
            evidenceLevel: "A",
            sourceRepo: sourceRepo,
            sourceCommit: sourceCommit,
            sourcePath: "book/23-学什么技能划算.md",
            sourceHeading: "14. 学完先合上书自己考一遍，别回头重读",
            license: "CC BY 4.0",
            retrievedAt: retrievedAt,
            adaptationNote: "明思将学习方法改成一次三句话的小练习。",
            keywords: ["学习", "复习", "回忆", "练习", "阅读"],
            citations: [
                LifeGuidanceCitation(title: "Testing (quizzing) boosts classroom learning", url: "https://doi.org/10.1037/bul0000309"),
                LifeGuidanceCitation(title: "Improving Students' Learning With Effective Learning Techniques", url: "https://doi.org/10.1177/1529100612453266")
            ],
            reviewStatus: .approved
        ),
        reviewedItem(
            id: "life.attention.batch-messages", editorialOrder: 5,
            title: "约定一个集中处理消息的时间",
            suggestion: "如果你的工作允许，先选一个时段集中看可延后回复的消息。",
            whyItMayHelp: "减少反复查看可能减轻压力；原研究主要针对邮件，即时消息属于延伸尝试。",
            firstStep: "选一个可延后回复的消息渠道，写下下一次查看时间，并保留必要联系。",
            cost: "几分钟安排；需要与相关的人说明回复节奏。",
            signal: "记录查看次数、压力感受，以及是否耽误了必要回复。",
            boundary: "值班、照护和紧急协作不适用。只调整可以延后的渠道。",
            category: "注意力", evidenceLevel: "B",
            sourcePath: "book/03-不要浪费精力.md",
            sourceHeading: "5. 把邮件和消息改成每天固定几次批量处理",
            keywords: ["消息", "邮件", "通知", "压力", "注意力"],
            citations: [LifeGuidanceCitation(title: "Checking email less frequently reduces stress", url: "https://doi.org/10.1016/j.chb.2014.11.005")]
        ),
        reviewedItem(
            id: "life.time.if-then", editorialOrder: 6,
            title: "把想做的事写成一个具体起点",
            suggestion: "为自己确实想做的一件事，写一句“到了这个时间或情境，我就先做这一步”。",
            whyItMayHelp: "具体起点可能帮助开始行动，但它不能替你决定目标是否值得。",
            firstStep: "补全一句话：明天在____，当____发生，我先____。",
            cost: "一两分钟；不需要额外购买工具。",
            signal: "回看约定的情境是否出现、第一步是否开始，以及卡在哪里。",
            boundary: "只用于你自愿选择的目标，不用它强迫自己接受不想要的安排。",
            category: "时间", evidenceLevel: "A",
            sourcePath: "book/04-不要浪费时间.md",
            sourceHeading: "1. 把「打算做」写成「几点、在哪、遇到什么就做什么」",
            keywords: ["计划", "开始", "目标", "行动", "时间"],
            citations: [LifeGuidanceCitation(title: "Implementation intentions and goal achievement", url: "https://doi.org/10.1016/S0065-2601(06)38002-1")]
        ),
        reviewedItem(
            id: "life.time.exit-condition", editorialOrder: 7,
            title: "开始前写下何时重新判断",
            suggestion: "为一个可调整的小尝试写下检查日期，以及到时继续、修改或停止的依据。",
            whyItMayHelp: "事先写条件能提供回看依据；原研究并未单独证明能节省多少时间。",
            firstStep: "写下：到____，如果还没看到____，我就重新判断这次尝试。",
            cost: "约五分钟；可能需要与共同参与的人协商。",
            signal: "到检查日期时，是否有足够事实决定下一步。",
            boundary: "不能用它单方面取消已承担的责任或必要照护；涉及合同和重要承诺先协商。",
            category: "判断", evidenceLevel: "B",
            sourcePath: "book/04-不要浪费时间.md",
            sourceHeading: "2. 开工前写下退出条件",
            keywords: ["判断", "尝试", "退出", "复盘", "时间"],
            citations: [LifeGuidanceCitation(title: "Implementation intentions and goal achievement", url: "https://doi.org/10.1016/S0065-2601(06)38002-1")]
        ),
        reviewedItem(
            id: "life.decision.future-cost", editorialOrder: 8,
            title: "把已经投入和接下来要投入分开",
            suggestion: "犹豫是否继续一件事时，先列未来还需要的投入和可能获得的结果。",
            whyItMayHelp: "已经投入的成本可能影响继续的意愿。分开列出有助于看清正在做的判断。",
            firstStep: "分两行写：接下来还要投入什么；继续之后可能改变什么。",
            cost: "几分钟记录；接受过去的投入已经发生可能让人不舒服。",
            signal: "是否能说清继续的理由来自未来结果，而不只来自不甘心。",
            boundary: "不直接建议停止工作、关系或投资；法律义务、责任和退出成本也属于未来需要考虑的条件。",
            category: "判断", evidenceLevel: "B",
            sourcePath: "book/04-不要浪费时间.md",
            sourceHeading: "3. 决定是否继续时，只看未来投入和未来回报，不看已投入多少",
            keywords: ["决定", "投入", "选择", "沉没成本", "判断"],
            citations: [LifeGuidanceCitation(title: "On the sunk-cost effect in economic decision-making", url: "https://doi.org/10.1007/s40685-014-0014-8")]
        ),
        reviewedItem(
            id: "life.work.reference-estimate", editorialOrder: 9,
            title: "估时间前先看上一次实际用了多久",
            suggestion: "为相似任务估时间时，先找一个最近的实际完成记录。",
            whyItMayHelp: "过去的耗时提供另一种参照，但任务差异很大时不能照搬。",
            firstStep: "找一件类似的已完成任务，写下实际耗时和这次不同的条件。",
            cost: "几分钟查找记录；没有记录时可以先开始记录。",
            signal: "完成后比较估计与实际，记下差异来自哪里。",
            boundary: "样本太少或任务完全不同，记录只能作参考；不要把估计当作对他人的保证。",
            category: "工作", evidenceLevel: "B",
            sourcePath: "book/04-不要浪费时间.md",
            sourceHeading: "4. 估工期时按过去同类任务的实际耗时估，不按计划推",
            keywords: ["估计", "耗时", "任务", "计划", "工作"],
            citations: [LifeGuidanceCitation(title: "Exploring the planning fallacy", url: "https://doi.org/10.1037/0022-3514.67.3.366")]
        ),
        reviewedItem(
            id: "life.communication.agenda", editorialOrder: 10,
            title: "会前先写清要确认的一件事",
            suggestion: "在你能安排的会议前，发出一段简短议程，说明需要共同确认什么。",
            whyItMayHelp: "有议程与参会者感到会议有效相关；这并不证明所有会议的实际产出都会提高。",
            firstStep: "写下本次会议要确认的一件事和需要的信息，提前发给相关的人。",
            cost: "五到十分钟准备；需要相关的人配合。",
            signal: "会后回看是否确认了议程中的事情，还有什么没有说清。",
            boundary: "不要因为没有议程而擅自拒绝必要会议；紧急情况可先处理，再补记录。",
            category: "沟通", evidenceLevel: "B",
            sourcePath: "book/04-不要浪费时间.md",
            sourceHeading: "5. 会前发议程，没议程的会不开；能站着开就站着开",
            keywords: ["会议", "沟通", "议程", "协作", "确认"],
            citations: [LifeGuidanceCitation(title: "Perceived meeting effectiveness", url: "https://doi.org/10.1007/s10869-009-9092-6")]
        ),
        reviewedItem(
            id: "life.money.subscription-check", editorialOrder: 11,
            title: "核对一个已经很少使用的订阅",
            suggestion: "先检查一个重复扣费的服务，确认是否还需要和下一次扣费时间。",
            whyItMayHelp: "节省来自你实际取消的不再需要的服务，不能用统一数字估计。",
            firstStep: "打开一个订阅的管理页，记录用途、费用和下次扣费日期，再自己决定是否保留。",
            cost: "几分钟检查；取消可能失去服务或优惠。",
            signal: "之后核对账单是否与自己的选择一致。",
            boundary: "不自动取消订阅；必要服务和年付优惠要一起考虑。本条不提供法律或投资意见。",
            category: "金钱", evidenceLevel: "C",
            sourcePath: "book/05-不要浪费钱.md",
            sourceHeading: "1. 关掉所有自动续费，改为到期手动续",
            keywords: ["订阅", "自动续费", "账单", "金钱", "消费"],
            citations: [LifeGuidanceCitation(title: "网络交易监督管理办法", url: "https://www.samr.gov.cn/zw/zfxxgk/fdzdgknr/fgs/art/2025/art_4b47c79b8d994a42bba4835997688faa.html")]
        ),
        reviewedItem(
            id: "life.learning.spaced-recall", editorialOrder: 12,
            title: "把一次复习分到不同的日子",
            suggestion: "在总时间不增加的情况下，把同一小主题的回忆安排到不同的日子。",
            whyItMayHelp: "分散练习对记忆有研究支持；复杂技能的最佳间隔没有统一日程。",
            firstStep: "选一个已经学过的小主题，给下一次合上材料回忆留一个现实的日期。",
            cost: "几分钟安排；需要提前开始。",
            signal: "下一次回忆时能想起什么，哪些地方仍需核对。",
            boundary: "不承诺适用于所有学科，也不替代技能练习与反馈；紧急考试按实际时间安排。",
            category: "学习", evidenceLevel: "A",
            sourcePath: "book/23-学什么技能划算.md",
            sourceHeading: "15. 把同样的时间摊到几天，别一次学完",
            keywords: ["学习", "复习", "记忆", "练习", "间隔"],
            citations: [LifeGuidanceCitation(title: "Distributed practice in verbal recall tasks", url: "https://doi.org/10.1037/0033-2909.132.3.354")]
        )
    ]

    private static func reviewedItem(
        id: String, editorialOrder: Int, title: String, suggestion: String,
        whyItMayHelp: String, firstStep: String, cost: String, signal: String,
        boundary: String, category: String, evidenceLevel: String,
        sourcePath: String, sourceHeading: String, keywords: [String],
        citations: [LifeGuidanceCitation]
    ) -> LifeGuidanceItem {
        LifeGuidanceItem(
            id: id, version: expandedVersion, editorialOrder: editorialOrder,
            title: title, suggestion: suggestion, whyItMayHelp: whyItMayHelp,
            firstStep: firstStep, cost: cost, signal: signal, boundary: boundary,
            category: category, evidenceLevel: evidenceLevel, sourceRepo: sourceRepo,
            sourceCommit: sourceCommit, sourcePath: sourcePath, sourceHeading: sourceHeading,
            license: "CC BY 4.0", retrievedAt: retrievedAt,
            adaptationNote: "明思缩小了动作并补充适用边界，不复制收益数字，也不承诺效果。",
            keywords: keywords, citations: citations, reviewStatus: .approved
        )
    }
}

struct LifeGuidanceDailySelection: Hashable {
    var dayKey: String
    var itemID: String
}


struct LifeGuidanceSelector {
    var catalog: [LifeGuidanceItem] = BuiltinLifeGuidanceCatalog.items

    func approvedItems() -> [LifeGuidanceItem] {
        catalog.filter { $0.isApproved && Self.isPublishable($0) }.sorted { $0.editorialOrder < $1.editorialOrder }
    }

    func eligibleItems() -> [LifeGuidanceItem] {
        catalog.filter(Self.isEligible).sorted { $0.editorialOrder < $1.editorialOrder }
    }

    static func isEligible(_ item: LifeGuidanceItem) -> Bool {
        if let entry = item.referenceEntry {
            return item.reviewStatus == .draft && item.id == entry.id && item.title == entry.title &&
                item.suggestion == entry.humanSummary && item.boundary == entry.note &&
                item.whyItMayHelp == entry.gain && item.cost == entry.cost && item.evidenceLevel == entry.evidenceLevel &&
                item.sourcePath == entry.sourcePath && item.sourceHeading == entry.sourceHeading &&
                !entry.rawMarkdown.isEmpty && !entry.source.isEmpty && !entry.humanSummary.isEmpty &&
                !item.sourceCommit.isEmpty && !item.version.isEmpty &&
                item.sourceRepo.split(separator: "/").count == 2 && item.license == "CC BY 4.0" &&
                LifeGuidanceCalendar.distance(from: item.retrievedAt, to: item.retrievedAt) != nil
        }
        return item.isApproved && isPublishable(item)
    }

    static func isPublishable(_ item: LifeGuidanceItem) -> Bool {
        !item.version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.suggestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.whyItMayHelp.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.firstStep.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.cost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.signal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.boundary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.sourceRepo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.sourceCommit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            item.license == "CC BY 4.0" &&
            item.sourceRepo.split(separator: "/").count == 2 &&
            !item.sourcePath.isEmpty && !item.sourceHeading.isEmpty && !item.adaptationNote.isEmpty &&
            LifeGuidanceCalendar.distance(from: item.retrievedAt, to: item.retrievedAt) != nil &&
            ["A", "B", "C"].contains(item.evidenceLevel) &&
            !item.citations.isEmpty && item.citations.allSatisfy {
                !$0.title.isEmpty && URL(string: $0.url)?.scheme == "https" && URL(string: $0.url)?.host != nil
            }
    }

    func dailySelection(dayKey: String, seed: Int? = nil) -> LifeGuidanceDailySelection? {
        let items = eligibleItems()
        guard !items.isEmpty else { return nil }
        let index = seed.map { Int($0.magnitude % UInt(items.count)) } ?? stableIndex(for: dayKey, count: items.count)
        return LifeGuidanceDailySelection(dayKey: dayKey, itemID: items[index].id)
    }

    func item(for selection: LifeGuidanceDailySelection) -> LifeGuidanceItem? {
        eligibleItems().first { $0.id == selection.itemID }
    }


    private func stableIndex(for key: String, count: Int) -> Int {
        let value = key.utf8.reduce(17) { (($0 * 31) + Int($1)) & 0x7fffffff }
        return value % count
    }
}
