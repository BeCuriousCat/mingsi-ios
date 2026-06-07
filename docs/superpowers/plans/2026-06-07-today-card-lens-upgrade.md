# Today Card Lens Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Upgrade Today core cards into quieter thinking-slip surfaces and upgrade built-in lenses into richer method assets with lightweight recommendation support.

**Architecture:** Keep persistence and prompt identities stable in `Sources/Domain/Models.swift`; add presentation/recommendation metadata to the existing lens catalog boundary; consume that catalog metadata from `Sources/Features/Today/TodayView.swift` without adding lens-specific UI copy switches. UI work stays local to Today card subviews and preserves existing AppStore state-machine behavior and automation identifiers.

**Tech Stack:** Swift 5, SwiftUI, XCTest via `xcodebuild`, existing `DS` design tokens, existing `ThinkingLens` / `LensLibrary` / `BuiltinLensCatalog` domain model.

---

## Current Worktree Warning

The worktree already contains unrelated uncommitted changes in:

- `Sources/App/AppStore.swift`
- `Sources/App/MingSiApp.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`
- several untracked screenshot folders

Do not revert them. Before editing a dirty file, inspect the current diff for that file and preserve user/current-work changes. When committing, stage only the files intentionally changed for that task.

## File Structure

- Modify `Sources/Domain/Models.swift`
  - Owns lens catalog metadata, stable local/prompt identities, accent role, method index, question seeds, and recommendation rules.
- Modify `Tests/App/AppStoreStateMachineTests.swift`
  - Adds focused tests beside the existing `// MARK: - ThinkingLens Catalog` section.
- Modify `Sources/Features/Today/TodayView.swift`
  - Renders recommended lens affordance in `selectLensSection` / `lensCard`.
  - Refines `ThinkingCardRow`, `QuestionCardView`, and `QuestCardView`.
  - Preserves existing `TodayAutomationID` identifiers.
- Optionally modify `Sources/DesignSystem/Theme.swift`
  - Only if a reusable tiny surface helper is clearer than repeating Today-local styling. Prefer Today-local helpers for this slice.

## Verification Commands

Use these commands during the tasks:

```bash
git diff --check
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_methodAssetMetadataIsComplete test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsEvidenceCheckForValidationHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsLeverageAnalysisForActionHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsOpposingViewForDeepRiskHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsFirstPrinciplesWhenNoTypeDominates test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected final result: all commands pass. If simulator or host tooling blocks a command, capture the exact error and run the narrower available verification first.

---

### Task 1: Lens Method Asset Tests

**Files:**
- Modify: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Inspect the current dirty test diff**

Run:

```bash
git diff -- Tests/App/AppStoreStateMachineTests.swift | sed -n '1,240p'
```

Expected: output may include current uncommitted test work. Preserve it.

- [ ] **Step 2: Add failing catalog metadata and recommendation tests**

In `Tests/App/AppStoreStateMachineTests.swift`, inside the existing `// MARK: - ThinkingLens Catalog` section after `testFirstPrinciples_metadata`, add:

