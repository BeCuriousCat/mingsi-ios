# Subtask 068 PRD: Production Project And Growth Evidence Chain Proof

Date: 2026-06-07

## Goal

Prove the production Today completion evidence that reloads into History can continue into Projects and Growth attribution without fake conclusions or Debug-only seed state.

This extends Subtask 067. Subtask 067 proved Today -> SQLite -> History reload. Subtask 068 proves the reloaded History evidence can support:

- user-confirmed Project creation/linking from a real completed quest;
- History reload containing the resulting ProjectLink;
- local Growth attribution backed by real source ids from completed records.

## Scope

Allowed files:

- `Tests/App/AppStoreStateMachineTests.swift`
- `docs/subtasks/068-production-project-growth-evidence-chain-prd.md`
- `docs/subtasks/068-production-project-growth-evidence-chain-progress.md`
- Process docs after acceptance

Production source edits are allowed only if the RED test proves a real evidence-chain bug and the fix stays scoped to:

- `Sources/App/AppStore.swift`

Do not modify:

- Persistence migrations
- PromptProvider, prompt text, parser, LLM clients, Keychain
- SwiftUI views
- Debug visual QA launch behavior
- Project or Growth product semantics

## Acceptance Criteria

- A production-path test drives a real Today completion using SQLite repositories and the normal AppStore Today state machine.
- The test seeds only enough historical completed/verified loops to satisfy the existing Growth evidence threshold; it must not fabricate Growth conclusions.
- A fresh AppStore reloads History and finds the completed Today record with raw input, main quest, lens session, and Growth contributions.
- A Project is created from the reloaded History main quest through the existing AppStore Project API.
- Another fresh AppStore reloads History and verifies:
  - the completed Today record still exists;
  - the ProjectLink points to the real quest source id;
  - `projectNames` resolves the created Project name;
  - Growth contributions on the History record have non-empty source ids and the completed DailyEntry id as `sourceDailyEntryId`.
- Focused 068 test passes.
- Full `AppStoreStateMachineTests` pass.
- `git diff --check` passes.
- iPhone 17 simulator build passes.

## Non-Goals

- Do not claim live GLM success.
- Do not add simulator screenshots for this proof-test slice.
- Do not generate or accept AI Project/Growth claims.
- Do not change production schema, migrations, or prompt behavior.
- Do not make broader MVP completion claims.

## Delegation Decision

Claude Code is not delegated.

Reason:

- The user requested fast local implementation for the current window.
- The slice is a production evidence-chain proof over existing AppStore and repository boundaries.
- Codex owns the product semantics around Projects/Growth evidence and final acceptance.
