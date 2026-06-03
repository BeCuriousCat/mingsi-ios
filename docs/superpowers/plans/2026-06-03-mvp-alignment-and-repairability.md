# MingSi MVP Alignment And Repairability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the MVP testable as a daily thinking loop where AI failures are recoverable, prompts are inspectable, principles can be manually entered, and navigation does not destroy work unless the user explicitly edits.

**Architecture:** Keep SwiftUI views thin and route behavior through `AppStore`, repositories, `PromptProvider`, and parser/service layers. Treat historical AI retry as candidate generation, never automatic overwrite, so old inputs can become assets without corrupting confirmed evidence.

**Tech Stack:** SwiftUI, XCTest, GRDB/SQLite, local-first BYOK GLM, `PromptRun` audit, `LocalPromptProvider`, `TodayAIService`.

---

## Current Problem Summary

The current app has a working core loop, but the MVP success bar is not yet clean enough for daily alpha use:

- Settings shows all recent `PromptRun` records inline, so 100 failures can bury API settings and prompt diagnostics.
- User-confirmed principles can only come from AI extraction; there is no manual principle input for externally learned rules.
- Today “上一步” is destructive because it calls `trimDerivedState(after:)`; it is really “返回并修改”, not “回看”.
- Historical AI failures are visible, but cross-day retry is not yet a safe candidate flow.
- Prompt templates exist in code and docs, but there is no app-level prompt inspector.

## Files And Responsibilities

- `Sources/App/AppStore.swift`
  - Owns Today state transitions, repairability, principle creation, prompt audit state, and historical retry orchestration.
- `Sources/Features/Today/TodayView.swift`
  - Shows current loop, action row, non-destructive review navigation, and explicit destructive edit actions.
- `Sources/Features/FeatureTabs.swift`
  - Contains Settings, History, Growth, Projects, prompt audit UI, manual principle entry surface, and history repair UI.
- `Sources/Services/CoreProtocols.swift`
  - Defines `PromptID`, `PromptProvider`, `LocalPromptProvider`, and prompt template text.
- `Sources/Services/TodayAIService.swift`
  - Builds `LLMRequest` and context payloads.
- `Sources/Services/PersistenceCore.swift`
  - Persists principles, prompt runs, cards, quests, lens sessions, and historical records.
- `Tests/App/AppStoreStateMachineTests.swift`
  - State-machine tests for navigation, principle creation, repairability, and audit presentation data.
- `Tests/Services/LocalPromptProviderTests.swift`
  - Prompt template contract tests.
- `docs/prompt-context-engineering-prd.md`
  - Source of truth for prompt/context policy and current implementation.
- `docs/ux-flow.md`
  - User journey and screen behavior.
- `docs/implementation-gap-audit.md`
  - Dynamic gap tracker for MVP stop conditions.
- `docs/agent-delegation-log.md`
  - Records Codex/Claude/GLM work and verification evidence.

## MVP Stop Conditions

Stop the current MVP hardening phase only when all of these are true:

- A user can complete one full daily loop with GLM enabled or failed, without losing input.
- AI failure is visible, explains why it failed, and offers same-step retry or safe historical candidate retry.
- Historical raw input can be turned into new candidate cards later without overwriting confirmed old cards.
- The user can manually add a principle asset and see it participate in later question/task context.
- The user can inspect prompt templates and recent prompt calls without losing access to API settings.
- Today navigation separates “peek previous step” from “edit previous step and invalidate downstream”.
- Full test suite passes.
- `git diff --check` passes.
- `docs/implementation-gap-audit.md`, `docs/ux-flow.md`, `docs/prompt-context-engineering-prd.md`, and `docs/agent-delegation-log.md` are updated with current behavior.

## Task 1: Collapsible AI Audit In Settings

**Files:**
- Modify: `Sources/Features/FeatureTabs.swift`
- Modify: `Sources/App/AppStore.swift`
- Test: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that proves audit loading can cap the default visible list while retaining the underlying recent runs:

```swift
func testLoadRecentPromptRunsCanCapAuditListForSettings() async throws {
    let database = try AppDatabase(dbQueue: DatabaseQueue())
    let promptRunRepo = SQLitePromptRunRepository(database: database)
    for index in 0..<20 {
        try await promptRunRepo.savePromptRun(
            PromptRun(
                promptId: PromptID.organizeCards.rawValue,
                promptVersion: "1.0.0",
                inputSchemaVersion: 1,
                outputSchemaVersion: 1,
                modelProvider: "GLM",
                modelName: "glm-test",
                sessionMode: SessionMode.standard.rawValue,
                sourceRecordIds: [UUID().uuidString],
                requestSummary: "run \(index)",
                error: index % 2 == 0 ? "HTTP 500" : nil,
                createdAt: Date(timeIntervalSince1970: TimeInterval(index))
            )
        )
    }
    let store = AppStore(promptRunRepository: promptRunRepo, refreshesAIServiceFromKeychain: false)
    await store.loadRecentPromptRuns(limit: 20)
    XCTAssertEqual(store.recentPromptRuns.count, 20)
    XCTAssertEqual(store.promptRunFailureCount, 10)
}
```