```swift
    func testBuiltinLensCatalog_methodAssetMetadataIsComplete() {
        let methodIndexes = BuiltinLensCatalog.items.map(\.methodIndex)

        XCTAssertEqual(Set(methodIndexes).count, ThinkingLens.allCases.count)
        XCTAssertEqual(methodIndexes.sorted(), [1, 2, 3, 4])

        for item in BuiltinLensCatalog.items {
            XCTAssertFalse(item.recommendedReason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(item.questionSeeds.isEmpty)
            XCTAssertTrue(item.questionSeeds.allSatisfy {
                !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            })
            XCTAssertFalse(item.accentRole.rawValue.isEmpty)
            XCTAssertGreaterThan(item.methodIndex, 0)
        }
    }

    func testBuiltinLensLibrary_recommendsEvidenceCheckForValidationHeavyCards() {
        let cards = [
            ThinkingCard(type: .fact, title: "客户预期变更", body: "需要确认客户是否真的接受延期。", priority: .high),
            ThinkingCard(type: .risk, title: "验收口径不清", body: "缺少事实支撑。", priority: .high),
            ThinkingCard(type: .problem, title: "判断依据不足", body: "目前只有推测。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.evidenceCheck.rawValue)
    }

    func testBuiltinLensLibrary_recommendsLeverageAnalysisForActionHeavyCards() {
        let cards = [
            ThinkingCard(type: .task, title: "确认接口负责人", body: "明天先定边界。", priority: .high),
            ThinkingCard(type: .decision, title: "短期兼容旧逻辑", body: "先保证交付。", priority: .medium),
            ThinkingCard(type: .task, title: "补完成标准", body: "写清验收条件。", priority: .medium)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .standard)

        XCTAssertEqual(item?.lensId, ThinkingLens.leverageAnalysis.rawValue)
    }

    func testBuiltinLensLibrary_recommendsOpposingViewForDeepRiskHeavyCards() {
        let cards = [
            ThinkingCard(type: .risk, title: "第三方接口延期", body: "计划可能被拖住。", priority: .medium),
            ThinkingCard(type: .problem, title: "只看到自己视角", body: "缺少反证。", priority: .medium),
            ThinkingCard(type: .risk, title: "技术债继续累积", body: "短期方案可能扩大成本。", priority: .low)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .deep)

        XCTAssertEqual(item?.lensId, ThinkingLens.opposingView.rawValue)
    }

    func testBuiltinLensLibrary_recommendsFirstPrinciplesWhenNoTypeDominates() {
        let cards = [
            ThinkingCard(type: .idea, title: "也许要重排优先级", body: "目前只是感觉。", priority: .medium),
            ThinkingCard(type: .communication, title: "同步会没有结论", body: "没人确认前提。", priority: .medium),
            ThinkingCard(type: .fact, title: "会议没有 owner", body: "这是唯一确定事实。", priority: .low)
        ]

        let item = BuiltinLensCatalog.library.recommendedItem(for: cards, mode: .quick)

        XCTAssertEqual(item?.lensId, ThinkingLens.firstPrinciples.rawValue)
    }
```

- [ ] **Step 3: Run tests to verify they fail**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_methodAssetMetadataIsComplete test
```

Expected: FAIL because `LensCatalogItem` does not have `methodIndex`, `recommendedReason`, `questionSeeds`, or `accentRole`.

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsEvidenceCheckForValidationHeavyCards test
```

Expected: FAIL because `LensLibrary.recommendedItem(for:mode:)` does not exist.

- [ ] **Step 4: Commit failing tests**

Run:

```bash
git add Tests/App/AppStoreStateMachineTests.swift
git commit -m "test: specify lens method asset recommendation"
```

Expected: commit succeeds with only `Tests/App/AppStoreStateMachineTests.swift` staged.

---

### Task 2: Lens Domain Metadata and Recommendation

**Files:**
- Modify: `Sources/Domain/Models.swift`
- Test: `Tests/App/AppStoreStateMachineTests.swift`

- [ ] **Step 1: Inspect the current domain diff**

Run:

```bash
git diff -- Sources/Domain/Models.swift | sed -n '1,220p'
```

Expected: either no output or unrelated current work. Preserve any existing edits.

- [ ] **Step 2: Add `LensAccentRole` and expand `LensCatalogItem`**

In `Sources/Domain/Models.swift`, replace the current `LensCatalogItem` declaration with:

```swift
enum LensAccentRole: String, CaseIterable {
    case graphite
    case brick
    case accent
    case principle
}

struct LensCatalogItem: Equatable {
    let lensId: String
    let promptId: String
    let version: String
    let title: String
    let subtitle: String
    let shortLabel: String
    let methodLine: String
    let promptGuidance: String
    let symbolName: String
    let recommendedReason: String
    let questionSeeds: [String]
    let accentRole: LensAccentRole
    let methodIndex: Int
}
```

- [ ] **Step 3: Add recommendation API to `LensCatalogProviding`**

Replace the protocol with:

