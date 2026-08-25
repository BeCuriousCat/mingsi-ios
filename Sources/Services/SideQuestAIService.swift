import Foundation

/// The LLM is the decision maker for life invitations. Local code only checks
/// consent, frequency, safety boundaries, and durable state transitions.
struct SideQuestPlanningContext: Hashable {
    var preference: SideQuestPreference
    var lifeContextProfile: SideQuestLifeContextProfile = .init()
    var now: Date
    var rawTodayText: String
    var trainingCases: [TrainingCase]
    var recentRuns: [SideQuestRun]
    var recentCorrections: [SideQuestCorrectionEvent] = []
    var experienceSummary: SideQuestExperienceSummary
    var contextSnapshot: SideQuestContextSnapshot?
    var season: SideQuestExplorationSeason? = nil
}

struct SideQuestAIPlan: Hashable {
    var shouldOffer: Bool
    var reason: String
    var run: SideQuestRun?
    var promptRunId: UUID
}

enum SideQuestPlanningError: LocalizedError {
    case invalidDecision
    case ungroundedDecision
    case unsafeProposal(String)

    var errorDescription: String? {
        switch self {
        case .invalidDecision:
            return "生活奇遇的生成结果不完整。"
        case .ungroundedDecision:
            return "生活奇遇没有说明它为什么适合此刻。"
        case .unsafeProposal(let reason):
            return "生活奇遇未通过安全边界：\(reason)"
        }
    }
}

final class SideQuestAIService {
    private let promptProvider: PromptProvider
    private let llmClient: LLMClient

    init(promptProvider: PromptProvider, llmClient: LLMClient) {
        self.promptProvider = promptProvider
        self.llmClient = llmClient
    }

    func plan(for context: SideQuestPlanningContext) async throws -> SideQuestAIPlan {
        let sourceIDs = Array(Set(context.trainingCases.map(\.id.uuidString))).sorted()
        let allowedCategories = context.preference.enabledCategories
            .subtracting(context.lifeContextProfile.unavailableCategories)
        guard !allowedCategories.isEmpty else {
            return SideQuestAIPlan(
                shouldOffer: false,
                reason: "你已关闭当前可用的生活奇遇方向。",
                run: nil,
                promptRunId: UUID()
            )
        }
        let request = LLMRequest(
            prompt: promptProvider.template(for: .generateSideQuest, mode: .standard),
            inputSummary: "side_quest_planning; cases=\(context.trainingCases.count); recent_runs=\(context.recentRuns.count)",
            contextPayload: PromptContextPayload(
                currentInput: .init(
                    dailyEntryId: context.trainingCases.first?.dailyEntryId.uuidString,
                    rawText: Self.serializedContext(context)
                ),
                userChoice: .init(sessionMode: SessionMode.standard.rawValue),
                privacy: .init(rules: "Use only the supplied local context. System data is already reduced on-device; never request or infer raw location, calendar text, contacts, health samples, or private account data.")
            ),
            sourceRecordIDs: sourceIDs,
            contextVersion: 1,
            contextRecordIDs: sourceIDs
        )
        let data = try await llmClient.complete(request)
        let decision = try Self.decodeDecision(data)
        let reason = decision.reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !reason.isEmpty else { throw SideQuestPlanningError.invalidDecision }

        switch decision.decision {
        case "hold":
            return SideQuestAIPlan(
                shouldOffer: false,
                reason: reason,
                run: nil,
                promptRunId: request.traceID
            )
        case "offer":
            guard let offer = decision.offer else { throw SideQuestPlanningError.invalidDecision }
            let allowedGroundingRefs = Self.availableGroundingRefs(for: context)
            try Self.validateGrounding(decision: decision, allowed: allowedGroundingRefs)
            try Self.validateInvitationConditions(
                offer: offer,
                groundingRefs: Set(decision.groundingRefs)
            )
            let run = try Self.makeRun(
                offer: offer,
                rationale: reason,
                promptRunID: request.traceID,
                preference: context.preference,
                lifeContextProfile: context.lifeContextProfile,
                season: context.season,
                at: context.now
            )
            return SideQuestAIPlan(
                shouldOffer: true,
                reason: reason,
                run: run,
                promptRunId: request.traceID
            )
        default:
            throw SideQuestPlanningError.invalidDecision
        }
    }

