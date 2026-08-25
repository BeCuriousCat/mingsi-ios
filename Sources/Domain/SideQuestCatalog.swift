import Foundation

// Side quests are optional real-world invitations. They are deliberately separate
// from a training Quest, which remains an action that verifies a user's judgment.
enum SideQuestCategory: String, CaseIterable, Codable, Hashable, Identifiable {
    case connection
    case curiosity
    case making
    case exploration
    case interest
    case vitality
    case selfCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .connection: return "连接"
        case .curiosity: return "好奇"
        case .making: return "制作"
        case .exploration: return "探索"
        case .interest: return "兴趣"
        case .vitality: return "活力"
        case .selfCare: return "自我照料"
        }
    }
}

enum SideQuestDayKind: String, Codable, Hashable {
    case workday
    case nonWorkday
}

enum SideQuestPrerequisite: String, CaseIterable, Codable, Hashable, Identifiable {
    case freelyChosenContact
    case daylightAndFamiliarRoute
    case availableMaterials
    case uninterruptedTenMinutes
    case bodyAppropriate
    case noRequiredSpending

    var id: String { rawValue }

    var copy: String {
        switch self {
        case .freelyChosenContact: return "只选择你愿意联系的人"
        case .daylightAndFamiliarRoute: return "选择白天且熟悉、安全的路线"
        case .availableMaterials: return "只使用手边已有的材料"
        case .uninterruptedTenMinutes: return "预留至少十分钟，不挤占必须完成的事"
        case .bodyAppropriate: return "只做此刻身体状况允许的动作"
        case .noRequiredSpending: return "不需要额外消费"
        }
    }
}

enum SideQuestGrowthTrack: String, CaseIterable, Codable, Hashable, Identifiable {
    case relationships
    case insight
    case craft
    case exploration
    case vitality
    case selfCare

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relationships: return "关系"
        case .insight: return "洞察"
        case .craft: return "创造"
        case .exploration: return "探索"
        case .vitality: return "活力"
        case .selfCare: return "自我照料"
        }
    }
}

struct SideQuestReward: Hashable {
    let track: SideQuestGrowthTrack
    let completionExperience: Int
    let reflectionBonusExperience: Int
}

/// How often a user is open to receiving an optional life invitation. None of
/// these choices turns side quests into a daily obligation.
enum SideQuestOfferFrequency: String, CaseIterable, Codable, Hashable, Identifiable {
    case rare
    case occasional
    case regular

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rare: return "偶尔遇见"
        case .occasional: return "适中"
        case .regular: return "多一些"
        }
    }

    var minimumDaysBetweenOffers: Int {
        switch self {
        case .rare: return 3
        case .occasional: return 2
        case .regular: return 1
        }
    }

    fileprivate var baselineAppearanceChance: Double {
        switch self {
        case .rare: return 0.14
        case .occasional: return 0.24
        case .regular: return 0.34
        }
    }

    fileprivate var maximumAppearanceChance: Double {
        switch self {
        case .rare: return 0.46
        case .occasional: return 0.64
        case .regular: return 0.72
        }
    }
}

/// A notification window is only a preference. Scheduling and permission are
/// deliberately handled by the Settings flow, never while a quest is offered.
struct SideQuestNotificationSchedule: Codable, Hashable {
    var startMinute: Int
    var endMinute: Int

    init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }

    var isValid: Bool {
        (0..<1_440).contains(startMinute) &&
            (0..<1_440).contains(endMinute) &&
            startMinute < endMinute
    }
}

struct SideQuestNotificationScheduleOption: Identifiable, Hashable {
    let id: String
    let title: String
    let schedule: SideQuestNotificationSchedule

    static let all: [Self] = [
        .init(
            id: "morning",
            title: "09:00-10:00",
            schedule: .init(startMinute: 9 * 60, endMinute: 10 * 60)
        ),
        .init(
            id: "midday",
            title: "12:00-13:00",
            schedule: .init(startMinute: 12 * 60, endMinute: 13 * 60)
        ),
        .init(
            id: "evening",
            title: "19:00-20:00",
            schedule: .init(startMinute: 19 * 60, endMinute: 20 * 60)
        )
    ]

    static let `default` = all[2]
}

/// Consent is separate from preference: no side-quest model request is made
/// until the person has explicitly allowed invitations.
enum SideQuestConsentStatus: String, Codable, Hashable {
    case notAsked
    case enabled
    case disabled
}

/// A deliberately reduced local view of a person's situation. It is the only
/// situation data that may enter a life-invitation model request.
struct SideQuestContextSnapshot: Hashable {
    enum Scene: String, Hashable {
        case home
        case work
        case familiarPlace
        case unknown
    }

    enum Availability: String, Hashable {
        case shortWindow
        case openWindow
        case busy
        case unknown
    }

