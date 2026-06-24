# Coach Teaching UX Alpha Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make MingSi's Today loop visibly teach the user's missing thinking move, training route, question purpose, and past-experience replay without adding chat or new product surfaces.

**Architecture:** Add one pure Domain policy that maps `CoachTurnState` and `TrainingPrescription` into a user-visible teaching diagnosis. Render that diagnosis in the existing Today training prescription area, render existing `ReflectionQuestion` functional fields as compact teaching cues, and reframe recalled principles as experience replay while preserving current persistence and feedback values.

**Tech Stack:** Swift, SwiftUI, XCTest, existing MingSi Domain models, existing Today seeded UI automation.

---

## File Structure

- Modify `Sources/Domain/Models.swift`
  - Add `CoachTeachingPlan` and `CoachTeachingPolicy`.
  - Keep the policy pure Domain: no SwiftUI, no persistence, no LLM, no networking.
- Modify `Sources/Features/Today/TodayView.swift`
  - Render the teaching diagnosis/route in `trainingPrescriptionCard`.
  - Render question teaching cues inside `QuestionCardView`.
  - Reframe `ReferencedPrinciplesView` copy as experience replay.
- Modify `Tests/App/AppStoreStateMachineTests.swift`
  - Add focused Domain tests for the teaching policy.
- Modify `Tests/UI/MingSiUITests.swift`
  - Add rendered Today tests for teaching route, question cues, and experience replay copy.
- Modify `Tests/Services/PromptSpecificationDocumentTests.swift`
  - Add doc alignment tests for teaching fields and experience replay.
- Modify `docs/prompt-spec.md`
  - Document `why_now`, `expected_update`, and `proceed_when` as user-visible teaching fields.
- Modify `docs/product-risks-and-design-language.md`
  - Document recalled principles as experience replay cues.
- Modify `docs/verification-log.md`
  - Record final verification after implementation.

## Task 1: Domain Teaching Policy

**Files:**
- Modify: `Sources/Domain/Models.swift`
- Modify: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write failing tests for teaching policy**

Add these tests near the existing Coach policy tests in `Tests/App/AppStoreStateMachineTests.swift`:

