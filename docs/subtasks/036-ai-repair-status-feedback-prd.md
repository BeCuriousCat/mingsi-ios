# Subtask 036 PRD: AI Repair Status Feedback Polish

Date: 2026-06-04

## Purpose

History repair and Settings audit now expose AI failures, retry candidates, and recent PromptRun rows. The remaining usability gap is that a user still has to infer what each run or candidate means: failed but unrepaired, candidate generated, accepted, ignored, blocked, retry failed, or successful and only audited.

Add clearer per-run/per-candidate status feedback without changing retry semantics.

## User Value

The alpha user can inspect a History day or Settings audit row and immediately understand:

- whether the AI call succeeded or failed;
- whether a failed historical run can generate a repair candidate;
- whether a candidate is still generating, ready for review, accepted, ignored, blocked, or failed;
- what the next user action is, if any;
- that successful PromptRuns are audit evidence, not repair tasks.

## Product Contract

- This is a display-only polish slice.
- Do not change historical retry behavior.
- Do not add retry support for prompts other than `organizeCards`.
- Do not change PromptRun persistence, HistoricalRetryCandidate persistence, migrations, parser, PromptProvider, LLM clients, Keychain, or AppStore orchestration.
- Do not display API keys, raw secret-bearing payloads, or new user raw input.
- Do not use fake data.
- Do not add navigation or deep-link behavior unless already present and trivial to reuse.
- Keep the UI calm, compact, and readable in light/dark mode.

## Expected UX

History day detail, `历史 AI 修复`:

- Add a compact summary line when repair content exists, for example:
  - unresolved repairable runs;
  - generated/reviewable candidates;
  - completed candidates;
  - failed or blocked candidates.
- For unresolved failed PromptRun rows:
  - show a clearer status label such as `待生成候选` when supported;
  - show `仅审计` / unsupported copy when not supported;
  - show a short next-step description beneath the error/summary.
- For HistoricalRetryCandidate rows:
  - keep the existing status chip;
  - add one short status explanation / next-step line for every status:
    - pending;
    - retrying;
    - candidateReady;
    - accepted;
    - dismissed;
    - blocked;
    - failed.

Settings AI audit:

- Keep failed/successful grouping and current expand/collapse behavior.
- Add one compact outcome line in each `PromptRunAuditRow`:
  - success: successful call, audit evidence retained;
  - failed + supported historical repair prompt + source ids: can be repaired from the corresponding History date;
  - failed + unsupported prompt: audit-only failure, no historical candidate retry yet.

## Architecture Boundary

Preferred implementation:

- Add small pure display helpers in `Sources/Features/FeatureTabs.swift`, near existing History/PromptRun display helpers.
- Helpers should be simple value types or extensions with testable strings.
- Tests should assert helper behavior, not pixel layout.

Do not:

- change `AppStore.startHistoricalOrganizeCardsRetry`;
- change `HistoricalRetryCandidateRepository`;
- change `PromptRunRepository`;
- change SQLite migrations;
- change prompt templates;
- change GLM retry behavior;
- add a broad Settings or History redesign.

## Allowed Files

- `Sources/Features/FeatureTabs.swift`
- `Tests/Features/HistoryFeatureTests.swift`
- `docs/subtasks/036-ai-repair-status-feedback-progress.md`

## Forbidden Files

- `Sources/App/AppStore.swift`
- `Sources/Services/PersistenceCore.swift`
- `Sources/Services/DirectGLMClient.swift`
- Prompt parser/provider files.
- Keychain code.
- Migration files.
- Project/Growth domain files.

## Required Tests

Add or extend focused tests in `Tests/Features/HistoryFeatureTests.swift`:

1. `HistoricalRetryCandidateStatus` exposes a non-empty user-facing detail string for every status.
2. The PromptRun audit outcome helper distinguishes:
   - successful run;
   - failed `organizeCards` run with source ids as repairable from History;
   - failed unsupported prompt as audit-only.
3. If a History repair summary helper is added, test mixed unresolved/candidate counts.

Run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/HistoryFeatureTests test
```

## Acceptance Criteria

- History repair rows communicate status and next action without requiring the user to infer from raw errors.
- Settings PromptRun audit rows communicate whether a run is success evidence, repairable failure, or audit-only failure.
- No retry behavior or persistence semantics change.
- Existing AI audit group expand/collapse behavior remains intact.
- Focused History feature tests pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes after Codex acceptance.

## Manager Acceptance

Codex will accept only after:

- worker progress reaches `HANDOFF`;
- worker reports tests run;
- Codex reviews final diff against this PRD;
- Codex reruns focused tests;
- Codex runs `git diff --check`;
- Codex runs an iPhone 17 simulator build if the UI diff is accepted.