    var scene: Scene
    var availability: Availability
    var knownContext: [String]
    var constraints: [String]

    /// The model must ground an offer in these stable, coarse facts. They are
    /// deliberately opaque tokens rather than raw system records.
    var groundingTokens: Set<String> {
        var tokens: Set<String> = []
        if scene != .unknown { tokens.insert("scene_\(scene.rawValue)") }
        if availability != .unknown { tokens.insert("availability_\(availability.rawValue)") }
        for item in knownContext where !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens.insert("context_\(item)")
        }
        for item in constraints where !item.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            tokens.insert("constraint_\(item)")
        }
        return tokens
    }

    var dynamicConstraints: [String] {
        constraints
    }

    static let empty = SideQuestContextSnapshot(
        scene: .unknown,
        availability: .unknown,
        knownContext: [],
        constraints: []
    )

    /// A user-selected scene intentionally wins over an imprecise system hint.
    /// The selection is ephemeral and never carries a coordinate or place name.
    func applying(manualScene: SideQuestManualSceneContext?, now: Date) -> Self {
        guard let manualScene, manualScene.isActive(at: now) else { return self }
        var snapshot = self
        snapshot.scene = manualScene.scene
        return snapshot
    }
}

/// A short-lived correction to the coarse scene inferred on-device. It stays in
/// memory only, so it naturally disappears on relaunch and is never persisted
/// alongside the long-lived life-context profile.
struct SideQuestManualSceneContext: Hashable {
    var scene: SideQuestContextSnapshot.Scene
    var expiresAt: Date

    init(scene: SideQuestContextSnapshot.Scene, expiresAt: Date) {
        self.scene = scene
        self.expiresAt = expiresAt
    }

    func isActive(at date: Date) -> Bool {
        date < expiresAt
    }

    static func throughEndOfDay(
        scene: SideQuestContextSnapshot.Scene,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> SideQuestManualSceneContext {
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        return SideQuestManualSceneContext(scene: scene, expiresAt: endOfDay)
    }
}

extension SideQuestContextSnapshot.Scene {
    var manualSelectionTitle: String {
        switch self {
        case .home: return "在家"
        case .work: return "在工作地点"
        case .familiarPlace: return "在熟悉地点"
        case .unknown: return "暂不确定"
        }
    }
}

/// The persistent user configuration for side quests. Notification permission
/// remains an independent explicit choice.
struct SideQuestPreference: Identifiable, Hashable {
    static let primaryID = "primary"

    var id: String
    var consentStatus: SideQuestConsentStatus
    var isEnabled: Bool { consentStatus == .enabled }
    var enabledCategories: Set<SideQuestCategory>
    var frequency: SideQuestOfferFrequency
    var notificationsEnabled: Bool
    var notificationSchedule: SideQuestNotificationSchedule?
    var lastAIPlanningAt: Date?
    var lastAIPlanningPromptRunId: UUID?
    var rotationSeed: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = SideQuestPreference.primaryID,
        isEnabled: Bool = false,
        consentStatus: SideQuestConsentStatus? = nil,
        enabledCategories: Set<SideQuestCategory> = Set(SideQuestCategory.allCases),
        frequency: SideQuestOfferFrequency = .occasional,
        notificationsEnabled: Bool = false,
        notificationSchedule: SideQuestNotificationSchedule? = nil,
        lastAIPlanningAt: Date? = nil,
        lastAIPlanningPromptRunId: UUID? = nil,
        rotationSeed: String = UUID().uuidString,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.consentStatus = consentStatus ?? (isEnabled ? .enabled : .notAsked)
        self.enabledCategories = enabledCategories
        self.frequency = frequency
        self.notificationsEnabled = notificationsEnabled
        self.notificationSchedule = notificationSchedule
        self.lastAIPlanningAt = lastAIPlanningAt
        self.lastAIPlanningPromptRunId = lastAIPlanningPromptRunId
        self.rotationSeed = rotationSeed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// The app enforces only durable consent and frequency limits. Whether today
/// deserves an invitation, and what it should be, stays with the LLM.
struct SideQuestPlanningEligibility {
    private let calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func permitsPlanning(
        preference: SideQuestPreference,
        mostRecentRun: SideQuestRun?,
        now: Date
    ) -> Bool {
        guard preference.isEnabled,
              !preference.enabledCategories.isEmpty,
              !calendar.isDate(preference.lastAIPlanningAt ?? .distantPast, inSameDayAs: now)
        else {
            return false
        }
        guard let mostRecentRun else { return true }
        let elapsedDays = calendar.dateComponents(
            [.day],
            from: mostRecentRun.offeredAt,
            to: now
        ).day ?? 0
        return elapsedDays >= preference.frequency.minimumDaysBetweenOffers
    }
}

enum SideQuestRunStatus: String, CaseIterable, Codable, Hashable {
    case offered
    case accepted
    case deferred
    case declined
    case completed
    case expired

