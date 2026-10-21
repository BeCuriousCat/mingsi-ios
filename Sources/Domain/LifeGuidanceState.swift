import CryptoKit
import Foundation

extension LifeGuidanceItem {
    var contentHash: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return SHA256.hash(data: (try? encoder.encode(self)) ?? Data()).map { String(format: "%02x", $0) }.joined()
    }

    var sourceURL: URL? {
        URL(string: "https://github.com/\(sourceRepo)/blob/\(sourceCommit)/\(sourcePath)")
    }

    var captureMaterial: String {
        if let referenceEntry {
            return "参考《高性价比人生指南》：\(title)\n\n\(referenceEntry.rawMarkdown)\n\n出处：\(sourceURL?.absoluteString ?? sourcePath)\n来源提交：\(sourceCommit) · \(license)\n\n我自己的情况："
        }
        return "参考明思建议：\(title)\n\(suggestion)\n第一步：\(firstStep)\n适用边界：\(boundary)\n出处：\(sourceURL?.absoluteString ?? sourcePath)\n\n我自己的情况："
    }
}

struct LifeGuidanceEvent: Codable, Equatable {
    let id: String
    let text: String
}

/// Keeps the exact content version that was shown, including attribution.
struct LifeGuidanceExposure: Codable, Identifiable, Equatable {
    let id: String
    let dayKey: String
    let trigger: LifeGuidanceTrigger
    let item: LifeGuidanceItem?
    let event: LifeGuidanceEvent?
    let explanation: String?
    let createdAt: Date
}

struct LifeGuidanceFeedback: Codable, Identifiable, Equatable {
    var id: String { item.id + "@" + item.version + ":" + item.contentHash }
    let item: LifeGuidanceItem
    var isSaved = false
    var hasTried = false
    var observation = ""
    var dismissedDayKeys: Set<String> = []
    var updatedAt: Date
}

struct LifeGuidanceCardContext: Identifiable, Equatable {
    var id: String { item.id + "@" + item.version }
    let item: LifeGuidanceItem
    var triggers: Set<LifeGuidanceTrigger>
    var event: LifeGuidanceEvent?
    var explanation: String?
}

enum LifeGuidanceCalendar {
    static func distance(from first: String, to second: String) -> Int? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        func date(_ key: String) -> Date? {
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { return nil }
            return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        }
        guard let a = date(first), let b = date(second) else { return nil }
        return calendar.dateComponents([.day], from: a, to: b).day
    }
}