```swift
protocol LensCatalogProviding {
    var items: [LensCatalogItem] { get }
    func item(localId: String) -> LensCatalogItem?
    func item(promptId: String) -> LensCatalogItem?
    func item(for lens: ThinkingLens) -> LensCatalogItem?
    func recommendedItem(for cards: [ThinkingCard], mode: SessionMode) -> LensCatalogItem?
}
```

- [ ] **Step 4: Implement recommendation in `LensLibrary`**

Replace `struct LensLibrary` with:

```swift
struct LensLibrary: LensCatalogProviding {
    let items: [LensCatalogItem]

    func item(localId: String) -> LensCatalogItem? {
        items.first { $0.lensId == localId }
    }

    func item(promptId: String) -> LensCatalogItem? {
        items.first { $0.promptId == promptId }
    }

    func item(for lens: ThinkingLens) -> LensCatalogItem? {
        item(localId: lens.rawValue)
    }

    func recommendedItem(for cards: [ThinkingCard], mode: SessionMode) -> LensCatalogItem? {
        let consideredCards = cards.filter { !$0.isExcludedFromModel }
        guard !consideredCards.isEmpty else {
            return items.sorted { $0.methodIndex < $1.methodIndex }.first
        }

        let counts = Dictionary(grouping: consideredCards, by: \.type).mapValues(\.count)
        let highPriorityTypes = Set(consideredCards.filter { $0.priority == .high }.map(\.type))
        let riskProblemCount = (counts[.risk] ?? 0) + (counts[.problem] ?? 0)
        let actionCount = (counts[.task] ?? 0) + (counts[.decision] ?? 0)
        let validationCount = (counts[.fact] ?? 0) + riskProblemCount
        let dominantCount = counts.values.max() ?? 0

        if mode == .deep && riskProblemCount >= 2 {
            return item(for: .opposingView)
        }

        if actionCount >= 2 && actionCount >= riskProblemCount {
            return item(for: .leverageAnalysis)
        }

        if validationCount >= 2 && !highPriorityTypes.isDisjoint(with: [.fact, .risk, .problem]) {
            return item(for: .evidenceCheck)
        }

        if dominantCount <= 1 {
            return item(for: .firstPrinciples)
        }

        return item(for: .firstPrinciples)
    }
}
```

- [ ] **Step 5: Fill built-in lens metadata**

Update each `LensCatalogItem` in `BuiltinLensCatalog.library`.

For `evidenceCheck`, use:

```swift
LensCatalogItem(
    lensId: "evidenceCheck",
    promptId: "evidence_check",
    version: "builtin.v1",
    title: "证据校验",
    subtitle: "把事实、判断和假设分开，先清理地基。",
    shortLabel: "事实",
    methodLine: "先问：我知道什么，还是我以为什么？",
    promptGuidance: "Separate facts, interpretations, assumptions, and validation gaps before asking the user to decide.",
    symbolName: "checklist",
    recommendedReason: "当前材料里有事实、风险或问题需要先验清依据。",
    questionSeeds: [
        "我知道什么，还是我以为什么？",
        "哪条判断现在缺少可验证证据？",
        "如果只保留事实，这件事还剩什么？"
    ],
    accentRole: .graphite,
    methodIndex: 1
)
```

For `opposingView`, use:

```swift
LensCatalogItem(
    lensId: "opposingView",
    promptId: "opposing_view",
    version: "builtin.v1",
    title: "反方视角",
    subtitle: "主动寻找相反证据，避免只证明自己是对的。",
    shortLabel: "反证",
    methodLine: "先问：如果我错了，证据会长什么样？",
    promptGuidance: "Challenge the user's current interpretation by looking for contrary evidence, missing stakeholders, and plausible alternative explanations.",
    symbolName: "arrow.left.arrow.right",
    recommendedReason: "当前材料里问题和风险偏多，适合先挑战默认判断。",
    questionSeeds: [
        "如果我错了，证据会长什么样？",
        "谁会不同意这个判断，理由是什么？",
        "有没有一个更便宜的解释？"
    ],
    accentRole: .brick,
    methodIndex: 2
)
```