```swift
    func testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection() {
        let turn = CoachTurnState(
            phase: .fillEvidenceGap,
            readiness: .notReady,
            recommendedMove: .slowDownConvergence,
            reason: "当前存在高风险、问题或明确证据缺口，直接行动会过早收敛。",
            openEvidenceGaps: [.missingObservation, .missingBaseline],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .testableAction],
            decisionSource: .coachRecommended,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "回答仍未关闭主要证据缺口，继续追问而不是直接收敛。"
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.evidenceCheck.rawValue,
            recommendationReason: "当前最需要先补证据。",
            confidence: 0.82,
            policyVersion: "test",
            alternatives: [],
            baselineChecks: [.factInterpretationSplit, .evidenceGap, .testableAction],
            primaryTrainingDimension: .evidenceDiscipline,
            secondaryTrainingDimensions: [],
            baselineTrainingDimensions: [.factInterpretationSeparation, .testableActionDesign],
            userSelectedLensId: nil,
            finalLensId: ThinkingLens.evidenceCheck.rawValue,
            source: .coachRecommended,
            overrideBoundary: nil
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)

        XCTAssertEqual(plan.policyVersion, CoachTeachingPolicy.policyVersion)
        XCTAssertTrue(plan.missingMoveTitle.contains("可观察证据"))
        XCTAssertEqual(plan.trainingTargetTitle, ThinkingTrainingDimension.evidenceDiscipline.displayTitle)
        XCTAssertTrue(plan.whyNotAnswer.contains("未经验证"))
        XCTAssertTrue(plan.proceedStandard.contains("可观察事实"))
        XCTAssertEqual(plan.routeSteps.first, "补上一个可观察事实")
    }

    func testCoachTeachingPolicy_readyRouteFormsTomorrowExperiment() {
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "已有任务、事实或判断，可以把下一步设计成校准实验。",
            openEvidenceGaps: [],
            baselineChecks: [.testableAction, .judgmentUpdate],
            decisionSource: .coachAccepted,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "回答补足了关键证据，教练轮次从追问推进到形成可验证行动。"
        )
        let prescription = TrainingPrescription(
            recommendedLensId: ThinkingLens.judgmentCalibration.rawValue,
            recommendationReason: "当前可以把判断转成校准实验。",
            confidence: 0.76,
            policyVersion: "test",
            alternatives: [],
            baselineChecks: [.testableAction, .judgmentUpdate],
            primaryTrainingDimension: .testableActionDesign,
            secondaryTrainingDimensions: [],
            baselineTrainingDimensions: [.judgmentCalibration],
            userSelectedLensId: nil,
            finalLensId: ThinkingLens.judgmentCalibration.rawValue,
            source: .coachAccepted,
            overrideBoundary: nil
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: prescription)

        XCTAssertTrue(plan.missingMoveTitle.contains("明天能留下证据"))
        XCTAssertEqual(plan.trainingTargetTitle, ThinkingTrainingDimension.testableActionDesign.displayTitle)
        XCTAssertTrue(plan.whyNotAnswer.contains("足够形成小实验"))
        XCTAssertTrue(plan.proceedStandard.contains("明日行动"))
        XCTAssertEqual(plan.routeSteps, ["固定当前判断", "设计一个明日小实验", "明天用结果校准判断"])
    }

    func testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary() {
        let turn = CoachTurnState(
            phase: .formAction,
            readiness: .ready,
            recommendedMove: .generateQuest,
            reason: "用户主动推进到行动生成。",
            openEvidenceGaps: [.missingObservation],
            baselineChecks: [.evidenceGap, .testableAction],
            decisionSource: .userOverrideProgress,
            policyVersion: CoachTurnPolicy.policyVersion,
            turnSummary: "用户主动推进到行动生成；这不是证据缺口已消失的证明，后续仍保留审计边界。"
        )

        let plan = CoachTeachingPolicy().makePlan(turn: turn, prescription: nil)

        XCTAssertTrue(plan.missingMoveTitle.contains("证据缺口仍然存在"))
        XCTAssertTrue(plan.trainingTargetTitle.contains("审计边界"))
        XCTAssertTrue(plan.whyNotAnswer.contains("override 是推进许可"))
        XCTAssertTrue(plan.proceedStandard.contains("可回看证据"))
        XCTAssertEqual(plan.routeSteps.first, "记录用户主动推进")
        XCTAssertTrue(plan.auditNote?.contains("不是缺口已经消失") ?? false)
    }
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_readyRouteFormsTomorrowExperiment -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary
```

Expected: FAIL because `CoachTeachingPolicy` and `CoachTeachingPlan` do not exist.

- [ ] **Step 3: Add Domain models and policy**

Add this code in `Sources/Domain/Models.swift` after `CoachDecisionAssessment` and before `CoachDecisionPolicyV2`:

