# Worktree Cleanup Audit

Date: 2026-06-03

Purpose: make the current dirty worktree reviewable without deleting or reverting unrelated user, Claude Code, or GLM changes.

## Current State

The worktree is intentionally not clean. It contains broad changes from previous MingSi MVP slices:

- Today AI failure/retry/streaming flow.
- History search, filters, calendar, and evidence drilldown.
- Project evidence, insights, merge review, editing, archive/restore.
- Growth attribution, report generation, and contribution detail.
- GLM BYOK direct client and settings validation path.
- Prompt/context engineering docs and subtask records.

Codex did not delete or revert unrelated dirty files because many of them are valid phase work or external-agent output that still needs review.

## Accepted Fixes In This Cleanup Pass

- `Sources/DesignSystem/Theme.swift`
  - Replaced fixed light-theme color tokens with dynamic light/dark colors.
  - Updated principle surfaces and tab bar selected tint to use dynamic colors.

- `Sources/App/AppStore.swift`
  - Added `supplementTodayCapture(_:)`.
  - Supplement behavior appends non-empty text, returns to Capture, clears derived artifacts, and prompts regeneration.

- `Sources/Features/Today/TodayView.swift`
  - Added a visible “补充材料” action from ReviewCards and later editable steps.

- `Sources/Features/FeatureTabs.swift`
  - Fixed `ProjectEditorSheet` `Section` initializer compile issue.

- `Tests/App/AppStoreStateMachineTests.swift`
  - Added dark-mode design-token regression.
  - Added supplement-input regression.

- Docs
  - Updated UX flow, implementation gap audit, 022 progress, and delegation log.

## Claude Code Usage Assessment

Claude Code should remain a supervised helper, not the coding owner.

Use it for:

- Parser/service slices with narrow contracts.
- Local UI polish with a small write set.
- Read-only audits.
- Test-first implementation when the PRD is already precise.

Avoid using it for:

- Core AppStore state-machine changes.
- Persistence migrations and evidence safety.
- Prompt context strategy.
- Cross-tab product semantics.
- Final UI taste decisions.

Required pipeline:

- One PRD file.
- One progress file.
- One Claude prompt file.
- Checkpoints only: `START`, `RED`, `IMPLEMENTED`, `TARGETED_VERIFIED`, `HANDOFF`.
- Codex checks progress every 3-5 minutes, not every few seconds.
- Codex accepts only after diff review and targeted tests.

## Stage Usability

The current tree builds and the AppStore state-machine suite passes after this cleanup pass.

Fresh evidence:

- `testSupplementCaptureAfterGeneratedCards_appendsTextAndReturnsToCaptureForRegeneration`: 1 test, 0 failures.
- `testDesignTokens_resolveToReadableDarkModeContrast`: 1 test, 0 failures.
- `AppStoreStateMachineTests`: 89 tests, 0 failures.
- Related AppStore / History / Persistence regression: 163 tests, 0 failures.
- Full suite: 246 tests, 0 failures.
- `git diff --check`: passed.

This means there is a stage-testable version for the Today loop and core state machine. It does not mean the whole dirty worktree is ready to ship or commit.

## Remaining Review Risks

- Simulator visual QA is still needed for Today, History, Projects, Growth, and Settings in light/dark mode.
- Projects and Growth still need taste-level UI polish.
- The true incremental “supplement only adds/merges cards without clearing existing cards” flow is intentionally deferred; MVP uses safe regeneration.
- Worktree should be split into reviewable commits only after full verification.
