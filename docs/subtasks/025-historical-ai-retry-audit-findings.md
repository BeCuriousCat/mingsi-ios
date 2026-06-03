# Subtask 025: Historical AI Retry Audit Findings

Date: 2026-06-03

Owner: Codex
Delegated implementer: Claude Code

## Summary

Historical AI retry is **intentionally blocked by design**. The current implementation supports current-day AI retry with visible failure recovery and PromptRun audit, but cross-day retry for old records is gated at two levels:

1. **Prompt-level guard**: Only 4 of 11 PromptIDs are repairable (organizeCards, generateQuestions, generateQuests, extractPrinciple)
2. **State-level guard**: Card repair is blocked if any confirmed cards, questions, quests, or principles exist

This is a **product decision**, not a missing implementation. The architecture already has the infrastructure for historical retry (PromptRun audit trail, unresolvedFailures query, source record IDs), but the UI and retry logic are constrained to prevent unsafe overwrites of confirmed evidence.

The safest next implementation slice is to add a **History entry point with candidate review UX** for historical retry, treating the retry result as a reviewable proposal rather than immediate overwrite.

## Current Implementation Map

### Current-Day AI Retry Paths

**File**: `Sources/Features/Today/TodayView.swift`

**Lines 88-97**: Today header shows "重试 AI" button when AI fails
```swift
if store.canRetryCurrentAI {
    Button {
        store.retryCurrentAIStep()
    } label: {
        Label("重试 AI", systemImage: "arrow.clockwise")
    }
}
```

**Lines 529-535**: Action row shows "重试当前步骤" button
```swift
if store.canRetryCurrentAI {
    Button("重试当前步骤") {
        store.retryCurrentAIStep()
    }
}
```

### Historical PromptRun Failure Discovery

**File**: `Sources/Services/PersistenceCore.swift`

**Lines 1851-1902**: `SQLitePromptRunRepository` implements `unresolvedFailures(limit:)`

Key logic:
- Fetches recent PromptRuns ordered by created_at desc (limit * 6 for filtering)
- Builds `resolutionKey` from promptId, promptVersion, modelProvider, modelName, sessionMode, sourceRecordIds, contextRecordIds
- **Filters out failures resolved by later success**: if a later PromptRun with the same resolutionKey succeeds, earlier failures are excluded
- Returns only failures where `responseJson == nil` and `error != nil`

**Lines 2136-2146**: `PromptRunRow.resolutionKey` computed property
```swift
var resolutionKey: String {
    [
        promptId,
        promptVersion,
        modelProvider,
        modelName,
        sessionMode,
        sourceRecordIdsJson ?? "",
        contextRecordIdsJson ?? ""
    ].joined(separator: "|")
}
```

### History UI for Repairable Records

**File**: `Sources/App/AppStore.swift` (partial read, referenced in summary)

- `repairablePromptRuns(for:)` filters unresolved PromptRuns by daily entry
- Uses `canRepairPrompt()` to determine which PromptIDs are retryable
- Historical UI shows repairable PromptRuns with **warning text** that cross-day retry is not yet open

### Cross-Day Retry Blockers

**File**: `Sources/App/AppStore.swift`

**Function**: `canRepairPrompt(_ prompt: PromptID) -> Bool` (referenced in test file)

Repairable prompts (4):
- `.organizeCards`
- `.generateQuestions`
- `.generateQuests`
- `.extractPrinciple`

Not repairable (7):
- `.recommendLenses`
- `.verifyQuest`
- `.weeklyCalibration`
- `.monthlyGrowth`
- `.suggestProjectLinks`
- `.generateProjectInsights`
- `.suggestProjectMerges`

**Guard**: `canRunBackgroundCardRepair` prevents card reorganization if any confirmed cards, questions, quests, or principles exist (referenced in test file)

### Data Available for Historical Retry Reconstruction

**File**: `Sources/Services/PersistenceCore.swift`

**Lines 2115-2190**: `PromptRunRow` stores:

For reconstructing the request:
- `promptId`: Which prompt to run
- `promptVersion`: Prompt version
- `inputSchemaVersion`: Input schema version
- `outputSchemaVersion`: Output schema version
- `modelProvider`: Provider (e.g., "glm")
- `modelName`: Model name
- `sessionMode`: quick/standard/deep
- `sourceRecordIds`: Source record IDs (JSON array)
- `contextRecordIds`: Context record IDs (JSON array)
- `requestSummary`: Request summary

For audit:
- `responseJson`: Success response (nullable)
- `error`: Error message (nullable)
- `createdAt`: Timestamp

### Test Coverage

**File**: `Tests/App/AppStoreStateMachineTests.swift`

- `testRetryPendingAIRepairs_doesNotRerunOrganizeCardsAfterConfirmedCardsOrDownstreamState`
- `repairablePromptRunsForHistoryRecordReturnsUnresolvedFailuresForThatEntry`

**File**: `Tests/Services/PersistenceCoreTests.swift`

- `testPromptRun_unresolvedFailuresReturnsOnlyFailedRuns`
- `testPromptRun_unresolvedFailuresIgnoresFailureResolvedByLaterSuccess`