    var canComplete: Bool {
        self == .accepted || self == .deferred
    }

    var occupiesInvitationSlot: Bool {
        self == .offered || self == .accepted || self == .deferred
    }
}

enum SideQuestRunOrigin: String, Codable, Hashable {
    case aiGenerated = "ai_generated"
    case catalogFallback = "catalog_fallback"
}

enum SideQuestExplorationSeasonStatus: String, Codable, Hashable, CaseIterable {
    case active
    case completed
    case abandoned
}

/// An optional thirty-day arc. Progress is a record of invitations accepted,
/// completed, and skipped; it is never a streak or a score for the main line.
struct SideQuestExplorationSeason: Identifiable, Codable, Hashable {
    static let defaultMaxDays = 30

    let id: UUID
    var title: String
    var intent: String?
    var startedAt: Date
    var endsAt: Date
    var status: SideQuestExplorationSeasonStatus
    var maxDays: Int
    var acceptedCount: Int
    var completedCount: Int
    var skippedCount: Int

    init(
        id: UUID = UUID(),
        title: String,
        intent: String? = nil,
        startedAt: Date = .now,
        endsAt: Date? = nil,
        status: SideQuestExplorationSeasonStatus = .active,
        maxDays: Int = SideQuestExplorationSeason.defaultMaxDays,
        acceptedCount: Int = 0,
        completedCount: Int = 0,
        skippedCount: Int = 0,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.title = String(title.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
        let normalizedIntent = intent?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.intent = normalizedIntent?.isEmpty == false ? String(normalizedIntent!.prefix(240)) : nil
        self.startedAt = startedAt
        self.maxDays = maxDays == SideQuestExplorationSeason.defaultMaxDays ? maxDays : SideQuestExplorationSeason.defaultMaxDays
        self.endsAt = endsAt ?? (calendar.date(byAdding: .day, value: self.maxDays, to: startedAt) ?? startedAt)
        self.status = status
        self.acceptedCount = max(0, acceptedCount)
        self.completedCount = max(0, completedCount)
        self.skippedCount = max(0, skippedCount)
    }

    var currentDay: Int {
        let days = Calendar.current.dateComponents([.day], from: startedAt, to: min(.now, endsAt)).day ?? 0
        return min(max(days + 1, 1), maxDays)
    }

    var isActive: Bool { status == .active }
}

/// A durable audit of one model planning decision. A `hold` has no run, but is
/// still product evidence: the trial must distinguish a restrained model from
/// one that simply never receives a chance to plan.
enum SideQuestPlanningDecision: String, Codable, Hashable {
    case offer
    case hold
}

struct SideQuestPlanningRecord: Identifiable, Hashable {
    let id: UUID
    var dayKey: String
    var decision: SideQuestPlanningDecision
    var promptRunId: UUID
    var plannedAt: Date

    init(
        id: UUID = UUID(),
        dayKey: String,
        decision: SideQuestPlanningDecision,
        promptRunId: UUID,
        plannedAt: Date = .now
    ) {
        self.id = id
        self.dayKey = dayKey
        self.decision = decision
        self.promptRunId = promptRunId
        self.plannedAt = plannedAt
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}

enum SideQuestCorrectionKind: String, CaseIterable, Codable, Hashable, Identifiable {
    case notHere = "not_here"
    case inconvenientNow = "inconvenient_now"
    case bodyNotSuitable = "body_not_suitable"
    case wrongJudgment = "wrong_judgment"
    case avoidCategory = "avoid_category"
    case note

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notHere: return "这不是我现在的情境"
        case .inconvenientNow: return "现在不方便"
        case .bodyNotSuitable: return "身体状态不适合"
        case .wrongJudgment: return "判断得不对"
        case .avoidCategory: return "我想少看到这类"
        case .note: return "补充说明"
        }
    }
}

struct SideQuestCorrectionEvent: Identifiable, Hashable {
    let id: UUID
    var sideQuestRunId: UUID?
    var kind: SideQuestCorrectionKind
    var note: String?
    var occurredAt: Date

    init(
        id: UUID = UUID(),
        sideQuestRunId: UUID? = nil,
        kind: SideQuestCorrectionKind,
        note: String? = nil,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.sideQuestRunId = sideQuestRunId
        self.kind = kind
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.note = trimmed?.isEmpty == false ? String(trimmed!.prefix(280)) : nil
        self.occurredAt = occurredAt
    }
}

/// A semantic place token that can be used for practical invitation grounding.
/// Labels associated with a place remain local-only profile data.
enum SideQuestPracticalPlace: String, CaseIterable, Codable, Hashable, Identifiable {
    case home
    case workplace

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "家"
        case .workplace: return "工作地点"
        }
    }
}

