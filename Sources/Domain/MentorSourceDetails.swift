import Foundation
import CryptoKit

enum MentorSourceDetailStatus: Equatable {
    case available
    case unavailable(String)
    case deleted

    var label: String {
        switch self {
        case .available: return "可查看"
        case .unavailable: return "暂不可查看"
        case .deleted: return "来源已删除"
        }
    }
}

struct MentorSourceDetail: Equatable, Identifiable {
    let id: MentorSourceReference
    let kind: String
    let title: String
    let content: String?
    let sourceVersion: String?
    let contentHash: String?
    let externalLinks: [MentorSourceExternalLink]
    let status: MentorSourceDetailStatus

    var isAvailable: Bool {
        if case .available = status { return content?.isEmpty == false }
        return false
    }
}

struct MentorSourceExternalLink: Equatable, Identifiable {
    let title: String
    let url: URL
    var id: String { url.absoluteString }
}

/// Resolves current-session snapshots and explicitly linked legacy originals.
/// It does not search unrelated history, infer ownership from a string prefix,
/// or call a model. A valid reference without an authorized object is unavailable.
struct MentorSourceResolver {
    func resolve(_ references: [MentorSourceReference], sessionID: UUID,
                 timeline: [MentorTimelineItem], understandings: [MentorUnderstanding],
                 links: [MentorSourceLink], legacyRounds: [LegacyNudgeRound] = [],
                 legacyHistory: LegacyNudgeChain? = nil) -> [MentorSourceDetail] {
        references.map { resolve($0, sessionID: sessionID, timeline: timeline, understandings: understandings, links: links,
            legacyRounds: legacyRounds, legacyHistory: legacyHistory) }
    }

