# Subtask 026: Historical AI Retry Candidate Review PRD

Date: 2026-06-03

Owner: Codex

## Goal

Turn historical AI failures from permanent dirty data into recoverable assets without corrupting the History evidence archive.

The first historical retry implementation must let the user retry an old failed `organizeCards` PromptRun, inspect the regenerated card candidates, and explicitly accept or dismiss them. Retry success must never silently overwrite confirmed downstream evidence.

## Source Documents

- `docs/mvp-current-goal.md`
- `docs/prd.md`
- `docs/data-architecture.md`
- `docs/architecture-decisions.md`
- `docs/subtasks/025-historical-ai-retry-audit-findings.md`

## Product Decisions

### Historical Retry Output

Historical retry output is a reviewable proposal, not an immediate write.

For the first implementation, the proposal contains:

- the original failed PromptRun metadata;
- the reconstructed source DailyEntry raw input;
- the new repair PromptRun metadata;
- validated candidate ThinkingCard payloads;
- the user decision: accepted, dismissed, or blocked.

### Initial Prompt Scope

MVP historical retry starts with `organizeCards` only.

Reasons:

- the source input can be reconstructed from `DailyEntry.rawText`;
- the output maps to ThinkingCard candidates;
- acceptance guards can be clearly defined;
- other prompts depend on more downstream context and should not be mixed into the first slice.

Unsupported prompts remain visible in audit surfaces but do not show an active retry button.

### Acceptance Semantics

Accepting a historical retry candidate may create or replace only unconfirmed card drafts for the same DailyEntry.

Acceptance is blocked when any of the following exists for the same DailyEntry:

- confirmed ThinkingCard;
- LensSession or ReflectionQuestion;
- Quest;
- PrincipleAsset sourced from the entry;
- ProjectLink, ProjectInsight, MetricContribution, or other cross-feature evidence sourced from the entry.

If blocked, the UI must explain why: the entry already has downstream evidence, so the retry result can be copied or dismissed but not automatically applied.

### User Experience

History day detail should expose a "历史 AI 修复" section when unresolved repairable failures exist for that day.

The candidate review flow:

1. User opens a History day with an unresolved `organizeCards` failure.
2. UI shows failed prompt, error summary, created time, and a clear "生成候选卡片" action.
3. User taps retry.
4. App reconstructs input from the source DailyEntry and calls GLM through existing PromptProvider / LLMClient boundaries.
5. While retrying, UI shows progress and does not remove existing local content.
6. On success, UI shows candidate cards with type, title, body, sensitivity, importance, and source.
7. User chooses "接受候选" or "忽略本次结果".
8. Accept writes cards only if guards still pass at the time of acceptance.
9. Dismiss keeps the audit trail but does not write cards.

## Data Model

Add a durable `HistoricalRetryCandidate` entity only with an explicit migration.

Fields:

```text
id
schemaVersion
failedPromptRunId
repairPromptRunId
promptId
sourceDailyEntryId
status: pending | retrying | candidate_ready | accepted | dismissed | blocked | failed
reconstructedInputSummary
candidatePayloadJson
error
blockedReason
createdAt
updatedAt
deletedAt
```

Rules:

- `failedPromptRunId` must reference the original failed PromptRun.
- `repairPromptRunId` is nullable until retry has been attempted.
- `candidatePayloadJson` stores validated candidate output, not UI layout.
- `reconstructedInputSummary` is a short summary for audit display. Full raw text remains in DailyEntry.
- `accepted` candidates must retain candidatePayloadJson for audit.
- `dismissed` and `blocked` candidates remain visible in audit history.
- Soft delete only.

## Repository Boundary

Add `HistoricalRetryCandidateRepository`.

Required methods:

```text
createCandidate(from failedPromptRun, sourceDailyEntryId)
updateStatus(id, status, error, blockedReason)
attachRepairRun(id, repairPromptRunId, candidatePayloadJson)
findCandidates(sourceDailyEntryId)
findCandidate(id)
markAccepted(id)
markDismissed(id)
```

Repository must not leak GRDB types to SwiftUI.

## AppStore / Use Case Boundary

The orchestration should live behind AppStore actions or dedicated use-case services, not in SwiftUI views.

Required actions:

```text
repairableHistoricalPromptRuns(for dailyEntryId)
startHistoricalOrganizeCardsRetry(failedPromptRunId)
acceptHistoricalRetryCandidate(candidateId)
dismissHistoricalRetryCandidate(candidateId)
```