/// Practical facts are explicitly scoped to one place. An unknown value stays
/// unknown rather than being inferred from a place label or a former global field.
struct SideQuestPlacePracticalContext: Hashable {
    var floorLevel: Int?
    var stairsAvailable: Bool?

    init(floorLevel: Int? = nil, stairsAvailable: Bool? = nil) {
        self.floorLevel = floorLevel
        self.stairsAvailable = stairsAvailable
    }
}

enum SideQuestTransitionWindow: String, CaseIterable, Codable, Hashable, Identifiable {
    case afterLunch = "after_lunch"
    case leavingWork = "leaving_work"
    case arrivingHome = "arriving_home"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .afterLunch: return "午饭后"
        case .leavingWork: return "离开工作地点时"
        case .arrivingHome: return "到家后"
        }
    }
}

/// User-entered, coarse life context used only to keep invitations practical.
/// It intentionally excludes coordinates and any system-derived calendar or health data.
struct SideQuestLifeContextProfile: Identifiable, Hashable {
    static let primaryID = "primary"

    var id: String
    /// These labels are displayed and exported locally, but are never model input.
    var homeLabel: String?
    var workLabel: String?
    var homePracticalContext: SideQuestPlacePracticalContext
    var workplacePracticalContext: SideQuestPlacePracticalContext
    var transitionWindows: Set<SideQuestTransitionWindow>
    /// Kept only so pre-v44 `floor_count` data is not discarded. It has no
    /// place scope and therefore is not eligible model grounding.
    var legacyFloorCount: Int?
    var commuteModes: Set<SideQuestCommuteMode>
    var preferredActivityRadius: SideQuestActivityRadius?
    var movementPreferences: Set<SideQuestMovementPreference>
    var unavailableCategories: Set<SideQuestCategory>
    var constraints: [String]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: String = SideQuestLifeContextProfile.primaryID,
        homeLabel: String? = nil,
        workLabel: String? = nil,
        homePracticalContext: SideQuestPlacePracticalContext = .init(),
        workplacePracticalContext: SideQuestPlacePracticalContext = .init(),
        transitionWindows: Set<SideQuestTransitionWindow> = [],
        legacyFloorCount: Int? = nil,
        commuteModes: Set<SideQuestCommuteMode> = [],
        preferredActivityRadius: SideQuestActivityRadius? = nil,
        movementPreferences: Set<SideQuestMovementPreference> = [],
        unavailableCategories: Set<SideQuestCategory> = [],
        constraints: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.homeLabel = Self.normalized(homeLabel, maximumLength: 80)
        self.workLabel = Self.normalized(workLabel, maximumLength: 80)
        self.homePracticalContext = homePracticalContext
        self.workplacePracticalContext = workplacePracticalContext
        self.transitionWindows = transitionWindows
        self.legacyFloorCount = legacyFloorCount
        self.commuteModes = commuteModes
        self.preferredActivityRadius = preferredActivityRadius
        self.movementPreferences = movementPreferences
        self.unavailableCategories = unavailableCategories
        self.constraints = constraints.compactMap { Self.normalized($0, maximumLength: 180) }
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalized(_ value: String?, maximumLength: Int) -> String? {
        guard let value else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : String(normalized.prefix(maximumLength))
    }

    func practicalContext(for place: SideQuestPracticalPlace) -> SideQuestPlacePracticalContext {
        switch place {
        case .home: return homePracticalContext
        case .workplace: return workplacePracticalContext
        }
    }

    mutating func setPracticalContext(
        _ context: SideQuestPlacePracticalContext,
        for place: SideQuestPracticalPlace
    ) {
        switch place {
        case .home: homePracticalContext = context
        case .workplace: workplacePracticalContext = context
        }
    }
}

enum SideQuestCommuteMode: String, CaseIterable, Codable, Hashable, Identifiable {
    case walking
    case cycling
    case publicTransit = "public_transit"
    case driving
    case remote

    var id: String { rawValue }
    var title: String {
        switch self {
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .publicTransit: return "公共交通"
        case .driving: return "驾车"
        case .remote: return "居家/远程"
        }
    }
}

enum SideQuestActivityRadius: String, CaseIterable, Codable, Hashable, Identifiable {
    case atHome = "at_home"
    case nearby
    case neighborhood
    case citywide

    var id: String { rawValue }
    var title: String {
        switch self {
        case .atHome: return "仅家中"
        case .nearby: return "附近"
        case .neighborhood: return "同一片区"
        case .citywide: return "城市内"
        }
    }
}

enum SideQuestMovementPreference: String, CaseIterable, Codable, Hashable, Identifiable {
    case seated
    case gentle
    case outdoors
    case social
    case quiet