    private static func makeRun(
        offer: OfferDTO,
        rationale: String,
        promptRunID: UUID,
        preference: SideQuestPreference,
        lifeContextProfile: SideQuestLifeContextProfile,
        season: SideQuestExplorationSeason?,
        at date: Date
    ) throws -> SideQuestRun {
        guard let category = category(from: offer.category),
              preference.enabledCategories.contains(category),
              !lifeContextProfile.unavailableCategories.contains(category),
              offer.minimumMinutes >= 5,
              offer.maximumMinutes >= offer.minimumMinutes,
              offer.maximumMinutes <= 45,
              (10...30).contains(offer.completionExperience),
              (0...5).contains(offer.reflectionBonusExperience)
        else {
            throw SideQuestPlanningError.invalidDecision
        }
        let prerequisites = try offer.prerequisiteIds.map { id -> SideQuestPrerequisite in
            guard let prerequisite = SideQuestPrerequisite(rawValue: id) else {
                throw SideQuestPlanningError.invalidDecision
            }
            return prerequisite
        }
        let title = offer.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let invitation = offer.invitation.trimmingCharacters(in: .whitespacesAndNewlines)
        let evidencePrompt = offer.evidencePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !invitation.isEmpty, !evidencePrompt.isEmpty else {
            throw SideQuestPlanningError.invalidDecision
        }
        try SideQuestSafetyPolicy().validate(
            title: title,
            invitation: invitation,
            category: category,
            prerequisites: prerequisites
        )
        let activeSeason = season.flatMap { season in
            season.status == .active && date >= season.startedAt && date < season.endsAt ? season : nil
        }
        let elapsedDays = activeSeason.flatMap {
            Calendar.current.dateComponents([.day], from: $0.startedAt, to: date).day
        } ?? 0
        return SideQuestRun(
            catalogId: "ai.\(promptRunID.uuidString)",
            catalogVersion: "life-orchestrator.v1",
            origin: .aiGenerated,
            promptRunId: promptRunID,
            decisionRationale: rationale,
            category: category,
            title: String(title.prefix(60)),
            invitation: String(invitation.prefix(360)),
            evidencePrompt: String(evidencePrompt.prefix(240)),
            prerequisites: prerequisites,
            minimumMinutes: offer.minimumMinutes,
            maximumMinutes: offer.maximumMinutes,
            reward: SideQuestReward(
                track: track(for: category),
                completionExperience: offer.completionExperience,
                reflectionBonusExperience: offer.reflectionBonusExperience
            ),
            offeredAt: date,
            notificationTitle: normalizedOptional(offer.notificationTitle, maximumLength: 80),
            notificationBody: normalizedOptional(offer.notificationBody, maximumLength: 160),
            seasonId: activeSeason?.id,
            seasonDay: activeSeason.map { min($0.maxDays, max(1, elapsedDays + 1)) },
            seasonStep: activeSeason.map { _ in "invitation" },
            createdAt: date,
            updatedAt: date
        )
    }

    /// The central model still decides whether to offer. This validation only
    /// rejects an offer that claims an unsupported situational reason.
    private static func validateGrounding(decision: DecisionDTO, allowed: Set<String>) throws {
        let references = decision.groundingRefs
        guard !references.isEmpty,
              Set(references).count == references.count,
              references.allSatisfy({ !$0.isEmpty && $0 == $0.trimmingCharacters(in: .whitespacesAndNewlines) }),
              Set(references).isSubset(of: allowed)
        else {
            throw SideQuestPlanningError.ungroundedDecision
        }
    }

    /// This boundary only rejects unsupported real-world requirements. It does
    /// not select a replacement invitation or infer a missing place condition.
    private static func validateInvitationConditions(
        offer: OfferDTO,
        groundingRefs: Set<String>
    ) throws {
        let text = "\(offer.title) \(offer.invitation)".lowercased()
        if SideQuestSemanticGroundingPolicy.requiresFacility(text) {
            // The current schema has no facility-level grounding reference.
            throw SideQuestPlanningError.ungroundedDecision
        }
        if SideQuestSemanticGroundingPolicy.requiresStairsOrFloor(text),
           groundingRefs.isDisjoint(with: SideQuestSemanticGroundingPolicy.stairsGroundingRefs) {
            throw SideQuestPlanningError.ungroundedDecision
        }
    }