## Gap List (Ordered by Severity)

### CRITICAL: No Historical Retry UX Entry Point

**Location**: `Sources/Features/FeatureTabs.swift` (History tab)

**Gap**: Historical UI shows repairable PromptRuns but cross-day retry is not yet open. Users can see old failures but cannot trigger retry.

**Evidence**: mvp-stage-progress.md states "Historical AI retry needs clear user entry points and candidate review behavior for failed old records."

**Impact**: Users cannot recover from old AI failures. Historical input remains dirty if AI fails and user moves on.

### HIGH: Missing Candidate Review Model for Historical Retry

**Location**: Domain layer

**Gap**: No domain model exists for "historical retry candidate" similar to `ProjectCandidate` or `ProjectLinkCandidate`.

**Evidence**: Current architecture has candidate review patterns for projects but not for AI retry.

**Impact**: Cannot implement historical retry safely without a reviewable intermediate state.

### HIGH: No Reconstruction Logic for Historical Retry

**Location**: `Sources/App/AppStore.swift` or dedicated use case

**Gap**: No function exists to reconstruct a retry request from a historical PromptRun.

**Requirements**:
- Load source records from `sourceRecordIds`
- Rebuild prompt context from `contextRecordIds`
- Invoke appropriate prompt with reconstructed input

### MEDIUM: Prompt-Level Guard Too Restrictive

**Location**: `Sources/App/AppStore.swift` - `canRepairPrompt()`

**Gap**: Only 4 of 11 prompts are repairable. Some prompts like `suggestProjectLinks` and `generateProjectInsights` might be safe to retry historically.

**Impact**: Users cannot retry certain failures even if they would be safe (e.g., project link failures where no confirmed projects exist yet).

### MEDIUM: Raw Input Not Preserved for Historical Reconstruction

**Location**: `PromptRun` schema in `Sources/Services/PersistenceCore.swift`

**Gap**: `PromptRun` stores sourceRecordIds but not the actual raw input text.

**Evidence**: For `organizeCards`, the raw input is the daily entry's `rawText`. This can be reconstructed, but the reconstruction logic is not implemented.

**Impact**: Historical retry requires loading source records and rebuilding input, which adds complexity.

### LOW: No User Feedback Loop for Historical Retry

**Gap**: No mechanism to collect user feedback on historical retry success/failure.

**Impact**: Cannot learn from historical retry patterns to improve guard conditions.

## Recommended Next Bounded Implementation Slice

**Slice**: Historical AI Retry Entry Point and Candidate Review UX

**Scope**:
1. Add domain model `HistoricalRetryCandidate` with fields:
   - `id: UUID`
   - `promptRunId: UUID`
   - `promptId: PromptID`
   - `sourceEntryId: UUID`
   - `reconstructedInput: String` (for organizeCards)
   - `candidateResult: String?` (nullable, populated after retry)
   - `status: HistoricalRetryStatus` (pending, retrying, candidate, accepted, dismissed)
   - `createdAt: Date`
   - `updatedAt: Date`

2. Add repository `HistoricalRetryCandidateRepository`

3. Add History UI entry point:
   - Show "修复历史失败" section in History when unresolved failures exist
   - Tap failure → create candidate → show candidate sheet
   - Candidate sheet shows original error and "重试" button
   - After retry, show candidate result with "接受" / "忽略" buttons

4. Add reconstruction logic for `organizeCards`:
   - Load DailyEntryDraft from sourceEntryId
   - Use `rawText` as reconstructed input
   - Invoke `organizeCards` prompt

5. Add acceptance logic:
   - Accept → overwrite old cards with new cards (only if no confirmed state exists)
   - Ignore → mark candidate as dismissed

**Why this slice is safe**:
- Only implements retry for `organizeCards` (simplest case)
- Uses candidate review pattern (proven in ProjectCandidate)
- Guards against overwriting confirmed state
- Does not modify existing PromptRun records (read-only audit)

**Why this slice is scoped**:
- Only one PromptID (organizeCards)
- Only one entry point (History)
- No prompt strategy changes
- No schema migrations (uses new table)

## Proposed Acceptance Tests

### Unit Tests

1. **testHistoricalRetryCandidate_creation**:
   - Create candidate from PromptRun
   - Verify promptRunId, promptId, sourceEntryId are populated
   - Verify status is .pending

2. **testHistoricalRetryCandidate_reconstructInputForOrganizeCards**:
   - Load DailyEntryDraft from sourceEntryId
   - Verify reconstructedInput equals draft.rawText

3. **testHistoricalRetryCandidate_acceptOverwritesUnconfirmedCards**:
   - Create candidate with pending cards
   - Accept candidate
   - Verify new cards replace old cards

4. **testHistoricalRetryCandidate_acceptDoesNotOverwriteConfirmedCards**:
   - Create candidate with confirmed cards
   - Attempt to accept candidate
   - Verify operation fails or requires explicit confirmation

5. **testHistoricalRetryCandidate_dismissMarksStatus**:
   - Create candidate
   - Dismiss candidate
   - Verify status is .dismissed

