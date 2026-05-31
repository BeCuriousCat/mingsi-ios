import Foundation
import UserNotifications

enum PromptID: String, CaseIterable, Identifiable {
    case organizeCards
    case recommendLenses
    case generateQuestions
    case generateQuests
    case verifyQuest
    case extractPrinciple
    case weeklyCalibration
    case monthlyGrowth

    var id: String { rawValue }
}

struct PromptTemplate: Hashable {
    let id: PromptID
    let version: String
    let systemText: String
    let userText: String
    let outputSchemaVersion: Int
}

struct LLMRequest: Hashable {
    let prompt: PromptTemplate
    let inputSummary: String
    let jsonPayload: [String: String]
}

enum LLMClientError: Error {
    case missingAPIKey
    case invalidEndpoint
    case invalidResponse
    case httpStatus(Int, Data)
    case encodingFailed(Error)
    case transport(Error)
}

protocol PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate
}

protocol LLMClient {
    func complete(_ request: LLMRequest) async throws -> Data
}

protocol ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus
    func schedule(_ request: ReminderRequest) async throws
    func cancel(id: String) async
}

enum ReminderPermissionStatus: Hashable {
    case notDetermined
    case authorized
    case denied

    var allowsScheduling: Bool {
        self == .authorized
    }
}

enum ReminderError: LocalizedError {
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission was denied."
        }
    }
}

struct ReminderRequest: Hashable {
    let id: String
    let title: String
    let body: String
    let fireDate: Date
}

final class LocalPromptProvider: PromptProvider {
    func template(for id: PromptID, mode: SessionMode) -> PromptTemplate {
        let version = "1.0.0"
        return PromptTemplate(
            id: id,
            version: version,
            systemText: Self.systemText(for: mode),
            userText: Self.userText(for: id, mode: mode),
            outputSchemaVersion: 1
        )
    }

    private static func systemText(for mode: SessionMode) -> String {
        """
        You are 明思, a thinking coach for a busy knowledge worker.
        Help the user clarify problems, challenge assumptions, choose high-value actions, and calibrate judgment.
        Do not decide for the user.
        Do not replace the user's thinking.
        Separate facts, interpretations, assumptions, risks, and validation needs.
        Do not encourage the user to share confidential company information, code, customer data, or internal documents.
        Be concise, concrete, and non-performative.
        Session mode: \(mode.rawValue). Quick is shortest path, standard is the default full loop, and deep uses more scrutiny.
        Return valid JSON only, matching the requested schema.
        """
    }