    private func resolve(_ reference: MentorSourceReference, sessionID: UUID,
                         timeline: [MentorTimelineItem], understandings: [MentorUnderstanding],
                         links: [MentorSourceLink], legacyRounds: [LegacyNudgeRound],
                         legacyHistory: LegacyNudgeChain?) -> MentorSourceDetail {
        let parts = reference.value.split(separator: ":", maxSplits: 1).map(String.init)
        guard let kind = parts.first, let rawID = parts.dropFirst().first else {
            return unavailable(reference, kind: "未知来源", title: "无法识别的来源", reason: "来源标识无效。")
        }
        let sourceLink = matchingLink(kind: kind, rawID: rawID, sessionID: sessionID, links: links)
        if sourceLink?.availability == .deleted {
            return MentorSourceDetail(id: reference, kind: kind, title: title(for: kind), content: nil,
                sourceVersion: sourceLink?.sourceVersion, contentHash: sourceLink?.contentHash,
                externalLinks: [], status: .deleted)
        }
        if sourceLink?.availability == .unavailable {
            return unavailable(reference, kind: kind, title: title(for: kind), reason: "这条来源已被标记为不可访问。")
        }

        switch kind {
        case "item":
            guard let itemID = UUID(uuidString: rawID),
                  let item = timeline.first(where: { $0.id == itemID && $0.sessionID == sessionID }) else {
                return unavailable(reference, kind: kind, title: "交流条目", reason: "这条交流内容没有随本次会话保存。")
            }
            guard let parsed = itemContent(item) else {
                return unavailable(reference, kind: kind, title: "交流条目", reason: "已保存的交流内容无法读取。")
            }
            let detail = MentorSourceDetail(id: reference, kind: kind, title: parsed.title,
                content: parsed.content, sourceVersion: nil, contentHash: Self.hash(parsed.content),
                externalLinks: parsed.links, status: .available)
            return validated(detail, link: sourceLink)

        case "understanding":
            guard let noteID = UUID(uuidString: rawID),
                  let note = understandings.first(where: { $0.id == noteID && $0.sessionID == sessionID }),
                  !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return unavailable(reference, kind: kind, title: "我的理解", reason: "这条理解没有随本次会话保存。")
            }
            let detail = MentorSourceDetail(id: reference, kind: kind, title: "我的理解",
                content: note.text, sourceVersion: "revision.\(note.revision)", contentHash: Self.hash(note.text),
                externalLinks: [], status: .available)
            return validated(detail, link: sourceLink)

        case "lesson":
            let lessonParts = rawID.split(separator: "@", maxSplits: 1).map(String.init)
            guard lessonParts.count == 2,
                  let lesson = timeline.compactMap({ item -> MentorLesson? in
                      guard item.sessionID == sessionID, item.kind == .lesson else { return nil }
                      return decodeLesson(item.payloadJSON)
                  }).first(where: { $0.id == lessonParts[0] && $0.version == lessonParts[1] }) else {
                return unavailable(reference, kind: kind, title: "教材来源", reason: "这份教材快照没有随本次会话保存，或版本已经不一致。")
            }
            guard lesson.contentHash == MentorLessonCatalog.contentHash(for: lesson) else {
                return unavailable(reference, kind: kind, title: lesson.title, reason: "教材快照的内容校验未通过。")
            }
            let content = lessonContent(lesson)
            let externalLinks = lesson.citations.compactMap { citation -> MentorSourceExternalLink? in
                guard let url = URL(string: citation.url), ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
                return MentorSourceExternalLink(title: citation.title, url: url)
            }
            let detail = MentorSourceDetail(id: reference, kind: kind, title: lesson.title, content: content,
                sourceVersion: lesson.version, contentHash: lesson.contentHash, externalLinks: externalLinks, status: .available)
            return validated(detail, link: sourceLink)

        case "capture":
            guard let sourceLink, sourceLink.ownerKind == .item, sourceLink.contentHash != nil,
                  let item = timeline.first(where: { $0.id == sourceLink.ownerID && $0.sessionID == sessionID && $0.kind == .user }),
                  let snapshot = itemContent(item) else {
                return unavailable(reference, kind: kind, title: title(for: kind), reason: "这条闪念的原文快照没有随本次交流保存。")
            }
            let detail = MentorSourceDetail(id: reference, kind: kind, title: title(for: kind),
                content: snapshot.content, sourceVersion: nil, contentHash: Self.hash(snapshot.content),
                externalLinks: [], status: .available)
            return validated(detail, link: sourceLink)

        case "legacy-nudge":
            guard let roundID = UUID(uuidString: rawID) else {
                return unavailable(reference, kind: kind, title: title(for: kind), reason: "旧点拨来源标识无效。")
            }
            let hasOwnedProjection = links.contains { link in
                link.sessionID == sessionID && link.sourceKind == kind &&
                UUID(uuidString: link.sourceID) == roundID && link.ownerKind == .item &&
                link.availability == .available &&
                timeline.contains { $0.id == link.ownerID && $0.sessionID == sessionID }
            }
            let isExplicitHistory = legacyHistory?.rootID == sessionID &&
                legacyHistory?.rounds.contains(where: { $0.id == roundID }) == true
            guard hasOwnedProjection || isExplicitHistory else {
                return unavailable(reference, kind: kind, title: title(for: kind), reason: "本次交流没有保存这条原始来源的明确链接。")
            }
            guard let round = legacyRounds.first(where: { $0.id == roundID }) else {
                return unavailable(reference, kind: kind, title: title(for: kind), reason: "原始旧点拨已不可读取，本次交流仍保留对它的引用记录。")
            }
            let content = Self.legacyContent(round.session)
            let detail = MentorSourceDetail(id: reference, kind: kind, title: title(for: kind), content: content,
                sourceVersion: nil, contentHash: Self.hash(content), externalLinks: [], status: .available)
            return validated(detail, link: sourceLink)

        default:
            return unavailable(reference, kind: kind, title: "未知来源", reason: "来源类型不受当前版本支持。")
        }
    }

    private func matchingLink(kind: String, rawID: String, sessionID: UUID, links: [MentorSourceLink]) -> MentorSourceLink? {
        let matches = links.filter { link in
            guard link.sessionID == sessionID,
                  link.sourceKind.caseInsensitiveCompare(kind) == .orderedSame else { return false }
            let source = link.sourceID.trimmingCharacters(in: .whitespacesAndNewlines)
            if source.caseInsensitiveCompare(rawID) == .orderedSame { return true }
            if kind == "lesson", let version = link.sourceVersion {
                return "\(source)@\(version)".caseInsensitiveCompare(rawID) == .orderedSame
            }
            return false
        }
        return matches.first(where: { $0.availability == .deleted }) ??
            matches.first(where: { $0.availability == .unavailable }) ?? matches.first
    }

    private func validated(_ detail: MentorSourceDetail, link: MentorSourceLink?) -> MentorSourceDetail {
        guard let link else { return detail }
        if let version = link.sourceVersion, version != detail.sourceVersion {
            return unavailable(detail.id, kind: detail.kind, title: detail.title, reason: "来源版本与保存快照不一致。")
        }
        if let hash = link.contentHash, hash != detail.contentHash {
            return unavailable(detail.id, kind: detail.kind, title: detail.title, reason: "来源内容与保存快照不一致。")
        }
        return detail
    }

    private func unavailable(_ reference: MentorSourceReference, kind: String, title: String, reason: String) -> MentorSourceDetail {
        MentorSourceDetail(id: reference, kind: kind, title: title, content: nil, sourceVersion: nil,
            contentHash: nil, externalLinks: [], status: .unavailable(reason))
    }

    private func title(for kind: String) -> String {
        switch kind {
        case "capture": return "闪念来源"
        case "legacy-nudge": return "旧点拨来源"
        case "understanding": return "我的理解"
        case "lesson": return "教材来源"
        default: return "交流来源"
        }
    }

    private func itemContent(_ item: MentorTimelineItem) -> (title: String, content: String, links: [MentorSourceExternalLink])? {
        let data = Data(item.payloadJSON.utf8)
        switch item.kind {
        case .user:
            guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: String],
                  Set(object.keys) == ["text"], let text = object["text"], !text.isEmpty else { return nil }
            return ("你说", text, [])
        case .assistant:
            guard let response = try? JSONDecoder().decode(MentorTurnResponse.self, from: data) else { return nil }
            let content = response.question.map { response.body + "\n\n" + $0 } ?? response.body
            return ("导师回应", content, [])
        case .lesson:
            guard let lesson = decodeLesson(item.payloadJSON), lesson.contentHash == MentorLessonCatalog.contentHash(for: lesson) else { return nil }
            let links = lesson.citations.compactMap { citation -> MentorSourceExternalLink? in
                guard let url = URL(string: citation.url), ["http", "https"].contains(url.scheme?.lowercased()) else { return nil }
                return MentorSourceExternalLink(title: citation.title, url: url)
            }
            return (lesson.title, lessonContent(lesson), links)
        }
    }

    private func decodeLesson(_ json: String) -> MentorLesson? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(MentorLesson.self, from: Data(json.utf8))
    }

    private func lessonContent(_ lesson: MentorLesson) -> String {
        var sections = ["观点\n\(lesson.claim)", "例子\n\(lesson.example)", "适用边界\n\(lesson.boundary)"]
        if let observation = lesson.observation, !observation.isEmpty { sections.append("可以观察\n\(observation)") }
        return sections.joined(separator: "\n\n")
    }

    static func hash(_ content: String) -> String {
        let digest = SHA256.hash(data: Data(content.utf8))
        return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Keep original user words and old model output visibly separate. The same
    /// deterministic rendering signs new projection links and displays sources.
    static func legacyContent(_ session: SingleNudgeSession) -> String {
        var sections = ["记录日期\n\(session.dayKey)"]
        func append(_ title: String, _ value: String?) {
            guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            sections.append("\(title)\n\(value)")
        }
        append("当时的原话", session.input)
        append("最初写下的想法", session.before)
        append("当时的问题（AI）", session.question)
        append("你的回答", session.after)
        append("当时的分析（AI）", session.diagnosis)
        append("模型记录的变化（AI）", session.cognitiveShift)
        append("当时的行动建议（AI）", session.thinkingAction)
        append("当时尚未确定（AI）", session.unresolvedUncertainty)
        sections.append("旧版模型的分析不等于你已确认的“我的理解”。")
        return sections.joined(separator: "\n\n")
    }
}
