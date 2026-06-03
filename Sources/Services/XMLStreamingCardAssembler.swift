import Foundation

enum StreamingCardStatus: Hashable {
    case receiving
    case closed
    case invalid(String)
}

struct StreamingCardDraft: Identifiable, Hashable {
    let id: UUID
    var type: String
    var title: String
    var body: String
    var importance: String
    var sensitivity: String
    var confidence: String
    var reason: String
    var status: StreamingCardStatus

    init(
        id: UUID = UUID(),
        type: String = "",
        title: String = "",
        body: String = "",
        importance: String = "",
        sensitivity: String = "",
        confidence: String = "",
        reason: String = "",
        status: StreamingCardStatus = .receiving
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.body = body
        self.importance = importance
        self.sensitivity = sensitivity
        self.confidence = confidence
        self.reason = reason
        self.status = status
    }

    var domainCard: ThinkingCard? {
        let normalizedTitle = title.mingsiStreamTrimmed
        let normalizedBody = body.mingsiStreamTrimmed.mingsiStreamIfEmpty(reason.mingsiStreamTrimmed)
        guard !normalizedTitle.isEmpty || !normalizedBody.isEmpty else { return nil }
        guard case .closed = status else { return nil }

        return ThinkingCard(
            type: ThinkingCardType(mingsiStreamRawValue: type),
            title: normalizedTitle.mingsiStreamIfEmpty("未命名卡片"),
            body: normalizedBody,
            priority: PriorityLevel(mingsiStreamRawValue: importance),
            sensitivity: SensitivityLevel(mingsiStreamRawValue: sensitivity),
            confidence: mingsiStreamConfidenceScore(from: confidence),
            isConfirmed: false
        )
    }
}

enum StreamingCardAssemblerEvent: Hashable {
    case updated([StreamingCardDraft])
}

final class XMLStreamingCardAssembler {
    private enum Field: String, CaseIterable {
        case type = "TYPE"
        case title = "TITLE"
        case body = "BODY"
        case importance = "IMPORTANCE"
        case sensitivity = "SENSITIVITY"
        case confidence = "CONFIDENCE"
        case reason = "REASON"
    }

    private static let allowedTags: Set<String> = Set(
        ["MINGSI_STREAM", "/MINGSI_STREAM", "CARD", "/CARD"] +
        Field.allCases.flatMap { [$0.rawValue, "/\($0.rawValue)"] }
    )

    private var buffer = ""
    private var cards: [StreamingCardDraft] = []
    private var currentField: Field?

    var currentCards: [StreamingCardDraft] {
        cards
    }

    @discardableResult
    func append(_ text: String) -> [StreamingCardAssemblerEvent] {
        guard !text.isEmpty else { return [] }
        buffer += text
        return processBuffer()
    }

    @discardableResult
    func finish() -> [StreamingCardAssemblerEvent] {
        var events: [StreamingCardAssemblerEvent] = []
        let trailingText = buffer
        buffer = ""
        appendText(trailingText)

        if let index = cards.indices.last,
           case .receiving = cards[index].status {
            cards[index].status = .invalid("流式输出中断，卡片没有闭合。")
            events.append(.updated(cards))
        }
        return events
    }

    private func processBuffer() -> [StreamingCardAssemblerEvent] {
        var events: [StreamingCardAssemblerEvent] = []

        while let tagStart = buffer.firstIndex(of: "<") {
            let beforeTag = String(buffer[..<tagStart])
            appendText(beforeTag)
            buffer.removeSubrange(..<tagStart)

            guard let tagEnd = buffer.firstIndex(of: ">") else {
                if !beforeTag.isEmpty {
                    events.append(.updated(cards))
                }
                return events
            }

            let rawTag = String(buffer[buffer.index(after: buffer.startIndex)..<tagEnd])
            guard Self.isKnownTag(rawTag) else {
                appendText("<")
                buffer.removeFirst()
                events.append(.updated(cards))
                continue
            }
            buffer.removeSubrange(...tagEnd)
            handleTag(rawTag)
            events.append(.updated(cards))
        }

        appendText(buffer)
        if !buffer.isEmpty {
            events.append(.updated(cards))
        }
        buffer = ""
        return events
    }

    private func handleTag(_ rawTag: String) {
        let tag = rawTag
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
        guard !tag.isEmpty else { return }

        if tag == "MINGSI_STREAM" || tag == "/MINGSI_STREAM" {
            currentField = nil
            return
        }

        if tag == "CARD" {
            cards.append(StreamingCardDraft())
            currentField = nil
            return
        }

        if tag == "/CARD" {
            closeCurrentCard()
            currentField = nil
            return
        }

        if tag.hasPrefix("/") {
            currentField = nil
            return
        }

        currentField = Field(rawValue: tag)
    }