    var id: String { rawValue }
    var title: String {
        switch self {
        case .seated: return "以静态活动为主"
        case .gentle: return "只接受轻度活动"
        case .outdoors: return "愿意户外活动"
        case .social: return "愿意与人互动"
        case .quiet: return "偏好安静独处"
        }
    }
}

/// A side quest snapshots the catalog content and reward at offer time, so a
/// later catalog update cannot rewrite a person's previous experience.
struct SideQuestRun: Identifiable, Hashable {
    let id: UUID
    var catalogId: String
    var catalogVersion: String
    var origin: SideQuestRunOrigin
    var promptRunId: UUID?
    var decisionRationale: String?
    var category: SideQuestCategory
    var title: String
    var invitation: String
    var evidencePrompt: String
    var prerequisites: [SideQuestPrerequisite]
    var minimumMinutes: Int
    var maximumMinutes: Int
    var reward: SideQuestReward
    var status: SideQuestRunStatus
    var offeredAt: Date
    var acceptedAt: Date?
    var deferredUntil: Date?
    var completedAt: Date?
    var reflection: String?
    var notificationTitle: String?
    var notificationBody: String?
    var seasonId: UUID?
    var seasonDay: Int?
    var seasonStep: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        catalogId: String,
        catalogVersion: String,
        origin: SideQuestRunOrigin = .catalogFallback,
        promptRunId: UUID? = nil,
        decisionRationale: String? = nil,
        category: SideQuestCategory,
        title: String,
        invitation: String,
        evidencePrompt: String,
        prerequisites: [SideQuestPrerequisite],
        minimumMinutes: Int,
        maximumMinutes: Int,
        reward: SideQuestReward,
        status: SideQuestRunStatus = .offered,
        offeredAt: Date = .now,
        acceptedAt: Date? = nil,
        deferredUntil: Date? = nil,
        completedAt: Date? = nil,
        reflection: String? = nil,
        notificationTitle: String? = nil,
        notificationBody: String? = nil,
        seasonId: UUID? = nil,
        seasonDay: Int? = nil,
        seasonStep: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.catalogId = catalogId
        self.catalogVersion = catalogVersion
        self.origin = origin
        self.promptRunId = promptRunId
        self.decisionRationale = decisionRationale
        self.category = category
        self.title = title
        self.invitation = invitation
        self.evidencePrompt = evidencePrompt
        self.prerequisites = prerequisites
        self.minimumMinutes = minimumMinutes
        self.maximumMinutes = maximumMinutes
        self.reward = reward
        self.status = status
        self.offeredAt = offeredAt
        self.acceptedAt = acceptedAt
        self.deferredUntil = deferredUntil
        self.completedAt = completedAt
        self.reflection = reflection
        self.notificationTitle = notificationTitle
        self.notificationBody = notificationBody
        self.seasonId = seasonId
        self.seasonDay = seasonDay
        self.seasonStep = seasonStep
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func offered(from item: SideQuestCatalogItem, at date: Date = .now) -> SideQuestRun {
        SideQuestRun(
            catalogId: item.id,
            catalogVersion: item.version,
            origin: .catalogFallback,
            category: item.category,
            title: item.title,
            invitation: item.invitation,
            evidencePrompt: item.evidencePrompt,
            prerequisites: item.prerequisites,
            minimumMinutes: item.minimumMinutes,
            maximumMinutes: item.maximumMinutes,
            reward: item.completionReward,
            offeredAt: date,
            createdAt: date,
            updatedAt: date
        )
    }
}

/// A durable reference to a photo attached to a completed side quest. The
/// asset remains in the user's photo library; the database stores no image bytes.
struct SideQuestPhotoMemory: Identifiable, Hashable, Codable {
    let id: UUID
    var assetLocalIdentifier: String
    var runId: UUID
    var createdAt: Date
    var unavailable: Bool

    init(
        id: UUID = UUID(),
        assetLocalIdentifier: String,
        runId: UUID,
        createdAt: Date = .now,
        unavailable: Bool = false
    ) {
        self.id = id
        self.assetLocalIdentifier = assetLocalIdentifier
        self.runId = runId
        self.createdAt = createdAt
        self.unavailable = unavailable
    }
}

/// This is a distinct positive ledger, not a MetricContribution. It makes the
/// reward visible without turning a simple checkbox into a score for judgment.
struct SideQuestExperienceEvent: Identifiable, Hashable {
    let id: UUID
    var sideQuestRunId: UUID
    var track: SideQuestGrowthTrack
    var completionExperience: Int
    var reflectionBonusExperience: Int
    var streakCount: Int
    var occurredAt: Date

    var totalExperience: Int {
        completionExperience + reflectionBonusExperience
    }

