# Subtask 024: Settings AI Audit Grouping PRD

Date: 2026-06-03

## Goal

Make the Settings AI call audit usable when prompt run history grows beyond a few rows.

Current issue:

- Settings renders `store.recentPromptRuns` as a flat list.
- Users can quickly see 7-8 failed calls and lose access to lower settings content.
- This undermines the MVP requirement that AI failures are visible, retryable, and auditable without turning Settings into a long dump.

## Scope

Add a local Settings UI grouping/collapse layer for recent PromptRun audit rows.

Required behavior:

- Show a compact summary line with counts:
  - total recent runs
  - failed runs
  - successful runs
- Group runs into at least:
  - `失败`
  - `成功`
- Failure group is expanded by default.
- Success group is collapsed by default.
- Each group header shows count and a chevron/expand affordance.
- Existing `PromptRunAuditRow` detail display remains reusable.
- Refresh button remains visible and reloads recent prompt runs.
- Empty state remains unchanged.
- Unavailable/error audit message remains visible.

## Non-Goals

- No PromptRun schema change.
- No persistence migration.
- No AppStore state-machine refactor.
- No new retry semantics.
- No historical repair feature.
- No Prompt inspector.
- No simulator screenshot automation required in this slice.

## Allowed Write Set

Preferred implementation write set:

- `Sources/Features/FeatureTabs.swift`
- `Tests/App/AppStoreStateMachineTests.swift` only if a small pure grouping helper is exposed/testable.
- `docs/subtasks/024-settings-ai-audit-grouping-progress.md`
- `docs/agent-delegation-log.md`
- `docs/mvp-stage-progress.md`
- `docs/verification-log.md`

If implementation introduces a pure helper type in Domain/Feature code, it must not depend on SwiftUI or GRDB.

## UX Requirements

The grouped audit section should remain visually calm:

- Use compact headers, not large cards inside cards.
- Avoid AI purple/neon colors.
- Use existing `DS` colors and small rounded surfaces.
- Text must fit on iPhone width.
- Do not obscure GLM configuration controls.

Suggested structure:

```text
AI 调用审计                    刷新
最近 12 次 · 失败 7 · 成功 5

[v] 失败 7
    PromptRunAuditRow
    PromptRunAuditRow

[>] 成功 5
```

## Acceptance Tests

At minimum, verify with code/tests:

- Given mixed PromptRun values, the grouping helper returns failure and success groups with correct counts.
- Failure group is default-expanded.
- Success group is default-collapsed.
- Empty audit list still shows the existing empty copy.
- `loadRecentPromptRuns(limit:)` still loads newest first and preserves source/context refs.

## Verification Commands

Worker should run targeted tests:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:MingSiTests/AppStoreStateMachineTests/testLoadRecentPromptRuns_loadsNewestFirstAuditRunsWithRefsAndErrors test
```

If a new test file or test method is added, run it explicitly. If compile changes touch `FeatureTabs.swift`, run:

```bash
xcodebuild -project MingSi.xcodeproj -scheme MingSi -destination 'platform=iOS Simulator,name=iPhone 17' build
git diff --check
```

## Delegation Notes

This is suitable for Claude Code only if it can work in isolation and reach `HANDOFF` with targeted verification.

Because the manager worktree is dirty, if isolated implementation cannot safely include current uncommitted code, Claude Code should be used for read-only implementation planning only. Codex may then implement or defer.