Views call these actions only.

## Prompt And Context Strategy

Historical retry reuses the current `organizeCards` prompt implementation and current schema version unless the failed PromptRun references an incompatible schema.

Input context:

- source DailyEntry rawText;
- original sessionMode from failed PromptRun;
- privacy flags and sensitivity exclusions available on the entry;
- no unrelated History, Project, Growth, or Principle context in the first slice.

PromptRun audit:

- failed retry attempts create a new PromptRun with `error`;
- successful retry attempts create a new PromptRun with `responseJson`;
- sourceRecordIds must include the DailyEntry id;
- contextRecordIds should stay empty for first `organizeCards` historical retry unless required by existing prompt contracts.

## UI Requirements

History repair section:

- appears inside History day detail, not as a global blocking banner;
- groups repairable and unsupported failures separately;
- shows concise status: failed, retrying, candidate ready, blocked, accepted, dismissed;
- makes unsupported prompts understandable without offering an action that cannot work.

Candidate sheet:

- uses the same calm evidence style as History;
- avoids full-screen AI result walls;
- shows cards as review objects, not final facts;
- clearly distinguishes "candidate" from "confirmed";
- preserves tab bar safe area and dark-mode readability.

## Failure Behavior

- If GLM retry fails, keep the old failed PromptRun and add a new failed repair PromptRun.
- Candidate status becomes `failed` with readable error.
- User can retry again from the candidate sheet.
- Repeated retry failures are grouped by candidate, not rendered as an endless flat list.
- No local fallback may be marked as a successful historical AI repair.

## Migration Requirements

Introducing `HistoricalRetryCandidate` requires:

- new migration id;
- creation of candidate table;
- indexes on `sourceDailyEntryId`, `failedPromptRunId`, `status`, and `updatedAt`;
- no deletion or modification of existing PromptRun, DailyEntry, or ThinkingCard rows;
- persistence tests for insert, update, query, soft delete, and migration from an existing database.

This is Codex-owned architecture work until implemented and verified.

## Acceptance Tests

### Persistence

- Creating a candidate stores failedPromptRunId, promptId, sourceDailyEntryId, and pending status.
- Candidate query by sourceDailyEntryId returns newest first.
- Attaching a repair PromptRun stores candidatePayloadJson and changes status to candidate_ready.
- Marking dismissed preserves audit payload.
- Soft delete removes candidate from active queries without deleting PromptRun.

### State Guards

- Retry is available for unresolved `organizeCards` failure with no downstream evidence.
- Retry is unavailable for unsupported prompt IDs.
- Accept is blocked when confirmed cards exist.
- Accept is blocked when questions, quests, principles, project links, project insights, or growth contributions exist.
- Accept re-checks guards at the moment of acceptance, not only at candidate creation.

### Retry Flow

- Starting retry reconstructs input from DailyEntry.rawText.
- Retry failure creates a new failed PromptRun and leaves existing content unchanged.
- Retry success creates candidate card payloads but does not persist confirmed cards before acceptance.
- Accept creates unconfirmed or review-ready ThinkingCards according to existing card confirmation rules.
- Dismiss leaves History content unchanged.

### UI

- History day detail shows repairable failure section for an unresolved old organizeCards failure.
- Candidate-ready state shows generated cards and accept/dismiss actions.
- Blocked state explains the exact downstream evidence category preventing acceptance.
- Unsupported prompt failures remain audit-visible but action-disabled.

## Delegation Plan

Do not delegate the whole feature.

Codex-owned slices:

- migration and persistence contract;
- AppStore orchestration and acceptance semantics;
- prompt/context compatibility decisions.

Delegatable slices after Codex-owned groundwork:

- repository tests and implementation if the schema is already fixed;
- History repair section UI for a fixed view model contract;
- candidate sheet layout for a fixed state model;
- grouped failure display for candidates and PromptRun rows.

## Non-Goals

- Batch retry.
- Automatic background historical retry.
- Retry for non-`organizeCards` prompts.
- Server-side prompt migration.
- Prompt version replay.
- Project or Growth regeneration from historical retry results.
- Calendar, Reminder, or notification integration.

## Stop Condition For This PRD

This PRD is complete when implementation can be split into small slices with no ambiguity about:

- whether a migration is required;
- which prompt is supported first;
- what can be accepted;
- what must be blocked;
- which layer owns retry orchestration;
- how PromptRun audit remains visible.