    private static func availableGroundingRefs(for context: SideQuestPlanningContext) -> Set<String> {
        let profile = context.lifeContextProfile
        var refs: Set<String> = ["current_day"]
        refs.formUnion(context.contextSnapshot?.groundingTokens ?? [])
        if !context.rawTodayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { refs.insert("today_notes") }
        if !context.recentRuns.isEmpty { refs.insert("recent_side_quest_history") }
        if !context.recentCorrections.isEmpty { refs.insert("recent_side_quest_corrections") }
        if let place = practicalPlace(for: context.contextSnapshot) {
            let practical = profile.practicalContext(for: place)
            if practical.floorLevel != nil || practical.stairsAvailable != nil {
                let prefix = "practical_place_\(place.rawValue)"
                refs.insert(prefix)
                if practical.floorLevel != nil { refs.insert("\(prefix)_floor") }
                if practical.stairsAvailable == true { refs.insert("\(prefix)_stairs") }
            }
        }
        if !profile.transitionWindows.isEmpty { refs.insert("practical_transition_windows") }
        if profile.preferredActivityRadius != nil { refs.insert("profile_activity_radius") }
        if !profile.commuteModes.isEmpty { refs.insert("profile_commute_modes") }
        if !profile.movementPreferences.isEmpty { refs.insert("profile_movement_preferences") }
        if !profile.constraints.isEmpty { refs.insert("profile_constraints") }
        return refs
    }

    /// Place-specific facts are only useful when the reduced, confirmed scene
    /// establishes that place. This deliberately treats a missing snapshot as
    /// unknown rather than inferring a location from profile data.
    private static func practicalPlace(for snapshot: SideQuestContextSnapshot?) -> SideQuestPracticalPlace? {
        switch snapshot?.scene ?? .unknown {
        case .home: return .home
        case .work: return .workplace
        case .familiarPlace, .unknown: return nil
        }
    }

    private static func category(from value: String) -> SideQuestCategory? {
        switch value {
        case "self_care": return .selfCare
        default: return SideQuestCategory(rawValue: value)
        }
    }

    private static func track(for category: SideQuestCategory) -> SideQuestGrowthTrack {
        switch category {
        case .connection: return .relationships
        case .curiosity: return .insight
        case .making, .interest: return .craft
        case .exploration: return .exploration
        case .vitality: return .vitality
        case .selfCare: return .selfCare
        }
    }

    private static func normalizedOptional(_ value: String?, maximumLength: Int) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(maximumLength))
    }

    private static func serializedContext(_ context: SideQuestPlanningContext) -> String {
        let formatter = ISO8601DateFormatter()
        let rawText = String(context.rawTodayText.prefix(1_200))
        let profile = context.lifeContextProfile
        let groundingRefs = availableGroundingRefs(for: context)
        let referenceMaterials: [[String: Any]] = BuiltinSideQuestCatalog.items
            .filter {
                context.preference.enabledCategories.contains($0.category) &&
                    !context.lifeContextProfile.unavailableCategories.contains($0.category)
            }
            .prefix(12)
            .map { item in
                [
                    "category": item.category.rawValue,
                    "title": item.title,
                    "duration": "\(item.minimumMinutes)-\(item.maximumMinutes)",
                    "prerequisites": item.prerequisites.map(\.rawValue)
                ]
            }
        let snapshot = context.contextSnapshot ?? .empty
        let seasonPayload: [String: Any] = context.season.map { season in
            let categoryHistory = context.recentRuns
                .filter { $0.seasonId == season.id }
                .reduce(into: [String: Int]()) { result, run in
                    result[run.category.rawValue, default: 0] += 1
                }
            return [
                "title": String(season.title.prefix(80)),
                "intent": season.intent.map { String($0.prefix(160)) } ?? NSNull(),
                "started_at": formatter.string(from: season.startedAt),
                "ends_at": formatter.string(from: season.endsAt),
                "max_days": season.maxDays,
                "accepted_count": season.acceptedCount,
                "completed_count": season.completedCount,
                "skipped_count": season.skippedCount,
                "category_history": categoryHistory
            ]
        } ?? [:]
        var lifeContext: [String: Any] = [
            "commute_modes": profile.commuteModes.map(\.rawValue).sorted(),
            "movement_preferences": profile.movementPreferences.map(\.rawValue).sorted(),
            "unavailable_categories": profile.unavailableCategories.map(\.rawValue).sorted(),
            "constraints": profile.constraints
        ]
        lifeContext["practical_places"] = practicalPlace(for: context.contextSnapshot).map { place in
            let practical = profile.practicalContext(for: place)
            return [[
                "place": place.rawValue,
                "floor_level": practical.floorLevel.map { $0 as Any } ?? NSNull(),
                "stairs_available": practical.stairsAvailable.map { $0 as Any } ?? NSNull()
            ]]
        } ?? []
        lifeContext["transition_windows"] = profile.transitionWindows.map(\.rawValue).sorted()
        lifeContext["activity_radius"] = profile.preferredActivityRadius?.rawValue ?? NSNull()
        let payload: [String: Any] = [
            "date": formatter.string(from: context.now),
            "enabled_categories": context.preference.enabledCategories.subtracting(profile.unavailableCategories).map(\.rawValue).sorted(),
            "frequency": context.preference.frequency.rawValue,
            "today_notes": rawText,
            "today_matters": context.trainingCases.prefix(5).map { ["title": $0.title, "status": $0.status.rawValue] },
            "recent_side_quest_runs": context.recentRuns.prefix(8).map {
                ["category": $0.category.rawValue, "title": $0.title, "status": $0.status.rawValue, "offered_at": formatter.string(from: $0.offeredAt)]
            },
            "recent_side_quest_corrections": context.recentCorrections.prefix(8).map {
                ["kind": $0.kind.rawValue, "has_note": $0.note != nil, "occurred_at": formatter.string(from: $0.occurredAt)]
            },
            "exploration_season": seasonPayload,
            "reference_materials": referenceMaterials,
            "life_experience_total": context.experienceSummary.totalExperience,
            "current_streak": context.experienceSummary.currentStreak,
            "longest_streak": context.experienceSummary.longestStreak,
            "available_grounding_refs": groundingRefs.sorted(),
            "life_context": lifeContext,
            "scene": snapshot.scene.rawValue,
            "availability": snapshot.availability.rawValue,
            "known_context": snapshot.knownContext,
            "dynamic_constraints": snapshot.dynamicConstraints
        ]
        guard JSONSerialization.isValidJSONObject(payload),
              let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
              let serialized = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return serialized
    }

    private static func decodeDecision(_ data: Data) throws -> DecisionDTO {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let raw = String(decoding: data, as: UTF8.self)
        let text: String
        if let envelope = try? decoder.decode(ChatEnvelope.self, from: data),
           let content = envelope.choices.first?.message?.content {
            text = content
        } else {
            text = raw
        }
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") else {
            throw SideQuestPlanningError.invalidDecision
        }
        return try decoder.decode(DecisionDTO.self, from: Data(text[start...end].utf8))
    }

    private struct ChatEnvelope: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable { var content: String? }
            var message: Message?
        }
        var choices: [Choice]
    }

    private struct DecisionDTO: Decodable {
        var decision: String
        var reason: String
        var offer: OfferDTO?
        var groundingRefs: [String]
    }

    private struct OfferDTO: Decodable {
        var category: String
        var title: String
        var invitation: String
        var evidencePrompt: String
        var minimumMinutes: Int
        var maximumMinutes: Int
        var prerequisiteIds: [String]
        var completionExperience: Int
        var reflectionBonusExperience: Int
        var notificationTitle: String?
        var notificationBody: String?
    }
}