```swift
struct CoachTeachingPlan: Codable, Hashable {
    var policyVersion: String
    var missingMoveTitle: String
    var trainingTargetTitle: String
    var whyNotAnswer: String
    var proceedStandard: String
    var routeSteps: [String]
    var auditNote: String?
}

struct CoachTeachingPolicy {
    static let policyVersion = "coach-teaching.local-v1"

    func makePlan(
        turn: CoachTurnState,
        prescription: TrainingPrescription?
    ) -> CoachTeachingPlan {
        if turn.decisionSource == .userOverrideProgress {
            return CoachTeachingPlan(
                policyVersion: Self.policyVersion,
                missingMoveTitle: "证据缺口仍然存在，但你选择先推进。",
                trainingTargetTitle: "带着审计边界行动",
                whyNotAnswer: "override 是推进许可，不是缺口已经消失；后续任务仍要留下校准证据。",
                proceedStandard: "任务必须留下可回看证据，方便明天校准。",
                routeSteps: ["记录用户主动推进", "保留未关闭缺口", "明天重点验证这个缺口是否造成偏差"],
                auditNote: "用户 override 不是缺口已经消失的证明。"
            )
        }

        if turn.readiness == .ready || turn.openEvidenceGaps.isEmpty {
            return CoachTeachingPlan(
                policyVersion: Self.policyVersion,
                missingMoveTitle: "现在不是继续分析，而是把判断转成明天能留下证据的行动。",
                trainingTargetTitle: (prescription?.primaryTrainingDimension ?? .testableActionDesign).displayTitle,
                whyNotAnswer: "当前证据已经足够形成小实验，继续追问的收益低于行动校准。",
                proceedStandard: "明日行动能留下负责人、验收标准和可观察结果。",
                routeSteps: ["固定当前判断", "设计一个明日小实验", "明天用结果校准判断"],
                auditNote: nil
            )
        }

        let primaryDimension = prescription?.primaryTrainingDimension ?? dimension(for: turn)
        return CoachTeachingPlan(
            policyVersion: Self.policyVersion,
            missingMoveTitle: missingMoveTitle(for: turn),
            trainingTargetTitle: primaryDimension.displayTitle,
            whyNotAnswer: whyNotAnswer(for: turn),
            proceedStandard: proceedStandard(for: turn),
            routeSteps: routeSteps(for: turn),
            auditNote: nil
        )
    }

    private func dimension(for turn: CoachTurnState) -> ThinkingTrainingDimension {
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return .judgmentCalibration
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return .systemFeedbackAwareness
        }
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return .evidenceDiscipline
        }
        return .assumptionTesting
    }

    private func missingMoveTitle(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "你已经有行动倾向，但还没有说明可观察证据。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "你已经有判断，但还没有说明明天用什么信号校准。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "你描述了现象，但还没有看清因果链或反馈回路。"
        }
        return "当前真正要解决的问题还没有被定义清楚。"
    }

    private func whyNotAnswer(for turn: CoachTurnState) -> String {
        if turn.recommendedMove == .slowDownConvergence {
            return "现在直接行动会把未经验证的解释当成事实。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "没有校准信号时，任务完成也不一定能更新判断。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "如果不先看清反馈结构，行动可能只修表面问题。"
        }
        return "问题边界不清时，答案容易变成泛泛建议。"
    }

    private func proceedStandard(for turn: CoachTurnState) -> String {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return "先说清一个可观察事实和一个验收基线。"
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return "先说清一个实际结果信号，以及它会如何改变判断。"
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return "先说清一个反馈信号，以及它的延迟或下游影响。"
        }
        return "先说清要解决的问题和一个关键前提。"
    }

    private func routeSteps(for turn: CoachTurnState) -> [String] {
        if turn.openEvidenceGaps.contains(.missingObservation) || turn.openEvidenceGaps.contains(.missingBaseline) {
            return ["补上一个可观察事实", "回答校准问题", "再形成明日验证行动"]
        }
        if turn.openEvidenceGaps.contains(.missingCalibrationSignal) {
            return ["说清原判断", "定义校准信号", "把信号转成明日观察"]
        }
        if turn.openEvidenceGaps.contains(.missingCausalLink) {
            return ["画出因果链", "找到反馈或延迟", "选择能测试结构的行动"]
        }
        return ["定义问题边界", "暴露关键前提", "再选择行动"]
    }
}
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_readyRouteFormsTomorrowExperiment -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary
```

Expected: PASS with 3 tests and 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/Domain/Models.swift Tests/App/AppStoreStateMachineTests.swift
git commit -m "feat: add coach teaching policy"
```

## Task 2: Today Training Route Surface

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`
- Modify: `Tests/UI/MingSiUITests.swift`

- [ ] **Step 1: Write failing UI test for teaching route**

Add this test after `testTodayTrainingPrescriptionShowsPrimaryFocusAndBaselineChecks` in `Tests/UI/MingSiUITests.swift`:

```swift
    func testTodayTrainingPrescriptionShowsTeachingRoute() throws {
        let app = seededTodayApp(stage: "review_cards_confirmed")
        app.launch()

        tapPrimaryAction(in: app, expectingState: "select_lens")

        XCTAssertTrue(app.staticTexts["本轮漏想点"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["训练路线"].waitForExistence(timeout: 4))
        let missingMove = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "可观察证据")
        ).firstMatch
        XCTAssertTrue(missingMove.waitForExistence(timeout: 4))
        let routeStep = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "补上一个可观察事实")
        ).firstMatch
        XCTAssertTrue(routeStep.waitForExistence(timeout: 4))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsTeachingRoute
```

Expected: FAIL because the route copy is not rendered yet.

- [ ] **Step 3: Render teaching plan in training prescription card**

In `Sources/Features/Today/TodayView.swift`, update the call site in `selectLensSection`:

```swift
            if let prescription, let recommendedItem {
                trainingPrescriptionCard(
                    prescription,
                    item: recommendedItem,
                    teachingPlan: store.coachTurnState.map {
                        CoachTeachingPolicy().makePlan(turn: $0, prescription: prescription)
                    }
                )
            }
```

Change the signature:

```swift
    private func trainingPrescriptionCard(
        _ prescription: TrainingPrescription,
        item: LensCatalogItem,
        teachingPlan: CoachTeachingPlan?
    ) -> some View {
```

After the existing `Text("主练：...")` block and before `底盘检查`, add:

```swift
            if let teachingPlan {
                teachingRouteView(teachingPlan)
            }
```

Add this helper near `trainingPrescriptionCard`:

```swift
    private func teachingRouteView(_ plan: CoachTeachingPlan) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            BriefRow(title: "本轮漏想点", body: plan.missingMoveTitle, accent: DS.brick)
            BriefRow(title: "训练目标", body: plan.trainingTargetTitle, accent: DS.accent)
            BriefRow(title: "为什么不是直接给答案", body: plan.whyNotAnswer, accent: DS.caution)
            BriefRow(title: "推进标准", body: plan.proceedStandard, accent: DS.success)

            VStack(alignment: .leading, spacing: 6) {
                Text("训练路线")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .textCase(.uppercase)
                ForEach(Array(plan.routeSteps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 7) {
                        Text("\(index + 1)")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(DS.accent)
                            .frame(width: 18, height: 18)
                            .background(DS.accent.opacity(0.10), in: Circle())
                        Text(step)
                            .font(.caption)
                            .foregroundStyle(DS.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if let auditNote = plan.auditNote {
                Text(auditNote)
                    .font(.caption2)
                    .foregroundStyle(DS.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(DS.hairline, lineWidth: 1)
        )
    }
```

- [ ] **Step 4: Run focused UI test**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsTeachingRoute
```

Expected: PASS with 1 test and 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/Today/TodayView.swift Tests/UI/MingSiUITests.swift
git commit -m "feat: show coach teaching route"
```