    private static func userText(for id: PromptID, mode: SessionMode) -> String {
        let modeGuidance = Self.modeGuidance(for: mode)
        switch id {
        case .organizeCards:
            return """
            Organize the user's raw daily input into editable thinking cards.
            Do not summarize into one article.
            Extract concrete facts, problems, decisions, risks, ideas, communications, and tasks.
            Preserve uncertainty. If boundaries are unclear, infer likely cards and mark lower confidence.
            If content may contain confidential company details, mark it possibly_sensitive or sensitive and avoid repeating unnecessary specifics.
            \(modeGuidance)

            Input will include rawText, optional projectContext, privacyRules, and sessionMode.
            Return JSON:
            {
              "cards": [
                {
                  "type": "fact | problem | decision | risk | idea | communication | task",
                  "title": "string",
                  "body": "string",
                  "importance": "low | medium | high",
                  "sensitivity": "normal | possibly_sensitive | sensitive",
                  "confidence": "low | medium | high",
                  "reason": "string"
                }
              ],
              "sensitivity_notes": ["string"],
              "transcript_quality": "low | medium | high",
              "recommended_next_step": "string"
            }
            """

        case .recommendLenses:
            return """
            Review the confirmed cards and recommend up to two thinking lenses.
            Choose lenses that improve the user's thinking quality today.
            Prefer lenses that expose unclear goals, weak evidence, opportunity cost, hidden assumptions, or low-leverage execution.
            Explain briefly why each lens is useful.
            \(modeGuidance)

            Input will include confirmedCards, excludedCardTitles, and sessionMode.
            Return JSON:
            {
              "recommended_lenses": [
                {
                  "id": "first_principles | occams_razor | opposing_view | opportunity_cost | leverage_analysis | evidence_check | execution_bias_check",
                  "name": "string",
                  "why_recommended": "string"
                }
              ],
              "default_lens": "string"
            }
            """

        case .generateQuestions:
            return """
            Generate lens-specific reflection questions from the confirmed cards.
            Questions must be specific to the user's content.
            Do not ask generic self-help questions.
            At least one question should challenge a hidden assumption.
            At least one question should connect to tomorrow's action.
            \(modeGuidance)

            Question count: quick 1-2, standard 3, deep 4-5 with a stronger opposing-view question.
            Input will include confirmedCards, selectedLens, priorAnswers, and sessionMode.
            Return JSON:
            {
              "questions": [
                {
                  "question": "string",
                  "why_this_matters": "string",
                  "expected_answer_type": "fact | judgment | tradeoff | validation"
                }
              ]
            }
            """

        case .generateQuests:
            return """
            Generate tomorrow's quests from confirmed cards and user answers.
            Create exactly one main quest unless information is insufficient.
            Create at most two side quests and at most one observation quest.
            The main quest should target the highest-value action, not the easiest task.
            Each quest must include why it matters, concrete completion criteria, expected resistance, one reflection question, and linked card titles.
            If information is insufficient, ask for clarification rather than inventing a task.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedLens, and sessionMode.
            Return JSON:
            {
              "main_quest": {
                "type": "main",
                "title": "string",
                "why_it_matters": "string",
                "completion_criteria": "string",
                "expected_resistance": "string",
                "reflection_question": "string",
                "linked_cards": ["string"]
              },
              "side_quests": [],
              "observation_quest": null,
              "rejected_low_value_tasks": ["string"]
            }
            """

        case .verifyQuest:
            return """
            Review yesterday's quest, completion status, and actual value.
            Identify whether the task was well-chosen, too vague, too large, blocked, avoided, interrupted, or lower-value than expected.
            Do not blame the user.
            Return a concise calibration note and one recommendation for today's quest design.
            \(modeGuidance)

            Input will include yesterdayQuest, userVerification, completionEvidence, and actualValue.
            Return JSON:
            {
              "calibration_note": "string",
              "likely_issue": "none | task_too_large | unclear_criteria | low_value | dependency_blocked | avoidance | interruption",
              "recommendation": "string"
            }
            """

        case .extractPrinciple:
            return """
            From the confirmed cards, answers, and selected quest, identify at most one reusable principle.
            Do not create a principle if the lesson is too situational.
            The principle must be concrete enough to apply later.
            Frame it as a behavior rule, not a slogan.
            \(modeGuidance)

            Input will include confirmedCards, reflectionAnswers, selectedQuest, and sessionMode.
            Return JSON:
            {
              "principle_candidate": {
                "title": "string",
                "summary": "string",
                "trigger_context": "string",
                "actions": ["string"],
                "success_criteria": "string",
                "exceptions": "string",
                "source_card_titles": ["string"]
              }
            }
            If no reusable rule is justified, return:
            {
              "principle_candidate": null
            }
            """

        case .weeklyCalibration:
            return """
            Analyze confirmed daily records and quest verifications for the week.
            Identify highest-value action, lowest-value time sink, repeated blocker, repeated thinking pattern, and recommended training focus for next week.
            Use evidence snippets from confirmed cards, quests, or verifications.
            Avoid vague praise.
            \(modeGuidance)

            Return JSON:
            {
              "highest_value_action": "string",
              "lowest_value_time_sink": "string",
              "repeated_blocker": "string",
              "thinking_pattern": "string",
              "next_week_focus": "string",
              "evidence": ["string"]
            }
            """

        case .monthlyGrowth:
            return """
            Compare this month's records against baseline and early-month examples.
            Show changes in clarity, value judgment, execution reliability, calibration, and reflection depth.
            Use before/after evidence.
            Do not present scores as objective intelligence measures; present them as personal trend indicators.
            \(modeGuidance)

            Return JSON:
            {
              "clarity": {},
              "value_judgment": {},
              "execution_reliability": {},
              "calibration": {},
              "reflection_depth": {},
              "before_after_examples": [],
              "next_month_focus": "string"
            }
            """
        }
    }

    private static func modeGuidance(for mode: SessionMode) -> String {
        switch mode {
        case .quick:
            return "Use the shortest useful path. Prefer fewer cards, fewer questions, and one main quest."
        case .standard:
            return "Use the default full loop: clear cards, one recommended lens, three questions, quests, and a principle candidate when justified."
        case .deep:
            return "Use higher scrutiny. Include stronger opposing views, more explicit assumptions, and deeper validation needs."
        }
    }
}

final class LocalNotificationReminder: ReminderService {
    func requestPermission() async throws -> ReminderPermissionStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            return granted ? .authorized : .denied
        @unknown default:
            return .denied
        }
    }

    func schedule(_ request: ReminderRequest) async throws {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notification = UNNotificationRequest(identifier: request.id, content: content, trigger: trigger)
        try await center.add(notification)
    }

    func cancel(id: String) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