    init(
        id: UUID = UUID(),
        sideQuestRunId: UUID,
        track: SideQuestGrowthTrack,
        completionExperience: Int,
        reflectionBonusExperience: Int,
        streakCount: Int = 0,
        occurredAt: Date = .now
    ) {
        self.id = id
        self.sideQuestRunId = sideQuestRunId
        self.track = track
        self.completionExperience = completionExperience
        self.reflectionBonusExperience = reflectionBonusExperience
        self.streakCount = streakCount
        self.occurredAt = occurredAt
    }
}

struct SideQuestExperienceSummary: Hashable {
    var totalExperience: Int
    var currentStreak: Int
    var longestStreak: Int
    var experienceByTrack: [SideQuestGrowthTrack: Int]

    static let empty = SideQuestExperienceSummary(
        totalExperience: 0,
        currentStreak: 0,
        longestStreak: 0,
        experienceByTrack: [:]
    )
}

/// A local-only readout for the 3-7 day life-invitation trial. It is derived
/// from durable run, correction, and experience records so trial decisions do
/// not depend on manually reconstructed histories or raw personal content.
struct SideQuestTrialMetrics: Hashable {
    var observationStart: Date
    var observationEnd: Date
    var planningDecisions: Int
    var holds: Int
    var offers: Int
    var accepted: Int
    var completed: Int
    var deferred: Int
    var declined: Int
    var expired: Int
    var correctionsByKind: [SideQuestCorrectionKind: Int]
    var offersByCategory: [SideQuestCategory: Int]
    var completedWithReflection: Int
    var aiGeneratedOffers: Int
    var uniqueOfferDays: Int

    var acceptanceRate: Double { rate(accepted) }
    var completionRate: Double { rate(completed) }
    var holdRate: Double {
        guard planningDecisions > 0 else { return 0 }
        return Double(holds) / Double(planningDecisions)
    }
    var correctionRate: Double { rate(correctionsByKind.values.reduce(0, +)) }
    var reflectionRate: Double {
        guard completed > 0 else { return 0 }
        return Double(completedWithReflection) / Double(completed)
    }

    private func rate(_ numerator: Int) -> Double {
        guard offers > 0 else { return 0 }
        return Double(numerator) / Double(offers)
    }
}

struct SideQuestCatalogItem: Identifiable, Hashable, Codable {
    let id: String
    let version: String
    let title: String
    let invitation: String
    let evidencePrompt: String
    let category: SideQuestCategory
    let minimumMinutes: Int
    let maximumMinutes: Int
    let suitableDayKinds: Set<SideQuestDayKind>
    let prerequisites: [SideQuestPrerequisite]
    let cooldownDays: Int
}

struct SideQuestOfferContext: Equatable {
    let isEnabled: Bool
    let enabledCategories: Set<SideQuestCategory>
    let frequency: SideQuestOfferFrequency
    let offerHistory: [String: Date]
    let lastOfferedAt: Date?
    let now: Date
    let rotationSeed: String

    init(
        isEnabled: Bool,
        enabledCategories: Set<SideQuestCategory>,
        frequency: SideQuestOfferFrequency = .occasional,
        offerHistory: [String: Date] = [:],
        lastOfferedAt: Date? = nil,
        now: Date = .now,
        rotationSeed: String = "default"
    ) {
        self.isEnabled = isEnabled
        self.enabledCategories = enabledCategories
        self.frequency = frequency
        self.offerHistory = offerHistory
        self.lastOfferedAt = lastOfferedAt
        self.now = now
        self.rotationSeed = rotationSeed
    }
}

struct SideQuestOfferPolicy {
    private let catalog: [SideQuestCatalogItem]
    private let calendar: Calendar

    init(
        catalog: [SideQuestCatalogItem] = BuiltinSideQuestCatalog.items,
        calendar: Calendar = .current
    ) {
        self.catalog = catalog
        self.calendar = calendar
    }

    func candidates(for context: SideQuestOfferContext) -> [SideQuestCatalogItem] {
        guard context.isEnabled,
              !context.enabledCategories.isEmpty,
              isNewPresentationDay(context) else {
            return []
        }

        let dayKind = dayKind(for: context.now)
        return catalog.filter { item in
            context.enabledCategories.contains(item.category) &&
                item.suitableDayKinds.contains(dayKind) &&
                isOutsideItemCooldown(item, context: context)
        }
    }

    // The result feels varied but is deterministic for one day and one catalog.
    // This avoids repeated reshuffles when a user returns to Today.
    func recommendation(for context: SideQuestOfferContext) -> SideQuestCatalogItem? {
        guard shouldSurface(for: context) else { return nil }
        let dayKey = "\(context.rotationSeed)|\(dayKey(for: context.now))"
        return candidates(for: context).min { lhs, rhs in
            let leftRank = stableRank("\(dayKey)|\(lhs.id)")
            let rightRank = stableRank("\(dayKey)|\(rhs.id)")
            if leftRank == rightRank { return lhs.id < rhs.id }
            return leftRank < rightRank
        }
    }