- [ ] **Step 2: Run test to verify it fails**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRunsCanCapAuditListForSettings test
```

Expected: FAIL because `promptRunFailureCount` does not exist.

- [ ] **Step 3: Implement minimal store data**

Add computed properties to `AppStore`:

```swift
var promptRunFailureCount: Int {
    recentPromptRuns.filter { $0.error?.isEmpty == false }.count
}

var promptRunSuccessCount: Int {
    recentPromptRuns.filter { $0.error == nil || $0.error?.isEmpty == true }.count
}
```

- [ ] **Step 4: Update Settings UI**

In `promptAuditCard`, add `@State private var isPromptAuditExpanded = false` to `SettingsView`.

Show only the latest 3 rows when collapsed:

```swift
let visibleRuns = isPromptAuditExpanded ? store.recentPromptRuns : Array(store.recentPromptRuns.prefix(3))
```

Add a compact header showing failure/success counts and a toggle:

```swift
Button(isPromptAuditExpanded ? "收起" : "展开全部") {
    withAnimation(.easeInOut(duration: 0.18)) {
        isPromptAuditExpanded.toggle()
    }
}
.buttonStyle(.bordered)
.controlSize(.small)
```

- [ ] **Step 5: Verify**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Expected: PASS.

## Task 2: Manual Principle Asset Entry

**Files:**
- Modify: `Sources/App/AppStore.swift`
- Modify: `Sources/Features/FeatureTabs.swift`
- Test: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write failing test**

```swift
func testCreateManualPrinciplePersistsActivePrinciple() async throws {
    let database = try AppDatabase(dbQueue: DatabaseQueue())
    let principleRepo = SQLitePrincipleRepository(database: database)
    let source = DailyEntryDraft(rawText: "Manual principle source", state: .sessionComplete)
    let dailyRepo = SQLiteDailyEntryRepository(database: database)
    try await dailyRepo.saveDraft(source)
    let store = AppStore(
        todayDraft: source,
        dailyEntryRepository: dailyRepo,
        principleRepository: principleRepo,
        refreshesAIServiceFromKeychain: false
    )

    await store.createManualPrinciple(
        title: "会前先定义确认事项",
        summary: "会议前列出必须确认的问题、材料和负责人。",
        triggerContext: "涉及跨团队会议或需要多人确认时",
        actionsText: "列出确认事项\n准备材料\n会后同步 action",
        successCriteria: "会议结束后能发出明确结论和责任人",
        exceptions: "纯信息同步会议可简化"
    )

    let active = try await principleRepo.activePrinciples()
    XCTAssertEqual(active.first?.title, "会前先定义确认事项")
    XCTAssertEqual(active.first?.actions.count, 3)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL because `createManualPrinciple` does not exist.

- [ ] **Step 3: Implement AppStore API**

Add:

```swift
func createManualPrinciple(
    title: String,
    summary: String,
    triggerContext: String,
    actionsText: String,
    successCriteria: String,
    exceptions: String
) async {
    let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !title.isEmpty else {
        todayLoopMessage = "原则标题不能为空。"
        return
    }
    let principle = PrincipleAsset(
        title: title,
        summary: summary.trimmingCharacters(in: .whitespacesAndNewlines),
        triggerContext: triggerContext.trimmingCharacters(in: .whitespacesAndNewlines),
        actions: Self.actions(from: actionsText),
        successCriteria: successCriteria.trimmingCharacters(in: .whitespacesAndNewlines),
        exceptions: exceptions.trimmingCharacters(in: .whitespacesAndNewlines),
        status: .active
    )
    principles.append(principle)
    do {
        try await principleRepository?.savePrinciple(principle, sourceDailyEntryId: todayDraft.id)
        todayLoopMessage = "原则已加入思考资产。"
    } catch {
        todayLoopMessage = "保存原则失败。"
    }
}
```

- [ ] **Step 4: Add UI entry**

In Settings or Growth, add a restrained “思考资产” section with a sheet for manual principle fields: title, summary, trigger context, actions, success criteria, exceptions.

- [ ] **Step 5: Verify principle retrieval**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/TodayAIServiceContextTests test
```

Expected: PASS and existing relevant-principle tests still work.

## Task 3: Non-Destructive Today Step Review

**Files:**
- Modify: `Sources/App/AppStore.swift`
- Modify: `Sources/Features/Today/TodayView.swift`
- Test: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write failing test**

```swift
func testReviewPreviousStepDoesNotTrimDownstreamState() async throws {
    store.todayDraft.state = .answerQuestions
    store.thinkingCards = [ThinkingCard(type: .fact, title: "Fact", body: "Body", isConfirmed: true)]
    store.questions = [ReflectionQuestion(question: "Q", whyItMatters: "W", answer: "A")]
    store.quests = [Quest(type: .main, title: "Quest", whyItMatters: "Why", completionCriteria: "Done", expectedResistance: "None", reflectionQuestion: "RQ")]

    store.reviewTodayLoopStep(.reviewCards)

    XCTAssertEqual(store.todayDraft.state, .reviewCards)
    XCTAssertEqual(store.questions.count, 1)
    XCTAssertEqual(store.quests.count, 1)
}
```

- [ ] **Step 2: Run test to verify it fails**

Expected: FAIL because `reviewTodayLoopStep` does not exist.

- [ ] **Step 3: Implement review vs edit split**

Add:

```swift
func reviewTodayLoopStep(_ state: DailyLoopState) {
    guard canNavigateTodayLoop(to: state), state != todayDraft.state else { return }
    moveTodayLoop(to: state, message: "正在回看\(state.title)。如需修改，请使用编辑并重算。")
}

func editTodayLoopFrom(_ state: DailyLoopState) {
    guard canNavigateTodayLoop(to: state), state != todayDraft.state else { return }
    trimDerivedState(after: state)
    moveTodayLoop(to: state, message: "已回到\(state.title)，后续内容会在确认后重新生成。")
}
```

Keep `navigateTodayLoop(to:)` temporarily calling `editTodayLoopFrom(_:)` for compatibility.

- [ ] **Step 4: Update Today UI**

Rename existing “上一步” to “回看上一步” and call `reviewTodayLoopStep`.

Add a smaller destructive action only on editable steps:

```swift
Button("编辑并重算") {
    store.editTodayLoopFrom(previousState)
}
.foregroundStyle(DS.caution)
```

- [ ] **Step 5: Verify**

Run AppStore tests and manually inspect Today flow in simulator.

## Task 4: Historical AI Retry As Candidate Generation

**Files:**
- Modify: `Sources/App/AppStore.swift`
- Modify: `Sources/Features/FeatureTabs.swift`
- Test: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Write failing test**

Create a test for a historical entry with no confirmed cards and failed `organizeCards`; retry should generate candidate cards and not mark them confirmed automatically.

- [ ] **Step 2: Implement data shape**

Add store state:

```swift
@Published var historicalRepairCandidatesByEntry: [UUID: [ThinkingCard]] = [:]
@Published var historicalRepairMessage: String = ""
```

- [ ] **Step 3: Implement retry API**

Add:

```swift
func generateHistoricalCardCandidates(for record: HistoryRecord) async {
    guard !record.draft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        historicalRepairMessage = "这条历史没有原始输入，无法补跑。"
        return
    }
    do {
        let cards = try await todayAIService?.streamOrganizedCards(
            for: TodayAIContext(draft: record.draft),
            onUpdate: { _ in }
        ) ?? []
        historicalRepairCandidatesByEntry[record.draft.id] = cards.map { card in
            var draft = card
            draft.isConfirmed = false
            return draft
        }
        historicalRepairMessage = "已生成候选卡片，请确认后再写入历史。"
    } catch {
        historicalRepairMessage = "历史补跑失败：\(error.localizedDescription)"
    }
}
```

- [ ] **Step 4: Confirm selected historical candidates**

Add a method that saves only user-confirmed candidates through `thinkingCardRepository.saveCards(_:dailyEntryId:)`, then reloads history.

- [ ] **Step 5: Update History UI**

In the AI repair section, show:

- “生成候选卡片”
- Candidate list with confirm/exclude controls
- “写入已确认卡片”

Never auto-overwrite existing confirmed cards.

## Task 5: Prompt Inspector

**Files:**
- Modify: `Sources/App/AppStore.swift`
- Modify: `Sources/Features/FeatureTabs.swift`
- Test: `Tests/Services/LocalPromptProviderTests.swift`

- [ ] **Step 1: Add prompt inventory test**

Verify every `PromptID` returns non-empty `systemText`, `userText`, version, and schema version.

- [ ] **Step 2: Add Settings Prompt Inspector**

In Settings, add a collapsed “Prompt 模板” section:

- Prompt picker.
- Mode picker.
- System text disclosure.
- User text disclosure.
- Schema version and prompt version.

Use `LocalPromptProvider().template(for:mode:)`.

- [ ] **Step 3: Verification**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/LocalPromptProviderTests test
```

Expected: PASS.

## Task 6: MVP Docs And Stop Report

**Files:**
- Modify: `docs/implementation-gap-audit.md`
- Modify: `docs/ux-flow.md`
- Modify: `docs/prompt-context-engineering-prd.md`
- Modify: `docs/agent-delegation-log.md`

- [ ] **Step 1: Update implementation gap audit**

Record current state for:

- Prompt audit collapsibility.
- Manual principles.
- Non-destructive review navigation.
- Historical retry candidate flow.
- Prompt inspector.

- [ ] **Step 2: Update UX flow**

Clarify:

- “回看上一步” does not clear downstream work.
- “编辑并重算” clears downstream work.
- Historical retry produces candidates.

- [ ] **Step 3: Update prompt context PRD**

Add current visible prompt inspector path and manual principle path.

- [ ] **Step 4: Final verification**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' test
git diff --check
```

Expected:

- Full suite passes.
- Diff check passes.