    private func appendText(_ text: String) {
        guard let currentField, !text.isEmpty, let index = cards.indices.last else { return }
        switch currentField {
        case .type:
            cards[index].type += text
        case .title:
            cards[index].title += text
        case .body:
            cards[index].body += text
        case .importance:
            cards[index].importance += text
        case .sensitivity:
            cards[index].sensitivity += text
        case .confidence:
            cards[index].confidence += text
        case .reason:
            cards[index].reason += text
        }
    }

    private func closeCurrentCard() {
        guard let index = cards.indices.last else { return }
        cards[index].type = cards[index].type.mingsiStreamTrimmed
        cards[index].title = cards[index].title.mingsiStreamTrimmed
        cards[index].body = cards[index].body.mingsiStreamTrimmed
        cards[index].importance = cards[index].importance.mingsiStreamTrimmed
        cards[index].sensitivity = cards[index].sensitivity.mingsiStreamTrimmed
        cards[index].confidence = cards[index].confidence.mingsiStreamTrimmed
        cards[index].reason = cards[index].reason.mingsiStreamTrimmed

        let hasUsableContent =
            !cards[index].title.isEmpty ||
            !cards[index].body.isEmpty ||
            !cards[index].reason.isEmpty
        guard hasUsableContent else {
            cards[index].status = .invalid("卡片缺少标题或正文。")
            return
        }

        if let validationError = Self.validationError(for: cards[index]) {
            cards[index].status = .invalid(validationError)
        } else {
            cards[index].status = .closed
        }
    }

    private static func isKnownTag(_ rawTag: String) -> Bool {
        let tag = normalizedTag(rawTag)
        return allowedTags.contains(tag)
    }

    private static func normalizedTag(_ rawTag: String) -> String {
        rawTag
            .split(separator: " ")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased() ?? ""
    }

    private static func validationError(for card: StreamingCardDraft) -> String? {
        if ThinkingCardType(rawValue: card.type.normalizedMingsiStreamRawValue) == nil {
            return "TYPE 不在允许范围内。"
        }
        if PriorityLevel(rawValue: card.importance.normalizedMingsiStreamRawValue) == nil {
            return "IMPORTANCE 不在允许范围内。"
        }
        if SensitivityLevel(mingsiStreamRawValue: card.sensitivity).rawValue != card.sensitivity.normalizedMingsiStreamSensitivityStorageValue {
            return "SENSITIVITY 不在允许范围内。"
        }
        if mingsiStreamConfidenceScore(from: card.confidence).isNaN {
            return "CONFIDENCE 不在允许范围内。"
        }
        return nil
    }
}

private extension ThinkingCardType {
    init(mingsiStreamRawValue: String) {
        self = ThinkingCardType(rawValue: mingsiStreamRawValue.normalizedMingsiStreamRawValue) ?? .idea
    }
}

private extension PriorityLevel {
    init(mingsiStreamRawValue: String) {
        self = PriorityLevel(rawValue: mingsiStreamRawValue.normalizedMingsiStreamRawValue) ?? .medium
    }
}

private extension SensitivityLevel {
    init(mingsiStreamRawValue: String) {
        switch mingsiStreamRawValue.normalizedMingsiStreamRawValue {
        case "sensitive":
            self = .sensitive
        case "possibly_sensitive", "possiblysensitive":
            self = .possiblySensitive
        default:
            self = .normal
        }
    }
}

private extension String {
    var mingsiStreamTrimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var normalizedMingsiStreamRawValue: String {
        mingsiStreamTrimmed
            .lowercased()
            .replacingOccurrences(of: "-", with: "_")
            .replacingOccurrences(of: " ", with: "_")
    }

    var normalizedMingsiStreamSensitivityStorageValue: String {
        switch normalizedMingsiStreamRawValue {
        case "possibly_sensitive", "possiblysensitive":
            return SensitivityLevel.possiblySensitive.rawValue
        case "sensitive":
            return SensitivityLevel.sensitive.rawValue
        case "normal":
            return SensitivityLevel.normal.rawValue
        default:
            return normalizedMingsiStreamRawValue
        }
    }

    func mingsiStreamIfEmpty(_ fallback: String) -> String {
        isEmpty ? fallback : self
    }
}

private func mingsiStreamConfidenceScore(from rawValue: String) -> Double {
    switch rawValue.lowercased().mingsiStreamTrimmed {
    case "high":
        return 0.86
    case "medium":
        return 0.72
    case "low":
        return 0.48
    default:
        if let number = Double(rawValue) {
            if number > 1 {
                return min(max(number / 100, 0), 1)
            }
            return min(max(number, 0), 1)
        }
        return .nan
    }
}