    func shouldSurface(for context: SideQuestOfferContext) -> Bool {
        guard !candidates(for: context).isEmpty else { return false }
        let elapsedDays = daysSinceLastOffer(context)
        let chance = min(
            context.frequency.maximumAppearanceChance,
            context.frequency.baselineAppearanceChance + Double(min(elapsedDays, 4)) * 0.10
        )
        let key = "\(context.rotationSeed)|\(dayKey(for: context.now))|appearance"
        return normalizedRank(for: key) < chance
    }

    private func isNewPresentationDay(_ context: SideQuestOfferContext) -> Bool {
        guard let lastOfferedAt = context.lastOfferedAt else { return true }
        let elapsedDays = calendar.dateComponents([.day], from: lastOfferedAt, to: context.now).day ?? 0
        return elapsedDays >= context.frequency.minimumDaysBetweenOffers
    }

    private func daysSinceLastOffer(_ context: SideQuestOfferContext) -> Int {
        guard let lastOfferedAt = context.lastOfferedAt else { return 0 }
        let days = calendar.dateComponents([.day], from: lastOfferedAt, to: context.now).day ?? 0
        return max(0, days)
    }

    private func isOutsideItemCooldown(
        _ item: SideQuestCatalogItem,
        context: SideQuestOfferContext
    ) -> Bool {
        guard let lastOfferedAt = context.offerHistory[item.id] else { return true }
        guard let nextOfferAt = calendar.date(
            byAdding: .day,
            value: item.cooldownDays,
            to: lastOfferedAt
        ) else {
            return false
        }
        return nextOfferAt <= context.now
    }

