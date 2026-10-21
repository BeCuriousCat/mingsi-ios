import Foundation

/// A user-authored, immutable piece of material captured outside the daily review.
struct CaptureFragment: Identifiable, Hashable, Codable {
    enum Source: String, Codable, CaseIterable { case app, appIntent = "app_intent" }
    enum Status: String, Codable, CaseIterable { case pending, included, archived }

    let id: UUID
    var rawText: String
    var source: Source
    var status: Status
    var dayKey: String
    var sourceID: String?
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), rawText: String, source: Source = .app, status: Status = .pending, dayKey: String, sourceID: String? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.rawText = rawText; self.source = source; self.status = status; self.dayKey = dayKey; self.sourceID = sourceID; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

struct DailyCaptureDigest: Identifiable, Hashable, Codable {
    enum Status: String, Codable, CaseIterable { case current, accepted, ignored }
    let id: UUID
    var dayKey: String
    var status: Status
    var summary: String
    var themes: [String]
    var recommendedQuestion: String?
    var sourceFragmentIDs: [UUID]
    var createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), dayKey: String, status: Status = .current, summary: String, themes: [String], recommendedQuestion: String? = nil, sourceFragmentIDs: [UUID], createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.dayKey = dayKey; self.status = status; self.summary = summary; self.themes = Array(themes.prefix(3)); self.recommendedQuestion = recommendedQuestion; self.sourceFragmentIDs = sourceFragmentIDs; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

struct CaptureDigestResponse: Codable, Hashable {
    var summary: String
    var themes: [String]
    var recommendedQuestion: String?
    var sourceRefs: [String]

    enum CodingKeys: String, CodingKey {
        case summary, themes
        case recommendedQuestion = "recommended_question"
        case sourceRefs = "source_refs"
    }
}

enum CaptureDayKey {
    static func value(for date: Date, calendar: Calendar = .current) -> String {
        var calendar = calendar
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
