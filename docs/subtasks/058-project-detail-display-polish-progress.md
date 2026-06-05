# Subtask 058 Progress: Project Detail Display Polish

Status: PREPARED_RESOURCE_BLOCKED

Owner: Codex manager
Delegated implementer: pending Claude Code launch

PRD: `docs/subtasks/058-project-detail-display-polish-prd.md`
Claude prompt: `docs/subtasks/058-project-detail-display-polish-claude-prompt.md`
Event log: `docs/subtasks/logs/058-project-detail-display-polish-events.jsonl`
Expected raw log: `docs/subtasks/logs/058-project-detail-display-polish-claude-run.jsonl`

## Manager Setup

- Timestamp: 2026-06-06
- Source evidence: Subtask 049 real iPhone 17 screenshot matrix and findings.
- Worktree state at setup: clean.
- Resource health at setup: `codex_tree_zombies=23/20`, `total_zombies=25/80`; wrapper health warns against launching new workers.
- Current decision: prepare the delegation package but do not launch Claude Code until resource health recovers.

## Planned Write Scope

- `Sources/Features/FeatureTabs.swift`
- `Sources/DesignSystem/Theme.swift` only if strictly needed for a local Project Detail surface treatment
- Existing focused test file only if a helper regression fits local patterns
- This progress file

## Worker Checkpoints

Claude Code must update this file at exactly these checkpoints after launch:

- `START`
- `RED`
- `IMPLEMENTED`
- `TARGETED_VERIFIED`
- `HANDOFF`

At `HANDOFF`, include one final status token:

- `DONE`
- `DONE_WITH_CONCERNS`
- `NEEDS_CONTEXT`
- `BLOCKED`

## Acceptance Targets

- Chinese status labels in Project Detail.
- Warmer Project Detail dark card surface.
- Empty thinking-change evidence card hidden or demoted.
- Long timeline bounded with explicit show-all affordance.
- Bottom content can scroll above the floating tab bar.
- No AppStore, persistence, prompt, parser, LLM, Keychain, or Project semantic changes.

## Current Status

- Prepared for delegation.
- Not launched due resource guard warning.
- No worker code exists.
- No implementation has been accepted.