For `leverageAnalysis`, use:

```swift
LensCatalogItem(
    lensId: "leverageAnalysis",
    promptId: "leverage_analysis",
    version: "builtin.v1",
    title: "杠杆分析",
    subtitle: "找出最能改变结果的一步，把精力放在关键处。",
    shortLabel: "杠杆",
    methodLine: "先问：哪一步最能改变结果？",
    promptGuidance: "Focus questions and quests on the smallest action, decision, or constraint that can most change the outcome.",
    symbolName: "point.topleft.down.curvedto.point.bottomright.up",
    recommendedReason: "当前材料已经出现任务或决策，适合收敛最高杠杆动作。",
    questionSeeds: [
        "哪一步最能改变结果？",
        "如果只做一件事，哪件事会让其他事变简单？",
        "当前真正卡住结果的约束是什么？"
    ],
    accentRole: .accent,
    methodIndex: 3
)
```

For `firstPrinciples`, use:

```swift
LensCatalogItem(
    lensId: "firstPrinciples",
    promptId: "first_principles",
    version: "builtin.v1",
    title: "第一性原理",
    subtitle: "拆掉默认前提，只保留不可再拆的事实和约束。",
    shortLabel: "本质",
    methodLine: "先问：如果从零开始，这件事必须成立的条件是什么？",
    promptGuidance: "Decompose the situation into non-negotiable facts, hard constraints, assumed rules, and rebuild the next action from those primitives.",
    symbolName: "square.stack.3d.down.right",
    recommendedReason: "当前材料没有单一主导类型，适合先拆前提和硬约束。",
    questionSeeds: [
        "如果从零开始，这件事必须成立的条件是什么？",
        "哪些规则是事实，哪些只是沿用的假设？",
        "去掉默认做法后，最小可行动作是什么？"
    ],
    accentRole: .principle,
    methodIndex: 4
)
```

- [ ] **Step 6: Run focused tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_methodAssetMetadataIsComplete -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsEvidenceCheckForValidationHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsLeverageAnalysisForActionHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsOpposingViewForDeepRiskHeavyCards -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensLibrary_recommendsFirstPrinciplesWhenNoTypeDominates test
```

Expected: PASS.

- [ ] **Step 7: Run identity regression tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testThinkingLens_existingRawValues_stable -only-testing:MingSiTests/AppStoreStateMachineTests/testThinkingLens_promptIds_stable -only-testing:MingSiTests/AppStoreStateMachineTests/testExistingLensTitles_unchanged -only-testing:MingSiTests/AppStoreStateMachineTests/testExistingLensSubtitles_unchanged test
```

Expected: PASS.

- [ ] **Step 8: Commit domain implementation**

Run:

```bash
git diff --check
git add Sources/Domain/Models.swift Tests/App/AppStoreStateMachineTests.swift
git commit -m "feat: enrich built-in lens method assets"
```

Expected: `git diff --check` passes and commit includes only domain plus the lens tests from Tasks 1 and 2.

---

### Task 3: Today Lens Recommendation UI

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`
- Test: compile through `AppStoreStateMachineTests`

- [ ] **Step 1: Inspect the current Today diff**

Run:

```bash
git diff -- Sources/Features/Today/TodayView.swift | sed -n '1,260p'
```

Expected: output includes current automation id / primary action guidance edits. Preserve those edits.

- [ ] **Step 2: Sort lens cards by catalog method index and compute recommendation**

In `selectLensSection`, replace:

```swift
            ForEach(ThinkingLens.allCases) { lens in
                lensCard(lens)
            }
```

with:

```swift
            let recommendedLensId = BuiltinLensCatalog.library
                .recommendedItem(for: store.thinkingCards.filter(\.isConfirmed), mode: store.todayDraft.sessionMode)
                ?.lensId

            ForEach(ThinkingLens.allCases.sorted { $0.catalogItem.methodIndex < $1.catalogItem.methodIndex }) { lens in
                lensCard(lens, isRecommended: lens.rawValue == recommendedLensId)
            }