    private func dayKind(for date: Date) -> SideQuestDayKind {
        calendar.isDateInWeekend(date) ? .nonWorkday : .workday
    }

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private func stableRank(_ value: String) -> UInt64 {
        value.utf8.reduce(1_469_598_103_934_665_603) { hash, byte in
            (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
    }

    private func normalizedRank(for value: String) -> Double {
        Double(stableRank(value) % 10_000) / 10_000
    }
}

extension SideQuestCatalogItem {
    var completionReward: SideQuestReward {
        let track: SideQuestGrowthTrack
        switch category {
        case .connection: track = .relationships
        case .curiosity: track = .insight
        case .making, .interest: track = .craft
        case .exploration: track = .exploration
        case .vitality: track = .vitality
        case .selfCare: track = .selfCare
        }

        return SideQuestReward(
            track: track,
            completionExperience: min(30, max(10, maximumMinutes)),
            reflectionBonusExperience: 5
        )
    }
}

enum BuiltinSideQuestCatalog {
    static let version = "side-quests.v1"

    // These prompts are original, constrained adaptations of the user's shared
    // "life side quest" reference. They are not copied source wording.
    static let items: [SideQuestCatalogItem] = [
        .init(
            id: "connection.gentle-reconnect",
            version: version,
            title: "轻轻重启一段联系",
            invitation: "给一位你愿意重新联系的人发一句具体、没有压力的近况问候。",
            evidencePrompt: "是否发出？对方的回应或你的感受中，有什么让你意外？",
            category: .connection,
            minimumMinutes: 5,
            maximumMinutes: 15,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.freelyChosenContact, .uninterruptedTenMinutes],
            cooldownDays: 21
        ),
        .init(
            id: "connection.specific-appreciation",
            version: version,
            title: "说出一次具体感谢",
            invitation: "告诉一位你愿意联系的人：他曾经做过的哪件具体小事，对你产生了影响。",
            evidencePrompt: "你说出的具体事实是什么？这次表达有没有改变你们的互动？",
            category: .connection,
            minimumMinutes: 5,
            maximumMinutes: 10,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.freelyChosenContact, .uninterruptedTenMinutes],
            cooldownDays: 28
        ),
        .init(
            id: "curiosity.cross-domain-question",
            version: version,
            title: "借一个陌生视角",
            invitation: "向一位不同领域的人请教：他们通常怎样判断一件事是否值得投入？",
            evidencePrompt: "记录对方的一个判断标准，以及它和你原来做法的差异。",
            category: .curiosity,
            minimumMinutes: 10,
            maximumMinutes: 20,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.freelyChosenContact, .uninterruptedTenMinutes],
            cooldownDays: 21
        ),
        .init(
            id: "curiosity.counterexample-source",
            version: version,
            title: "找一个不支持你的例子",
            invitation: "为最近一个顺手的看法，找一个可靠但不支持它的例子。",
            evidencePrompt: "这个例子改变了你的判断边界，还是只让你补充了条件？",
            category: .curiosity,
            minimumMinutes: 10,
            maximumMinutes: 25,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.uninterruptedTenMinutes],
            cooldownDays: 14
        ),
        .init(
            id: "making.ten-minute-artifact",
            version: version,
            title: "做出一个十分钟成品",
            invitation: "用十分钟做出一个能被看见或听见的小成品，不追求质量，只完成一个版本。",
            evidencePrompt: "它现在具体是什么？下一次你会保留还是改变哪一个选择？",
            category: .making,
            minimumMinutes: 10,
            maximumMinutes: 20,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes],
            cooldownDays: 7
        ),
        .init(
            id: "making.repair-one-friction",
            version: version,
            title: "修好一个小摩擦",
            invitation: "选择一个今天反复造成摩擦的小物件、文件或设置，把它修到能顺畅使用。",
            evidencePrompt: "原来的摩擦是什么？修好后，下一次会少掉哪一步？",
            category: .making,
            minimumMinutes: 10,
            maximumMinutes: 25,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes],
            cooldownDays: 10
        ),
        .init(
            id: "making.observation-sketch",
            version: version,
            title: "画下一个正在发生的结构",
            invitation: "用文字、线条或方框，画下今天一个你本来会忽略的流程或物件结构。",
            evidencePrompt: "画完后，你第一次注意到了什么关系？",
            category: .making,
            minimumMinutes: 10,
            maximumMinutes: 20,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes],
            cooldownDays: 10
        ),
        .init(
            id: "exploration.familiar-area-new-route",
            version: version,
            title: "走一条新的熟悉路线",
            invitation: "在熟悉区域内，走一段平时不会走的路线，只观察，不需要到达特别目的地。",
            evidencePrompt: "你看见了哪件此前不存在于日常路线里的事？",
            category: .exploration,
            minimumMinutes: 20,
            maximumMinutes: 45,
            suitableDayKinds: [.nonWorkday],
            prerequisites: [.daylightAndFamiliarRoute],
            cooldownDays: 14
        ),
        .init(
            id: "exploration.field-note",
            version: version,
            title: "留下一条现场笔记",
            invitation: "在今天会经过的一个地方，停两分钟，记录一个具体声音、动作或秩序。",
            evidencePrompt: "这条观察说明了什么，又没有说明什么？",
            category: .exploration,
            minimumMinutes: 5,
            maximumMinutes: 10,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.uninterruptedTenMinutes],
            cooldownDays: 7
        ),
        .init(
            id: "self-care.clear-one-repeated-friction",
            version: version,
            title: "替明天少做一步",
            invitation: "找一件你每天都会重复一次的小麻烦，提前整理好它的入口、材料或顺序。",
            evidencePrompt: "明天实际少掉了哪一步？如果没有少掉，卡在了哪里？",
            category: .selfCare,
            minimumMinutes: 10,
            maximumMinutes: 20,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes],
            cooldownDays: 7
        ),
        .init(
            id: "self-care.leave-a-clear-ending",
            version: version,
            title: "给今天留一个清楚的结尾",
            invitation: "把一个悬着的小决定写成“继续、暂停或放弃”之一，并写下依据。",
            evidencePrompt: "你选择了什么？这个结尾释放了哪一种注意力？",
            category: .selfCare,
            minimumMinutes: 5,
            maximumMinutes: 15,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.uninterruptedTenMinutes],
            cooldownDays: 7
        ),
        .init(
            id: "interest.return-to-a-small-practice",
            version: version,
            title: "给一个兴趣留二十分钟",
            invitation: "选一个你曾经喜欢、或一直想试的兴趣，完成一个足够小的练习版本。",
            evidencePrompt: "这二十分钟里，什么让你愿意再回来一次？",
            category: .interest,
            minimumMinutes: 15,
            maximumMinutes: 30,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes, .noRequiredSpending],
            cooldownDays: 10
        ),
        .init(
            id: "vitality.gentle-movement",
            version: version,
            title: "完成一段舒适的移动",
            invitation: "用你觉得安全、舒服的方式活动身体一会儿：走路、拉伸、骑行或其他熟悉动作都可以。",
            evidencePrompt: "结束后，你的身体状态或注意力有什么具体变化？",
            category: .vitality,
            minimumMinutes: 15,
            maximumMinutes: 30,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.bodyAppropriate, .noRequiredSpending],
            cooldownDays: 5
        ),
        .init(
            id: "self-care.reset-one-used-space",
            version: version,
            title: "整理一个今天会用到的地方",
            invitation: "花十分钟整理一个你今天或明天会实际使用的区域，让它更容易开始和收尾。",
            evidencePrompt: "整理后，哪件具体事情变得更容易了？",
            category: .selfCare,
            minimumMinutes: 10,
            maximumMinutes: 20,
            suitableDayKinds: [.workday, .nonWorkday],
            prerequisites: [.availableMaterials, .uninterruptedTenMinutes],
            cooldownDays: 7
        )
    ]
}