private enum SideQuestSemanticGroundingPolicy {
    static let stairsGroundingRefs: Set<String> = [
        "practical_place_home_stairs",
        "practical_place_workplace_stairs"
    ]

    private static let stairsOrFloorTerms = [
        "楼梯", "楼层", "上楼", "下楼", "爬楼", "走楼",
        "stair", "stairs", "staircase", "floor", "floors", "climb", "climbing",
        "ascend", "ascending", "ascent", "descend", "descending", "descent",
        "upstairs", "downstairs"
    ]

    private static let facilityTerms = [
        "游泳", "泳池", "游泳馆", "健身房", "pool", "swim", "swimming", "gym", "fitness center"
    ]

    static func requiresStairsOrFloor(_ text: String) -> Bool {
        stairsOrFloorTerms.contains { text.contains($0) }
    }

    static func requiresFacility(_ text: String) -> Bool {
        facilityTerms.contains { text.contains($0) }
    }
}

private struct SideQuestSafetyPolicy {
    private let disallowedTerms = [
        "陌生人", "酒", "赌博", "开车", "危险", "购买", "消费", "药物", "节食", "体重",
        "alcohol", "gambling", "stranger", "drive", "danger", "purchase", "diet", "weight"
    ]

    func validate(
        title: String,
        invitation: String,
        category: SideQuestCategory,
        prerequisites: [SideQuestPrerequisite]
    ) throws {
        let text = "\(title) \(invitation)".lowercased()
        if let match = disallowedTerms.first(where: { text.contains($0) }) {
            throw SideQuestPlanningError.unsafeProposal("包含不适合的内容：\(match)")
        }
        if category == .connection, !prerequisites.contains(.freelyChosenContact) {
            throw SideQuestPlanningError.unsafeProposal("关系类邀请必须保留自主联系人边界")
        }
        if category == .vitality, !prerequisites.contains(.bodyAppropriate) {
            throw SideQuestPlanningError.unsafeProposal("活力类邀请必须保留身体适应性边界")
        }
        if category == .exploration, !prerequisites.contains(.daylightAndFamiliarRoute) {
            throw SideQuestPlanningError.unsafeProposal("探索类邀请必须限制为熟悉、安全路线")
        }
    }
}