## Task 3: Question Teaching Cues

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`
- Modify: `Tests/UI/MingSiUITests.swift`

- [ ] **Step 1: Write failing UI test for question teaching fields**

Add this test after `testTodayAnswerQuestionsSeedCanTypeThroughAccessibilityIdentifier`:

```swift
    func testTodayAnswerQuestionsShowsQuestionTeachingCue() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["训练动作"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["为什么现在问"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["答案会改变"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["推进标准"].waitForExistence(timeout: 4))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsShowsQuestionTeachingCue
```

Expected: FAIL because the question card does not render the functional coach fields.

- [ ] **Step 3: Add teaching cue rows to QuestionCardView**

In `Sources/Features/Today/TodayView.swift`, add this inside `QuestionCardView.body` after `Text(question.whyItMatters)` and before the `TextField`:

```swift
            if hasTeachingCue {
                VStack(alignment: .leading, spacing: 7) {
                    if let lensMove = question.lensMove {
                        BriefRow(title: "训练动作", body: lensMove.displayTitle, accent: DS.accent)
                    }
                    if let gapTitle = teachingGapTitle {
                        BriefRow(title: "补的缺口", body: gapTitle, accent: DS.brick)
                    }
                    if let whyNow = trimmed(question.whyNow) {
                        BriefRow(title: "为什么现在问", body: whyNow, accent: DS.caution)
                    }
                    if let expectedUpdate = trimmed(question.expectedUpdate) {
                        BriefRow(title: "答案会改变", body: expectedUpdate, accent: DS.accent)
                    }
                    if let proceedWhen = trimmed(question.proceedWhen) {
                        BriefRow(title: "推进标准", body: proceedWhen, accent: DS.success)
                    }
                }
                .padding(10)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(DS.hairline, lineWidth: 1)
                )
            }
```

Add these computed helpers inside `QuestionCardView`:

```swift
    private var hasTeachingCue: Bool {
        question.lensMove != nil ||
            teachingGapTitle != nil ||
            trimmed(question.whyNow) != nil ||
            trimmed(question.expectedUpdate) != nil ||
            trimmed(question.proceedWhen) != nil
    }

    private var teachingGapTitle: String? {
        guard let evidenceGapType = question.evidenceGapType else { return nil }
        if evidenceGapType == .none {
            return "取舍或框架问题"
        }
        return evidenceGapType.displayTitle
    }

    private func trimmed(_ value: String?) -> String? {
        let text = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }
```

- [ ] **Step 4: Run focused UI test**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsShowsQuestionTeachingCue
```

Expected: PASS with 1 test and 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/Today/TodayView.swift Tests/UI/MingSiUITests.swift
git commit -m "feat: show question teaching cues"
```

## Task 4: Experience Replay Copy

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`
- Modify: `Tests/UI/MingSiUITests.swift`

- [ ] **Step 1: Write failing UI test for experience replay language**

Add this test after `testTodayAnswerQuestionsSeedShowsReferencedPrincipleRetrievalReason`:

```swift
    func testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay() throws {
        let app = seededTodayApp(stage: "answer_questions")
        app.launch()

        XCTAssertTrue(app.staticTexts["today.state.answer_questions"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["过往经验复现"].waitForExistence(timeout: 4))
        let replayPrompt = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "这次先判断")
        ).firstMatch
        XCTAssertTrue(replayPrompt.waitForExistence(timeout: 4))
        XCTAssertTrue(app.buttons["today.principle.feedback.helpful-action"].label.contains("适用"))
        XCTAssertTrue(app.buttons["today.principle.feedback.not-applicable-action"].label.contains("不复现"))
        XCTAssertTrue(app.buttons["today.principle.feedback.misrecalled-action"].label.contains("召回错了"))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay
```

Expected: FAIL because current copy says "本次参考的原则" and feedback labels use old wording.

- [ ] **Step 3: Update ReferencedPrinciplesView copy**

In `Sources/Features/Today/TodayView.swift`, inside `ReferencedPrinciplesView`:

Replace:

```swift
Text("本次参考的原则")
```

with:

```swift
Text("过往经验复现")
```

Replace:

```swift
Text("仅作对照")
```

with:

```swift
Text("先判断是否适用")
```

After the header `HStack`, add:

```swift
Text("这次先判断：这些经验是否应该复现；如果不适用，就把原因标出来。")
    .font(.caption)
    .foregroundStyle(DS.mutedInk)
    .fixedSize(horizontal: false, vertical: true)
```

Replace feedback labels:

```swift
Label("有帮助", systemImage: "hand.thumbsup")
Label("不适用", systemImage: "xmark.circle")
Label("误召回", systemImage: "exclamationmark.bubble")
```

with:

```swift
Label("适用，今天要复现", systemImage: "hand.thumbsup")
Label("场景不同，不复现", systemImage: "xmark.circle")
Label("召回错了", systemImage: "exclamationmark.bubble")
```

Replace the note field prompt:

```swift
"可选：这条原则哪里不适用？"
```

with:

```swift
"可选：为什么复现或不复现？"
```

- [ ] **Step 4: Run focused UI tests**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsSeedCanRejectReferencedPrinciple -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsSeedShowsReferencedPrincipleRetrievalReason
```

Expected: PASS with 3 tests and 0 failures.

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/Today/TodayView.swift Tests/UI/MingSiUITests.swift
git commit -m "feat: frame recalled principles as experience replay"
```

## Task 5: Documentation Alignment

**Files:**
- Modify: `docs/prompt-spec.md`
- Modify: `docs/product-risks-and-design-language.md`
- Modify: `Tests/Services/PromptSpecificationDocumentTests.swift`

- [ ] **Step 1: Write failing doc tests**

Add this test to `Tests/Services/PromptSpecificationDocumentTests.swift` before `readRepositoryFile`:

```swift
    func testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay() throws {
        let spec = try readRepositoryFile("docs/prompt-spec.md")
        let productRisks = try readRepositoryFile("docs/product-risks-and-design-language.md")

        XCTAssertTrue(spec.contains("user-visible teaching fields"))
        XCTAssertTrue(spec.contains("why_now"))
        XCTAssertTrue(spec.contains("expected_update"))
        XCTAssertTrue(spec.contains("proceed_when"))
        XCTAssertTrue(spec.contains("why this question now"))
        XCTAssertTrue(spec.contains("what the answer will change"))
        XCTAssertTrue(spec.contains("what is sufficient to proceed"))
        XCTAssertTrue(productRisks.contains("experience replay"))
        XCTAssertTrue(productRisks.contains("not passive references"))
        XCTAssertTrue(productRisks.contains("复现"))
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptSpecificationDocumentTests/testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay
```

Expected: FAIL because docs do not yet contain the exact teaching-cue and experience-replay phrases.

- [ ] **Step 3: Update prompt spec**

In `docs/prompt-spec.md`, under the `Reflection Question` schema, add:

````markdown
`why_now`, `expected_update`, and `proceed_when` are user-visible teaching fields, not hidden parser metadata. Together they must explain why this question now, what the answer will change, and what is sufficient to proceed. Today may render them directly inside question teaching cues, so they must be concrete, short, and grounded in the current coach turn.
````

- [ ] **Step 4: Update product risks/design language**

In `docs/product-risks-and-design-language.md`, near the existing principle recall feedback bullets, add:

```markdown
- Recalled principles should be framed as experience replay, not passive references. The UI should ask whether the user should复现 the prior experience in this case, whether the scene is different, or whether the recall was wrong.
```

- [ ] **Step 5: Run focused doc test**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/PromptSpecificationDocumentTests/testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay
```

Expected: PASS with 1 test and 0 failures.

- [ ] **Step 6: Commit**

```bash
git add docs/prompt-spec.md docs/product-risks-and-design-language.md Tests/Services/PromptSpecificationDocumentTests.swift
git commit -m "docs: align teaching cues and experience replay"
```

## Task 6: Final Verification And Log

**Files:**
- Modify: `docs/verification-log.md`

- [ ] **Step 1: Run focused verification**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_readyRouteFormsTomorrowExperiment -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary -only-testing:MingSiTests/PromptSpecificationDocumentTests/testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsTeachingRoute -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsShowsQuestionTeachingCue -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay
```

Expected: PASS. Record exact test counts from output.

- [ ] **Step 2: Run full verification**

Run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

Expected:

- `MingSiTests`: pass with 0 failures.
- `MingSiUITests`: pass with 0 failures.
- `git diff --check`: no output and exit 0.

- [ ] **Step 3: Update verification log**

Append this entry to `docs/verification-log.md`. Use the actual test counts printed by Step 1 and Step 2, and write the exact numbers directly into the result bullets before committing:

````markdown
## 2026-06-25: Coach Teaching UX Alpha

Scope:

- Add a pure Domain coach teaching policy.
- Render teaching diagnosis and training route in Today training prescription.
- Render question teaching cues from functional question fields.
- Reframe recalled principles as experience replay.
- Align prompt/product docs.

Commands run:

```bash
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_notReadyEvidenceRouteStartsWithEvidenceCollection -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_readyRouteFormsTomorrowExperiment -only-testing:MingSiTests/AppStoreStateMachineTests/testCoachTeachingPolicy_overrideRouteKeepsAuditBoundary -only-testing:MingSiTests/PromptSpecificationDocumentTests/testPromptSpecDocumentsQuestionFieldsAsTeachingCuesAndExperienceReplay
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests/MingSiUITests/testTodayTrainingPrescriptionShowsTeachingRoute -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsShowsQuestionTeachingCue -only-testing:MingSiUITests/MingSiUITests/testTodayAnswerQuestionsFramesPrinciplesAsExperienceReplay
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests
xcodebuild test -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiUITests
git diff --check
```

Result:

- Focused Domain/doc verification passed with the exact executed test count from the first focused command and 0 failures.
- Focused UI verification passed with the exact executed test count from the second focused command and 0 failures.
- Full `MingSiTests` passed with the exact executed and skipped test counts printed by xcodebuild, and 0 failures.
- Full `MingSiUITests` passed with the exact executed test count printed by xcodebuild and 0 failures.
- `git diff --check` passed.

Residual risk:

- This slice improves Today teaching expression. It does not add adaptive curriculum, a teaching dashboard, principle adjustment persistence, remote prompt/lens delivery, or open-source packaging.
````

- [ ] **Step 4: Commit verification log**

```bash
git add docs/verification-log.md
git commit -m "test: verify coach teaching ux alpha"
```

- [ ] **Step 5: Final status check**

Run:

```bash
git status --short --branch
git log --oneline --decorate -8
```

Expected: clean worktree on `codex/mingsi-coach-teaching-ux-alpha`, with the latest commits for teaching policy, route UI, question cues, experience replay, docs, and verification.
