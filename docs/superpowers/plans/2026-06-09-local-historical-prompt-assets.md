# Local Historical Prompt Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make rollback target prompt versions resolvable by the real `LocalPromptProvider`, so persisted prompt asset selections can survive restart without test-only fixture providers.

**Architecture:** Keep the existing `PromptProvider` boundary. `LocalPromptProvider.template(for:mode:)` returns the current first-party prompt asset, while `template(for:mode:version:)` resolves either that current asset or a local historical asset record. This slice ships a narrow historical pack for `generateQuestions` version `0.9.0`, because current rollback/eval tests already use that version as the rollback target.

**Tech Stack:** Swift, XCTest, Xcode iOS Simulator, existing MingSi domain/persistence architecture.

---

## File Structure

- `Sources/Services/CoreProtocols.swift`: extend `LocalPromptProvider` with local historical asset lookup and metadata/text overrides for `generateQuestions@0.9.0`.
- `Tests/Services/LocalPromptProviderTests.swift`: add RED tests proving the real local provider resolves historical rollback versions and keeps current templates current.
- `Tests/App/AppStoreStateMachineTests.swift`: add/adjust a rollback restart test to use `LocalPromptProvider` directly instead of fixture-only historical lookup.
- `docs/mvp-stage-progress.md`: add Subtask 102 summary after verification.
- `docs/verification-log.md`: add Subtask 102 verification evidence.

---

### Task 1: Real LocalPromptProvider Historical Lookup Test

**Files:**
- Test: `Tests/Services/LocalPromptProviderTests.swift`
- Modify: `Sources/Services/CoreProtocols.swift`

- [ ] **Step 1: Write the failing provider tests**

Add these tests to `LocalPromptProviderTests`:

```swift
func testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget() {
    let current = provider.template(for: .generateQuestions, mode: .standard)

    XCTAssertEqual(current.version, "1.0.0")
    XCTAssertEqual(current.rollbackTargetVersion, "0.9.0")
}

func testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset() {
    let current = provider.template(for: .generateQuestions, mode: .standard)
    let historical = provider.template(for: .generateQuestions, mode: .standard, version: "0.9.0")

    XCTAssertNotNil(historical)
    XCTAssertEqual(historical?.version, "0.9.0")
    XCTAssertEqual(historical?.systemPolicyVersion, current.systemPolicyVersion)
    XCTAssertEqual(historical?.contextPolicyVersion, current.contextPolicyVersion)
    XCTAssertEqual(historical?.evalSuiteVersion, current.evalSuiteVersion)
    XCTAssertEqual(historical?.outputSchemaVersion, current.outputSchemaVersion)
    XCTAssertNil(historical?.rollbackTargetVersion)
    XCTAssertNotEqual(historical?.userText, current.userText)
    XCTAssertTrue(historical?.userText.contains("Generate concrete reflection questions") ?? false)
}

func testTemplateVersionLookup_returnsNilForUnknownHistoricalAsset() {
    XCTAssertNil(provider.template(for: .generateQuestions, mode: .standard, version: "0.8.0"))
    XCTAssertNil(provider.template(for: .generateQuests, mode: .standard, version: "0.9.0"))
}
```

- [ ] **Step 2: Run provider RED**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-red-dd -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsCurrentTemplate_declaresLocalRollbackTarget -only-testing:MingSiTests/LocalPromptProviderTests/testGenerateQuestionsRollbackTarget_resolvesHistoricalPromptAsset -only-testing:MingSiTests/LocalPromptProviderTests/testTemplateVersionLookup_returnsNilForUnknownHistoricalAsset test
```

Expected: FAIL because `LocalPromptProvider` does not yet expose `generateQuestions` rollback metadata or historical lookup.

- [ ] **Step 3: Implement minimal local historical asset support**

In `LocalPromptProvider`, override `template(for:mode:version:)` and add a private historical asset helper:

```swift
func template(for id: PromptID, mode: SessionMode, version: String) -> PromptTemplate? {
    let current = template(for: id, mode: mode)
    if current.version == version {
        return current
    }
    return Self.historicalTemplate(for: id, mode: mode, version: version, current: current)
}
```

Change `assetMetadata(for:)` so `generateQuestions` current metadata includes `rollbackTargetVersion: "0.9.0"`.

Add a historical template for `generateQuestions@0.9.0` that preserves system/context/eval/schema versions and uses older, still valid question-generation wording. Its `rollbackTargetVersion` must be nil.

- [ ] **Step 4: Run provider GREEN**

Run the same command from Step 2.

Expected: PASS with 3 tests, 0 failures.

---

### Task 2: Real Provider Restart Restoration Test

**Files:**
- Test: `Tests/App/AppStoreStateMachineTests.swift`
- Modify: `Sources/Services/CoreProtocols.swift` only if Task 1 implementation needs adjustment.

- [ ] **Step 1: Write failing AppStore test using `LocalPromptProvider`**

Add a test near the existing prompt rollback persistence test that saves `PromptAssetSelection(generateQuestions, selectedVersion: "0.9.0")`, creates an `AppStore` with `LocalPromptProvider`, calls `loadPersistedState()`, and verifies `runPromptEvalSuite()` traces `generateQuestions` at version `0.9.0`.

Use the existing SQLite test repositories and `recentPromptEvalRuns` assertions from nearby tests.

- [ ] **Step 2: Run AppStore RED/GREEN depending on Task 1 state**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-app-dd -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadPersistedState_restoresHistoricalPromptAssetSelectionWithLocalProvider test
```

Expected before Task 1 implementation: FAIL because the real provider cannot resolve `0.9.0`. Expected after Task 1 implementation: PASS.

- [ ] **Step 3: Keep fixture providers only where they model failed-current eval scenarios**

Do not remove rollback fixture providers that intentionally manufacture failed/stale current eval gates. Remove or avoid only fixture use that exists solely because the real provider lacked historical version lookup.

---

### Task 3: Verification and Documentation

**Files:**
- Modify: `docs/mvp-stage-progress.md`
- Modify: `docs/verification-log.md`

- [ ] **Step 1: Run focused suites**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-suites-dd -only-testing:MingSiTests/LocalPromptProviderTests -only-testing:MingSiTests/AppStoreStateMachineTests test
```

Expected: PASS.

- [ ] **Step 2: Run full verification**

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-full-dd -only-testing:MingSiTests test
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath /tmp/mingsi-historical-prompts-ui-dd -only-testing:MingSiUITests test
git diff --check
```

Expected: all pass; `git diff --check` has no output.

- [ ] **Step 3: Update docs**

Add Subtask 102 to `docs/verification-log.md` and `docs/mvp-stage-progress.md` describing local historical prompt packs, focused RED/GREEN evidence, full verification, and residual risk that remote prompt registry / marketplace behavior remains future work.