### Integration Tests

6. **testHistoryUI_showsRepairablePromptRuns**:
   - Create unresolved PromptRun for organizeCards
   - Load History
   - Verify "修复历史失败" section appears

7. **testHistoryUI_retryFlowCreatesCandidate**:
   - Tap repairable PromptRun
   - Tap "重试" button
   - Verify candidate is created with status .retrying

8. **testHistoryUI_candidateReviewShowsResult**:
   - Retry completes successfully
   - Verify candidate sheet shows new cards
   - Verify "接受" and "忽略" buttons appear

9. **testHistoryUI_acceptanceOverwritesOldCards**:
   - Accept candidate
   - Verify old cards are replaced
   - Verify PromptRun is marked as resolved

### Edge Case Tests

10. **testHistoricalRetry_guard_blocksWhenConfirmedStateExists**:
    - Create unresolved PromptRun for organizeCards
    - Create confirmed cards for the same entry
    - Verify retry is blocked or requires explicit bypass

11. **testHistoricalRetry_unsupportedPromptIdIsBlocked**:
    - Create unresolved PromptRun for recommendLenses
    - Verify UI does not show retry option

12. **testHistoricalRetry_resolutionKeyFiltersResolvedFailures**:
    - Create failure PromptRun
    - Create success PromptRun with same resolutionKey
    - Verify failure is not shown in repairable list

## Risks

1. **User confusion**: Users may not understand why some failures are retryable and others are not.
   - **Mitigation**: Add clear UI text explaining which failures can be retried and why.

2. **Data inconsistency**: If a user accepts a historical retry after making manual changes, data may become inconsistent.
   - **Mitigation**: Guard against overwriting confirmed state. Require explicit confirmation if any manual changes exist.

3. **AI cost**: Historical retry could trigger unnecessary AI calls if user accidentally clicks retry.
   - **Mitigation**: Show explicit retry confirmation dialog with cost estimate.

4. **Prompt version drift**: Historical PromptRun may reference old prompt version that no longer exists.
   - **Mitigation**: Check prompt version compatibility before retry. Fall back to current version with warning.

5. **Schema changes**: If prompt input/output schema changes, historical retry may fail.
   - **Mitigation**: Store schema versions in PromptRun. Add migration logic for incompatible schemas.

## Non-Goals

1. **Full cross-day retry for all PromptIDs**: Only implement for organizeCards in this slice.
2. **Automatic background historical retry**: All historical retry is user-initiated.
3. **Prompt version migration**: Use current prompt versions for now.
4. **Batch historical retry**: Only single-entry retry in this slice.
5. **Historical retry statistics**: No analytics or feedback collection in this slice.

## Final Recommendation

**Recommendation**: **Delegate implementation**

**Rationale**:
1. The slice is well-bounded and follows proven patterns (ProjectCandidate, ProjectLinkCandidate).
2. The architecture already supports the required infrastructure (PromptRun audit, source record IDs, repository pattern).
3. The product decision is clear: historical retry should be reviewable, not automatic.
4. The implementation does not require schema migrations or prompt strategy changes.
5. The test coverage requirements are explicit and achievable.

**Preconditions for delegation**:
1. Codex confirms the slice scope (organizeCards only, History entry point).
2. Codex confirms the candidate review pattern is acceptable.
3. Codex confirms the guard against overwriting confirmed state is sufficient.

**Alternative**: **Document/product decision first**

If there is uncertainty about:
- Which PromptIDs should be retryable historically
- Whether historical retry should require user review or can be automatic
- Whether historical retry should overwrite confirmed state with confirmation

Then Codex should clarify these product decisions before delegating implementation.

## Codex Manager Acceptance Review

Status: **Accepted as audit, rejected as direct implementation plan**

Accepted:

1. Current-day retry paths, PromptRun unresolved-failure discovery, and state guards are accurately identified.
2. Historical retry should be reviewable first instead of automatically overwriting durable evidence.
3. `organizeCards` is the safest first historical retry candidate because it can be reconstructed from the daily raw input.

Rejected or needs redesign:

1. The recommendation to add a new repository/table while saying "No schema migrations" is contradictory. Any durable retry-candidate table requires an explicit migration and persistence tests.
2. Accepting retry results by overwriting old cards remains product-sensitive and cannot be delegated without a PRD-level decision about confirmed downstream state, user review, and conflict handling.
3. Direct implementation touches cross-day semantics, AppStore orchestration, and likely persistence, so it is not currently a safe Claude Code implementation slice.

Next manager decision:

- Produce a historical retry candidate-review PRD and architecture note first, or split out a smaller no-migration UI slice that explains unresolved old failures and the current recovery limitation.
- Do not delegate implementation until persistence strategy, overwrite semantics, write set, and acceptance tests are settled.

## Verification

Required command:

```bash
git diff --check -- docs/subtasks/025-historical-ai-retry-audit-progress.md docs/subtasks/025-historical-ai-retry-audit-findings.md
```

Run after updating HANDOFF in progress file.