```

- [ ] **Step 3: Replace `lensCard` with catalog-driven method card**

Replace `private func lensCard(_ lens: ThinkingLens) -> some View` with:

```swift
    private func lensCard(_ lens: ThinkingLens, isRecommended: Bool) -> some View {
        let item = lens.catalogItem
        let isSelected = store.todayDraft.selectedLens == lens

        return Button(action: { store.selectThinkingLens(lens) }) {
            HStack(alignment: .top, spacing: 13) {
                LensGlyph(lens: lens, isSelected: isSelected)

                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("[\(item.methodIndex)]")
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .foregroundStyle(lens.tint.opacity(0.82))
                        Text(item.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(DS.ink)
                        Text(item.shortLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(lens.tint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(lens.tint.opacity(0.10), in: Capsule())
                        if isRecommended {
                            Text("推荐")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(DS.accentInk)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(DS.accent.opacity(0.10), in: Capsule())
                        }
                    }

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(DS.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.methodLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(lens.tint)
                        .fixedSize(horizontal: false, vertical: true)

                    if isRecommended {
                        Text(item.recommendedReason)
                            .font(.caption2)
                            .foregroundStyle(DS.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 10)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isSelected ? DS.accent : DS.mutedInk.opacity(0.42))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(DS.cardInnerPadding)
        .background(
            isSelected ? lens.tint.opacity(0.055) : Color(.systemBackground),
            in: RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(lens.tint)
                .frame(width: isRecommended || isSelected ? 4 : 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.cornerRadius, style: .continuous)
                .stroke(isSelected ? lens.tint.opacity(0.42) : (isRecommended ? lens.tint.opacity(0.24) : Color.primary.opacity(0.05)), lineWidth: isSelected ? 1.25 : 1)
        )
    }
```

- [ ] **Step 4: Replace lens tint switch with catalog accent role**

In `private extension ThinkingLens`, replace the `tint` property with:

```swift
    var tint: Color {
        switch catalogItem.accentRole {
        case .graphite: return DS.graphite
        case .brick: return DS.brick
        case .accent: return DS.accent
        case .principle: return DS.graphite
        }
    }
```

- [ ] **Step 5: Compile focused tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testBuiltinLensCatalog_methodAssetMetadataIsComplete test
```

Expected: PASS. This proves the UI compiles against the new catalog fields.

- [ ] **Step 6: Commit Today lens UI**

Run:

```bash
git diff --check
git add Sources/Features/Today/TodayView.swift
git commit -m "feat: show recommended lens method cards"
```

Expected: commit includes only `Sources/Features/Today/TodayView.swift`.

---

### Task 4: Today Thinking, Question, and Quest Card Surfaces

**Files:**
- Modify: `Sources/Features/Today/TodayView.swift`
- Optional Modify: `Sources/DesignSystem/Theme.swift`

- [ ] **Step 1: Inspect current card subviews**

Run:

```bash
nl -ba Sources/Features/Today/TodayView.swift | sed -n '1140,1345p'
```

Expected: shows `ThinkingCardRow`, `QuestionCardView`, and `QuestCardView`.

- [ ] **Step 2: Add small display helpers in TodayView**

Near `private extension ThinkingLens`, add:

```swift
private extension PriorityLevel {
    var displayTitle: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
}

private extension SensitivityLevel {
    var displayTitle: String {
        switch self {
        case .normal: return "普通"
        case .possiblySensitive: return "可能敏感"
        case .sensitive: return "敏感"
        }
    }
}

private struct BriefRow: View {
    let title: String
    let body: String
    var accent: Color = DS.mutedInk

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(accent)
            Text(body)
                .font(.subheadline)
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
```

- [ ] **Step 3: Replace `ThinkingCardRow` non-editing layout**

Inside `ThinkingCardRow.body`, keep the existing editing controls. Replace the current non-editing display and action row with this full body structure:

```swift
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Circle()
                    .fill(card.type.color)
                    .frame(width: 7, height: 7)

                Text(card.type.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(card.type.color)

                Text("重要性 \(card.priority.displayTitle)")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DS.mutedInk)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(DS.surface, in: Capsule())

                if card.sensitivity != .normal {
                    Text(card.sensitivity.displayTitle)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(DS.caution)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(DS.caution.opacity(0.10), in: Capsule())
                }

                Spacer()

                Image(systemName: card.isConfirmed ? "checkmark.square.fill" : "square")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(card.isConfirmed ? DS.success : DS.mutedInk.opacity(0.55))
            }

            if isEditing {
                EditableField(title: "标题", text: $draftTitle)
                EditableField(title: "内容", text: $draftBody, axis: .vertical)
                Picker("类型", selection: $draftType) {
                    ForEach(ThinkingCardType.allCases) { type in
                        Text(type.title).tag(type)
                    }
                }
                .pickerStyle(.menu)
                Picker("重要性", selection: $draftPriority) {
                    Text("低").tag(PriorityLevel.low)
                    Text("中").tag(PriorityLevel.medium)
                    Text("高").tag(PriorityLevel.high)
                }
                .pickerStyle(.segmented)
                Picker("敏感性", selection: $draftSensitivity) {
                    Text("普通").tag(SensitivityLevel.normal)
                    Text("可能敏感").tag(SensitivityLevel.possiblySensitive)
                    Text("敏感").tag(SensitivityLevel.sensitive)
                }
                .pickerStyle(.segmented)
            } else {
                Text(card.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(card.body)
                    .font(.subheadline)
                    .foregroundStyle(DS.mutedInk)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(isEditing ? "保存编辑" : "编辑") {
                    if isEditing {
                        update(draftType, draftTitle, draftBody, draftPriority, draftSensitivity)
                    }
                    isEditing.toggle()
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)

                Button(card.isConfirmed ? "已确认" : "确认", action: confirm)
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(DS.accent)
                    .accessibilityIdentifier(TodayAutomationID.cardConfirmAction)

                Button(card.isExcludedFromModel ? "已排除" : "排除", action: exclude)
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(TodayAutomationID.cardExcludeAction)

                Button("删除", role: .destructive, action: delete)
                    .font(.caption)
                    .buttonStyle(.bordered)
            }
        }
        .thinkingCardSurface(type: card.type, isExcluded: card.isExcludedFromModel)
        .opacity(card.isExcludedFromModel ? 0.5 : 1)
```

Ensure there is still exactly one `.accessibilityIdentifier(TodayAutomationID.cardConfirmAction)` and one `.accessibilityIdentifier(TodayAutomationID.cardExcludeAction)`.

- [ ] **Step 4: Replace `QuestionCardView.body`**

Replace `QuestionCardView.body` with:

```swift
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "scope")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accent)
                Text("透镜追问")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DS.accentInk)
            }

            Text(question.question)
                .font(.headline.weight(.semibold))
                .foregroundStyle(DS.ink)
                .fixedSize(horizontal: false, vertical: true)

            Text(question.whyItMatters)
                .font(.caption)
                .foregroundStyle(DS.mutedInk)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField("写下你的判断，不需要完整答案", text: $answer, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .padding(12)
                .background(DS.surface, in: RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.smallRadius, style: .continuous)
                        .stroke(Color.primary.opacity(0.05), lineWidth: 1)
                )
                .accessibilityIdentifier(TodayAutomationID.questionAnswerField)
        }
        .questionSurface()
    }
```

- [ ] **Step 5: Replace `QuestCardView` non-editing display**

In `QuestCardView.body`, keep the editing branch. Replace the non-editing branch with:

```swift
            } else {
                Text(quest.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DS.ink)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    BriefRow(title: "为什么重要", body: quest.whyItMatters, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "完成标准", body: quest.completionCriteria, accent: quest.type == .main ? DS.accent : DS.mutedInk)
                    BriefRow(title: "预期阻力", body: quest.expectedResistance, accent: DS.caution)
                    BriefRow(title: "回看问题", body: quest.reflectionQuestion, accent: DS.graphite)
                }
            }
```

Keep the existing `.questSurface(isMain: quest.type == .main)`.

- [ ] **Step 6: Compile focused Today tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testTodayAutomationIdentifiers_areStableForRenderedWalkthroughControls test
```

Expected: PASS. This proves automation identifiers survived the visual rewrite.

- [ ] **Step 7: Run full AppStore state-machine tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Expected: PASS.

- [ ] **Step 8: Commit Today card surfaces**

Run:

```bash
git diff --check
git add Sources/Features/Today/TodayView.swift
git commit -m "feat: refine Today thinking card surfaces"
```

Expected: commit includes only `Sources/Features/Today/TodayView.swift`, unless `Sources/DesignSystem/Theme.swift` was intentionally used for a shared helper.

---

### Task 5: Build and Rendered Verification

**Files:**
- No required source edits.
- Optional documentation update: `docs/verification-log.md` if this project convention requires recording verification evidence.

- [ ] **Step 1: Run final whitespace check**

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 2: Run full focused app tests**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Expected: PASS.

- [ ] **Step 3: Run simulator build**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Expected: PASS.

- [ ] **Step 4: Capture rendered Today Review Cards and Select Lens if simulator is available**

Use the existing Debug visual QA seed paths. First launch Review Cards:

```bash
xcrun simctl boot "iPhone 17" || true
xcrun simctl terminate booted com.mingsi.app || true
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=review_cards xcrun simctl launch booted com.mingsi.app
```

Then capture a screenshot to:

```text
docs/subtasks/screenshots/077-today-card-lens-upgrade/01-review-cards.png
```

Launch Select Lens:

```bash
xcrun simctl terminate booted com.mingsi.app || true
SIMCTL_CHILD_MINGSI_VISUAL_QA_TODAY_STAGE=select_lens xcrun simctl launch booted com.mingsi.app
```

Then capture a screenshot to:

```text
docs/subtasks/screenshots/077-today-card-lens-upgrade/02-select-lens.png
```

Expected visual evidence:

- Review Cards shows quieter paper-slip cards, semantic spines, compact status, and lower button noise.
- Select Lens shows method-indexed lens cards, recommendation marker, semantic spine, and no large decorative fills.

- [ ] **Step 5: Document verification result if screenshots or long build logs are produced**

If screenshots were captured, append this entry to `docs/verification-log.md`:

```markdown
## 2026-06-07 Today Card Lens Upgrade

Files verified:
- `Sources/Domain/Models.swift`
- `Sources/Features/Today/TodayView.swift`
- `Tests/App/AppStoreStateMachineTests.swift`

Commands:
- `git diff --check`
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests test`
- `xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build`

Rendered evidence:
- `docs/subtasks/screenshots/077-today-card-lens-upgrade/01-review-cards.png`
- `docs/subtasks/screenshots/077-today-card-lens-upgrade/02-select-lens.png`
```

- [ ] **Step 6: Commit verification docs if created**

Run:

```bash
git add docs/verification-log.md docs/subtasks/screenshots/077-today-card-lens-upgrade
git commit -m "docs: record Today card lens verification"
```

Expected: commit only verification docs/screenshots. If no docs or screenshots were created, skip this commit.

---

## Final Acceptance Checklist

- [ ] `ThinkingLens.rawValue` values remain unchanged.
- [ ] `LensCatalogItem.promptId` values remain unchanged.
- [ ] Every built-in lens has `recommendedReason`, `questionSeeds`, `accentRole`, and `methodIndex`.
- [ ] `LensLibrary.recommendedItem(for:mode:)` returns the expected lens for validation-heavy, action-heavy, deep risk-heavy, and no-dominant-type card sets.
- [ ] Today lens cards are catalog-driven and show recommendation without auto-selecting.
- [ ] Today thinking cards, question cards, and quest cards visually follow the approved paper-slip direction.
- [ ] Existing Today automation identifiers remain present.
- [ ] `git diff --check` passes.
- [ ] Focused and full `AppStoreStateMachineTests` pass, or any blocker is recorded with exact command output.
- [ ] iPhone 17 simulator build passes, or any blocker is recorded with exact command output.
