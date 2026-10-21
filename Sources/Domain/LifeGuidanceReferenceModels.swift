import Foundation

struct LifeGuidanceReferenceCounts: Codable, Equatable {
    let sections: Int
    let entries: Int
    let longReads: Int
}

struct LifeGuidanceReferenceEntry: Identifiable, Codable, Hashable {
    let id: String
    let number: Int
    let title: String
    let cost: String
    let humanSummary: String
    let gain: String
    let evidenceLevel: String
    let source: String
    let note: String
    let moneyCost: String
    let timeCost: String
    let willCost: String
    let benefitLevel: String
    let lens: String
    let sourcePath: String
    let sourceHeading: String
    let rawMarkdown: String
}

struct LifeGuidanceReferenceSection: Identifiable, Codable, Hashable {
    let id: String
    let number: Int
    let title: String
    let sourcePath: String
    let intro: [String]
    let entries: [LifeGuidanceReferenceEntry]
}

struct LifeGuidanceReferenceDocument: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let sourcePath: String
    let markdown: String
}

struct LifeGuidanceReferenceReadmeSection: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let markdown: String
}

struct LifeGuidanceGlossaryTerm: Identifiable, Codable, Hashable {
    var id: String { term }
    let term: String
    let meaning: String
}

struct LifeGuidanceReferenceBook: Codable, Equatable {
    let schemaVersion: Int
    let title: String
    let summary: String
    let sourceRepo: String
    let sourceCommit: String
    let retrievedAt: String
    let license: String
    let attribution: String
    let counts: LifeGuidanceReferenceCounts
    let sections: [LifeGuidanceReferenceSection]
    let longReads: [LifeGuidanceReferenceDocument]
    let readmeSections: [LifeGuidanceReferenceReadmeSection]
    let glossary: [LifeGuidanceGlossaryTerm]

    var entries: [LifeGuidanceReferenceEntry] {
        sections.flatMap(\.entries)
    }

    var categories: [String] {
        sections.map { "第\($0.number)节 · \($0.title)" }
    }

    var recommendationItems: [LifeGuidanceItem] {
        sections.flatMap { section in
            section.entries.map { entry in
                LifeGuidanceItem(
                    id: entry.id, version: "reference." + sourceCommit,
                    editorialOrder: 1_000 + section.number * 100 + entry.number,
                    title: entry.title, suggestion: entry.humanSummary, whyItMayHelp: entry.gain,
                    firstStep: "", cost: entry.cost, signal: "", boundary: entry.note,
                    category: "第\(section.number)节 · \(section.title)", evidenceLevel: entry.evidenceLevel,
                    sourceRepo: sourceRepo, sourceCommit: sourceCommit, sourcePath: entry.sourcePath,
                    sourceHeading: entry.sourceHeading, license: license, retrievedAt: retrievedAt,
                    adaptationNote: attribution, keywords: [], citations: [], reviewStatus: .draft,
                    referenceEntry: entry
                )
            }
        }
    }

    func item(for entry: LifeGuidanceReferenceEntry) -> LifeGuidanceItem? {
        recommendationItems.first { $0.referenceEntry == entry }
    }

    func section(number: Int) -> LifeGuidanceReferenceSection? {
        sections.first { $0.number == number }
    }

    func search(
        _ query: String,
        evidenceLevel: String? = nil,
        sectionNumber: Int? = nil,
        benefitLevel: String? = nil,
        lowCostOnly: Bool = false
    ) -> [LifeGuidanceReferenceEntry] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return sections
            .filter { sectionNumber == nil || $0.number == sectionNumber }
            .flatMap(\.entries)
            .filter { entry in
                guard evidenceLevel == nil || evidenceLevel == "全部" || entry.evidenceLevel == evidenceLevel else { return false }
                guard benefitLevel == nil || benefitLevel == "全部" || entry.benefitLevel == benefitLevel else { return false }
                if lowCostOnly {
                    let lowMoney = entry.moneyCost == "0" || entry.moneyCost == "少"
                    let lowTime = entry.timeCost == "少"
                    let lowWill = entry.willCost == "否"
                    guard lowMoney && lowTime && lowWill else { return false }
                }
                guard !normalized.isEmpty else { return true }
                let haystack = [entry.title, entry.humanSummary, entry.cost, entry.gain, entry.evidenceLevel,
                                entry.source, entry.note, entry.sourceHeading, entry.sourcePath,
                                entry.benefitLevel, entry.lens, entry.rawMarkdown]
                    .joined(separator: "\n")
                    .lowercased()
                return haystack.contains(normalized)
            }
    }

    static let empty = LifeGuidanceReferenceBook(
        schemaVersion: 1,
        title: "高性价比人生指南",
        summary: "完整参考库暂不可用。",
        sourceRepo: "eternity4719/HowToLiveBetter",
        sourceCommit: "",
        retrievedAt: "",
        license: "CC BY 4.0",
        attribution: "",
        counts: LifeGuidanceReferenceCounts(sections: 0, entries: 0, longReads: 0),
        sections: [],
        longReads: [],
        readmeSections: [],
        glossary: []
    )

    static func loadBundled(bundle: Bundle = .main) -> LifeGuidanceReferenceBook {
        guard let url = bundle.url(forResource: "life-guidance-reference", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let book = try? JSONDecoder().decode(Self.self, from: data) else {
            return .empty
        }
        return book
    }

    static func decode(_ data: Data) throws -> LifeGuidanceReferenceBook {
        try JSONDecoder().decode(Self.self, from: data)
    }
}
